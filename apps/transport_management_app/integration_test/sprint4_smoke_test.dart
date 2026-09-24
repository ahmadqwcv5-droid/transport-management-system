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
  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('Sprint 4 customer and fleet browser acceptance', (tester) async {
    expect(email, isNotEmpty);
    expect(password, isNotEmpty);
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
      data: {'preferredLocale': 'ar'},
    );
    final driverName = 'Sprint4 Driver $suffix';
    final driver = await api.post<Map<String, dynamic>>(
      '/api/drivers',
      data: {'fullName': driverName, 'licenseNumber': 'S4-$suffix'},
    );
    final driverId = driver.data!['id'] as String;

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await _tap(tester, find.byType(FilledButton));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('fleet-dashboard'))),
      ),
      TextDirection.rtl,
    );
    await binding.takeScreenshot('01-arabic-login-dashboard');
    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('English').last);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('language-selector'))),
      ),
      TextDirection.ltr,
    );

    final clientName = 'Sprint4 Client $suffix';
    await _tap(tester, find.byKey(const Key('nav-clients')));
    await _tap(tester, find.byKey(const Key('add-client')));
    await tester.enterText(find.byKey(const Key('client-name')), clientName);
    await tester.enterText(
      find.byKey(const Key('client-legal-name')),
      'Sprint4 Legal $suffix',
    );
    await _tap(tester, find.byKey(const Key('save-client')));
    await tester.enterText(find.byKey(const Key('clients-search')), clientName);
    await tester.pump(const Duration(seconds: 1));
    await _waitFor(tester, find.text(clientName));
    await binding.takeScreenshot('02-client-created-immediate-list');
    await _tap(tester, find.text(clientName).last);
    await _waitFor(tester, find.byKey(const Key('client-details')));

    await _addContact(tester, 'Primary Contact $suffix', primary: true);
    await _addContact(tester, 'Secondary Contact $suffix', primary: false);
    await _addMapSite(tester, 'Factory $suffix');
    await _addManualSite(tester, 'Warehouse $suffix');
    await binding.takeScreenshot('03-client-contacts-sites-map');

    final plate = 'S4-${suffix.substring(suffix.length - 7)}';
    await _tap(tester, find.byKey(const Key('nav-trucks')));
    await _tap(tester, find.byKey(const Key('add-truck')));
    await tester.enterText(find.byKey(const Key('truck-plate')), plate);
    await tester.enterText(
      find.byKey(const Key('truck-fleet-code')),
      'F-$suffix',
    );
    await tester.enterText(find.byKey(const Key('truck-vin')), 'VIN$suffix');
    final driverDropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(driverDropdowns.last);
    tester
        .widget<DropdownButtonFormField<String>>(driverDropdowns.last)
        .onChanged!(driverId);
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, find.byKey(const Key('save-truck')));
    await tester.enterText(find.byKey(const Key('trucks-search')), plate);
    await tester.pump(const Duration(seconds: 1));
    await _waitFor(tester, find.text(plate));
    await binding.takeScreenshot('04-truck-created-immediate-list');
    await _tap(tester, find.text(plate).last);
    await _waitFor(tester, find.byKey(const Key('truck-details')));
    await tester.drag(
      find.byKey(const Key('truck-details')),
      const Offset(0, -420),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('05-truck-profile-default-driver-history');

    await _tap(tester, find.byKey(const Key('nav-clients')));
    await tester.enterText(find.byKey(const Key('clients-search')), clientName);
    await tester.pump(const Duration(seconds: 1));
    await _waitFor(tester, find.text(clientName));
    await binding.takeScreenshot('06-english-client-list-no-reload');

    final clients = await api.get<List<dynamic>>('/api/clients');
    final createdClient = clients.data!
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['name'] == clientName);
    final details = await api.get<Map<String, dynamic>>(
      '/api/clients/${createdClient['id']}/details',
    );
    final trucks = await api.get<List<dynamic>>('/api/trucks');
    final createdTruck = trucks.data!.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['plateNumber'] == plate,
    );
    expect((details.data!['contacts'] as List<dynamic>).length, 2);
    expect((details.data!['sites'] as List<dynamic>).length, 2);
    expect(createdTruck['defaultDriverId'], driverId);

    await _tap(tester, find.byKey(const Key('logout-button')));
    await _waitFor(tester, find.byType(FilledButton));
    await binding.takeScreenshot('07-logout-login-redirect');
    binding.reportData = {
      'clientId': createdClient['id'],
      'truckId': createdTruck['id'],
      'driverId': driverId,
      'contactsCreated': 2,
      'sitesCreated': 2,
      'factoryMapCoordinate': {'latitude': 39.9208, 'longitude': 32.8541},
      'immediateRefreshVerified': true,
      'defaultDriverVerified': true,
      'arabicRtlVerified': true,
      'englishLtrVerified': true,
      'logoutRedirectVerified': true,
    };
  });
}

Future<void> _addContact(
  WidgetTester tester,
  String name, {
  required bool primary,
}) async {
  await _tap(tester, find.byKey(const Key('add-client-contact')));
  await tester.enterText(find.byKey(const Key('contact-name')), name);
  final checkbox = tester.widget<CheckboxListTile>(
    find.byType(CheckboxListTile),
  );
  if (checkbox.value != primary) checkbox.onChanged!(primary);
  await tester.pump();
  await _tap(tester, find.byType(FilledButton).last);
  await _waitFor(tester, find.text(name));
}

Future<void> _addMapSite(WidgetTester tester, String name) async {
  await _tap(tester, find.byKey(const Key('add-client-site')));
  await tester.enterText(find.byKey(const Key('site-name')), name);
  await _tap(tester, find.byKey(const Key('site-select-map')));
  await _waitFor(tester, find.byKey(const Key('location-picker-dialog')));
  tester
      .widget<MapLibreMap>(find.byKey(const Key('location-picker-map')))
      .onMapClick!(
    const Point<double>(220, 150),
    const LatLng(39.9208, 32.8541),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await _tap(tester, find.byKey(const Key('confirm-location')));
  expect(
    tester
        .widget<TextField>(find.byKey(const Key('site-latitude')))
        .controller!
        .text,
    startsWith('39.9208'),
  );
  await _tap(tester, find.byType(FilledButton).last);
  await _waitFor(tester, find.text(name));
}

Future<void> _addManualSite(WidgetTester tester, String name) async {
  await _tap(tester, find.byKey(const Key('add-client-site')));
  await tester.enterText(find.byKey(const Key('site-name')), name);
  await tester.enterText(find.byKey(const Key('site-latitude')), '39.9708');
  await tester.enterText(find.byKey(const Key('site-longitude')), '32.9541');
  await _tap(tester, find.byType(FilledButton).last);
  await _waitFor(tester, find.text(name));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}
