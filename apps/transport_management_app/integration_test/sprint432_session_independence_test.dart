import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const role = String.fromEnvironment('E2E_SESSION_ROLE');
  const ownerEmail = String.fromEnvironment('E2E_EMAIL');
  const driverEmail = String.fromEnvironment('E2E_INVITEE_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');
  const brokerUrl = String.fromEnvironment(
    'E2E_BROKER_URL',
    defaultValue: 'http://localhost:8099',
  );

  testWidgets('Owner and Driver isolated sessions remain independent', (
    tester,
  ) async {
    expect({'owner', 'driver'}, contains(role));
    final expectedEmail = role == 'owner' ? ownerEmail : driverEmail;
    final expectedHome = role == 'owner' ? 'fleet-dashboard' : 'driver-my-trip';
    final ownReady = role == 'owner' ? '/owner-ready' : '/driver-ready';
    final peerReady = role == 'owner' ? '/driver-ready' : '/owner-ready';
    final broker = Dio(BaseOptions(baseUrl: brokerUrl));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TransportManagementApp(),
      ),
    );
    await _waitFor(tester, find.byKey(const Key('login-submit')));
    await _waitUntil(tester, () {
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('login-submit')),
      );
      return button.onPressed != null;
    });
    await tester.enterText(find.byKey(const Key('login-email')), expectedEmail);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.byKey(const Key('login-submit')));
    await _waitFor(tester, find.byKey(Key(expectedHome)));
    expect(
      container.read(authControllerProvider).value!.user.email,
      expectedEmail,
    );
    await broker.post<void>(ownReady);
    await _waitUntil(tester, () async {
      final response = await broker.get<Map<String, dynamic>>(peerReady);
      return response.data?['ready'] == true;
    });
    expect(find.byKey(Key(expectedHome)), findsOneWidget);
    expect(
      container.read(authControllerProvider).value!.user.email,
      expectedEmail,
    );
    await container.read(authControllerProvider.notifier).logout();
    await tester.pump();
    await _waitFor(tester, find.byKey(const Key('login-submit')));
    expect(container.read(authControllerProvider).value, isNull);
  });
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) => _waitUntil(tester, () => finder.evaluate().isNotEmpty, timeout: timeout);

Future<void> _waitUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(await condition(), isTrue);
}
