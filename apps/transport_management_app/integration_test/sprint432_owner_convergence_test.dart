import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/company_users/presentation/company_users_controller.dart';
import 'package:transport_management_app/features/memberships/presentation/membership_providers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ownerEmail = String.fromEnvironment('E2E_EMAIL');
  const ownerPassword = String.fromEnvironment('E2E_PASSWORD');
  const inviteeEmail = String.fromEnvironment('E2E_INVITEE_EMAIL');
  const brokerUrl = String.fromEnvironment(
    'E2E_BROKER_URL',
    defaultValue: 'http://localhost:8099',
  );
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );

  testWidgets(
    'owner screen converges after isolated invitee acceptance without reload',
    (tester) async {
      expect(ownerEmail, isNotEmpty);
      expect(ownerPassword, isNotEmpty);
      expect(inviteeEmail, isNotEmpty);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final broker = Dio(BaseOptions(baseUrl: brokerUrl));
      final ownerApi = Dio(BaseOptions(baseUrl: baseUrl));
      final login = await ownerApi.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': ownerEmail, 'password': ownerPassword},
      );
      ownerApi.options.headers['Authorization'] =
          'Bearer ${login.data!['accessToken']}';
      final suffix = DateTime.now().millisecondsSinceEpoch.toString();
      final driverName = 'Sprint 4.3.2 Linked Firefox Driver';
      final createdDriver = await ownerApi.post<Map<String, dynamic>>(
        '/api/drivers',
        data: {'fullName': driverName, 'licenseNumber': 'S432-LINK-$suffix'},
      );
      final driverId = createdDriver.data!['id'] as String;

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
      await tester.enterText(find.byKey(const Key('login-email')), ownerEmail);
      await tester.enterText(
        find.byKey(const Key('login-password')),
        ownerPassword,
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));

      await tester.tap(find.byKey(const Key('nav-company-users')));
      await _waitFor(tester, find.byKey(const Key('create-driver-user')));
      await tester.tap(find.byKey(const Key('create-driver-user')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('driver-user-name')),
        'Sprint 4.3.2 Firefox Driver',
      );
      await tester.enterText(
        find.byKey(const Key('driver-user-email')),
        inviteeEmail,
      );
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('driver-user-link')),
          )
          .onChanged!(driverId);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('save-driver-user')));
      await _waitFor(tester, find.byKey(const Key('invitation-link-value')));

      final invitationValue = tester
          .widget<SelectableText>(
            find.byKey(const Key('invitation-link-value')),
          )
          .data!;
      final invitationUri = Uri.tryParse(invitationValue);
      final invitationPath =
          invitationUri?.fragment.startsWith('/accept-invitation?token=') ==
              true
          ? invitationUri!.fragment
          : invitationValue;
      if (!invitationPath.startsWith('/accept-invitation?token=')) {
        fail('The generated invitation URL was not valid.');
      }
      await tester.tap(find.byKey(const Key('invitation-link-done')));
      await tester.pump();

      await tester.tap(find.byType(Tab).at(1));
      await tester.pump(const Duration(milliseconds: 300));
      await _waitUntil(tester, () {
        final invitations =
            container.read(invitationsProvider).value ?? const [];
        return invitations.any(
          (item) => item.email == inviteeEmail && item.status == 'Pending',
        );
      });
      final membersBefore =
          container.read(companyUsersControllerProvider).value ?? const [];
      expect(
        membersBefore.any((member) => member.email == inviteeEmail),
        isFalse,
      );
      expect(find.text(inviteeEmail), findsWidgets);
      await binding.takeScreenshot('invitation-pending-no-member');

      await broker.post<void>(
        '/invitation',
        data: jsonEncode(<String, String>{'path': invitationPath}),
        options: Options(contentType: Headers.textPlainContentType),
      );

      await _waitUntil(tester, () async {
        final response = await broker.get<Map<String, dynamic>>('/accepted');
        return response.data?['accepted'] == true;
      }, timeout: const Duration(seconds: 120));

      final convergenceStartedAt = DateTime.now();
      await _waitUntil(tester, () {
        final invitations =
            container.read(invitationsProvider).value ?? const [];
        final members =
            container.read(companyUsersControllerProvider).value ?? const [];
        final invitationConverged = invitations.any(
          (item) => item.email == inviteeEmail && item.status != 'Pending',
        );
        final matchingMembers = members.where(
          (item) => item.email == inviteeEmail,
        );
        if (matchingMembers.isEmpty) return false;
        final member = matchingMembers.single;
        return invitationConverged &&
            member.membershipStatus == 'Active' &&
            member.roles.contains('Driver') &&
            member.driverId == driverId &&
            member.driverName == driverName;
      }, timeout: const Duration(seconds: 10));
      expect(
        DateTime.now().difference(convergenceStartedAt),
        lessThanOrEqualTo(const Duration(seconds: 10)),
      );

      final tabController = DefaultTabController.of(
        tester.element(find.byType(TabBar)),
      );
      expect(tabController.index, 1);
      await tester.tap(find.byType(Tab).at(0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(inviteeEmail), findsWidgets);
      await binding.takeScreenshot('invitation-converged-linked-driver');
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
