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

  testWidgets('complete Sprint 2 operational workflow', (tester) async {
    expect(
      password,
      isNotEmpty,
      reason: 'Pass E2E_PASSWORD with --dart-define.',
    );
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final clientName = 'E2E Factory $suffix';
    final plate = 'E2E-$suffix';
    final driverName = 'E2E Driver $suffix';
    final origin = 'Origin $suffix';
    final destination = 'Destination $suffix';

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clients'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-client')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('client-name')), clientName);
    await tester.tap(find.byKey(const Key('save-client')));
    await tester.pumpAndSettle();
    expect(find.text(clientName), findsOneWidget);

    await tester.tap(find.text('Trucks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-truck')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('truck-plate')), plate);
    await tester.tap(find.byKey(const Key('save-truck')));
    await tester.pumpAndSettle();
    expect(find.text(plate), findsOneWidget);

    await tester.tap(find.text('Drivers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-driver')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('driver-name')), driverName);
    await tester.enterText(
      find.byKey(const Key('driver-license')),
      'LIC-$suffix',
    );
    await tester.tap(find.byKey(const Key('save-driver')));
    await tester.pumpAndSettle();
    expect(find.text(driverName), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-trip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trip-origin')), origin);
    await tester.enterText(
      find.byKey(const Key('trip-destination')),
      destination,
    );
    await tester.enterText(find.byKey(const Key('trip-cargo')), 'E2E cargo');
    await tester.enterText(find.byKey(const Key('trip-price')), '2500');
    await tester.tap(find.byKey(const Key('save-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$origin → $destination'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-action-assign')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-assignment')));
    await tester.pumpAndSettle();
    for (final action in ['start', 'mark-in-transit', 'deliver', 'complete']) {
      await tester.tap(find.byKey(Key('trip-action-$action')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Completed'), findsWidgets);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}
