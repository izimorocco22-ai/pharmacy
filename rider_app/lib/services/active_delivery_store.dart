import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the rider's in-progress delivery locally so it survives the app
/// being backgrounded, closed, or killed. Cleared only when the delivery is
/// completed or found to be no longer active on the backend.
///
/// Stored locally (SharedPreferences) — never affects other devices.
class ActiveDeliveryStore {
  static const _kDelivery = 'active_delivery';
  static const _kPhase = 'active_delivery_phase';

  /// Save the full delivery map plus the current phase.
  static Future<void> save(Map<String, dynamic> delivery, String phase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDelivery, jsonEncode(delivery));
      await prefs.setString(_kPhase, phase);
    } catch (_) {}
  }

  /// Update just the phase (e.g. to_pharmacy -> to_patient) without rewriting
  /// the whole delivery map.
  static Future<void> savePhase(String phase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPhase, phase);
    } catch (_) {}
  }

  /// Returns the stored delivery map, or null if none is active.
  static Future<Map<String, dynamic>?> loadDelivery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDelivery);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Returns the stored phase, defaulting to 'to_pharmacy'.
  static Future<String> loadPhase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kPhase) ?? 'to_pharmacy';
    } catch (_) {
      return 'to_pharmacy';
    }
  }

  /// Clear the active delivery (call on delivered / cancelled).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDelivery);
      await prefs.remove(_kPhase);
    } catch (_) {}
  }
}
