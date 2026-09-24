import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/clients/presentation/clients_screen.dart';
import 'features/clients/presentation/client_details_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/fleet/drivers/presentation/drivers_screen.dart';
import 'features/fleet/trucks/presentation/trucks_screen.dart';
import 'features/fleet/trucks/presentation/truck_details_screen.dart';
import 'features/trips/presentation/trip_details_screen.dart';
import 'features/trips/presentation/trip_planner_screen.dart';
import 'features/trips/presentation/trips_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/live_operations/presentation/driver_my_trip_screen.dart';
import 'features/live_operations/presentation/notifications_screen.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRouteState = ref.watch(
    authControllerProvider.select(
      (auth) => (
        isLoading: auth.isLoading,
        signedIn: auth.value != null,
        role: auth.value?.user.role,
      ),
    ),
  );
  final signedIn = authRouteState.signedIn;
  return GoRouter(
    initialLocation: signedIn
        ? (authRouteState.role == 'Driver' ? '/my-trip' : '/dashboard')
        : '/login',
    redirect: (context, state) {
      if (authRouteState.isLoading) return null;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn && !onLogin) return '/login';
      if (signedIn && onLogin) {
        return authRouteState.role == 'Driver' ? '/my-trip' : '/dashboard';
      }
      final driver = authRouteState.role == 'Driver';
      final driverRoute =
          state.matchedLocation == '/my-trip' ||
          state.matchedLocation == '/notifications' ||
          state.matchedLocation == '/settings';
      if (driver && !driverRoute) return '/my-trip';
      if (!driver && state.matchedLocation == '/my-trip') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) =>
            const AppShell(selectedIndex: 0, child: DashboardScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) =>
            const AppShell(selectedIndex: 5, child: SettingsScreen()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) =>
            const AppShell(selectedIndex: -1, child: NotificationsScreen()),
      ),
      GoRoute(
        path: '/my-trip',
        builder: (_, _) =>
            const AppShell(selectedIndex: 0, child: DriverMyTripScreen()),
      ),
      GoRoute(
        path: '/clients',
        builder: (_, _) =>
            const AppShell(selectedIndex: 1, child: ClientsScreen()),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => AppShell(
              selectedIndex: 1,
              child: ClientDetailsScreen(clientId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/trucks',
        builder: (_, _) =>
            const AppShell(selectedIndex: 2, child: TrucksScreen()),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => AppShell(
              selectedIndex: 2,
              child: TruckDetailsScreen(truckId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/drivers',
        builder: (_, _) =>
            const AppShell(selectedIndex: 3, child: DriversScreen()),
      ),
      GoRoute(
        path: '/trips',
        builder: (_, _) =>
            const AppShell(selectedIndex: 4, child: TripsScreen()),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) =>
                const AppShell(selectedIndex: 4, child: TripPlannerScreen()),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => AppShell(
              selectedIndex: 4,
              child: TripPlannerScreen(tripId: state.pathParameters['id']),
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => AppShell(
              selectedIndex: 4,
              child: TripDetailsScreen(tripId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});

class TransportManagementApp extends ConsumerWidget {
  const TransportManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferredLocale =
        ref.watch(authControllerProvider).value?.user.preferredLocale ?? 'en';
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: Locale(preferredLocale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF175CD3)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
