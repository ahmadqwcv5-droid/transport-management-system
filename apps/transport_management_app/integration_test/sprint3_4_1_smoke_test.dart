import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('Sprint 3.4.1 authenticated four-step trip workflow', (
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
    await api.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );

    final clientName = 'Sprint 3.4.1 Client $suffix';
    await _createId(api, '/api/clients', {'name': clientName});
    final availablePlate = 'A341-${suffix.substring(suffix.length - 6)}';
    final availableTruck = await _createId(api, '/api/trucks', {
      'plateNumber': availablePlate,
    });
    final maintenancePlate = 'M341-${suffix.substring(suffix.length - 6)}';
    final maintenanceTruck = await _createId(api, '/api/trucks', {
      'plateNumber': maintenancePlate,
    });
    await api.put<void>(
      '/api/trucks/$maintenanceTruck/status',
      data: {'status': 'Maintenance'},
    );
    final availableDriverName = 'A341 Driver $suffix';
    final availableDriver = await _createId(api, '/api/drivers', {
      'fullName': availableDriverName,
      'licenseNumber': 'A341-$suffix',
    });
    final unavailableDriverName = 'U341 Driver $suffix';
    final unavailableDriver = await _createId(api, '/api/drivers', {
      'fullName': unavailableDriverName,
      'licenseNumber': 'U341-$suffix',
    });
    await api.put<void>(
      '/api/drivers/$unavailableDriver/status',
      data: {'status': 'Unavailable'},
    );

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('العربية').last);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('language-selector'))),
      ),
      TextDirection.rtl,
    );
    await binding.takeScreenshot('01-arabic-rtl-shell');

    final assignedCargo = 'Browser assigned $suffix';
    await _openNewTrip(tester);
    await tester.enterText(find.byKey(const Key('trip-cargo')), assignedCargo);
    await _tap(tester, find.byKey(const Key('trip-step-1-next')));
    await _waitFor(tester, find.byKey(const Key('calculate-route')));
    await _selectMapStop(
      tester,
      buttonKey: 'trip-pickup-select-map',
      nameKey: 'trip-pickup-name',
      name: 'Ankara pickup',
      point: const LatLng(39.9208, 32.8541),
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('trip-pickup-latitude')))
          .controller!
          .text,
      isNotEmpty,
    );
    await _selectMapStop(
      tester,
      buttonKey: 'trip-delivery-select-map',
      nameKey: 'trip-delivery-name',
      name: 'Ankara delivery',
      point: const LatLng(39.9708, 32.9541),
    );
    await binding.takeScreenshot('02-map-selected-stops');
    await _tap(tester, find.byKey(const Key('calculate-route')));
    await _waitFor(
      tester,
      find.byKey(const Key('skip-assignment')),
      timeout: const Duration(seconds: 40),
    );
    expect(find.textContaining('km'), findsWidgets);
    expect(find.textContaining('min'), findsWidgets);
    await binding.takeScreenshot('03-route-distance-duration-provider');

    await _toggleAssignment(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.byKey(const Key('assignment-truck')));
    await _selectAssignmentOption(
      tester,
      fieldKey: 'assignment-truck',
      value: availableTruck,
    );
    await _selectAssignmentOption(
      tester,
      fieldKey: 'assignment-driver',
      value: availableDriver,
    );
    final optionTrip = await _tripByCargo(api, assignedCargo);
    final visibleOptions = await api.get<Map<String, dynamic>>(
      '/api/trips/${optionTrip['id']}/assignment-options',
    );
    expect(
      (visibleOptions.data!['trucks'] as List<dynamic>).any(
        (item) =>
            item['isEligible'] == false &&
            item['reasonCode'] == 'TRUCK_MAINTENANCE',
      ),
      true,
    );
    expect(
      (visibleOptions.data!['drivers'] as List<dynamic>).any(
        (item) =>
            item['isEligible'] == false &&
            item['reasonCode'] == 'DRIVER_NOT_AVAILABLE',
      ),
      true,
    );
    await binding.takeScreenshot('04-eligible-ineligible-reasons');
    await _tap(tester, find.byKey(const Key('trip-step-3-next')));
    await _waitFor(tester, find.byKey(const Key('trip-review-summary')));
    await binding.takeScreenshot('05-complete-review');
    await _pressFilledButton(tester, 'finish-assign-trip');
    final assignedTrip = await _waitForTripStatus(
      api,
      assignedCargo,
      'Assigned',
    );
    await _waitFor(tester, find.text(assignedCargo));
    expect(assignedTrip['status'], 'Assigned');
    expect(assignedTrip['truckId'], isNotNull);
    expect(assignedTrip['driverId'], isNotNull);
    await binding.takeScreenshot('06-assigned-trip-details');

    final draftCargo = 'Browser draft $suffix';
    await _openNewTrip(tester);
    await tester.enterText(find.byKey(const Key('trip-cargo')), draftCargo);
    await _tap(tester, find.byKey(const Key('trip-step-1-next')));
    await _waitFor(tester, find.byKey(const Key('calculate-route')));
    await _selectMapStop(
      tester,
      buttonKey: 'trip-pickup-select-map',
      nameKey: 'trip-pickup-name',
      name: 'Draft pickup',
      point: const LatLng(40.1000, 32.7000),
    );
    await _selectMapStop(
      tester,
      buttonKey: 'trip-delivery-select-map',
      nameKey: 'trip-delivery-name',
      name: 'Draft delivery',
      point: const LatLng(40.1600, 32.7800),
    );
    await _tap(tester, find.byKey(const Key('calculate-route')));
    await _waitFor(
      tester,
      find.byKey(const Key('trip-step-3-next')),
      timeout: const Duration(seconds: 40),
    );
    await _tap(tester, find.byKey(const Key('trip-step-3-next')));
    await _waitFor(tester, find.byKey(const Key('finish-save-draft')));
    await _pressOutlinedButton(tester, 'finish-save-draft');
    await _waitFor(
      tester,
      find.widgetWithText(OutlinedButton, 'تعديل المسودة'),
    );
    var draft = await _tripByCargo(api, draftCargo);
    expect(draft['status'], 'Draft');
    final draftId = draft['id'] as String;
    final originalRouteId = (draft['routePlan'] as Map<String, dynamic>)['id'];
    await binding.takeScreenshot('07-unassigned-draft-details');

    await _tap(tester, find.widgetWithText(OutlinedButton, 'تعديل المسودة'));
    await _waitFor(tester, find.byKey(const Key('skip-assignment')));
    await _tap(tester, find.byKey(const Key('edit-route')));
    await _tap(tester, find.byKey(const Key('calculate-route')));
    await _waitFor(
      tester,
      find.byKey(const Key('skip-assignment')),
      timeout: const Duration(seconds: 40),
    );
    await _tap(tester, find.byKey(const Key('save-draft')));
    await tester.pump(const Duration(seconds: 2));
    draft = await _tripByCargo(api, draftCargo);
    expect((draft['routePlan'] as Map<String, dynamic>)['id'], isNotNull);
    final options = await api.get<Map<String, dynamic>>(
      '/api/trips/$draftId/assignment-options',
    );
    expect(options.data!['canAssign'], true);
    await binding.takeScreenshot('08-resumed-unchanged-route-valid');

    // Deterministic assignment race: the UI has selected the first eligible
    // pair, then that exact truck becomes unavailable before confirmation.
    await _toggleAssignment(tester);
    final eligibleTruck = (options.data!['trucks'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['isEligible'] == true);
    final eligibleDriver = (options.data!['drivers'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['isEligible'] == true);
    await _selectAssignmentOption(
      tester,
      fieldKey: 'assignment-truck',
      value: eligibleTruck['id'] as String,
    );
    await _selectAssignmentOption(
      tester,
      fieldKey: 'assignment-driver',
      value: eligibleDriver['id'] as String,
    );
    await _tap(tester, find.byKey(const Key('trip-step-3-next')));
    await _waitFor(tester, find.byKey(const Key('finish-assign-trip')));
    final selectedTruck = eligibleTruck['id'] as String;
    await api.put<void>(
      '/api/trucks/$selectedTruck/status',
      data: {'status': 'Maintenance'},
    );
    await _pressFilledButton(tester, 'finish-assign-trip');
    await _waitFor(tester, find.byKey(const Key('skip-assignment')));
    draft = await _tripByCargo(api, draftCargo);
    expect(draft['status'], 'Draft');
    expect((draft['routePlan'] as Map<String, dynamic>)['id'], isNotNull);
    expect(await _tripCountByCargo(api, draftCargo), 1);
    await binding.takeScreenshot('09-assignment-race-draft-preserved');
    await api.put<void>(
      '/api/trucks/$selectedTruck/status',
      data: {'status': 'Available'},
    );

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('English').last);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('language-selector'))),
      ),
      TextDirection.ltr,
    );
    await binding.takeScreenshot('10-english-ltr-shell');

    binding.reportData = {
      'tenantEmail': email,
      'assignedTripId': assignedTrip['id'],
      'draftTripId': draftId,
      'routeIdBeforeUnchangedSave': originalRouteId,
      'routeIdAfterUnchangedSave':
          (draft['routePlan'] as Map<String, dynamic>)['id'],
      'assignmentRaceDraftCount': await _tripCountByCargo(api, draftCargo),
      'assignmentRaceRecovered': true,
      'arabicRtlVerified': true,
      'englishLtrVerified': true,
      'availableFixtureIds': [availableTruck, availableDriver],
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

Future<void> _openNewTrip(WidgetTester tester) async {
  if (find.byKey(const Key('add-trip')).evaluate().isEmpty) {
    final tripsNavigation = find.byKey(const Key('nav-trips'));
    if (tripsNavigation.evaluate().isNotEmpty) {
      await _tap(tester, tripsNavigation);
    } else {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/trips');
      await tester.pump(const Duration(milliseconds: 500));
    }
  }
  await _tap(tester, find.byKey(const Key('add-trip')));
  await _waitFor(tester, find.byKey(const Key('trip-cargo')));
}

Future<void> _selectMapStop(
  WidgetTester tester, {
  required String buttonKey,
  required String nameKey,
  required String name,
  required LatLng point,
}) async {
  await tester.enterText(find.byKey(Key(nameKey)), name);
  await _tap(tester, find.byKey(Key(buttonKey)));
  tester
      .widget<MapLibreMap>(find.byKey(const Key('trip-planner-map')))
      .onMapClick!(const Point<double>(200, 140), point);
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _toggleAssignment(WidgetTester tester) async {
  final tile = tester.widget<SwitchListTile>(
    find.byKey(const Key('skip-assignment')),
  );
  expect(tile.value, true);
  tile.onChanged!(false);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _selectAssignmentOption(
  WidgetTester tester, {
  required String fieldKey,
  required String value,
}) async {
  final fieldFinder = find.descendant(
    of: find.byKey(Key(fieldKey)),
    matching: find.byType(DropdownButtonFormField<String>),
  );
  await _waitFor(tester, fieldFinder);
  final field = tester.widget<DropdownButtonFormField<String>>(
    fieldFinder.first,
  );
  field.onChanged!(value);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pressFilledButton(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await _waitFor(tester, finder);
  final button = tester.widget<FilledButton>(finder);
  expect(button.onPressed, isNotNull, reason: '$key must be enabled');
  button.onPressed!.call();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pressOutlinedButton(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await _waitFor(tester, finder);
  final button = tester.widget<OutlinedButton>(finder);
  expect(button.onPressed, isNotNull, reason: '$key must be enabled');
  button.onPressed!.call();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<Map<String, dynamic>> _tripByCargo(Dio api, String cargo) async {
  final response = await api.get<Map<String, dynamic>>(
    '/api/trips',
    queryParameters: {'pageSize': 100, 'sort': 'created', 'direction': 'desc'},
  );
  return (response.data!['items'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .singleWhere((item) => item['cargoDescription'] == cargo);
}

Future<int> _tripCountByCargo(Dio api, String cargo) async {
  final response = await api.get<Map<String, dynamic>>(
    '/api/trips',
    queryParameters: {'pageSize': 100, 'sort': 'created', 'direction': 'desc'},
  );
  return (response.data!['items'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((item) => item['cargoDescription'] == cargo)
      .length;
}

Future<Map<String, dynamic>> _waitForTripStatus(
  Dio api,
  String cargo,
  String status,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final trip = await _tripByCargo(api, cargo);
    if (trip['status'] == status) return trip;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  final trip = await _tripByCargo(api, cargo);
  expect(trip['status'], status);
  return trip;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  // The dashboard intentionally polls forever; pump a bounded frame window
  // instead of waiting for the whole app to become permanently idle.
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}
