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

  testWidgets('Sprint 3 localized tracking workflow', (tester) async {
    expect(password, isNotEmpty, reason: 'Pass --dart-define=E2E_PASSWORD=...');
    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.byType(FilledButton));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));

    // A previous interrupted local run may have left the persisted preference
    // in Arabic. Normalize to English so the language transition is exercised.
    if (find.text('لوحة التشغيل').evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('nav-settings')));
      await _waitFor(tester, find.byKey(const Key('language-selector')));
      await tester.tap(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    }

    // Always create a fresh truck so this smoke test does not depend on seed
    // data or positions left by a previous run.
    await tester.tap(find.byKey(const Key('nav-trucks')));
    await _waitFor(tester, find.byKey(const Key('add-truck')));
    await tester.tap(find.byKey(const Key('add-truck')));
    await tester.pumpAndSettle();
    final suffix = DateTime.now().millisecondsSinceEpoch % 1000000;
    await tester.enterText(find.byKey(const Key('truck-plate')), 'E2E-$suffix');
    await tester.tap(find.byKey(const Key('save-truck')));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('nav-settings')));
    await _waitFor(tester, find.byKey(const Key('language-selector')));
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    final dashboardContext = tester.element(
      find.byKey(const Key('fleet-dashboard')),
    );
    expect(Directionality.of(dashboardContext), TextDirection.rtl);
    expect(find.text('لوحة التشغيل'), findsWidgets);

    await tester.tap(find.byKey(const Key('sim-start')));
    final marker = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('truck-marker-'),
      description: 'tracked truck marker',
    );
    await _waitFor(tester, marker);
    await tester.tap(marker.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('السائق'), findsWidgets);
    expect(find.textContaining('الرحلة النشطة'), findsOneWidget);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sim-pause')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('nav-settings')));
    await _waitFor(tester, find.byKey(const Key('language-selector')));
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await _waitFor(tester, find.text('Dashboard'));
    expect(
      Directionality.of(tester.element(find.byKey(const Key('logout-button')))),
      TextDirection.ltr,
    );

    await tester.tap(find.byKey(const Key('logout-button')));
    await _waitFor(tester, find.byType(TextFormField));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
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
