import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/notifications/notifications_list_screen.dart';
import 'api_service.dart';

/// Handles messages received while the app is in the background or terminated.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
/// For messages that carry a `notification` payload, the OS shows the system
/// tray notification automatically — nothing else is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Tracks the route currently on top so a notification tap that *launched* the
/// app can wait for the splash screen to hand over to the real first screen.
/// The splash screens finish with `pushReplacementNamed`, which replaces the
/// top-most route — so anything pushed while the splash is still showing is
/// silently thrown away.
class _TopRouteObserver extends NavigatorObserver {
  Route<dynamic>? _top;

  /// Name of the top-most route, or null when it was pushed without one.
  String? get topRouteName => _top?.settings.name;

  /// True once the app has routed away from the splash (`/`).
  bool get isPastSplash => _top != null && _top!.settings.name != '/';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _top = route;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _top = newRoute;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _top = previousRoute;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _top)) _top = previousRoute;
  }
}

class PushNotificationService {
  /// Attached to MaterialApp.navigatorKey so taps on notifications can
  /// navigate even when no BuildContext is at hand.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final _TopRouteObserver _routeObserver = _TopRouteObserver();

  /// Attach to MaterialApp.navigatorObservers so a tap that launched the app
  /// can tell when the splash screen has finished routing.
  static NavigatorObserver get routeObserver => _routeObserver;

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ordogo_default',
    'Notifications',
    description: 'Order, delivery and payment updates',
    importance: Importance.high,
  );

  static bool _initialized = false;
  static bool _tokenListenerAttached = false;

  /// The token this device last registered. Remembered so logout can remove
  /// just this device server-side without calling getToken() again (which can
  /// hang on iOS when APNs is not ready).
  static String? _currentToken;

  /// Sets up local notifications + FCM listeners. Call once at startup after
  /// Firebase has been initialized.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Local notifications render foreground messages on Android. iOS is told
    // to present them itself (see setForegroundNotificationPresentationOptions
    // below), so the Darwin side only needs to exist for notification taps —
    // its permission prompts are all disabled here so the user is not asked
    // twice (FirebaseMessaging.requestPermission does the asking).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _local.initialize(
      settings: initSettings,
      // Tap on a notification shown while the app was in the foreground. The
      // local notification carries the FCM data map as its JSON payload, so we
      // decode it and deep-link to the relevant screen.
      onDidReceiveNotificationResponse: (response) {
        _handleTapWhenReady(_decodePayload(response.payload));
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Ask for permission (Android 13+, iOS). On iOS nothing is ever delivered
    // until the user authorises, so surface the outcome in the logs.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '[push] notification permission: ${settings.authorizationStatus}');

    // iOS suppresses notifications for the app that is currently in the
    // foreground unless it is explicitly told to present them. Without this
    // call, a message that arrives while the user is looking at the app is
    // silently dropped on iOS.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages. On iOS the system now draws the banner itself, so
    // showing a local notification as well would display it twice.
    FirebaseMessaging.onMessage.listen((message) {
      if (!Platform.isAndroid) return;
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // Tap on the system notification while the app was in the BACKGROUND.
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleTapWhenReady(message.data));

    // Tap on the system notification while the app was TERMINATED: the tap is
    // what launched the app, so navigate once the splash screen has routed.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleTapWhenReady(initialMessage.data);
    }
  }

  /// Opens the notifications screen as soon as it can survive being pushed.
  ///
  /// A fixed delay cannot work here: the splash screen finishes with
  /// `pushReplacementNamed`, which discards whatever sits on top of it, and how
  /// long it takes depends on auth checks and network calls that vary per app
  /// and per device. So wait for the route to actually change instead of
  /// guessing, and give up rather than navigate somewhere surprising.
  static Future<void> _handleTapWhenReady(Map<String, dynamic> data) async {
    for (var attempt = 0; attempt < 120; attempt++) {
      if (navigatorKey.currentState != null && _routeObserver.isPastSplash) {
        // A signed-out user lands on /login: deep targets would only 401 there,
        // so leave the login form alone.
        if (_routeObserver.topRouteName != '/login') _navigateForData(data);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('[push] gave up waiting for the navigator to leave the splash');
  }

  /// Convert the local-notification JSON payload back into the FCM data map.
  static Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  /// Deep-links a notification tap to the order's detail screen. The pharmacy
  /// order-detail screen needs the full order object and there is no
  /// fetch-by-id endpoint, so we load the orders list and find the match.
  /// Falls back to the notifications list when it can't be resolved.
  /// Pure routing decision for a notification payload. Returns 'order-detail'
  /// when the payload carries an orderId, else 'notifications'. Exposed for
  /// unit testing.
  @visibleForTesting
  static String deepLinkDecision(Map<String, dynamic> data) {
    final orderId = data['orderId']?.toString();
    if (orderId != null && orderId.isNotEmpty) return 'order-detail';
    return 'notifications';
  }

  static Future<void> _navigateForData(Map<String, dynamic> data) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final orderId = data['orderId']?.toString();

    if (deepLinkDecision(data) == 'order-detail') {
      try {
        final res = await ApiService.get('/pharmacy/orders');
        if (res.success && res.data != null) {
          final orders = (res.data['orders'] as List? ?? []);
          for (final o in orders) {
            final m = Map<String, dynamic>.from(o as Map);
            if (m['id']?.toString() == orderId ||
                m['_id']?.toString() == orderId) {
              nav.pushNamed('/order-detail', arguments: m);
              return;
            }
          }
        }
      } catch (_) {}
    }
    // Prescription requests / anything unresolved: show the notifications list.
    _openNotifications();
  }

  static void _openNotifications() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsListScreen()),
    );
  }

  /// On iOS, FCM cannot mint a registration token until APNs has handed the
  /// app a device token. Calling getToken() before that throws
  /// `apns-token-not-set` — the single most common reason an iOS build
  /// registers no token and therefore never receives a push. APNs normally
  /// answers in well under a second; allow up to ~10s on a cold start.
  static Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null) return apns;
      } catch (e) {
        debugPrint('[push] getAPNSToken failed: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// The language the user picked in the app, as LanguageProvider stores it.
  /// Sent to the backend with the token so push notifications arrive in that
  /// language — the server has no other way of knowing which one is in use.
  static Future<String> _currentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('language_code') ?? 'en';
    } catch (e) {
      debugPrint('[push] could not read language: $e');
      return 'en';
    }
  }

  /// Sends this device's FCM token to the backend. Call after the user is
  /// authenticated (a valid auth token must already be stored).
  static Future<void> registerToken() async {
    // Attach the refresh listener first and only once: if the token is not
    // available yet (or this call fails), a later refresh still reaches the
    // backend. Re-attaching on every home-screen mount would post the token
    // once per listener.
    if (!_tokenListenerAttached) {
      _tokenListenerAttached = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        try {
          _currentToken = t;
          await ApiService.post('/notifications/token', {'fcmToken': t, 'language': await _currentLanguage()});
        } catch (e) {
          debugPrint('[push] token refresh upload failed: $e');
        }
      });
    }

    try {
      if (Platform.isIOS) {
        final apns = await _waitForApnsToken();
        if (apns == null) {
          // Either the user denied notifications, the build is missing the
          // Push Notifications capability / an APNs key in Firebase, or the
          // aps-environment entitlement does not match the build type.
          debugPrint('[push] no APNs token — iOS push cannot be registered');
          return;
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[push] FCM returned a null token');
        return;
      }
      _currentToken = token;
      await ApiService.post('/notifications/token', {'fcmToken': token, 'language': await _currentLanguage()});
      debugPrint('[push] FCM token registered');
    } catch (e) {
      debugPrint('[push] registerToken failed: $e');
    }
  }

  /// Clears the token on the backend (call on logout).
  static Future<void> unregisterToken() async {
    // Each step is time-limited so a slow network or a stuck FCM/APNs state
    // can never hang a caller (e.g. logout).
    try {
      // Pass this device's token so only this device is unsubscribed —
      // otherwise logging out on one phone would kill push on every other
      // device signed into the same account.
      final path = _currentToken == null
          ? '/notifications/token'
          : '/notifications/token?token=${Uri.encodeQueryComponent(_currentToken!)}';
      await ApiService.delete(path).timeout(const Duration(seconds: 5));
      _currentToken = null;
    } catch (e) {
      debugPrint('[push] token delete on backend failed: $e');
    }
    try {
      await FirebaseMessaging.instance
          .deleteToken()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[push] FCM deleteToken failed: $e');
    }
  }
}
