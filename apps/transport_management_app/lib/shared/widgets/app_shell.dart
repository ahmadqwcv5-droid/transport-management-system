import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../l10n/l10n_extensions.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.selectedIndex, super.key});
  final Widget child;
  final int selectedIndex;

  static const _paths = [
    '/dashboard',
    '/clients',
    '/trucks',
    '/drivers',
    '/trips',
    '/settings',
  ];
  List<NavigationDestination> _destinations(BuildContext context) => [
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

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.appTitle),
          actions: [
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
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) => context.go(_paths[index]),
                    labelType: NavigationRailLabelType.all,
                    destinations: _destinations(context)
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
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) => context.go(_paths[index]),
                destinations: _destinations(context),
              ),
      );
    },
  );
}
