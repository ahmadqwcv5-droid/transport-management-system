import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
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
      GoRoute(path: '/dashboard', builder: (_, _) => const AppShell()),
    ],
  );
});

class TransportManagementApp extends ConsumerWidget {
  const TransportManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Transport Management',
    debugShowCheckedModeBanner: false,
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
