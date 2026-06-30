import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationsListScreen extends StatefulWidget {
  const NotificationsListScreen({super.key});

  @override
  State<NotificationsListScreen> createState() =>
      _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen> {
  bool _loading = true;
  List<AppNotification> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final res = await NotificationService.fetch();
    if (!mounted) return;
    setState(() {
      _items = res.notifications;
      _loading = false;
    });
    // Mark everything read once the list has been opened.
    if (res.unreadCount > 0) {
      await NotificationService.markAllRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) => _tile(_items[i]),
                    ),
            ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none,
                    size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('No notifications yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  "We'll let you know when something happens.",
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final (icon, color) = _visual(n.type);
    return Container(
      color: n.isRead ? null : AppTheme.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(n.body,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Text(_timeAgo(n.createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  (IconData, Color) _visual(String type) {
    switch (type) {
      case 'quote_received':
      case 'quote_updated':
        return (Icons.receipt_long, AppTheme.info);
      case 'prescription_submitted':
        return (Icons.upload_file, AppTheme.primary);
      case 'prescription_request':
        return (Icons.assignment_outlined, AppTheme.warning);
      case 'prescription_reassigned':
        return (Icons.swap_horiz, AppTheme.info);
      case 'prescription_expired':
      case 'quote_expired':
        return (Icons.timer_off_outlined, AppTheme.error);
      case 'rider_assigned':
      case 'rider_coming':
      case 'delivery_available':
        return (Icons.delivery_dining, AppTheme.info);
      case 'order_confirmed':
      case 'payment_confirmed':
        return (Icons.check_circle_outline, AppTheme.success);
      case 'payment_proof_received':
        return (Icons.payments_outlined, AppTheme.warning);
      case 'order_picked_up':
        return (Icons.shopping_bag_outlined, AppTheme.info);
      case 'order_in_transit':
        return (Icons.local_shipping_outlined, AppTheme.info);
      case 'order_delivered':
        return (Icons.done_all, AppTheme.success);
      case 'order_cancelled':
      case 'quote_cancelled':
        return (Icons.cancel_outlined, AppTheme.error);
      default:
        return (Icons.notifications_outlined, AppTheme.primary);
    }
  }
}
