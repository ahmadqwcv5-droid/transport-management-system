import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/clients/presentation/clients_screen.dart';
import 'package:transport_management_app/features/operations/domain/operations_models.dart';
import 'package:transport_management_app/features/operations/presentation/operations_controller.dart';
import 'package:transport_management_app/features/trips/presentation/trip_details_screen.dart';
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
}
