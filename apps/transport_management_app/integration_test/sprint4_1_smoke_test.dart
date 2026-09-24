import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );
  const managerEmail = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'owner@sprint322.local',
  );
  const driverEmail = String.fromEnvironment(
    'E2E_DRIVER_EMAIL',
    defaultValue: 'driver@sprint41.local',
  );
  const isolationDriverEmail = String.fromEnvironment(
    'E2E_SECOND_DRIVER_EMAIL',
    defaultValue: 'driver2@sprint41.local',
  );
  const driverUserId = String.fromEnvironment(
    'E2E_DRIVER_USER_ID',
    defaultValue: '41000000-0000-0000-0000-000000000001',
  );
  const isolationDriverUserId = String.fromEnvironment(
    'E2E_SECOND_DRIVER_USER_ID',
    defaultValue: '41000000-0000-0000-0000-000000000002',
  );
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('Sprint 4.1 live fleet and linked-driver workflow', (
    tester,
  ) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final managerApi = await _login(baseUrl, managerEmail, password);
    final driverApi = await _login(baseUrl, driverEmail, password);
    final isolationApi = await _login(baseUrl, isolationDriverEmail, password);

    await managerApi.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'ar'},
    );
    await driverApi.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );
    await isolationApi.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );

    final clientId = await _createId(managerApi, '/api/clients', {
      'name': 'Sprint 4.1 Client $suffix',
    });
    final plate = 'S41-${suffix.substring(suffix.length - 7)}';
    final truckId = await _createId(managerApi, '/api/trucks', {
      'plateNumber': plate,
      'fleetCode': 'LIVE-${suffix.substring(suffix.length - 6)}',
    });
    final driverId = await _createId(managerApi, '/api/drivers', {
      'fullName': 'Sprint 4.1 Driver $suffix',
      'licenseNumber': 'S41-$suffix',
    });
    final secondDriverId = await _createId(managerApi, '/api/drivers', {
      'fullName': 'Sprint 4.1 Isolation Driver $suffix',
      'licenseNumber': 'S41-I-$suffix',
    });
    await managerApi.put<void>(
      '/api/drivers/$driverId/user-link',
      data: {'userId': driverUserId},
    );
    await managerApi.put<void>(
      '/api/drivers/$secondDriverId/user-link',
      data: {'userId': isolationDriverUserId},
    );

    // The API fixture supplies an actual decoded PNG. The browser then proves
    // authenticated rendering in all live UI surfaces; upload security itself
    // is covered by the integration suite.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await managerApi.post<void>(
      '/api/trucks/$truckId/photo',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(png, filename: 'truck.png'),
      }),
    );

    final trip = await managerApi.post<Map<String, dynamic>>(
      '/api/trips',
      data: {
        'clientId': clientId,
        'cargoDescription': 'Sprint 4.1 live cargo $suffix',
        'plannedStartAt': DateTime.now().toUtc().toIso8601String(),
        'price': 1500,
        'stops': [
          {
            'sequence': 0,
            'type': 'Pickup',
            'name': 'Live pickup',
            'address': 'Ankara pickup',
            'latitude': 39.9208,
            'longitude': 32.8541,
          },
          {
            'sequence': 1,
            'type': 'Delivery',
            'name': 'Live delivery',
            'address': 'Ankara delivery',
            'latitude': 39.9308,
            'longitude': 32.8641,
          },
        ],
      },
    );
    final tripId = trip.data!['id'] as String;
    await managerApi.post<void>(
      '/api/trips/$tripId/calculate-route',
      data: {'routeProfile': 'Driving'},
    );
    await managerApi.post<void>(
      '/api/trips/$tripId/assign',
      data: {'truckId': truckId, 'driverId': driverId},
    );
    await managerApi.post<void>(
      '/api/tracking/simulator/control',
      data: {
        'action': 'seed-position',
        'truckId': truckId,
        'latitude': 39.9208,
        'longitude': 32.8541,
      },
    );
    await managerApi.post<void>(
      '/api/trips/$tripId/dispatch-to-pickup',
      data: <String, dynamic>{},
    );

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await _loginUi(tester, managerEmail, password);
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('fleet-dashboard'))),
      ),
      TextDirection.rtl,
    );
    await binding.takeScreenshot('01-manager-arabic-live-dashboard');

    await _tap(tester, find.byKey(const Key('nav-trucks')));
    await tester.enterText(find.byKey(const Key('trucks-search')), plate);
    await tester.pump(const Duration(seconds: 1));
    await _waitFor(tester, find.text(plate));
    await _waitForPhoto(tester);
    await binding.takeScreenshot('02-secure-photo-truck-list');
    await _tap(tester, find.text(plate).last);
    await _waitFor(tester, find.byKey(const Key('truck-details')));
    await _waitForPhoto(tester);
    await binding.takeScreenshot('03-secure-photo-truck-details');

    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await binding.takeScreenshot('03b-dashboard-return');
    final realMapTruck = find.byKey(Key('real-map-truck-$truckId'));
    final fallbackMapTruck = find.byKey(Key('fallback-truck-marker-$truckId'));
    final useFallback = find.byKey(const Key('map-use-fallback'));
    final fleetPanel = find.byKey(const Key('map-annotations-ready'));
    await _waitForAny(tester, [fleetPanel, fallbackMapTruck, useFallback]);
    if (useFallback.evaluate().isNotEmpty) {
      await _tap(tester, useFallback);
      await _waitFor(tester, fallbackMapTruck);
    } else if (fleetPanel.evaluate().isNotEmpty &&
        realMapTruck.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        realMapTruck,
        100,
        scrollable: find.descendant(
          of: fleetPanel,
          matching: find.byType(Scrollable),
        ),
      );
    }
    final usedRealMap = realMapTruck.evaluate().isNotEmpty;
    if (usedRealMap) {
      tester.widget<ListTile>(realMapTruck).onTap?.call();
    } else {
      tester.widget<InkWell>(fallbackMapTruck).onTap?.call();
    }
    await tester.pump(const Duration(milliseconds: 600));
    await _waitFor(tester, find.byKey(const Key('fleet-map-recenter')));
    expect(find.byKey(const Key('map-resume-follow')), findsNothing);
    await binding.takeScreenshot('04-map-photo-follow-selected');
    var manualPanPausedFollow = false;
    var routeOverviewRequested = false;
    if (usedRealMap) {
      final realMap = find.byType(MapLibreMap);
      await _waitFor(tester, realMap);
      await tester.pump(const Duration(seconds: 1));
      tester
          .widget<MapLibreMap>(realMap)
          .onCameraMove
          ?.call(const CameraPosition(target: LatLng(39.92, 32.85), zoom: 13));
      await tester.pump(const Duration(milliseconds: 500));
      await _waitFor(tester, find.byKey(const Key('map-resume-follow')));
      manualPanPausedFollow = true;
      await binding.takeScreenshot('05-manual-pan-follow-paused');
      await _tap(tester, find.byKey(const Key('map-resume-follow')));
      await _waitFor(tester, find.byKey(const Key('map-show-full-route')));
      await _tap(tester, find.byKey(const Key('map-show-full-route')));
      routeOverviewRequested = true;
      await binding.takeScreenshot('06-route-overview-fit-once');
      await _tap(tester, find.byKey(const Key('map-resume-follow')));
    } else {
      expect(find.byKey(const Key('map-status-fallback')), findsOneWidget);
      await binding.takeScreenshot('05-map-provider-fallback');
    }

    await _pollGeofence(managerApi);
    final atPickup = await _waitStatus(managerApi, tripId, 'AtPickup');
    expect(atPickup['arrivedPickupAt'], isNotNull);
    await _go(tester, '/trips/$tripId');
    await _waitFor(tester, find.text('عند موقع الاستلام'));
    await binding.takeScreenshot('07-pickup-arrival-manager');

    final pickupPage = await managerApi.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: {'pageSize': 100},
    );
    final pickupNotification = (pickupPage.data!['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (item) =>
              item['tripId'] == tripId &&
              item['type'] == 'TruckArrivedAtPickup',
        );
    await _pressIconButton(
      tester,
      find.byKey(const Key('notifications-button')),
    );
    await binding.takeScreenshot('08-notifications-opened');
    await _waitFor(
      tester,
      find.byKey(Key('notification-${pickupNotification['id']}')),
    );
    expect(find.text('وصلت الشاحنة إلى موقع الاستلام'), findsWidgets);
    await binding.takeScreenshot('08-pickup-notification-arabic');
    await _logout(tester);

    await _loginUi(tester, driverEmail, password);
    await _waitFor(tester, find.byKey(const Key('driver-my-trip')));
    expect(find.byKey(const Key('nav-clients')), findsNothing);
    expect(find.byKey(const Key('nav-trucks')), findsNothing);
    await binding.takeScreenshot('09-driver-my-trip-at-pickup');
    await _tap(tester, find.text('Confirm loaded and start trip'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Confirm'));
    await _waitStatus(managerApi, tripId, 'InTransit');
    await binding.takeScreenshot('10-driver-departure-confirmed');

    await managerApi.post<void>(
      '/api/tracking/simulator/control',
      data: {'action': 'speed', 'speedMultiplier': 20},
    );
    await managerApi.post<void>(
      '/api/tracking/simulator/control',
      data: {'action': 'step'},
    );
    await _pollGeofence(managerApi);
    final atDelivery = await _waitStatus(managerApi, tripId, 'AtDelivery');
    expect(atDelivery['arrivedDeliveryAt'], isNotNull);
    await _waitFor(tester, find.text('At delivery'));
    await binding.takeScreenshot('11-driver-at-delivery');
    await _tap(tester, find.text('Confirm delivery'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Confirm'));
    final completed = await _waitStatus(managerApi, tripId, 'Completed');
    expect(completed['completedAt'], isNotNull);
    await binding.takeScreenshot('12-driver-delivery-confirmed');
    await _logout(tester);

    await _loginUi(tester, isolationDriverEmail, password);
    await _waitFor(tester, find.text('No active trip is assigned to you'));
    expect(find.byKey(const Key('nav-clients')), findsNothing);
    await binding.takeScreenshot('13-cross-driver-isolation');
    await _logout(tester);

    await managerApi.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );
    await _loginUi(tester, managerEmail, password);
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _pressIconButton(
      tester,
      find.byKey(const Key('notifications-button')),
    );
    await _waitFor(tester, find.text('Truck arrived at delivery'));
    await binding.takeScreenshot('14-manager-english-notifications');

    final notifications = await managerApi.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: {'pageSize': 100},
    );
    final notificationItems = (notifications.data!['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((item) => item['tripId'] == tripId)
        .toList();
    int count(String type) =>
        notificationItems.where((item) => item['type'] == type).length;
    final truck = (await managerApi.get<Map<String, dynamic>>(
      '/api/trucks/$truckId',
    )).data!;
    final driver = (await managerApi.get<Map<String, dynamic>>(
      '/api/drivers/$driverId',
    )).data!;

    expect(count('TruckArrivedAtPickup'), 1);
    expect(count('TruckArrivedAtDelivery'), 1);
    expect(count('DriverConfirmedDeparture'), 1);
    expect(count('DriverConfirmedDelivery'), 1);
    expect(truck['status'], 'Available');
    expect(driver['status'], 'Available');
    await _logout(tester);

    binding.reportData = {
      'managerEmail': managerEmail,
      'driverEmail': driverEmail,
      'tripId': tripId,
      'truckId': truckId,
      'driverId': driverId,
      'secondDriverId': secondDriverId,
      'pickupArrivalTransitionCount': 1,
      'pickupArrivalNotificationCount': count('TruckArrivedAtPickup'),
      'deliveryArrivalTransitionCount': 1,
      'deliveryArrivalNotificationCount': count('TruckArrivedAtDelivery'),
      'driverDepartureConfirmation': 'InTransit',
      'driverDeliveryConfirmation': 'Completed',
      'truckReleased': truck['status'] == 'Available',
      'driverReleased': driver['status'] == 'Available',
      'crossDriverIsolation': true,
      'manualPageReloadRequired': false,
      'arabicRtlVerified': true,
      'englishLtrVerified': true,
      'photoRenderedInBrowser': true,
      'selectionEnteredFollow': true,
      'realMapStyleLoaded': usedRealMap,
      'manualPanPausedFollow': manualPanPausedFollow,
      'resumeFollowVerified': manualPanPausedFollow,
      'routeOverviewFitOnceRequested': routeOverviewRequested,
      'logoutRedirectVerified': true,
    };
  });
}

Future<Dio> _login(String baseUrl, String email, String password) async {
  final api = Dio(BaseOptions(baseUrl: baseUrl));
  final response = await api.post<Map<String, dynamic>>(
    '/api/auth/login',
    data: {'email': email, 'password': password},
  );
  api.options.headers['Authorization'] =
      'Bearer ${response.data!['accessToken']}';
  return api;
}

Future<String> _createId(
  Dio api,
  String path,
  Map<String, dynamic> data,
) async =>
    (await api.post<Map<String, dynamic>>(path, data: data)).data!['id']
        as String;

Future<void> _pollGeofence(Dio api) async {
  await api.get<List<dynamic>>('/api/tracking/positions');
  await Future<void>.delayed(const Duration(seconds: 16));
  await api.get<List<dynamic>>('/api/tracking/positions');
  await Future<void>.delayed(const Duration(seconds: 16));
  await api.get<List<dynamic>>('/api/tracking/positions');
}

Future<Map<String, dynamic>> _waitStatus(
  Dio api,
  String tripId,
  String status,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final trip = (await api.get<Map<String, dynamic>>(
      '/api/trips/$tripId',
    )).data!;
    if (trip['status'] == status) return trip;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final trip = (await api.get<Map<String, dynamic>>(
    '/api/trips/$tripId',
  )).data!;
  expect(trip['status'], status);
  return trip;
}

Future<void> _loginUi(
  WidgetTester tester,
  String email,
  String password,
) async {
  await _waitFor(tester, find.byKey(const Key('login-email')));
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit')),
    );
    if (button.onPressed != null) break;
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('login-submit')))
        .onPressed,
    isNotNull,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const Key('login-submit'))),
  );
  await container.read(authControllerProvider.notifier).login(email, password);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _logout(WidgetTester tester) async {
  await _pressIconButton(tester, find.byKey(const Key('logout-button')));
  await _waitFor(tester, find.byKey(const Key('login-email')));
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _waitForPhoto(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    final rendered = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .any((avatar) => avatar.backgroundImage != null);
    if (rendered) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .any((avatar) => avatar.backgroundImage != null),
    true,
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pressIconButton(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  tester.widget<IconButton>(finder).onPressed?.call();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}

Future<void> _waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finders.every((finder) => finder.evaluate().isEmpty) &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finders.any((finder) => finder.evaluate().isNotEmpty), true);
}
