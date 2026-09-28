import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ownerEmail = String.fromEnvironment('E2E_EMAIL');
  const ownerPassword = String.fromEnvironment('E2E_PASSWORD');
  const inviteeEmail = String.fromEnvironment('E2E_INVITEE_EMAIL');
  const inviteePassword = String.fromEnvironment('E2E_INVITEE_PASSWORD');

  testWidgets('owner invitation is accepted with a self-owned local account', (
    tester,
  ) async {
    expect(ownerEmail, isNotEmpty);
    expect(ownerPassword, isNotEmpty);
    expect(inviteeEmail, isNotEmpty);
    expect(inviteePassword.length, greaterThanOrEqualTo(12));

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await tester.pumpAndSettle();
    await _login(tester, ownerEmail, ownerPassword);
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));

    await tester.tap(find.byKey(const Key('nav-company-users')));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.byKey(const Key('create-driver-user')));
    await tester.tap(find.byKey(const Key('create-driver-user')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('driver-user-name')),
      'Firefox Sprint Driver',
    );
    await tester.enterText(
      find.byKey(const Key('driver-user-email')),
      inviteeEmail,
    );
    await tester.tap(find.byKey(const Key('save-driver-user')));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.byKey(const Key('invitation-link-value')));
    final invitationPath = tester
        .widget<SelectableText>(find.byKey(const Key('invitation-link-value')))
        .data!;
    expect(invitationPath, startsWith('/accept-invitation?token='));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-identity-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-button')));
    await _waitFor(tester, find.byKey(const Key('login-submit')));

    GoRouter.of(tester.element(find.byKey(const Key('login-submit'))))
        .go(invitationPath);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.byKey(const Key('accept-invitation')));
    await tester.enterText(
      find.byKey(const Key('invitation-email')),
      inviteeEmail,
    );
    await tester.enterText(
      find.byKey(const Key('invitation-name')),
      'Firefox Sprint Driver',
    );
    await tester.enterText(
      find.byKey(const Key('invitation-password')),
      inviteePassword,
    );
    await tester.tap(find.byKey(const Key('accept-invitation')));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.textContaining('Invitation accepted'));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}

Future<void> _login(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}
