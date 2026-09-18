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

  testWidgets('route-aware planner, operations, and fleet map workflow', (
    tester,
  ) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final clientName = 'Route Client $suffix';
    final plate = 'RT-${suffix.substring(suffix.length - 8)}';
    final driverName = 'Route Driver $suffix';
    final pickup = 'Ankara Depot $suffix';
    final delivery = 'Istanbul Customer $suffix';

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
    await _tap(tester, find.text('English').last);

    await _tap(tester, find.text('Clients'));
    await _tap(tester, find.byKey(const Key('add-client')));
    await tester.enterText(find.byKey(const Key('client-name')), clientName);
    await _tap(tester, find.byKey(const Key('save-client')));

    await _tap(tester, find.text('Trucks'));
    await _tap(tester, find.byKey(const Key('add-truck')));
    await tester.enterText(find.byKey(const Key('truck-plate')), plate);
    await _tap(tester, find.byKey(const Key('save-truck')));

    await _tap(tester, find.text('Drivers'));
    await _tap(tester, find.byKey(const Key('add-driver')));
    await tester.enterText(find.byKey(const Key('driver-name')), driverName);
    await tester.enterText(
      find.byKey(const Key('driver-license')),
      'RL-$suffix',
    );
    await _tap(tester, find.byKey(const Key('save-driver')));

    await _tap(tester, find.text('Trips'));
    await _tap(tester, find.byKey(const Key('add-trip')));
    await tester.enterText(find.byKey(const Key('trip-pickup-name')), pickup);
    await tester.enterText(
      find.byKey(const Key('trip-pickup-latitude')),
      '39.9334',
    );
    await tester.enterText(
      find.byKey(const Key('trip-pickup-longitude')),
      '32.8597',
    );
    await tester.enterText(
      find.byKey(const Key('trip-delivery-name')),
      delivery,
    );
    await tester.enterText(
      find.byKey(const Key('trip-delivery-latitude')),
      '41.0082',
    );
    await tester.enterText(
      find.byKey(const Key('trip-delivery-longitude')),
      '28.9784',
    );
    await tester.enterText(
      find.byKey(const Key('trip-cargo')),
      'Route-aware cargo',
    );
    await tester.enterText(find.byKey(const Key('trip-price')), '2500');
    await binding.takeScreenshot('01-planner-locations');

    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('calculate-route')));
    await _waitFor(
      tester,
      find.textContaining('km ·'),
      timeout: const Duration(seconds: 30),
    );
    await binding.takeScreenshot('02-road-route-preview');
    await _tap(tester, find.byKey(const Key('save-trip')));
    await _waitFor(tester, find.text('$pickup → $delivery'));
    await _tap(tester, find.text('$pickup → $delivery'));
    await _waitFor(tester, find.text('Route distance'));
    await binding.takeScreenshot('03-route-trip-details');

    await _tap(tester, find.byKey(const Key('trip-action-assign')));
    await _tap(tester, find.byKey(const Key('confirm-assignment')));
    await _tap(tester, find.byKey(const Key('trip-action-start')));
    await _tap(tester, find.byKey(const Key('trip-action-mark-in-transit')));
    await _tap(tester, find.text('Dashboard'));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _tap(tester, find.byKey(const Key('sim-start')));
    final selector = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('real-map-truck-'),
    );
    await _waitFor(tester, selector, timeout: const Duration(seconds: 30));
    await _tap(tester, selector.first);
    await _waitFor(tester, find.byKey(const Key('fleet-route-progress')));
    _hideSnackBar(tester);
    await binding.takeScreenshot('01-road-detailed-selected-truck');

    // Observe ten complete one-second polling cycles. The deterministic
    // coordinator test records exact operation counts; this browser interval
    // proves the platform view stays continuously rendered under real polling.
    // One deterministic simulator step per cycle makes the travelled trail
    // visually legible at full-route zoom.
    for (var cycle = 0; cycle < 10; cycle++) {
      await _tap(tester, find.byKey(const Key('sim-step')));
      await tester.pump(const Duration(seconds: 1));
    }
    await binding.takeScreenshot('02-route-trail-stops-after-10-polls');

    final map = find.byKey(const Key('real-maplibre-map'));
    await tester.drag(map, const Offset(120, 0));
    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await binding.takeScreenshot('03-manual-pan-preserved');
    await _tap(tester, find.byKey(const Key('fleet-map-recenter')));
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('04-fit-route-recentered');

    await _tap(tester, find.byKey(const Key('sim-pause')));
    await tester.pump(const Duration(seconds: 2));
    await _tap(tester, find.byKey(const Key('sim-resume')));
    await tester.pump(const Duration(seconds: 2));

    if (selector.evaluate().length > 1) {
      await _tap(tester, selector.last);
      await tester.pump(const Duration(seconds: 1));
      await binding.takeScreenshot('05-synchronized-fleet-selection');
    }

    await _tap(tester, find.text('Settings'));
    await _tap(tester, find.byKey(const Key('language-selector')));
    await _tap(tester, find.text('العربية').last);
    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    _hideSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('06-arabic-rtl-fleet');
  });
}

void _hideSnackBar(WidgetTester tester) {
  ScaffoldMessenger.of(
    tester.element(find.byType(Scaffold).first),
  ).clearSnackBars();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 150));
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
