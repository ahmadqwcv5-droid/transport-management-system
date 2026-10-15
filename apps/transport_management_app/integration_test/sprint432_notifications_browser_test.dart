import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/live_operations_controller.dart';
import 'package:transport_management_app/features/live_operations/presentation/notification_snapshot_text.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );
  const ownerEmail = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('real Firefox localized notification categories', (tester) async {
    final owner = await _signedIn(baseUrl, ownerEmail, password);
    final me = await owner.get<Map<String, dynamic>>('/api/auth/me');
    final originalLocale = me.data!['preferredLocale'] as String? ?? 'en';
    addTearDown(() async {
      await owner.put<void>(
        '/api/auth/me/preferences',
        data: {'preferredLocale': originalLocale},
      );
    });
    await owner.put<void>(
      '/api/auth/me/preferences',
      data: {'preferredLocale': 'en'},
    );

    final oldTrips = await owner.get<Map<String, dynamic>>(
      '/api/trips',
      queryParameters: {'pageSize': 100},
    );
    for (final trip
        in (oldTrips.data!['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      if (trip['cargoDescription'] == 'Sprint 4.3.2 notification cargo' &&
          !const {
            'Completed',
            'Cancelled',
            'Archived',
          }.contains(trip['status'])) {
        await owner.post<void>(
          '/api/trips/${trip['id']}/cancel',
          data: {'reason': 'Sprint 4.3.2 disposable rerun cleanup'},
          options: Options(validateStatus: (_) => true),
        );
      }
    }
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final driverAResponse = await owner.post<Map<String, dynamic>>(
      '/api/drivers',
      data: {
        'fullName': 'Sprint 4.3.2 Current Driver',
        'licenseNumber': 'S432-CURRENT-$suffix',
      },
    );
    final driverAId = driverAResponse.data!['id'] as String;
    final driverAEmail = 'sprint432.current.$suffix@demo.local';
    final invitation = await owner.post<Map<String, dynamic>>(
      '/api/membership-invitations',
      data: {
        'email': driverAEmail,
        'displayName': 'Sprint 4.3.2 Current Driver',
        'roles': ['Driver'],
        'driverId': driverAId,
      },
    );
    final invitationUri = Uri.parse(
      invitation.data!['acceptancePath'] as String,
    );
    final invitationRoute = invitationUri.fragment.isNotEmpty
        ? Uri.parse(invitationUri.fragment)
        : invitationUri;
    final token = invitationRoute.queryParameters['token']!;
    final anonymous = Dio(BaseOptions(baseUrl: baseUrl));
    await anonymous.post<void>(
      '/api/invitations/accept',
      data: {
        'token': token,
        'email': driverAEmail,
        'displayName': 'Sprint 4.3.2 Current Driver',
        'password': password,
        'preferredLocale': 'en',
      },
    );
    final disposableDriver = await _signedIn(baseUrl, driverAEmail, password);
    final disposablePassword = '$password!S432';
    await disposableDriver.put<void>(
      '/api/auth/me/password',
      data: {
        'currentPassword': password,
        'newPassword': disposablePassword,
        'confirmPassword': disposablePassword,
      },
    );

    final driverBResponse = await owner.post<Map<String, dynamic>>(
      '/api/drivers',
      data: {
        'fullName': 'Sprint 4.3.2 Requesting Driver',
        'licenseNumber': 'S432-REQUESTING-$suffix',
      },
    );
    final driverBId = driverBResponse.data!['id'] as String;
    final driverBEmail = 'sprint432.requesting.$suffix@demo.local';
    final driverBInvitation = await owner.post<Map<String, dynamic>>(
      '/api/membership-invitations',
      data: {
        'email': driverBEmail,
        'displayName': 'Sprint 4.3.2 Requesting Driver',
        'roles': ['Driver'],
        'driverId': driverBId,
      },
    );
    final driverBUri = Uri.parse(
      driverBInvitation.data!['acceptancePath'] as String,
    );
    final driverBRoute = driverBUri.fragment.isNotEmpty
        ? Uri.parse(driverBUri.fragment)
        : driverBUri;
    await anonymous.post<void>(
      '/api/invitations/accept',
      data: {
        'token': driverBRoute.queryParameters['token']!,
        'email': driverBEmail,
        'displayName': 'Sprint 4.3.2 Requesting Driver',
        'password': password,
        'preferredLocale': 'en',
      },
    );

    final users = await owner.get<List<dynamic>>('/api/company-users');
    final driverBMember = users.data!.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['email'] == driverBEmail,
    );
    final driverBMembershipId = driverBMember['membershipId'] as String;
    await owner.put<void>(
      '/api/memberships/$driverBMembershipId/status',
      data: {'status': 'Suspended'},
    );
    await owner.put<void>(
      '/api/memberships/$driverBMembershipId/status',
      data: {'status': 'Active'},
    );

    final client = await owner.post<Map<String, dynamic>>(
      '/api/clients',
      data: {'name': 'Sprint 4.3.2 Notification Client $suffix'},
    );
    final clientId = client.data!['id'] as String;
    final truck = await owner.post<Map<String, dynamic>>(
      '/api/trucks',
      data: {
        'plateNumber': 'N432-${suffix.substring(suffix.length - 7)}',
        'fleetCode': 'N432-${suffix.substring(suffix.length - 10)}',
        'defaultDriverId': driverAId,
      },
    );
    final truckId = truck.data!['id'] as String;
    final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
    final trip = await owner.post<Map<String, dynamic>>(
      '/api/trips',
      data: {
        'clientId': clientId,
        'cargoDescription': 'Sprint 4.3.2 notification cargo',
        'plannedStartAt': tomorrow.toIso8601String(),
        'price': 432.0,
        'routeProfile': 'Driving',
        'stops': [
          {
            'sequence': 0,
            'type': 'Pickup',
            'name': 'Sprint 4.3.2 Pickup',
            'address': 'Ankara acceptance pickup',
            'latitude': 39.9208,
            'longitude': 32.8541,
          },
          {
            'sequence': 1,
            'type': 'Delivery',
            'name': 'Sprint 4.3.2 Delivery',
            'address': 'Bolu acceptance delivery',
            'latitude': 40.7350,
            'longitude': 31.6061,
          },
        ],
      },
    );
    final tripId = trip.data!['id'] as String;
    await owner.post<Map<String, dynamic>>(
      '/api/trips/$tripId/calculate-route',
      data: {'routeProfile': 'Driving'},
    );
    await owner.post<Map<String, dynamic>>(
      '/api/trips/$tripId/assign',
      data: {'truckId': truckId, 'driverId': driverAId},
    );
    await owner.post<Map<String, dynamic>>(
      '/api/tracking/simulator/control',
      data: {
        'action': 'seed-position',
        'truckId': truckId,
        'latitude': 39.9208,
        'longitude': 32.8541,
      },
    );
    await owner.post<Map<String, dynamic>>(
      '/api/trucks/$truckId/qr/regenerate',
    );
    final qr = await owner.post<Map<String, dynamic>>(
      '/api/trucks/$truckId/qr/regenerate',
    );
    final driverB = await _signedIn(baseUrl, driverBEmail, password);
    final pending = await driverB.post<Map<String, dynamic>>(
      '/api/driver/truck-qr/confirm',
      data: {'code': qr.data!['code'], 'reason': 'Acceptance handover'},
    );
    final handoverId = pending.data!['handoverRequestId'] as String;
    await owner.post<Map<String, dynamic>>(
      '/api/handovers/$handoverId/approve',
      data: {'reason': 'Acceptance approved'},
    );
    await owner.post<Map<String, dynamic>>(
      '/api/trips/$tripId/dispatch-to-pickup',
      data: {'reason': 'Acceptance dispatch'},
    );
    await owner.post<Map<String, dynamic>>('/api/trips/$tripId/arrive-pickup');
    await owner.post<Map<String, dynamic>>(
      '/api/tracking/simulator/control',
      data: {'action': 'offline', 'truckId': truckId},
    );
    await owner.get<List<dynamic>>('/api/tracking/positions');
    await Future<void>.delayed(const Duration(seconds: 3));

    final page = await owner.get<Map<String, dynamic>>(
      '/api/notifications?page=1&pageSize=200',
    );
    final all = (page.data!['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(OperationNotification.fromJson)
        .toList();
    const required = <String, NotificationCategory>{
      'CompanyInvitationAccepted': NotificationCategory.peopleAccess,
      'MembershipSuspended': NotificationCategory.peopleAccess,
      'PasswordChanged': NotificationCategory.security,
      'TruckQrGenerated': NotificationCategory.fleet,
      'TruckQrRegenerated': NotificationCategory.fleet,
      'DriverHandoverRequested': NotificationCategory.trip,
      'DriverHandoverApproved': NotificationCategory.trip,
      'TripAssignedToDriver': NotificationCategory.trip,
      'TruckBecameOffline': NotificationCategory.fleet,
    };
    final expectedDestinations = <String, String>{
      'CompanyInvitationAccepted': '/company-users',
      'MembershipSuspended': '/company-users',
      'PasswordChanged': '/settings',
      'TruckQrGenerated': '/trucks/$truckId',
      'TruckQrRegenerated': '/trucks/$truckId',
      'DriverHandoverRequested': '/trips/$tripId',
      'DriverHandoverApproved': '/trips/$tripId',
      'TripAssignedToDriver': '/trips/$tripId',
      'TruckBecameOffline': '/trips/$tripId',
    };
    final selected = <OperationNotification>[];
    for (final entry in required.entries) {
      final matches = all.where((item) => item.type == entry.key);
      expect(matches, isNotEmpty, reason: 'Missing ${entry.key}');
      final item = matches.first;
      expect(notificationTypeCategory(item.type), entry.value);
      selected.add(item);
    }

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
    await tester.enterText(find.byKey(const Key('login-email')), ownerEmail);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.byKey(const Key('login-submit')));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await _waitUntil(
      tester,
      () => container.read(notificationControllerProvider).hasValue,
    );
    expect(
      container.read(operationalAlertControllerProvider).soundPlayRequests,
      0,
    );
    expect(container.read(operationalAlertControllerProvider).queue, isEmpty);

    final dashboardContext = tester.element(
      find.byKey(const Key('fleet-dashboard')),
    );
    final englishTitles = <String, String>{};
    final englishBodies = <String, String>{};
    for (final item in selected) {
      final presentation = notificationPresentation(dashboardContext, item);
      englishTitles[item.id] = presentation.title;
      englishBodies[item.id] = presentation.body;
      expect(presentation.title, isNotEmpty);
      expect(presentation.body, isNotEmpty);
      expect(notificationSnapshotIdentity(item), isNotEmpty);
      expect(
        notificationDestination(item, role: 'Owner'),
        expectedDestinations[item.type],
        reason: 'Wrong destination for ${item.type}',
      );
      final visible = '${presentation.title}\n${presentation.body}'
          .toLowerCase();
      expect(visible, isNot(contains('{')));
      expect(visible, isNot(contains(password.toLowerCase())));
      expect(visible, isNot(contains(disposablePassword.toLowerCase())));
      expect(visible, isNot(contains('token')));
      expect(visible, isNot(contains('qrpayload')));
      final raw = (item.dataJson ?? '').toLowerCase();
      expect(raw, isNot(contains(password.toLowerCase())));
      expect(raw, isNot(contains(disposablePassword.toLowerCase())));
      expect(raw, isNot(contains('"password"')));
      expect(raw, isNot(contains('token')));
      expect(raw, isNot(contains('qrpayload')));
    }
    expect(englishTitles.values.toSet().length, greaterThanOrEqualTo(9));

    expect(
      await container.read(authControllerProvider.notifier).updateLocale('ar'),
      isTrue,
    );
    await tester.pumpAndSettle();
    await _waitUntil(
      tester,
      () =>
          Directionality.of(
            tester.element(find.byKey(const Key('fleet-dashboard'))),
          ) ==
          TextDirection.rtl,
    );
    final arabicContext = tester.element(
      find.byKey(const Key('fleet-dashboard')),
    );
    for (final item in selected) {
      final arabic = notificationPresentation(arabicContext, item);
      expect(arabic.title, isNot(englishTitles[item.id]));
      expect(arabic.body, isNot(englishBodies[item.id]));
      expect(arabic.title, isNotEmpty);
      expect(arabic.body, isNotEmpty);
    }
    expect(
      container.read(operationalAlertControllerProvider).soundPlayRequests,
      0,
    );

    GoRouter.of(arabicContext).go('/notifications');
    await _waitFor(tester, find.byKey(const Key('notifications-read-all')));
    final hydratedIds = container
        .read(notificationControllerProvider)
        .value!
        .items
        .map((item) => item.id)
        .toSet();
    expect(hydratedIds, containsAll(selected.map((item) => item.id)));
    expect(find.byType(ListTile), findsWidgets);
    await binding.takeScreenshot('notifications-arabic-categories');

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('notifications-read-all'))),
    );
    for (final item in selected) {
      router.go('/notifications');
      await tester.pump(const Duration(milliseconds: 500));
      await _waitFor(tester, find.byKey(const Key('notifications-read-all')));
      final tile = find.byKey(Key('notification-${item.id}'));
      final notificationScroll = find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      );
      expect(notificationScroll, findsOneWidget);
      await tester.scrollUntilVisible(
        tile,
        350,
        scrollable: notificationScroll,
        maxScrolls: 100,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tile, findsOneWidget);
      debugPrint('Opening ${item.type} notification');
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 300));
      final expectedPath = expectedDestinations[item.type]!;
      await _waitUntil(
        tester,
        () =>
            router.routerDelegate.currentConfiguration.uri.path == expectedPath,
      );
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        expectedPath,
        reason: 'Tile navigation failed for ${item.type}',
      );
    }
  });
}

Future<Dio> _signedIn(String baseUrl, String email, String password) async {
  final api = Dio(BaseOptions(baseUrl: baseUrl));
  final login = await api.post<Map<String, dynamic>>(
    '/api/auth/login',
    data: {'email': email, 'password': password},
  );
  api.options.headers['Authorization'] = 'Bearer ${login.data!['accessToken']}';
  return api;
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
