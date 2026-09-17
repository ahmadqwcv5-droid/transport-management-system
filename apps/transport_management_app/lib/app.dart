import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/clients/presentation/clients_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/fleet/drivers/presentation/drivers_screen.dart';
import 'features/fleet/trucks/presentation/trucks_screen.dart';
import 'features/trips/presentation/trip_details_screen.dart';
import 'features/trips/presentation/trips_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final signedIn = auth.value != null;
  return GoRouter(
    initialLocation: signedIn ? '/dashboard' : '/login',
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn && !onLogin) return '/login';
      if (signedIn && onLogin) return '/dashboard';
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
        path: '/clients',
        builder: (_, _) =>
            const AppShell(selectedIndex: 1, child: ClientsScreen()),
      ),
      GoRoute(
        path: '/trucks',
        builder: (_, _) =>
            const AppShell(selectedIndex: 2, child: TrucksScreen()),
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
