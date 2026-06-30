import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationResult {
  final List<AppNotification> notifications;
  final int unreadCount;
  const NotificationResult(this.notifications, this.unreadCount);
}

class NotificationService {
  /// Fetches the current user's notifications plus the unread count.
  static Future<NotificationResult> fetch() async {
    final res = await ApiService.get('/notifications');
    if (res.success && res.data != null) {
      final list = (res.data['notifications'] as List? ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final unread = (res.data['unreadCount'] as num?)?.toInt() ?? 0;
      return NotificationResult(list, unread);
    }
    return const NotificationResult([], 0);
  }

  /// Marks all of the user's notifications as read.
  static Future<void> markAllRead() async {
    await ApiService.post('/notifications/read', {});
  }
}
