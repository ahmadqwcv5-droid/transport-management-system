import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
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

  testWidgets('visible simulator location and heartbeat acceptance workflow', (
    tester,
  ) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final plate = 'S331-${suffix.substring(suffix.length - 7)}';
    final api = Dio(BaseOptions(baseUrl: baseUrl));
    final login = await api.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    api.options.headers['Authorization'] =
        'Bearer ${login.data!['accessToken']}';
    await api.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );

    final clientId = await _createId(api, '/api/clients', {
      'name': 'Sprint 3.3.1 Browser $suffix',
    });
    final truckId = await _createId(api, '/api/trucks', {'plateNumber': plate});
    final driverId = await _createId(api, '/api/drivers', {
      'fullName': 'Sprint 3.3.1 Driver $suffix',
      'licenseNumber': 'S331-L-$suffix',
    });
    final tripId = await _createTrip(api, clientId, suffix);
    await api.post<void>(
      '/api/trips/$tripId/assign',
      data: {'truckId': truckId, 'driverId': driverId},
    );

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _selectSimulatorTruck(tester, truckId);
    expect(find.byKey(const Key('sim-state-NoLocation')), findsOneWidget);
    await binding.takeScreenshot('01-new-truck-no-location');

    await _openTrip(tester, tripId);
    await _tap(
      tester,
      find.byKey(const Key('trip-action-preview-repositioning')),
    );
    await _waitFor(tester, find.byKey(const Key('truck-location-recovery')));
    await binding.takeScreenshot('02-missing-location-recovery-en');
    await _tap(tester, find.byKey(const Key('recover-set-location')));
    await _waitFor(tester, find.byKey(const Key('location-picker-map')));
    await tester.pump(const Duration(seconds: 3));
    await binding.takeScreenshot('03-real-map-location-picker');

    final pickerMap = find.byKey(const Key('location-picker-map'));
    final pickerWidget = tester.widget<MapLibreMap>(pickerMap);
    pickerWidget.onMapClick!(
      const Point<double>(180, 140),
      const LatLng(40.120000, 31.650000),
    );
    await tester.pump(const Duration(seconds: 2));
    await _waitFor(tester, find.byKey(const Key('location-selection-preview')));
    final selectedLatitude = _fieldText(tester, 'location-latitude');
    final selectedLongitude = _fieldText(tester, 'location-longitude');
    expect(double.tryParse(selectedLatitude), isNotNull);
    expect(double.tryParse(selectedLongitude), isNotNull);
    await binding.takeScreenshot('04-map-click-selected-coordinate');
    await _tap(tester, find.byKey(const Key('confirm-location')));
    final seededPosition = await _position(api, truckId);
    expect(seededPosition['latitude'], 40.12);
    expect(seededPosition['longitude'], 31.65);

    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _waitForFleetTruck(
      tester,
      find.byKey(Key('real-map-truck-$truckId')),
      timeout: const Duration(seconds: 45),
    );
    await binding.takeScreenshot('05-confirmed-fleet-marker');

    await _openTrip(tester, tripId);
    await _tap(
      tester,
      find.byKey(const Key('trip-action-preview-repositioning')),
    );
    await _waitFor(
      tester,
      find.byKey(const Key('confirm-dispatch-to-pickup')),
      timeout: const Duration(seconds: 35),
    );
    await binding.takeScreenshot('06-successful-route-to-pickup-preview');
    await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));

    final before = await _position(api, truckId);
    final historyBefore = await _history(api, truckId);
    for (var poll = 0; poll < 18; poll++) {
      await api.get<Map<String, dynamic>>('/api/dashboard');
      await tester.pump(const Duration(seconds: 2));
    }
    final afterHeartbeat = await _position(api, truckId);
    final historyAfter = await _history(api, truckId);
    final inventoryAfterHeartbeat = await _inventoryTruck(api, truckId);
    expect(inventoryAfterHeartbeat['locationState'], 'Current');
    expect(afterHeartbeat['latitude'], before['latitude']);
    expect(afterHeartbeat['longitude'], before['longitude']);
    expect(afterHeartbeat['movementPhase'], before['movementPhase']);
    final heartbeatRows = historyAfter.length - historyBefore.length;
    expect(heartbeatRows, inInclusiveRange(1, 9));
    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _selectSimulatorTruck(tester, truckId);
    await binding.takeScreenshot('07-current-after-freshness-window');

    await _tap(tester, find.byKey(const Key('sim-pause')));
    final pausedBefore = await _position(api, truckId);
    for (var poll = 0; poll < 4; poll++) {
      await api.get<Map<String, dynamic>>('/api/dashboard');
      await tester.pump(const Duration(seconds: 2));
    }
    final pausedAfter = await _position(api, truckId);
    expect(pausedAfter['latitude'], pausedBefore['latitude']);
    expect(pausedAfter['longitude'], pausedBefore['longitude']);
    expect((await _inventoryTruck(api, truckId))['locationState'], 'Current');

    final offlineButton = find.byKey(const Key('sim-offline'));
    await tester.ensureVisible(offlineButton);
    tester.widget<OutlinedButton>(offlineButton).onPressed!.call();
    await tester.pump();
    await _waitForInventoryState(api, truckId, 'Offline');
    await tester.pump(const Duration(seconds: 2));
    await _waitFor(tester, find.byKey(const Key('sim-state-Offline')));
    String? offlineError;
    try {
      await api.post<void>('/api/trips/$tripId/repositioning/preview');
      fail('Offline preview unexpectedly succeeded.');
    } on DioException catch (error) {
      offlineError =
          (error.response?.data as Map<String, dynamic>)['errorCode']
              as String?;
      expect(offlineError, 'TRUCK_OFFLINE');
    }
    await binding.takeScreenshot('08-explicit-offline');

    final offlinePosition = await _position(api, truckId);
    final onlineButton = find.byKey(const Key('sim-online'));
    await tester.ensureVisible(onlineButton);
    tester.widget<OutlinedButton>(onlineButton).onPressed!.call();
    await tester.pump();
    await _waitForInventoryState(api, truckId, 'Current');
    final onlinePosition = await _position(api, truckId);
    expect(onlinePosition['latitude'], offlinePosition['latitude']);
    expect(onlinePosition['longitude'], offlinePosition['longitude']);
    await tester.pump(const Duration(seconds: 2));
    await _waitFor(tester, find.byKey(const Key('sim-state-Current')));
    await binding.takeScreenshot('09-online-recovery-no-jump');

    final beforeMove = await _position(api, truckId);
    final moveButton = find.byKey(const Key('sim-set-location'));
    await tester.ensureVisible(moveButton);
    await tester.tap(moveButton);
    await tester.pumpAndSettle(const Duration(milliseconds: 150));
    await _waitFor(tester, find.byKey(const Key('location-picker-dialog')));
    tester
        .widget<MapLibreMap>(find.byKey(const Key('location-picker-map')))
        .onMapClick!(
      const Point<double>(260, 120),
      const LatLng(40.250000, 33.100000),
    );
    await tester.pump(const Duration(seconds: 1));
    expect((await _position(api, truckId))['latitude'], beforeMove['latitude']);
    await _tap(tester, find.byKey(const Key('confirm-location')));
    await tester.pump(const Duration(seconds: 2));
    final afterMove = await _position(api, truckId);
    expect(afterMove['latitude'], 40.25);
    expect(afterMove['longitude'], 33.1);
    await binding.takeScreenshot('10-manual-move-after-confirmation');

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('العربية').last);
    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.text('محاكي التتبع'));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('simulator-controls'))),
      ),
      TextDirection.rtl,
    );
    await binding.takeScreenshot('11-arabic-rtl-simulator-map');

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('English').last);
    await _tap(tester, find.byKey(const Key('nav-trips')));
    await _tap(tester, find.byKey(const Key('add-trip')));
    await _waitFor(tester, find.byKey(const Key('trip-planner-map')));
    await tester.enterText(
      find.byKey(const Key('trip-pickup-name')),
      'Map pickup',
    );
    await _pressMapSelection(tester, 'trip-pickup-select-map');
    final plannerMap = find.byKey(const Key('trip-planner-map'));
    final plannerWidget = tester.widget<MapLibreMap>(plannerMap);
    plannerWidget.onMapClick!(
      const Point<double>(180, 140),
      const LatLng(39.920800, 32.854100),
    );
    await tester.pump(const Duration(seconds: 2));
    final pickupLatitude = _fieldText(tester, 'trip-pickup-latitude');
    expect(pickupLatitude, isNotEmpty);
    await binding.takeScreenshot('12-immediate-pickup-marker');

    await tester.enterText(
      find.byKey(const Key('trip-delivery-name')),
      'Map delivery',
    );
    await _pressMapSelection(tester, 'trip-delivery-select-map');
    tester.widget<MapLibreMap>(plannerMap).onMapClick!(
      const Point<double>(280, 100),
      const LatLng(39.970800, 32.954100),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(_fieldText(tester, 'trip-delivery-latitude'), isNotEmpty);
    await binding.takeScreenshot('13-both-markers-before-route');

    await _pressMapSelection(tester, 'trip-pickup-select-map');
    tester.widget<MapLibreMap>(plannerMap).onMapClick!(
      const Point<double>(210, 180),
      const LatLng(39.940000, 32.880000),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(_fieldText(tester, 'trip-pickup-latitude'), isNot(pickupLatitude));
    await binding.takeScreenshot('14-moved-pickup-marker-no-duplicate');

    binding.reportData = {
      'tenantEmail': email,
      'truckId': truckId,
      'plateNumber': plate,
      'tripId': tripId,
      'locationWasSetThroughVisiblePicker': true,
      'mapClickCallbackExercisedInRealFirefox': true,
      'firstMapSelectedLatitude': selectedLatitude,
      'firstMapSelectedLongitude': selectedLongitude,
      'freshnessWindowSeconds':
          inventoryAfterHeartbeat['maximumPositionAgeSeconds'],
      'stationaryObservationSeconds': 36,
      'heartbeatRowsDuringObservation': heartbeatRows,
      'coordinatesBeforeHeartbeat': {
        'latitude': before['latitude'],
        'longitude': before['longitude'],
      },
      'coordinatesAfterHeartbeat': {
        'latitude': afterHeartbeat['latitude'],
        'longitude': afterHeartbeat['longitude'],
      },
      'offlinePreviewErrorCode': offlineError,
      'onlineCoordinateJump': false,
      'manualPanPollingUpdatesCoveredByAutomatedCoordinatorTest': 10,
      'pickupAndDeliverySelectedThroughRealPlannerMap': true,
    };
  });
}

Future<String> _createId(
  Dio api,
  String path,
  Map<String, dynamic> data,
) async =>
    (await api.post<Map<String, dynamic>>(path, data: data)).data!['id']
        as String;

Future<String> _createTrip(Dio api, String clientId, String suffix) =>
    _createId(api, '/api/trips', {
      'clientId': clientId,
      'cargoDescription': 'Sprint 3.3.1 cargo $suffix',
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
          'name': 'Ankara pickup',
          'latitude': 39.9208,
          'longitude': 32.8541,
        },
        {
          'sequence': 1,
          'type': 'Delivery',
          'name': 'Ankara delivery',
          'latitude': 39.9708,
          'longitude': 32.9541,
        },
      ],
    });

Future<Map<String, dynamic>> _position(Dio api, String truckId) async =>
    (await api.get<Map<String, dynamic>>(
      '/api/tracking/trucks/$truckId/position',
    )).data!;

Future<List<dynamic>> _history(Dio api, String truckId) async =>
    (await api.get<List<dynamic>>(
      '/api/tracking/trucks/$truckId/history?limit=200',
    )).data!;

Future<Map<String, dynamic>> _inventoryTruck(Dio api, String truckId) async =>
    (await api.get<List<dynamic>>('/api/tracking/simulator/trucks')).data!
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['truckId'] == truckId);

Future<void> _waitForInventoryState(
  Dio api,
  String truckId,
  String expected,
) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await api.get<Map<String, dynamic>>('/api/dashboard');
    final truck = await _inventoryTruck(api, truckId);
    if (truck['locationState'] == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  expect((await _inventoryTruck(api, truckId))['locationState'], expected);
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

Future<void> _openTrip(WidgetTester tester, String tripId) async {
  await _tap(tester, find.byKey(const Key('nav-trips')));
  await _tap(tester, find.byKey(Key('trip-$tripId')));
  await _waitFor(
    tester,
    find.byKey(const Key('trip-action-preview-repositioning')),
  );
}

Future<void> _selectSimulatorTruck(WidgetTester tester, String truckId) async {
  await _waitFor(tester, find.byKey(const Key('simulator-controls')));
  final selector = find.byKey(const Key('sim-truck-selector'));
  tester.widget<DropdownButtonFormField<String>>(selector).onChanged!(truckId);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 150));
}

Future<void> _pressMapSelection(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  await tester.ensureVisible(button);
  tester.widget<TextButton>(button).onPressed!.call();
  await tester.pump();
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
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
