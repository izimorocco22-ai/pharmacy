import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationService {
  static Timer? _timer;
  static bool _isTracking = false;

  /// Request location permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Get current position once.
  static Future<Position?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  /// Send the current location to the backend.
  ///
  /// [isOnline] is intentionally nullable and defaults to null: a plain
  /// location ping must NOT change the rider's online/offline status. Only the
  /// explicit availability toggle passes a value here. The backend leaves
  /// isOnline unchanged when it is not sent.
  static Future<void> updateLocation({bool? isOnline}) async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    final body = <String, dynamic>{
      'lat': pos.latitude,
      'lng': pos.longitude,
    };
    if (isOnline != null) body['isOnline'] = isOnline;
    await ApiService.put('/rider/update-location', body);
  }

  /// Start periodic location updates every 30 seconds. These only refresh the
  /// rider's coordinates — they never change the online/offline status.
  static void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    updateLocation(); // send immediately (location only)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => updateLocation());
  }

  /// Stop the location timer only — does NOT mark rider offline.
  /// Call markOffline() separately when rider manually goes offline.
  static void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _isTracking = false;
  }

  /// Mark the rider offline on the backend. Sends only the status so the
  /// last known location is preserved.
  static Future<void> markOffline() async {
    stopTracking();
    await ApiService.put('/rider/update-location', {
      'isOnline': false,
    });
  }

  static bool get isTracking => _isTracking;
}
