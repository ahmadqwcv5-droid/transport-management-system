import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/clients/presentation/clients_screen.dart';
import 'package:transport_management_app/features/operations/domain/operations_models.dart';
import 'package:transport_management_app/features/operations/presentation/operations_controller.dart';
import 'package:transport_management_app/features/trips/presentation/trip_details_screen.dart';
import 'package:transport_management_app/features/trips/presentation/trip_planner_screen.dart';
import 'package:transport_management_app/shared/widgets/app_shell.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';

const emptyData = OperationsData(
  clients: [],
  trucks: [],
  drivers: [],
  trips: [],
);

class FakeOperationsController extends OperationsController {
  FakeOperationsController(this.data);
  final OperationsData data;
  @override
  FutureOr<OperationsData> build() => data;
}

Widget testApp(Widget child, OperationsData data, {bool canManage = true}) =>
    ProviderScope(
      overrides: [
        operationsControllerProvider.overrideWith(
          () => FakeOperationsController(data),
        ),
        operationsCanManageProvider.overrideWithValue(canManage),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('shell exposes every Sprint 2 module', (tester) async {
    await tester.pumpWidget(
      testApp(
        const AppShell(selectedIndex: 0, child: Text('Content')),
        emptyData,
      ),
    );
    for (final label in ['Clients', 'Trucks', 'Drivers', 'Trips']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('clients handles empty state and validates create form', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const ClientsScreen(), emptyData));
    await tester.pumpAndSettle();
    expect(find.text('No clients yet.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-client')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-client')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('trip details shows only server-allowed status actions', (
    tester,
  ) async {
    const trip = Trip(
      id: 'trip-1',
      clientId: 'client-1',
      truckId: 'truck-1',
      driverId: 'driver-1',
      origin: 'Ankara',
      destination: 'Istanbul',
      cargoDescription: 'Parts',
      plannedStartAt: '2026-09-18T08:00:00Z',
      price: 1250,
      status: 'Assigned',
      allowedActions: ['preview-repositioning', 'dispatch-to-pickup', 'cancel'],
    );
    const data = OperationsData(
      clients: [Client(id: 'client-1', name: 'Factory', isActive: true)],
      trucks: [
        Truck(
          id: 'truck-1',
          plateNumber: '06-TMS-01',
          status: 'OnTrip',
          isActive: true,
        ),
      ],
      drivers: [
        Driver(
          id: 'driver-1',
          fullName: 'Test Driver',
          licenseNumber: 'DL-1',
          status: 'OnTrip',
          isActive: true,
        ),
      ],
      trips: [trip],
    );
    await tester.pumpWidget(
      testApp(const TripDetailsScreen(tripId: 'trip-1'), data),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Preview route to pickup'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Cancel'), findsOneWidget);
    expect(find.text('dispatch-to-pickup'), findsNothing);
    expect(find.text('Mark in transit'), findsNothing);
  });

  testWidgets(
    'trip planner shows and moves stop markers before route calculation',
    (tester) async {
      const data = OperationsData(
        clients: [Client(id: 'client-1', name: 'Factory', isActive: true)],
        trucks: [],
        drivers: [],
        trips: [],
      );
      await tester.pumpWidget(testApp(const TripPlannerScreen(), data));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('trip-pickup-name')),
        'Pickup',
      );
      await tester.enterText(
        find.byKey(const Key('trip-pickup-latitude')),
        '39.9',
      );
      await tester.enterText(
        find.byKey(const Key('trip-pickup-longitude')),
        '32.8',
      );
      await tester.pump();
      expect(find.byKey(const Key('planner-pickup-marker')), findsOneWidget);
      expect(find.byKey(const Key('planner-delivery-marker')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('trip-delivery-name')),
        'Delivery',
      );
      await tester.enterText(
        find.byKey(const Key('trip-delivery-latitude')),
        '41.0',
      );
      await tester.enterText(
        find.byKey(const Key('trip-delivery-longitude')),
        '29.0',
      );
      await tester.pump();
      expect(find.byKey(const Key('planner-pickup-marker')), findsOneWidget);
      expect(find.byKey(const Key('planner-delivery-marker')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('trip-pickup-latitude')),
        '40.1',
      );
      await tester.pump();
      expect(find.byKey(const Key('planner-pickup-marker')), findsOneWidget);
      expect(find.byKey(const Key('planner-delivery-marker')), findsOneWidget);
      expect(find.byKey(const Key('calculate-route')), findsOneWidget);
    },
  );

  testWidgets('draft edit initializes both stop markers before routing', (
    tester,
  ) async {
    const draft = Trip(
      id: 'draft-1',
      clientId: 'client-1',
      origin: 'Depot',
      destination: 'Customer',
      cargoDescription: 'Parts',
      plannedStartAt: '2026-09-22T08:00:00Z',
      price: 500,
      status: 'Draft',
      allowedActions: [],
      stops: [
        TripStop(
          sequence: 0,
          type: 'Pickup',
          name: 'Depot',
          latitude: 39.92,
          longitude: 32.85,
        ),
        TripStop(
          sequence: 1,
          type: 'Delivery',
          name: 'Customer',
          latitude: 41.01,
          longitude: 28.97,
        ),
      ],
    );
    const data = OperationsData(
      clients: [Client(id: 'client-1', name: 'Factory', isActive: true)],
      trucks: [],
      drivers: [],
      trips: [draft],
    );

    await tester.pumpWidget(
      testApp(const TripPlannerScreen(tripId: 'draft-1'), data),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planner-pickup-marker')), findsOneWidget);
    expect(find.byKey(const Key('planner-delivery-marker')), findsOneWidget);
  });
}
