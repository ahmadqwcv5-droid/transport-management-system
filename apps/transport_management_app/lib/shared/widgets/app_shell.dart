import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final content = const DashboardScreen();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transport Management'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
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
                    selectedIndex: 0,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Dashboard'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  const Expanded(child: DashboardScreen()),
                ],
              )
            : content,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                ],
              ),
      );
    },
  );
}
