import 'package:flutter/material.dart';

import '../../models/session_user.dart';
import '../../services/app_notification_service.dart';
import '../../services/session_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final AppNotificationService _notifications = AppNotificationService.instance;
  SessionUser? _session;

  @override
  void initState() {
    super.initState();
    _notifications.addListener(_onChanged);
    _loadSession();
  }

  @override
  void dispose() {
    _notifications.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = await SessionService().getSession();
    if (!mounted) return;
    setState(() => _session = session);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _formatTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _notifications.notificationsFor(_session);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: visibleItems.isEmpty
          ? const Center(child: Text('No notifications yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(item.title),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item.message),
                    ),
                    trailing: Text(
                      _formatTime(item.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
