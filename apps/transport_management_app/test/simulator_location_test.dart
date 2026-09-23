import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/dashboard/domain/dashboard_models.dart';
import 'package:transport_management_app/features/dashboard/presentation/dashboard_controller.dart';
import 'package:transport_management_app/features/dashboard/presentation/simulator_controls.dart';
import 'package:transport_management_app/features/locations/presentation/location_picker_dialog.dart';
import 'package:transport_management_app/features/trips/domain/trip_models.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';

class _FakeDashboardController extends DashboardController {
  final calls =
      <
        ({String action, String? truckId, double? latitude, double? longitude})
      >[];

  @override
  FutureOr<DashboardData> build() => const DashboardData(
    fleet: {},
    trips: {},
    tracking: {},
    positions: [],
    simulatorTrucks: [],
    recentTrips: [],
  );

  @override
  Future<bool> control(
    String action, {
    String? truckId,
    double? speedMultiplier,
    double? latitude,
    double? longitude,
  }) async {
    calls.add((
      action: action,
      truckId: truckId,
      latitude: latitude,
      longitude: longitude,
    ));
    return true;
  }
}

Widget _localized(
  Widget child,
  _FakeDashboardController fake, {
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [dashboardControllerProvider.overrideWith(() => fake)],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

const _unlocated = SimulatorTruck(
  truckId: 'truck-1',
  plateNumber: '06 NEW 01',
  truckStatus: 'Available',
  locationState: 'NoLocation',
  maximumPositionAgeSeconds: 300,
);

const _current = SimulatorTruck(
  truckId: 'truck-1',
  plateNumber: '06 NEW 01',
  truckStatus: 'Available',
  locationState: 'Current',
  maximumPositionAgeSeconds: 300,
  latitude: 39.9208,
  longitude: 32.8541,
  recordedAt: '2026-09-21T18:00:00Z',
  positionAgeSeconds: 8,
  isOnline: true,
);

void main() {
  testWidgets(
    'no-location truck is selectable and manual location is confirmed',
    (tester) async {
      final fake = _FakeDashboardController();
      await tester.pumpWidget(
        _localized(const SimulatorControls(trucks: [_unlocated]), fake),
      );
      await tester.pumpAndSettle();

      expect(find.text('No location'), findsWidgets);
      expect(find.byKey(const Key('sim-set-location')), findsOneWidget);
      expect(find.byKey(const Key('sim-refresh-location')), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('sim-refresh-location')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('sim-set-location')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-picker-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('location-latitude')),
        '39.9208',
      );
      await tester.enterText(
        find.byKey(const Key('location-longitude')),
        '32.8541',
      );
      await tester.tap(find.byKey(const Key('confirm-location')));
      await tester.pumpAndSettle();

      expect(fake.calls.last.action, 'set-position');
      expect(fake.calls.last.truckId, 'truck-1');
      expect(fake.calls.last.latitude, 39.9208);
      expect(fake.calls.last.longitude, 32.8541);
    },
  );

  testWidgets('invalid manual coordinates block confirmation', (tester) async {
    LocationSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async => result = await showLocationPickerDialog(
                context: context,
                title: 'Picker',
                search: (_) async => const [],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-latitude')), '91');
    await tester.enterText(find.byKey(const Key('location-longitude')), '32');
    await tester.tap(find.byKey(const Key('confirm-location')));
    await tester.pump();
    expect(find.text('Enter a valid coordinate.'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('current truck refresh uses the explicit same-position command', (
    tester,
  ) async {
    final fake = _FakeDashboardController();
    await tester.pumpWidget(
      _localized(const SimulatorControls(trucks: [_current]), fake),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sim-refresh-location')));
    await tester.pump();

    expect(fake.calls.last.action, 'refresh-position');
    expect(fake.calls.last.truckId, 'truck-1');
    expect(fake.calls.last.latitude, isNull);
    expect(fake.calls.last.longitude, isNull);
  });

  testWidgets(
    'search result synchronizes coordinate preview and confirmation',
    (tester) async {
      LocationSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async => result = await showLocationPickerDialog(
                  context: context,
                  title: 'Picker',
                  search: (_) async => const [
                    LocationResult(
                      displayName: 'Ankara Depot',
                      address: 'Ankara',
                      latitude: 39.9208,
                      longitude: 32.8541,
                      providerName: 'Test',
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('location-search-query')),
        'Ankara',
      );
      await tester.tap(find.byKey(const Key('location-search')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ankara Depot'));
      await tester.pump();
      expect(find.text('Ankara Depot'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-location')));
      await tester.pumpAndSettle();
      expect(result?.latitude, 39.9208);
      expect(result?.longitude, 32.8541);
    },
  );

  testWidgets('Arabic location state renders RTL', (tester) async {
    final fake = _FakeDashboardController();
    await tester.pumpWidget(
      _localized(
        const SimulatorControls(trucks: [_unlocated]),
        fake,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد موقع'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byType(SimulatorControls))),
      TextDirection.rtl,
    );
  });
}
