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

  testWidgets('login and logout return the user to the login route', (
    tester,
  ) async {
    expect(
      password,
      isNotEmpty,
      reason: 'Pass the smoke-test password with --dart-define=E2E_PASSWORD=...',
    );
    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      email,
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byTooltip('Sign out'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
