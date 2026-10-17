import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/app_breakpoints.dart';
import '../../design_system/app_design_tokens.dart';
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
  static const _driverPaths = [
    '/my-trip',
    '/my-trips',
    '/my-truck',
    '/notifications',
    '/settings',
  ];
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
      icon: const Icon(Icons.today_outlined, key: Key('nav-my-trip')),
      selectedIcon: const Icon(Icons.today),
      label: context.l10n.todayWork,
    ),
    NavigationDestination(
      icon: const Icon(Icons.history_outlined, key: Key('nav-my-trips')),
      selectedIcon: const Icon(Icons.history),
      label: context.l10n.myTrips,
    ),
    NavigationDestination(
      icon: const Icon(Icons.local_shipping_outlined, key: Key('nav-my-truck')),
      selectedIcon: const Icon(Icons.local_shipping),
      label: context.l10n.myTruck,
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
      final compact = AppBreakpoints.isCompact(context);
      final authenticatedUser = ref.watch(authControllerProvider).value?.user;
      final isManager =
          authenticatedUser?.hasRole('Owner') == true ||
          authenticatedUser?.hasRole('Operations') == true;
      final hasDriver = authenticatedUser?.hasRole('Driver') == true;
      final isDriverOnly = hasDriver && !isManager;
      final tokens = context.tokens;
      final expandedManagerRail =
          isManager && AppBreakpoints.isExpanded(context);
      final paths = isDriverOnly
          ? _driverPaths
          : isManager
          ? [..._managerPaths, if (hasDriver) ..._driverPaths.take(3)]
          : _managerPaths.take(6).toList();
      final destinations = isDriverOnly
          ? _driverDestinations(context)
          : isManager
          ? [
              ..._managerDestinations(context),
              if (hasDriver) ..._driverDestinations(context).take(3),
            ]
          : _managerDestinations(context).take(6).toList();
      final currentPath = _currentPath(context);
      final pathIndex = paths.indexWhere(
        (path) =>
            currentPath == path || currentPath?.startsWith('$path/') == true,
      );
      final inferredIndex = pathIndex >= 0 ? pathIndex : selectedIndex;
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
              backgroundColor: isManager
                  ? tokens.commandBackground
                  : Theme.of(context).scaffoldBackgroundColor,
              drawer: compact && !isDriverOnly
                  ? NavigationDrawer(
                      backgroundColor: isManager ? tokens.commandSurface : null,
                      indicatorColor: isManager
                          ? tokens.commandAccent.withValues(alpha: .16)
                          : null,
                      selectedIndex: safeIndex,
                      onDestinationSelected: (index) {
                        Navigator.of(context).pop();
                        context.go(paths[index]);
                      },
                      children: [
                        if (isManager && authenticatedUser != null)
                          _ManagerWorkspaceIdentity(
                            companyName: authenticatedUser.companyName,
                            roles: authenticatedUser.roles.isEmpty
                                ? [authenticatedUser.role]
                                : authenticatedUser.roles,
                            compact: false,
                          )
                        else
                          const SizedBox(height: 12),
                        ...destinations.map(
                          (item) => NavigationDrawerDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon,
                            label: Text(item.label),
                          ),
                        ),
                      ],
                    )
                  : null,
              appBar: AppBar(
                backgroundColor: isManager ? tokens.commandSurface : null,
                foregroundColor: isManager ? tokens.commandText : null,
                surfaceTintColor: Colors.transparent,
                title: isManager && authenticatedUser != null
                    ? _ManagerWorkspaceIdentity(
                        companyName: authenticatedUser.companyName,
                        roles: authenticatedUser.roles.isEmpty
                            ? [authenticatedUser.role]
                            : authenticatedUser.roles,
                        compact: compact,
                      )
                    : Text(context.l10n.appTitle),
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
                    AccountIdentityControl(
                      user: authenticatedUser,
                      wide: !compact,
                      onDarkSurface: isManager,
                    ),
                ],
              ),
              body: !compact
                  ? Row(
                      children: [
                        NavigationRail(
                          key: isManager
                              ? const Key('atlas-manager-navigation')
                              : null,
                          backgroundColor: isManager
                              ? tokens.commandSurface
                              : null,
                          indicatorColor: isManager
                              ? tokens.commandAccent.withValues(alpha: .16)
                              : null,
                          selectedIconTheme: isManager
                              ? IconThemeData(color: tokens.commandAccent)
                              : null,
                          unselectedIconTheme: isManager
                              ? IconThemeData(color: tokens.commandTextMuted)
                              : null,
                          selectedLabelTextStyle: isManager
                              ? TextStyle(
                                  color: tokens.commandAccent,
                                  fontWeight: FontWeight.w700,
                                )
                              : null,
                          unselectedLabelTextStyle: isManager
                              ? TextStyle(color: tokens.commandTextMuted)
                              : null,
                          extended: expandedManagerRail,
                          minExtendedWidth: 220,
                          scrollable: true,
                          selectedIndex: safeIndex,
                          onDestinationSelected: (index) =>
                              context.go(paths[index]),
                          labelType: expandedManagerRail
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
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
                        VerticalDivider(
                          width: 1,
                          color: isManager ? tokens.commandBorder : null,
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: currentPath == '/dashboard' && isManager
                                ? tokens.commandBackground
                                : tokens.canvas,
                            child: child,
                          ),
                        ),
                      ],
                    )
                  : ColoredBox(
                      color: currentPath == '/dashboard' && isManager
                          ? tokens.commandBackground
                          : tokens.canvas,
                      child: child,
                    ),
              bottomNavigationBar: !compact || !isDriverOnly
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

  String? _currentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } on GoError {
      // AppShell is mounted below GoRouter in production. A null path keeps
      // standalone widget harnesses and embedders on their supplied index.
      return null;
    }
  }
}

class _ManagerWorkspaceIdentity extends StatelessWidget {
  const _ManagerWorkspaceIdentity({
    required this.companyName,
    required this.roles,
    required this.compact,
  });

  final String companyName;
  final List<String> roles;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final roleLabel = roles.map((role) => _role(context, role)).join(' / ');
    return Padding(
      key: const Key('atlas-workspace-identity'),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: compact ? 0 : tokens.space4,
        vertical: compact ? 0 : tokens.space3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.commandAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              border: Border.all(color: tokens.commandBorder),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.space2),
              child: Icon(
                Icons.radar,
                size: tokens.iconMedium,
                color: tokens.commandAccent,
              ),
            ),
          ),
          SizedBox(width: tokens.space2),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName.isEmpty ? context.l10n.appTitle : companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tokens.commandText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!compact && roleLabel.isNotEmpty)
                  Text(
                    roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.commandTextMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _role(BuildContext context, String role) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return switch (role) {
      'Owner' => arabic ? 'المالك' : 'Owner',
      'Operations' => arabic ? 'العمليات' : 'Operations',
      'Driver' => arabic ? 'السائق' : 'Driver',
      _ => role,
    };
  }
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
              Text(
                notificationCategoryLabel(
                  context,
                  notificationTypeCategory(notification.type),
                ),
                style: Theme.of(context).textTheme.labelSmall,
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
                    final destination = notificationDestination(
                      notification,
                      role: role,
                    );
                    if (destination == '/my-trip') {
                      ref.invalidate(driverTripControllerProvider);
                    }
                    if (destination != null) context.go(destination);
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

  static IconData _icon(String type) => notificationTypeIcon(type);

  static String _title(BuildContext context, String type) =>
      notificationTypeTitle(context, type);

  static String _message(
    BuildContext context,
    OperationNotification notification,
  ) => notificationSnapshotMessage(context, notification);

  static String _identity(OperationNotification notification) =>
      notificationSnapshotIdentity(notification);

  static String _time(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
