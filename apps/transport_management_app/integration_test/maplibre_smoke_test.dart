import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'owner@demo.local',
  );
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('configured MapLibre style genuinely reaches ready state', (
    tester,
  ) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await _login(tester, email, password);

    expect(find.byKey(const Key('map-status-loading')), findsWidgets);
    await _waitFor(
      tester,
      find.byKey(const Key('map-status-loaded')),
      timeout: const Duration(seconds: 30),
    );
    expect(find.byKey(const Key('real-maplibre-map')), findsOneWidget);
    expect(find.byKey(const Key('offline-map-surface')), findsNothing);
    expect(find.byKey(const Key('map-status-fallback')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('sim-start')));
    await tester.tap(find.byKey(const Key('sim-start')));
    final realTruck = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('real-map-truck-'),
      description: 'truck selector backed by real MapLibre annotations',
    );
    await _waitFor(tester, realTruck);
    expect(find.byKey(const Key('map-annotations-ready')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'fallback-truck-marker-',
            ),
      ),
      findsNothing,
    );

    await tester.ensureVisible(realTruck.first);
    await tester.tap(realTruck.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Driver'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await binding.takeScreenshot('maplibre-real-map');

    await tester.tap(find.byKey(const Key('logout-button')));
    await _waitFor(tester, find.byType(TextFormField));
  });
}

Future<void> _login(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.byType(FilledButton));
  await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
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
