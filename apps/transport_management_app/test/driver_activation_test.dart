import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/driver_my_trip_screen.dart';
import 'package:transport_management_app/features/live_operations/presentation/live_operations_controller.dart';
import 'package:transport_management_app/features/trips/domain/trip_models.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'assigned trip exposes primary departure before map on compact UI',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = FakeDriverTripController(workspace());

      await tester.pumpWidget(localized(fake));
      await tester.pump();

      final panel = find.byKey(const Key('driver-departure-panel'));
      final button = find.byKey(const Key('confirm-departure-to-pickup'));
      final map = find.byKey(const Key('driver-map-unavailable'));
      expect(panel, findsOneWidget);
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(panel).dy, lessThan(tester.getTopLeft(map).dy));
      expect(
        find.text(
          'The truck will not start moving until you confirm departure.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('blocked telemetry remains visible with actionable guidance', (
    tester,
  ) async {
    final fake = FakeDriverTripController(
      workspace(blockingReason: 'TRUCK_POSITION_REQUIRED'),
    );
    await tester.pumpWidget(localized(fake));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-departure-to-pickup')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.textContaining('Ask the manager to set or refresh'),
      findsOneWidget,
    );
  });

  testWidgets('Arabic assignment panel is RTL and localized', (tester) async {
    final fake = FakeDriverTripController(
      workspace(blockingReason: 'TRUCK_OFFLINE'),
    );
    await tester.pumpWidget(localized(fake, locale: const Locale('ar')));
    await tester.pump();

    final panel = find.byKey(const Key('driver-departure-panel'));
    expect(Directionality.of(tester.element(panel)), TextDirection.rtl);
    expect(find.text('تم إسناد الرحلة إليك'), findsOneWidget);
    expect(find.textContaining('نظام تتبع الشاحنة غير متصل'), findsOneWidget);
  });

  testWidgets('stale telemetry and repeated poll warning remain actionable', (
    tester,
  ) async {
    final fake = FakeDriverTripController(
      workspace(
        blockingReason: 'TRUCK_POSITION_STALE',
      ).copyWithUiState(connectionWarning: true),
    );
    await tester.pumpWidget(localized(fake));
    await tester.pump();

    expect(find.textContaining('too old to start safely'), findsOneWidget);
    expect(
      find.byKey(const Key('driver-workspace-connection-warning')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Showing the last received trip state'),
      findsOneWidget,
    );
  });

  testWidgets(
    'departure shows progress, prevents repeat, and refreshes phase',
    (tester) async {
      final gate = Completer<void>();
      final fake = FakeDriverTripController(
        workspace(),
        departed: workspace(status: 'EnRouteToPickup', includeAction: false),
        gate: gate,
      );
      await tester.pumpWidget(localized(fake));
      await tester.pump();

      await tester.tap(find.byKey(const Key('confirm-departure-to-pickup')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirm-driver-departure-dialog')),
      );
      await tester.pump();
      expect(fake.departCalls, 1);
      expect(find.text('Preparing route to pickup…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-departure-to-pickup')),
            )
            .onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(fake.departCalls, 1);
      expect(find.text('En route to pickup'), findsWidgets);
      expect(find.byKey(const Key('driver-departure-panel')), findsNothing);
    },
  );
}

Widget localized(
  FakeDriverTripController fake, {
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [driverTripControllerProvider.overrideWith(() => fake)],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const Scaffold(body: DriverMyTripScreen()),
  ),
);

class FakeDriverTripController extends DriverTripController {
  FakeDriverTripController(this.initial, {this.departed, this.gate});

  final DriverWorkspace initial;
  final DriverWorkspace? departed;
  final Completer<void>? gate;
  int departCalls = 0;

  @override
  Future<DriverWorkspace> build() async => initial;

  @override
  Future<DriverActionResult> depart() async {
    if (state.value?.actionInProgress == true) {
      return const DriverActionResult.failure('DEPARTURE_ALREADY_IN_PROGRESS');
    }
    departCalls++;
    state = AsyncData(initial.copyWithUiState(actionInProgress: true));
    await gate?.future;
    state = AsyncData(
      departed ?? initial.copyWithUiState(actionInProgress: false),
    );
    return const DriverActionResult.success();
  }
}

DriverWorkspace workspace({
  String status = 'Assigned',
  String? blockingReason,
  bool includeAction = true,
}) => DriverWorkspace(
  state: blockingReason ?? 'ACTIVE_TRIP_READY',
  trackingState: blockingReason == null ? 'Current' : 'NoTelemetry',
  allowedActions: includeAction ? const ['depart-to-pickup'] : const [],
  actions: includeAction
      ? [
          DriverActionReadiness(
            code: 'DEPART_TO_PICKUP',
            visible: true,
            enabled: blockingReason == null,
            blockingReason: blockingReason,
            requiresConfirmation: true,
          ),
        ]
      : const [],
  currentTrip: Trip(
    id: 'trip-1',
    clientId: 'client-1',
    cargoDescription: 'Cargo',
    status: status,
    allowedActions: const [],
    truckId: 'truck-1',
    driverId: 'driver-1',
    stops: const [
      TripStop(
        sequence: 0,
        type: 'Pickup',
        name: 'Pickup',
        latitude: 39.92,
        longitude: 32.85,
      ),
      TripStop(
        sequence: 1,
        type: 'Delivery',
        name: 'Delivery',
        latitude: 40.0,
        longitude: 33.0,
      ),
    ],
  ),
  truck: const DriverWorkspaceTruck(id: 'truck-1', plateNumber: '06 TEST 01'),
  currentPosition: blockingReason == 'TRUCK_POSITION_REQUIRED'
      ? null
      : const DriverWorkspacePosition(
          latitude: 39.90,
          longitude: 32.82,
          speed: 0,
          heading: 0,
          recordedAt: '2026-09-25T12:00:00Z',
          isOnline: true,
        ),
  nextStop: const TripStop(
    sequence: 0,
    type: 'Pickup',
    name: 'Pickup',
    latitude: 39.92,
    longitude: 32.85,
  ),
);
