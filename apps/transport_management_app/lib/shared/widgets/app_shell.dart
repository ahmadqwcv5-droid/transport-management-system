import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../l10n/l10n_extensions.dart';
import '../../features/live_operations/presentation/live_operations_controller.dart';

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
      final paths = isDriver ? _driverPaths : _managerPaths;
      final destinations = isDriver
          ? _driverDestinations(context)
          : _managerDestinations(context);
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
      return Scaffold(
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
            IconButton(
              key: const Key('logout-button'),
              tooltip: context.l10n.signOut,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: safeIndex,
                    onDestinationSelected: (index) => context.go(paths[index]),
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
                onDestinationSelected: (index) => context.go(paths[index]),
                destinations: destinations,
              ),
      );
    },
  );
}
