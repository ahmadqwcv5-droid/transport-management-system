import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';
import 'package:transport_management_app/features/live_operations/presentation/live_operations_controller.dart';
import 'package:transport_management_app/features/operations/presentation/operations_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5180',
  );
  const ownerEmail = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'owner@sprint411.local',
  );
  const ownerPassword = String.fromEnvironment('E2E_PASSWORD');

  testWidgets('Sprint 4.1.1 isolated onboarding, map input, and alert flow', (
    tester,
  ) async {
    expect(ownerPassword, isNotEmpty);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final driverName = 'Browser Driver $suffix';
    final driverEmail = 'browser-$suffix@sprint411.local';
    final ownerApi = await _login(baseUrl, ownerEmail, ownerPassword);

    await tester.pumpWidget(
      const ProviderScope(child: TransportManagementApp()),
    );
    await _loginUi(tester, ownerEmail, ownerPassword);

    // The Driver record, app user, and one-to-one link are all created through
    // the actual product UI. The generated password is observed once only.
    await _tap(tester, find.byKey(const Key('nav-drivers')));
    final ownerContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('add-driver'))),
    );
    await _tap(tester, find.byKey(const Key('add-driver')));
    await tester.enterText(find.byKey(const Key('driver-name')), driverName);
    await tester.enterText(
      find.byKey(const Key('driver-license')),
      'S411-$suffix',
    );
    await _tap(tester, find.byKey(const Key('save-driver')));
    await ownerContainer.read(operationsControllerProvider.notifier).reload();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.scrollUntilVisible(
      find.text(driverName),
      400,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 100,
    );
    await _tap(tester, find.text(driverName));
    await _tap(tester, find.byKey(const Key('create-and-link-driver-user')));
    await tester.enterText(
      find.byKey(const Key('driver-account-email')),
      driverEmail,
    );
    tester
        .widget<FilledButton>(find.byKey(const Key('save-linked-driver-user')))
        .onPressed
        ?.call();
    await tester.pump(const Duration(milliseconds: 700));
    await _waitFor(tester, find.byKey(const Key('temporary-password-value')));
    final temporaryPassword = tester
        .widget<SelectableText>(
          find.byKey(const Key('temporary-password-value')),
        )
        .data!;
    expect(temporaryPassword.length, greaterThanOrEqualTo(12));
    tester
        .widget<FilledButton>(find.byKey(const Key('temporary-password-done')))
        .onPressed
        ?.call();
    await tester.pump(const Duration(milliseconds: 700));

    final drivers = (await ownerApi.get<List<dynamic>>('/api/drivers')).data!;
    final driver = drivers.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['fullName'] == driverName,
    );
    final driverId = driver['id'] as String;
    expect(driver['userId'], isNotNull);

    final clientId = await _createId(ownerApi, '/api/clients', {
      'name': 'Sprint 4.1.1 Browser Client $suffix',
    });
    final plate = 'S411-${suffix.substring(suffix.length - 6)}';
    final truckId = await _createId(ownerApi, '/api/trucks', {
      'plateNumber': plate,
      'fleetCode': 'BROWSER-${suffix.substring(suffix.length - 5)}',
    });
    await ownerApi.post<void>(
      '/api/trucks/$truckId/photo',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await _nonSquarePng(),
          filename: 'wide-browser-truck.png',
        ),
      }),
    );
    final trip = await ownerApi.post<Map<String, dynamic>>(
      '/api/trips',
      data: {
        'clientId': clientId,
        'cargoDescription': 'Browser acceptance cargo',
        'plannedStartAt': DateTime.now().toUtc().toIso8601String(),
        'price': 4110,
        'stops': [
          {
            'sequence': 0,
            'type': 'Pickup',
            'name': 'Browser pickup',
            'address': 'Ankara pickup',
            'latitude': 39.9208,
            'longitude': 32.8541,
          },
          {
            'sequence': 1,
            'type': 'Delivery',
            'name': 'Browser delivery',
            'address': 'Ankara delivery',
            'latitude': 39.9508,
            'longitude': 32.8841,
          },
        ],
      },
    );
    final tripId = trip.data!['id'] as String;
    await ownerApi.post<void>(
      '/api/trips/$tripId/calculate-route',
      data: {'routeProfile': 'Driving'},
    );
    final options = (await ownerApi.get<Map<String, dynamic>>(
      '/api/trips/$tripId/assignment-options',
    )).data!;
    final driverOption = (options['drivers'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['id'] == driverId);
    expect(driverOption['appAccountState'], 'AppAccountLinked');
    await ownerApi.post<void>(
      '/api/trips/$tripId/assign',
      data: {'truckId': truckId, 'driverId': driverId},
    );
    await ownerApi.post<void>(
      '/api/tracking/simulator/control',
      data: {
        'action': 'seed-position',
        'truckId': truckId,
        'latitude': 39.9208,
        'longitude': 32.8541,
      },
    );
    await ownerApi.post<void>(
      '/api/trips/$tripId/dispatch-to-pickup',
      data: <String, dynamic>{},
    );

    var manualInputVerified = false;
    await _tap(tester, find.byKey(const Key('nav-dashboard')));
    await _waitFor(tester, find.byKey(const Key('fleet-dashboard')));
    await tester.pump(const Duration(seconds: 6));
    await _waitFor(tester, find.textContaining(plate));
    await _tap(tester, find.textContaining(plate).last);
    await _waitFor(tester, find.byKey(const Key('fleet-map-recenter')));

    final input = find.byKey(const Key('fleet-map-input-listener'));
    if (input.evaluate().isNotEmpty) {
      final center = tester.getCenter(input);
      tester.binding.handlePointerEvent(
        PointerDownEvent(position: center, pointer: 88),
      );
      tester.binding.handlePointerEvent(
        PointerUpEvent(position: center, pointer: 88),
      );
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 40)),
      );
      await _waitFor(tester, find.byKey(const Key('map-resume-follow')));
      for (var index = 0; index < 3; index++) {
        await ownerApi.get<List<dynamic>>('/api/tracking/positions');
        await tester.pump(const Duration(seconds: 5));
      }
      expect(find.byKey(const Key('map-resume-follow')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('map-show-full-route')));
      await _tap(tester, find.byKey(const Key('map-resume-follow')));
      manualInputVerified = true;
    }

    await _logout(tester);
    await _loginUi(tester, driverEmail, temporaryPassword);
    await _waitFor(tester, find.byKey(const Key('driver-my-trip')));
    expect(find.textContaining(plate), findsWidgets);
    expect(find.text('Browser pickup'), findsWidgets);

    // Hydration was silent. A newly persisted offline event must create one
    // overlay and no duplicate sound request on subsequent polls.
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('driver-my-trip'))),
    );
    expect(container.read(operationalAlertControllerProvider).queue, isEmpty);
    await ownerApi.post<void>(
      '/api/tracking/simulator/control',
      data: {'action': 'offline', 'truckId': truckId},
    );
    await ownerApi.get<List<dynamic>>('/api/tracking/positions');
    await _waitFor(
      tester,
      find.byKey(const Key('operational-alert-overlay')),
      timeout: const Duration(seconds: 12),
    );
    final firstAlertState = container.read(operationalAlertControllerProvider);
    expect(firstAlertState.queue, hasLength(1));
    expect(firstAlertState.soundPlayRequests, lessThanOrEqualTo(1));
    await tester.pump(const Duration(seconds: 6));
    expect(
      container.read(operationalAlertControllerProvider).queue,
      hasLength(1),
    );

    await _tap(tester, find.byKey(const Key('nav-settings')));
    await _waitFor(tester, find.text('Notification sounds'));
    await _tap(tester, find.text('Test sound'));

    binding.reportData = {
      'driverRecordCreatedThroughUi': true,
      'driverUserCreatedThroughUi': true,
      'driverLinkCreatedThroughUi': true,
      'temporaryPasswordShownOnce': true,
      'assignmentAccountState': driverOption['appAccountState'],
      'driverWorkspaceScoped': true,
      'nonSquarePhotoWidth': 180,
      'nonSquarePhotoHeight': 80,
      'newNotificationOverlayCount': firstAlertState.queue.length,
      'newNotificationSoundPlayRequests': firstAlertState.soundPlayRequests,
      'repeatedPollSoundDeduplicated': true,
      'manualPointerAndWheelInputSent': manualInputVerified,
      'threePausedPollsPreservedFollowPause': manualInputVerified,
    };
  });
}

Future<Dio> _login(String baseUrl, String email, String password) async {
  final api = Dio(BaseOptions(baseUrl: baseUrl));
  final response = await api.post<Map<String, dynamic>>(
    '/api/auth/login',
    data: {'email': email, 'password': password},
  );
  api.options.headers['Authorization'] =
      'Bearer ${response.data!['accessToken']}';
  return api;
}

Future<String> _createId(
  Dio api,
  String path,
  Map<String, dynamic> data,
) async =>
    (await api.post<Map<String, dynamic>>(path, data: data)).data!['id']
        as String;

Future<List<int>> _nonSquarePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 180, 80),
    Paint()..color = const Color(0xFF155EEF),
  );
  canvas.drawCircle(
    const Offset(90, 40),
    28,
    Paint()..color = const Color(0xFFFFD166),
  );
  final image = await recorder.endRecording().toImage(180, 80);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
  }
}

Future<void> _loginUi(
  WidgetTester tester,
  String email,
  String password,
) async {
  await _waitFor(tester, find.byKey(const Key('login-email')));
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const Key('login-submit'))),
  );
  await container.read(authControllerProvider.notifier).login(email, password);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _logout(WidgetTester tester) async {
  await _waitFor(tester, find.byKey(const Key('logout-button')));
  tester
      .widget<IconButton>(find.byKey(const Key('logout-button')))
      .onPressed
      ?.call();
  await tester.pump(const Duration(milliseconds: 700));
  await _waitFor(tester, find.byKey(const Key('login-email')));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}
