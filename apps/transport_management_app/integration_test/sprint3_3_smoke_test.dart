import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );
  const email = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'owner@sprint322.local',
  );
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('Trip A to Trip B dispatch, restart, arrival, and cargo', (
    tester,
  ) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final api = Dio(BaseOptions(baseUrl: baseUrl));
    final login = await api.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    api.options.headers['Authorization'] =
        'Bearer ${login.data!['accessToken']}';

    final clientId = await _createId(api, '/api/clients', {
      'name': 'Sprint 3.3 Browser $suffix',
    });
    final truckId = await _createId(api, '/api/trucks', {
      'plateNumber': 'S33-${suffix.substring(suffix.length - 8)}',
    });
    final driverId = await _createId(api, '/api/drivers', {
      'fullName': 'Sprint 3.3 Driver $suffix',
      'licenseNumber': 'S33-L-$suffix',
    });

    final tripAId = await _createTrip(api, clientId, 'Trip A $suffix', const [
      39.9208,
      32.8541,
      39.9250,
      32.8600,
    ]);
    await _assign(api, tripAId, truckId, driverId);
    await _seed(api, truckId, 39.9208, 32.8541);
    await api.post<void>(
      '/api/trips/$tripAId/dispatch-to-pickup',
      data: {'reason': 'Browser acceptance manager override'},
    );
    await api.post<void>('/api/trips/$tripAId/start');
    await api.post<void>('/api/trips/$tripAId/mark-in-transit');
    await _control(api, 'step');
    await api.get<List<dynamic>>('/api/tracking/positions');
    await api.post<void>('/api/trips/$tripAId/deliver');
    await api.post<void>('/api/trips/$tripAId/complete');
    final tripAFinal = await _position(api, truckId);

    final tripBId = await _createTrip(api, clientId, 'Trip B $suffix', const [
      41.0082,
      28.9784,
      41.0150,
      28.9900,
    ]);
    await _assign(api, tripBId, truckId, driverId);
    for (var poll = 0; poll < 4; poll++) {
      await api.get<List<dynamic>>('/api/tracking/positions');
    }
    final assignedPosition = await _position(api, truckId);
    expect(assignedPosition['latitude'], tripAFinal['latitude']);
    expect(assignedPosition['longitude'], tripAFinal['longitude']);

    String? startError;
    try {
      await api.post<void>('/api/trips/$tripBId/start');
      fail('Distant cargo start unexpectedly succeeded.');
    } on DioException catch (error) {
      expect(error.response?.statusCode, 409);
      startError =
          (error.response?.data as Map<String, dynamic>)['errorCode']
              as String?;
      expect(startError, 'TRUCK_NOT_AT_PICKUP');
    }

    await api.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );
    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _waitFor(
      tester,
      find.byKey(const Key('map-annotations-ready')),
      timeout: const Duration(seconds: 45),
    );
    final fleetTruck = find.byKey(Key('real-map-truck-$truckId'));
    await _waitForFleetTruck(tester, fleetTruck);
    await _selectFleetTruck(tester, fleetTruck);
    await _waitFor(tester, find.byKey(const Key('fleet-route-progress')));
    await binding.takeScreenshot('01-assigned-no-teleport');

    final preview = await api.post<Map<String, dynamic>>(
      '/api/trips/$tripBId/repositioning/preview',
    );
    final plan = preview.data!['plan'] as Map<String, dynamic>;
    final planId = plan['id'] as String;
    final tripB = await api.get<Map<String, dynamic>>('/api/trips/$tripBId');
    final cargoRoute = tripB.data!['routePlan'] as Map<String, dynamic>;
    expect(planId, isNot(cargoRoute['id']));
    await _refreshSelectedTruck(tester, fleetTruck);
    await _waitFor(tester, find.text('Route to pickup'));
    await binding.takeScreenshot('02-proposed-approach-and-cargo-routes');

    await api.post<void>(
      '/api/trips/$tripBId/dispatch-to-pickup',
      data: {
        'repositioningPlanId': planId,
        'reason': 'Browser acceptance manager override',
      },
    );
    await _control(api, 'step');
    await api.get<List<dynamic>>('/api/tracking/positions');
    await _control(api, 'step');
    await api.get<List<dynamic>>('/api/tracking/positions');
    await _control(api, 'pause');
    final progressBeforeRestart = await _approachProgress(api, tripBId);
    expect(progressBeforeRestart['progressPercent'], greaterThan(0));
    final beforeRestart = await _position(api, truckId);
    await _refreshSelectedTruck(tester, fleetTruck);
    await binding.takeScreenshot('03-active-approach-progress');

    // The outer smoke runner watches for this marker and restarts only the API
    // container while this browser waits. PostgreSQL and its volume stay up.
    debugPrint('SPRINT33_RESTART_REQUIRED');
    await tester.pump(const Duration(seconds: 45));
    await _waitForApi(api);
    final afterRestart = await _position(api, truckId);
    final restartDelta = _coordinateDeltaMeters(beforeRestart, afterRestart);
    expect(restartDelta, lessThan(80));
    final progressAfterRestart = await _approachProgress(api, tripBId);
    expect(
      (progressAfterRestart['progressPercent'] as num).toDouble(),
      greaterThanOrEqualTo(
        (progressBeforeRestart['progressPercent'] as num).toDouble() - 0.2,
      ),
    );

    Map<String, dynamic> currentTrip = {};
    for (var step = 0; step < 80; step++) {
      currentTrip = (await api.get<Map<String, dynamic>>(
        '/api/trips/$tripBId',
      )).data!;
      if (currentTrip['status'] == 'AtPickup') break;
      await _control(api, 'speed', speedMultiplier: 20);
      await _control(api, 'step');
      await api.get<List<dynamic>>('/api/tracking/positions');
    }
    expect(currentTrip['status'], 'AtPickup');
    expect(currentTrip['actualStartAt'], isNull);
    await _refreshSelectedTruck(tester, fleetTruck);
    await binding.takeScreenshot('04-at-pickup-not-started');

    final pickupPosition = await _position(api, truckId);
    await api.post<void>('/api/trips/$tripBId/start');
    await api.post<void>('/api/trips/$tripBId/mark-in-transit');
    await _control(api, 'speed', speedMultiplier: 10);
    await _control(api, 'start');
    await api.get<List<dynamic>>('/api/tracking/positions');
    final cargoPosition = await _position(api, truckId);
    expect(cargoPosition['speed'], 65);
    expect(
      _coordinateDeltaMeters(pickupPosition, cargoPosition),
      lessThan(11000),
    );
    await _refreshSelectedTruck(tester, fleetTruck);
    await _waitFor(tester, find.textContaining('65 km/h'));
    await binding.takeScreenshot('05-explicit-cargo-start-10x');

    final map = find.byKey(const Key('real-maplibre-map'));
    await tester.drag(map, const Offset(140, 0));
    for (var poll = 0; poll < 10; poll++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await binding.takeScreenshot('06-manual-pan-after-10-polls');

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('العربية').last);
    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.byKey(const Key('map-annotations-ready')));
    await _waitForFleetTruck(tester, fleetTruck);
    await _selectFleetTruck(tester, fleetTruck);
    await _waitFor(tester, find.text('المسار إلى الاستلام'));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('fleet-trail-legend'))),
      ),
      TextDirection.rtl,
    );
    await binding.takeScreenshot('07-arabic-rtl-real-map');

    binding.reportData = {
      'truckId': truckId,
      'tripAId': tripAId,
      'tripBId': tripBId,
      'tripAFinalPosition': tripAFinal,
      'tripBAssignedPositionAfterFourPolls': assignedPosition,
      'distantStartStatus': 409,
      'distantStartErrorCode': startError,
      'approachRouteId': planId,
      'approachDistanceMeters': plan['distanceMeters'],
      'cargoRouteId': cargoRoute['id'],
      'cargoDistanceMeters': cargoRoute['distanceMeters'],
      'approachProgressBeforeRestart': progressBeforeRestart,
      'approachProgressAfterRestart': progressAfterRestart,
      'positionBeforeRestart': beforeRestart,
      'positionAfterRestart': afterRestart,
      'restartCoordinateDeltaMeters': restartDelta,
      'atPickupStatus': currentTrip['status'],
      'cargoStartedExplicitly': true,
      'reportedPhysicalSpeedAt10x': cargoPosition['speed'],
      'manualPanPollingUpdates': 10,
    };
  });
}

Future<String> _createId(
  Dio api,
  String path,
  Map<String, dynamic> data,
) async {
  final response = await api.post<Map<String, dynamic>>(path, data: data);
  return response.data!['id'] as String;
}

Future<String> _createTrip(
  Dio api,
  String clientId,
  String cargo,
  List<double> coordinates,
) async {
  final tripId = await _createId(api, '/api/trips', {
    'clientId': clientId,
    'cargoDescription': cargo,
    'plannedStartAt': DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String(),
    'price': 1000,
    'routeProfile': 'Driving',
    'stops': [
      {
        'sequence': 0,
        'type': 'Pickup',
        'name': '$cargo pickup',
        'latitude': coordinates[0],
        'longitude': coordinates[1],
      },
      {
        'sequence': 1,
        'type': 'Delivery',
        'name': '$cargo delivery',
        'latitude': coordinates[2],
        'longitude': coordinates[3],
      },
    ],
  });
  await api.post<void>(
    '/api/trips/$tripId/calculate-route',
    data: {'routeProfile': 'Driving'},
  );
  return tripId;
}

Future<void> _assign(Dio api, String tripId, String truckId, String driverId) =>
    api.post<void>(
      '/api/trips/$tripId/assign',
      data: {'truckId': truckId, 'driverId': driverId},
    );

Future<void> _seed(
  Dio api,
  String truckId,
  double latitude,
  double longitude,
) => api.post<void>(
  '/api/tracking/simulator/control',
  data: {
    'action': 'seed-position',
    'truckId': truckId,
    'latitude': latitude,
    'longitude': longitude,
  },
);

Future<void> _control(Dio api, String action, {double? speedMultiplier}) =>
    api.post<void>(
      '/api/tracking/simulator/control',
      data: {'action': action, 'speedMultiplier': ?speedMultiplier},
    );

Future<Map<String, dynamic>> _position(Dio api, String truckId) async =>
    (await api.get<Map<String, dynamic>>(
      '/api/tracking/trucks/$truckId/position',
    )).data!;

Future<Map<String, dynamic>> _approachProgress(Dio api, String tripId) async =>
    (await api.get<Map<String, dynamic>>(
      '/api/trips/$tripId/repositioning-progress',
    )).data!;

double _coordinateDeltaMeters(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final latitude =
      ((first['latitude'] as num).toDouble() -
              (second['latitude'] as num).toDouble())
          .abs();
  final longitude =
      ((first['longitude'] as num).toDouble() -
              (second['longitude'] as num).toDouble())
          .abs();
  return (latitude * 111320) + (longitude * 85000);
}

Future<void> _waitForApi(Dio api) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    try {
      await api.get<void>('/health');
      return;
    } on DioException {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  fail('API did not return after the orchestrated restart.');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 150));
}

Future<void> _selectFleetTruck(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  tester.widget<ListTile>(finder.first).onTap!.call();
  await tester.pump();
}

Future<void> _refreshSelectedTruck(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(seconds: 6));
  await _waitForFleetTruck(tester, finder);
  tester.widget<ListTile>(finder.first).onTap!.call();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _waitForFleetTruck(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    final scrollable = find.descendant(
      of: find.byKey(const Key('map-annotations-ready')),
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -110));
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}
