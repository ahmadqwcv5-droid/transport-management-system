import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/anonymous_locale_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const inviteeEmail = String.fromEnvironment('E2E_INVITEE_EMAIL');
  const inviteePassword = String.fromEnvironment('E2E_INVITEE_PASSWORD');
  const brokerUrl = String.fromEnvironment(
    'E2E_BROKER_URL',
    defaultValue: 'http://localhost:8099',
  );

  testWidgets(
    'isolated invitee switches to Arabic and accepts with password control',
    (tester) async {
      expect(inviteeEmail, isNotEmpty);
      expect(inviteePassword.length, greaterThanOrEqualTo(12));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final broker = Dio(BaseOptions(baseUrl: brokerUrl));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TransportManagementApp(),
        ),
      );
      await _waitFor(tester, find.byKey(const Key('login-submit')));

      late String invitationPath;
      await _waitUntil(tester, () async {
        final response = await broker.get<Map<String, dynamic>>(
          '/invitation',
          options: Options(
            validateStatus: (status) => status == 200 || status == 204,
          ),
        );
        final path = response.data?['path'];
        if (path is! String || path.isEmpty) return false;
        invitationPath = path;
        return true;
      }, timeout: const Duration(seconds: 45));

      GoRouter.of(
        tester.element(find.byKey(const Key('login-submit'))),
      ).go(invitationPath);
      await _waitFor(tester, find.byKey(const Key('accept-invitation')));

      await tester.tap(find.text('العربية').last);
      await tester.pumpAndSettle();
      expect(container.read(anonymousLocaleControllerProvider).value, 'ar');
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('accept-invitation'))),
        ),
        TextDirection.rtl,
      );
      await binding.takeScreenshot('public-invitation-arabic-rtl');
      await tester.enterText(
        find.byKey(const Key('invitation-email')),
        inviteeEmail,
      );
      await tester.enterText(
        find.byKey(const Key('invitation-name')),
        'سائق فايرفوكس',
      );
      await tester.enterText(
        find.byKey(const Key('invitation-password')),
        inviteePassword,
      );
      final passwordScope = find.byKey(const Key('invitation-password'));
      final passwordField = find.descendant(
        of: passwordScope,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);
      final visibilityButton = find.descendant(
        of: passwordScope,
        matching: find.byType(IconButton),
      );
      await tester.tap(visibilityButton);
      await tester.pump();
      expect(tester.widget<EditableText>(passwordField).obscureText, isFalse);
      await tester.tap(visibilityButton);
      await tester.pump();
      expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);

      await tester.ensureVisible(find.byKey(const Key('accept-invitation')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('accept-invitation')));
      await _waitFor(
        tester,
        find.byKey(const Key('invitation-accepted-state')),
      );
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('invitation-accepted-state'))),
        ),
        TextDirection.rtl,
      );
      await broker.post<void>(
        '/accepted',
        options: Options(contentType: Headers.textPlainContentType),
      );
    },
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) => _waitUntil(tester, () => finder.evaluate().isNotEmpty, timeout: timeout);

Future<void> _waitUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(await condition(), isTrue);
}
