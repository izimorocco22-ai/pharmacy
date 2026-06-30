import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../features/notifications/notifications_list_screen.dart';

/// A bell icon with an unread-count badge. Tapping it opens the notifications
/// list. The badge refreshes when the user returns, every 30 seconds, and when
/// the app comes back to the foreground, so new notifications show up promptly.
class NotificationBell extends StatefulWidget {
  final Color iconColor;
  const NotificationBell({super.key, this.iconColor = Colors.white});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCount();
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => _loadCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadCount();
  }

  Future<void> _loadCount() async {
    final res = await NotificationService.fetch();
    if (mounted) setState(() => _unread = res.unreadCount);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsListScreen()),
    );
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            _unread > 0 ? Icons.notifications : Icons.notifications_outlined,
            color: widget.iconColor,
          ),
          onPressed: _open,
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unread > 9 ? '9+' : '$_unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
