import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/google_web_identity_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'configured backend and Web client expose Google Identity Services',
    (tester) async {
      const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      expect(clientId, isNotEmpty);

      await tester.pumpWidget(
        const ProviderScope(child: TransportManagementApp()),
      );
      await _waitFor(tester, find.byKey(const Key('login-submit')));
      await _waitFor(tester, find.byType(GoogleWebIdentityButton));

      expect(find.byType(GoogleWebIdentityButton), findsOneWidget);
    },
  );
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
