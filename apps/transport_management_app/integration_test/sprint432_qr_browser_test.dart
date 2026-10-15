import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transport_management_app/app.dart';
import 'package:transport_management_app/core/qr/qr_png_encoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );
  const ownerEmail = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');
  const driverEmail = String.fromEnvironment('E2E_INVITEE_EMAIL');

  testWidgets('real Firefox QR lifecycle and render recovery', (tester) async {
    final ownerApi = Dio(BaseOptions(baseUrl: baseUrl));
    final ownerLogin = await ownerApi.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': ownerEmail, 'password': password},
    );
    ownerApi.options.headers['Authorization'] =
        'Bearer ${ownerLogin.data!['accessToken']}';
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final plate = 'S432-${suffix.substring(suffix.length - 7)}';
    final truckResponse = await ownerApi.post<Map<String, dynamic>>(
      '/api/trucks',
      data: {
        'plateNumber': plate,
        'fleetCode': 'S432-QR-${suffix.substring(suffix.length - 10)}',
        'vin': 'S432$suffix',
      },
    );
    final truckId = truckResponse.data!['id'] as String;
    addTearDown(() async {
      final deleted = await ownerApi.delete<void>(
        '/api/trucks/$truckId',
        options: Options(validateStatus: (_) => true),
      );
      if (deleted.statusCode == 409) {
        await ownerApi.post<void>(
          '/api/trucks/$truckId/deactivate',
          options: Options(validateStatus: (_) => true),
        );
      }
    });

    final encoder = _FailOnceQrEncoder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [qrPngEncoderProvider.overrideWithValue(encoder)],
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
    GoRouter.of(
      tester.element(find.byKey(const Key('fleet-dashboard'))),
    ).go('/trucks/$truckId');
    await _waitFor(tester, find.byKey(const Key('truck-details')));
    await _tapVisible(tester, find.byKey(const Key('generate-truck-qr')));

    await _waitFor(tester, find.byKey(const Key('qr-render-error')));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('recoverable-qr-manual-code')), findsOneWidget);
    final statusAfterFailure = await ownerApi.get<Map<String, dynamic>>(
      '/api/trucks/$truckId/qr',
    );
    final generatedAt = statusAfterFailure.data!['generatedAt'];
    final firstCode = tester
        .widget<SelectableText>(
          find.byKey(const Key('recoverable-qr-manual-code')),
        )
        .data!;

    await _tapVisible(tester, find.byKey(const Key('retry-qr-display')));
    await _waitFor(tester, find.byKey(const Key('generated-truck-qr-image')));
    expect(find.byKey(const Key('generated-truck-qr-code')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final statusAfterRetry = await ownerApi.get<Map<String, dynamic>>(
      '/api/trucks/$truckId/qr',
    );
    expect(statusAfterRetry.data!['generatedAt'], generatedAt);
    expect(encoder.calls, 2);
    expect(encoder.lastBytes, isNotNull);
    final codec = await ui.instantiateImageCodec(encoder.lastBytes!);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
    frame.image.dispose();
    codec.dispose();

    await tester.tap(find.byKey(const Key('download-truck-qr-png')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('close-truck-qr-dialog')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('truck-details')), findsOneWidget);
    final generateButton = tester.widget<FilledButton>(
      find.byKey(const Key('generate-truck-qr')),
    );
    expect(generateButton.onPressed, isNotNull);

    await _tapVisible(tester, find.byKey(const Key('generate-truck-qr')));
    await _waitFor(tester, find.byType(AlertDialog));
    await tester.tap(find.byType(FilledButton).last);
    await _waitFor(tester, find.byKey(const Key('generated-truck-qr-code')));
    final secondCode = tester
        .widget<SelectableText>(
          find.byKey(const Key('generated-truck-qr-code')),
        )
        .data!;
    expect(secondCode, isNot(firstCode));

    final driverApi = Dio(BaseOptions(baseUrl: baseUrl));
    final driverLogin = await driverApi.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': driverEmail, 'password': password},
    );
    driverApi.options.headers['Authorization'] =
        'Bearer ${driverLogin.data!['accessToken']}';
    final oldResult = await driverApi.post<Map<String, dynamic>>(
      '/api/driver/truck-qr/preview',
      data: {'code': firstCode},
      options: Options(validateStatus: (_) => true),
    );
    expect(oldResult.statusCode, greaterThanOrEqualTo(400));
    final newResult = await driverApi.post<Map<String, dynamic>>(
      '/api/driver/truck-qr/preview',
      data: {'code': secondCode},
    );
    expect(newResult.statusCode, 200);
    expect(newResult.data!['truckId'], truckId);
    await tester.tap(find.byKey(const Key('close-truck-qr-dialog')));
    await tester.pump(const Duration(milliseconds: 300));
  });
}

final class _FailOnceQrEncoder implements QrPngEncoder {
  final QrPngEncoder _delegate = const FlutterQrPngEncoder();
  int calls = 0;
  Uint8List? lastBytes;

  @override
  Future<Uint8List> encode(String payload) async {
    calls++;
    if (calls == 1) throw StateError('intentional acceptance render failure');
    return lastBytes = await _delegate.encode(payload);
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) => _waitUntil(tester, () => finder.evaluate().isNotEmpty, timeout: timeout);

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(condition(), isTrue);
}
