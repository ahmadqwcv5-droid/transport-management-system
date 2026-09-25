import 'package:flutter/material.dart';
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
    title: Text(_title(context, notification.type)),
    subtitle: Text(
      notification.type == 'TripAssignedToDriver'
          ? '${context.l10n.assignmentRequiresDeparture}\n${_formatTime(notification.createdAt)}'
          : _formatTime(notification.createdAt),
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
    if (role == 'Driver') {
      ref.invalidate(driverTripControllerProvider);
      context.go('/my-trip');
    } else if (notification.tripId != null) {
      context.go('/trips/${notification.tripId}');
    } else if (notification.truckId != null) {
      context.go('/trucks/${notification.truckId}');
    }
  }

  String _title(BuildContext context, String type) => switch (type) {
    'TruckArrivedAtPickup' => context.l10n.notificationArrivedPickup,
    'TruckArrivedAtDelivery' => context.l10n.notificationArrivedDelivery,
    'DriverConfirmedDeparture' => context.l10n.notificationDepartureConfirmed,
    'DriverConfirmedDelivery' => context.l10n.notificationDeliveryConfirmed,
    'TripAssignedToDriver' => context.l10n.notificationTripAssigned,
    'TruckBecameOffline' => context.l10n.notificationTruckOffline,
    'TruckPositionBecameStale' => context.l10n.notificationPositionStale,
    _ => context.l10n.operationalUpdate,
  };

  String _formatTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
