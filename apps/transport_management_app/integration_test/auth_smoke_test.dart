import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'owner@demo.local',
  );
  const password = String.fromEnvironment('E2E_PASSWORD');
  const expectedHomeKey = String.fromEnvironment(
    'E2E_EXPECTED_HOME_KEY',
    defaultValue: 'fleet-dashboard',
  );

  testWidgets('login and logout return the user to the login route', (
    tester,
  ) async {
    expect(
      password,
      isNotEmpty,
      reason:
          'Pass the smoke-test password with --dart-define=E2E_PASSWORD=...',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TransportManagementApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump(const Duration(milliseconds: 200));

    final authDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (container.read(authControllerProvider).isLoading &&
        DateTime.now().isBefore(authDeadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final auth = container.read(authControllerProvider);
    expect(auth.hasError, isFalse, reason: 'Login returned an auth error.');
    expect(auth.value, isNotNull, reason: 'Login did not create a session.');
    await _waitFor(tester, find.byKey(const Key(expectedHomeKey)));
    await tester.tap(find.byKey(const Key('account-identity-control')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await _waitFor(tester, find.byType(TextFormField));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byKey(const Key(expectedHomeKey)), findsNothing);
  });
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}
