import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'owner@demo.local',
  );
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('unreachable style times out, retries, and enters fallback', (
    tester,
  ) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.byType(FilledButton));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));

    expect(find.byKey(const Key('maplibre-attempt-0')), findsOneWidget);
    await _waitFor(tester, find.byKey(const Key('map-status-failed')));
    await tester.tap(find.byKey(const Key('map-retry')));
    await tester.pump();
    expect(find.byKey(const Key('maplibre-attempt-1')), findsOneWidget);
    expect(find.byKey(const Key('map-status-loading')), findsOneWidget);
    await _waitFor(tester, find.byKey(const Key('map-status-failed')));
    await tester.tap(find.byKey(const Key('map-use-fallback')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-status-fallback')), findsOneWidget);
    expect(find.byKey(const Key('offline-map-surface')), findsOneWidget);
    expect(find.byKey(const Key('map-status-loaded')), findsNothing);
    await tester.tap(find.byKey(const Key('logout-button')));
    await _waitFor(tester, find.byType(TextFormField));
  });
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
