import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Handles messages received while the app is in the background or terminated.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
/// For messages that carry a `notification` payload, Android shows the system
/// tray notification automatically — nothing else is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ordogo_default',
    'Notifications',
    description: 'Order, delivery and payment updates',
    importance: Importance.high,
  );

  static bool _initialized = false;

  /// Sets up local notifications + FCM listeners. Call once at startup after
  /// Firebase has been initialized.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Local notifications are used to display messages while the app is in the
    // foreground (FCM does not show those automatically).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(settings: initSettings);

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Ask for permission (Android 13+, iOS).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages: show a local notification so the user sees it.
    FirebaseMessaging.onMessage.listen((message) {
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
  }

  /// Sends this device's FCM token to the backend. Call after the user is
  /// authenticated (a valid auth token must already be stored).
  static Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.post('/notifications/token', {'fcmToken': token});
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        ApiService.post('/notifications/token', {'fcmToken': t});
      });
    } catch (_) {}
  }

  /// Clears the token on the backend (call on logout).
  static Future<void> unregisterToken() async {
    try {
      await ApiService.delete('/notifications/token');
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
