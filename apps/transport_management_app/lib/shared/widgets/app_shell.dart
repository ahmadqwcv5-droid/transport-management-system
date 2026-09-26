import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../l10n/l10n_extensions.dart';
import '../../features/live_operations/presentation/live_operations_controller.dart';
import '../../features/live_operations/domain/live_operations_models.dart';
import '../../features/live_operations/presentation/notification_snapshot_text.dart';
import 'account_identity_control.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.selectedIndex, super.key});
  final Widget child;
  final int selectedIndex;

  static const _managerPaths = [
    '/dashboard',
    '/clients',
    '/trucks',
    '/drivers',
    '/trips',
    '/settings',
    '/company-users',
  ];
  static const _driverPaths = ['/my-trip', '/notifications', '/settings'];
  List<NavigationDestination> _managerDestinations(BuildContext context) => [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined, key: Key('nav-dashboard')),
      selectedIcon: Icon(Icons.dashboard),
      label: context.l10n.dashboard,
    ),
    NavigationDestination(
      icon: Icon(Icons.business_outlined, key: Key('nav-clients')),
      selectedIcon: Icon(Icons.business),
      label: context.l10n.clients,
    ),
    NavigationDestination(
      icon: Icon(Icons.local_shipping_outlined, key: Key('nav-trucks')),
      selectedIcon: Icon(Icons.local_shipping),
      label: context.l10n.trucks,
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline, key: Key('nav-drivers')),
      selectedIcon: Icon(Icons.people),
      label: context.l10n.drivers,
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined, key: Key('nav-trips')),
      selectedIcon: Icon(Icons.route),
      label: context.l10n.trips,
    ),
    NavigationDestination(
      icon: const Icon(Icons.settings_outlined, key: Key('nav-settings')),
      selectedIcon: const Icon(Icons.settings),
      label: context.l10n.settings,
    ),
    NavigationDestination(
      icon: const Icon(
        Icons.manage_accounts_outlined,
        key: Key('nav-company-users'),
      ),
      selectedIcon: const Icon(Icons.manage_accounts),
      label: context.l10n.companyUsers,
    ),
  ];

  List<NavigationDestination> _driverDestinations(BuildContext context) => [
    NavigationDestination(
      icon: const Icon(Icons.route_outlined, key: Key('nav-my-trip')),
      selectedIcon: const Icon(Icons.route),
      label: context.l10n.myTrip,
    ),
    NavigationDestination(
      icon: const Icon(
        Icons.notifications_outlined,
        key: Key('nav-notifications'),
      ),
      selectedIcon: const Icon(Icons.notifications),
      label: context.l10n.notifications,
    ),
    NavigationDestination(
      icon: const Icon(Icons.settings_outlined, key: Key('nav-settings')),
      selectedIcon: const Icon(Icons.settings),
      label: context.l10n.settings,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final authenticatedUser = ref.watch(authControllerProvider).value?.user;
      final isDriver = authenticatedUser?.role == 'Driver';
      final isOwner = authenticatedUser?.role == 'Owner';
      final paths = isDriver
          ? _driverPaths
          : isOwner
          ? _managerPaths
          : _managerPaths.take(6).toList();
      final destinations = isDriver
          ? _driverDestinations(context)
          : isOwner
          ? _managerDestinations(context)
          : _managerDestinations(context).take(6).toList();
      final inferredIndex = selectedIndex < 0
          ? paths.indexOf('/notifications')
          : selectedIndex;
      final safeIndex = inferredIndex < 0 || inferredIndex >= paths.length
          ? 0
          : inferredIndex;
      // AppShell is only routed after authentication in production. Keeping
      // this conditional also avoids starting an unauthorized poll while auth
      // is restoring (and makes the shell deterministic in widget tests).
      final unread = authenticatedUser == null
          ? 0
          : ref
                    .watch(notificationControllerProvider)
                    .value
                    ?.items
                    .where((item) => item.isUnread)
                    .length ??
                0;
      final alert = ref.watch(operationalAlertControllerProvider);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (authenticatedUser?.notificationSoundsEnabled == true) {
            ref.read(operationalAlertControllerProvider.notifier).unlockSound();
          }
        },
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.appTitle),
                actions: [
                  Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    child: IconButton(
                      key: const Key('notifications-button'),
                      tooltip: context.l10n.notifications,
                      onPressed: () => context.go('/notifications'),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                  if (authenticatedUser != null)
                    AccountIdentityControl(user: authenticatedUser, wide: wide),
                ],
              ),
              body: wide
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: safeIndex,
                          onDestinationSelected: (index) =>
                              context.go(paths[index]),
                          labelType: NavigationRailLabelType.all,
                          destinations: destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: item.icon,
                                  selectedIcon: item.selectedIcon,
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: child),
                      ],
                    )
                  : child,
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: safeIndex,
                      onDestinationSelected: (index) =>
                          context.go(paths[index]),
                      destinations: destinations,
                    ),
            ),
            if (alert.current != null)
              PositionedDirectional(
                key: const Key('operational-alert-overlay'),
                top: 76,
                end: 16,
                width: constraints.maxWidth < 460
                    ? constraints.maxWidth - 32
                    : 400,
                child: _OperationalAlertCard(alert.current!),
              ),
          ],
        ),
      );
    },
  );
}

class _OperationalAlertCard extends ConsumerWidget {
  const _OperationalAlertCard(this.notification);
  final OperationNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final severity = notification.severity.toLowerCase();
    final color = switch (severity) {
      'critical' => Theme.of(context).colorScheme.error,
      'warning' => Colors.orange.shade800,
      'success' => Colors.green.shade700,
      _ => Theme.of(context).colorScheme.primary,
    };
    final blocked = ref.watch(operationalAlertControllerProvider).soundBlocked;
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: BorderDirectional(start: BorderSide(color: color, width: 5)),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon(notification.type), color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _title(context, notification.type),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const Key('dismiss-operational-alert'),
                    tooltip: context.l10n.dismiss,
                    onPressed: ref
                        .read(operationalAlertControllerProvider.notifier)
                        .dismiss,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(_message(context, notification)),
              if (_identity(notification).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _identity(notification),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _time(notification.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (blocked)
                TextButton.icon(
                  key: const Key('enable-notification-sound'),
                  onPressed: ref
                      .read(operationalAlertControllerProvider.notifier)
                      .unlockSound,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: Text(context.l10n.enableNotificationSound),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('view-operational-alert'),
                  onPressed: () async {
                    if (notification.isUnread) {
                      await ref
                          .read(notificationControllerProvider.notifier)
                          .markRead(notification.id);
                    }
                    ref
                        .read(operationalAlertControllerProvider.notifier)
                        .dismiss();
                    if (!context.mounted) return;
                    final role = ref
                        .read(authControllerProvider)
                        .value
                        ?.user
                        .role;
                    if (role == 'Driver') {
                      ref.invalidate(driverTripControllerProvider);
                      context.go('/my-trip');
                    } else if (notification.tripId != null) {
                      context.go('/trips/${notification.tripId}');
                    } else if (notification.truckId != null) {
                      context.go('/trucks/${notification.truckId}');
                    }
                  },
                  child: Text(
                    notification.type == 'TripAssignedToDriver'
                        ? context.l10n.openTrip
                        : context.l10n.view,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
    'TruckArrivedAtPickup' || 'TruckArrivedAtDelivery' => Icons.location_on,
    'DriverConfirmedDelivery' => Icons.task_alt,
    'TripAssignedToDriver' => Icons.assignment_ind_outlined,
    'TruckBecameOffline' => Icons.signal_wifi_connected_no_internet_4,
    'TruckPositionBecameStale' => Icons.update_disabled,
    _ => Icons.notifications_active,
  };

  static String _title(BuildContext context, String type) => switch (type) {
    'TruckArrivedAtPickup' => context.l10n.notificationArrivedPickup,
    'TruckArrivedAtDelivery' => context.l10n.notificationArrivedDelivery,
    'DriverConfirmedDeparture' => context.l10n.notificationDepartureConfirmed,
    'DriverConfirmedDelivery' => context.l10n.notificationDeliveryConfirmed,
    'TripAssignedToDriver' => context.l10n.notificationTripAssigned,
    'TruckBecameOffline' => context.l10n.notificationTruckOffline,
    'TruckPositionBecameStale' => context.l10n.notificationPositionStale,
    _ => context.l10n.operationalUpdate,
  };

  static String _message(
    BuildContext context,
    OperationNotification notification,
  ) => notification.type == 'TripAssignedToDriver'
      ? context.l10n.assignmentRequiresDeparture
      : notification.tripId == null
      ? context.l10n.operationalAlertMessage
      : context.l10n.operationalTripAlertMessage;

  static String _identity(OperationNotification notification) =>
      notificationSnapshotIdentity(notification);

  static String _time(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
