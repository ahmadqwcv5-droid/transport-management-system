import 'package:flutter/material.dart';

import 'notification_snapshot_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../../l10n/l10n_extensions.dart';
import '../domain/live_operations_models.dart';
import 'live_operations_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationControllerProvider);
    return notifications.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(context.l10n.genericError)),
      data: (page) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.notifications,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton.icon(
                  key: const Key('notifications-read-all'),
                  onPressed: page.items.any((item) => item.isUnread)
                      ? () => ref
                            .read(notificationControllerProvider.notifier)
                            .markAllRead()
                      : null,
                  icon: const Icon(Icons.done_all),
                  label: Text(context.l10n.markAllRead),
                ),
              ],
            ),
          ),
          Expanded(
            child: page.items.isEmpty
                ? Center(child: Text(context.l10n.noNotifications))
                : RefreshIndicator(
                    onRefresh: ref
                        .read(notificationControllerProvider.notifier)
                        .refresh,
                    child: ListView.builder(
                      itemCount: page.items.length,
                      itemBuilder: (_, index) =>
                          _NotificationTile(page.items[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.notification);
  final OperationNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: Key('notification-${notification.id}'),
    leading: Icon(
      notification.isUnread
          ? Icons.notifications_active
          : Icons.notifications_none,
    ),
    title: Text(notificationTypeTitle(context, notification.type)),
    subtitle: Text(
      [
        notificationCategoryLabel(
          context,
          notificationTypeCategory(notification.type),
        ),
        if (notification.type == 'TripAssignedToDriver')
          context.l10n.assignmentRequiresDeparture,
        notificationSnapshotDetail(context, notification),
        _formatTime(notification.createdAt),
      ].where((value) => value.isNotEmpty).join('\n'),
    ),
    selected: notification.isUnread,
    trailing: notification.type == 'TripAssignedToDriver'
        ? TextButton(
            key: const Key('open-assigned-trip'),
            onPressed: () => _open(context, ref),
            child: Text(context.l10n.openTrip),
          )
        : notification.isUnread
        ? IconButton(
            tooltip: context.l10n.markRead,
            onPressed: () => ref
                .read(notificationControllerProvider.notifier)
                .markRead(notification.id),
            icon: const Icon(Icons.done),
          )
        : null,
    onTap: () => _open(context, ref),
  );

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (notification.isUnread) {
      await ref
          .read(notificationControllerProvider.notifier)
          .markRead(notification.id);
    }
    if (!context.mounted) return;
    final role = ref.read(authControllerProvider).value?.user.role;
    final destination = notificationDestination(notification, role: role);
    if (destination == '/my-trip') ref.invalidate(driverTripControllerProvider);
    if (destination != null) context.go(destination);
  }

  String _formatTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
