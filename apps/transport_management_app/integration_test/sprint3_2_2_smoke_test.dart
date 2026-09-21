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
    defaultValue: 'owner@demo.local',
  );
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('trip-isolated reset-safe trail and physical 10x speed', (
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
      'name': 'Trail Client $suffix',
    });
    final plate = 'TH-${suffix.substring(suffix.length - 8)}';
    final truckId = await _createId(api, '/api/trucks', {'plateNumber': plate});
    final driverId = await _createId(api, '/api/drivers', {
      'fullName': 'Trail Driver $suffix',
      'licenseNumber': 'THL-$suffix',
    });

    final tripAId = await _createTrip(api, clientId, 'Trip A $suffix', const [
      39.9334,
      32.8597,
      40.1826,
      29.0665,
    ]);
    await _activate(api, tripAId, truckId, driverId);
    await _control(api, 'reset');
    await _control(api, 'start');
    for (var index = 0; index < 3; index++) {
      await _control(api, 'step');
      await api.get<List<dynamic>>('/api/tracking/positions');
    }
    await api.post<void>('/api/trips/$tripAId/deliver');
    await api.post<void>('/api/trips/$tripAId/complete');

    final tripBId = await _createTrip(api, clientId, 'Trip B $suffix', const [
      41.0082,
      28.9784,
      40.7654,
      29.9408,
    ]);
    await _activate(api, tripBId, truckId, driverId);

    // Compare deterministic equal-step progress while keeping physical speed
    // independent from the demonstration multiplier.
    await _control(api, 'reset');
    await api.get<List<dynamic>>('/api/tracking/positions');
    final oneXStart = await _travelledMeters(api, tripBId);
    await _control(api, 'start');
    await _control(api, 'step');
    await api.get<List<dynamic>>('/api/tracking/positions');
    final oneXDelta = await _travelledMeters(api, tripBId) - oneXStart;

    await _control(api, 'reset');
    await api.get<List<dynamic>>('/api/tracking/positions');
    final tenXStart = await _travelledMeters(api, tripBId);
    await _control(api, 'speed', speedMultiplier: 10);
    await _control(api, 'start');
    await _control(api, 'step');
    await api.get<List<dynamic>>('/api/tracking/positions');
    final tenXDelta = await _travelledMeters(api, tripBId) - tenXStart;
    expect(tenXDelta, greaterThan(oneXDelta * 8));

    // Build two visibly renderable 1 km-step segments around a reset.
    await _control(api, 'reset');
    await api.get<List<dynamic>>('/api/tracking/positions');
    await _control(api, 'start');
    for (var index = 0; index < 3; index++) {
      await _control(api, 'step');
      await api.get<List<dynamic>>('/api/tracking/positions');
    }
    await _control(api, 'reset');
    await api.get<List<dynamic>>('/api/tracking/positions');
    await _control(api, 'start');
    for (var index = 0; index < 3; index++) {
      await _control(api, 'step');
      await api.get<List<dynamic>>('/api/tracking/positions');
    }
    await _control(api, 'speed', speedMultiplier: 10);
    final firstPosition = await api.get<Map<String, dynamic>>(
      '/api/tracking/trucks/$truckId/position',
    );
    expect(firstPosition.data!['speed'], 65);

    final tripAHistory = await api.get<Map<String, dynamic>>(
      '/api/tracking/trips/$tripAId/history',
    );
    final tripBHistory = await api.get<Map<String, dynamic>>(
      '/api/tracking/trips/$tripBId/history',
    );
    expect(tripAHistory.data!['truckId'], truckId);
    expect(tripBHistory.data!['truckId'], truckId);
    expect(tripBHistory.data!['segments'], isA<List<dynamic>>());
    expect(
      (tripBHistory.data!['segments'] as List<dynamic>).length,
      greaterThanOrEqualTo(2),
    );
    binding.reportData = {
      'truckId': truckId,
      'tripAId': tripAId,
      'tripBId': tripBId,
      'tripAPointCount': tripAHistory.data!['pointCount'],
      'tripBSegments': tripBHistory.data!['segments'],
      'reportedSpeedAt10x': firstPosition.data!['speed'],
      'oneXProgressMeters': oneXDelta,
      'tenXProgressMeters': tenXDelta,
    };

    // Normalize the dedicated smoke account before launching the browser so
    // evidence remains deterministic across repeated local runs.
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
    await _waitFor(tester, fleetTruck, timeout: const Duration(seconds: 30));
    await _selectFleetTruck(tester, fleetTruck);
    await _waitFor(tester, find.byKey(const Key('fleet-route-progress')));
    await _waitFor(tester, find.byKey(const Key('fleet-trail-legend')));
    expect(find.textContaining('65 km/h'), findsOneWidget);
    await binding.takeScreenshot('01-trip-b-isolated-10x-physical-speed');

    await tester.tap(find.byKey(const Key('fleet-trail-visibility')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-trail-visibility')));
    await tester.pump();
    await binding.takeScreenshot('02-post-reset-independent-segments');

    final map = find.byKey(const Key('real-maplibre-map'));
    await tester.drag(map, const Offset(140, 0));
    for (var poll = 0; poll < 10; poll++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await binding.takeScreenshot('03-manual-pan-after-10-polls');

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('العربية').last);
    // Keep the selected smoke truck fresh while the dashboard provider is
    // disposed during settings navigation.
    await _control(api, 'step');
    await api.get<List<dynamic>>('/api/tracking/positions');
    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _waitFor(tester, fleetTruck);
    await _selectFleetTruck(tester, fleetTruck);
    await _waitFor(tester, find.text('المسار المخطط'));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('fleet-trail-legend'))),
      ),
      TextDirection.rtl,
    );
    await binding.takeScreenshot('04-arabic-rtl-trail-legend');
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
) => _createId(api, '/api/trips', {
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

Future<void> _activate(
  Dio api,
  String tripId,
  String truckId,
  String driverId,
) async {
  await api.post<void>(
    '/api/trips/$tripId/assign',
    data: {'truckId': truckId, 'driverId': driverId},
  );
  await api.post<void>('/api/trips/$tripId/start');
  await api.post<void>('/api/trips/$tripId/mark-in-transit');
}

Future<void> _control(Dio api, String action, {double? speedMultiplier}) =>
    api.post<void>(
      '/api/tracking/simulator/control',
      data: {'action': action, 'speedMultiplier': ?speedMultiplier},
    );

Future<double> _travelledMeters(Dio api, String tripId) async {
  final response = await api.get<Map<String, dynamic>>(
    '/api/trips/$tripId/route-progress',
  );
  return (response.data!['travelledDistanceMeters'] as num).toDouble();
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
