import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transport_management_app/features/auth/domain/auth_session.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/driver_my_trip_screen.dart';
import 'package:transport_management_app/features/live_operations/presentation/live_operations_controller.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';
import 'package:transport_management_app/shared/widgets/app_shell.dart';

void main() {
  testWidgets(
    'assignment alert explicitly opens and refreshes Driver workspace',
    (tester) async {
      final notification = OperationNotification(
        id: 'notification-1',
        type: 'TripAssignedToDriver',
        severity: 'Information',
        createdAt: '2026-09-25T12:00:00Z',
        tripId: 'trip-1',
        truckId: 'truck-1',
        driverId: 'driver-1',
        dataJson: '{"tripNumber":"TRP-2026-000001","plateNumber":"06 TEST 01"}',
      );
      final notifications = FakeNotificationController(notification);
      final driver = FakeDriverController();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(FakeDriverAuthController.new),
          notificationControllerProvider.overrideWith(() => notifications),
          driverTripControllerProvider.overrideWith(() => driver),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(operationalAlertControllerProvider.notifier)
          .enqueue(notification, soundEnabled: false);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AppShell(
              selectedIndex: 0,
              child: Center(child: Text('Driver home')),
            ),
          ),
          GoRoute(
            path: '/my-trip',
            builder: (_, _) =>
                const AppShell(selectedIndex: 0, child: DriverMyTripScreen()),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Open trip'), findsOneWidget);
      expect(
        find.text(
          'Open the trip and confirm departure before the truck starts moving.',
        ),
        findsOneWidget,
      );
      expect(find.text('TRP-2026-000001 · 06 TEST 01'), findsOneWidget);

      await tester.tap(find.text('Open trip'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/my-trip');
      expect(notifications.markReadCalls, 1);
      expect(driver.buildCalls, 1);
      expect(find.text('No active trip is assigned to you'), findsOneWidget);
    },
  );
}

class FakeDriverAuthController extends AuthController {
  @override
  FutureOr<AuthSession?> build() => const AuthSession(
    user: CurrentUser(
      id: 'user-1',
      companyId: 'company-1',
      email: 'driver@example.test',
      displayName: 'Driver',
      role: 'Driver',
      preferredLocale: 'en',
    ),
  );
}

class FakeNotificationController extends NotificationController {
  FakeNotificationController(this.notification);
  final OperationNotification notification;
  int markReadCalls = 0;

  @override
  Future<NotificationPage> build() async =>
      NotificationPage(items: [notification], totalCount: 1);

  @override
  Future<void> markRead(String id) async {
    markReadCalls++;
  }
}

class FakeDriverController extends DriverTripController {
  int buildCalls = 0;

  @override
  Future<DriverWorkspace> build() async {
    buildCalls++;
    return const DriverWorkspace(
      state: 'NO_ACTIVE_TRIP',
      trackingState: 'NoTrip',
      allowedActions: [],
    );
  }
}
