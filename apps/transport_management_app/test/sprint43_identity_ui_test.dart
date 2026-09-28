import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/auth/data/external_identity_launcher.dart';
import 'package:transport_management_app/features/auth/domain/auth_session.dart';
import 'package:transport_management_app/features/auth/presentation/login_screen.dart';
import 'package:transport_management_app/features/memberships/domain/membership_models.dart';
import 'package:transport_management_app/features/memberships/presentation/membership_providers.dart';
import 'package:transport_management_app/features/memberships/presentation/truck_qr_scanner.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';
import 'package:transport_management_app/l10n/l10n_extensions.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  test(
    'multi-role current user and workspace parse without tenant assumptions',
    () {
      final user = CurrentUser.fromJson({
        'id': 'account-1',
        'membershipId': 'membership-1',
        'companyId': 'company-1',
        'companyName': 'Company A',
        'email': 'person@example.test',
        'displayName': 'Person',
        'role': 'Owner',
        'roles': ['Owner', 'Driver'],
        'preferredLocale': 'en',
        'hasLocalPassword': true,
        'requiresWorkspaceSelection': false,
      });
      final workspace = Workspace.fromJson({
        'membershipId': 'membership-2',
        'companyId': 'company-2',
        'companyName': 'Company B',
        'roles': ['Operations'],
        'status': 'Active',
      });

      expect(user.hasRole('Owner'), isTrue);
      expect(user.hasRole('Driver'), isTrue);
      expect(user.companyId, 'company-1');
      expect(workspace.companyName, 'Company B');
      expect(workspace.roles, ['Operations']);
    },
  );

  test('QR preview and handover contracts preserve operational context', () {
    final preview = TruckQrPreview.fromJson({
      'truckId': 'truck-1',
      'plateNumber': '34 TEST 43',
      'fleetCode': 'F-43',
      'truckStatus': 'Available',
      'currentDriverId': 'driver-a',
      'currentDriverName': 'Driver A',
      'tripId': 'trip-1',
      'tripNumber': 'T-43',
      'tripStatus': 'InTransit',
      'requiresHandover': true,
      'positionRecordedAt': '2026-09-27T16:00:00Z',
    });
    final handover = Handover.fromJson({
      'id': 'handover-1',
      'tripId': 'trip-1',
      'tripNumber': 'T-43',
      'truckId': 'truck-1',
      'plateNumber': '34 TEST 43',
      'currentDriverName': 'Driver A',
      'requestingDriverName': 'Driver B',
      'tripStatus': 'InTransit',
      'status': 'Pending',
      'createdAt': '2026-09-27T16:00:00Z',
      'expiresAt': '2026-09-27T16:15:00Z',
    });

    expect(preview.requiresHandover, isTrue);
    expect(preview.tripId, handover.tripId);
    expect(handover.currentDriverName, 'Driver A');
    expect(handover.requestingDriverName, 'Driver B');
  });

  testWidgets('local login remains available and Google is honestly disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    final google = tester.widget<OutlinedButton>(
      find.byKey(const Key('google-sign-in')),
    );
    expect(google.onPressed, isNull);
    expect(
      find.text('Google sign-in is not configured for this environment.'),
      findsOneWidget,
    );
  });

  testWidgets('configured Google action is enabled through provider adapter', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleConfiguredProvider.overrideWithValue(true),
          externalIdentityLauncherProvider.overrideWithValue(
            const _FakeExternalLauncher(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    final google = tester.widget<OutlinedButton>(
      find.byKey(const Key('google-sign-in')),
    );
    expect(google.onPressed, isNotNull);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Sprint 4.3 error codes are centralized in Arabic RTL', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(Directionality.of(captured), TextDirection.rtl);
    expect(
      localizedErrorCode(
        AppLocalizations.of(captured)!,
        'HANDOVER_REQUEST_STALE',
      ),
      'لم يعد طلب التسليم مطابقاً لتعيين الرحلة الحالي.',
    );
    expect(
      localizedErrorCode(
        AppLocalizations.of(captured)!,
        'INVITATION_EMAIL_MISMATCH',
      ),
      'سجّل الدخول بالبريد الذي استلم الدعوة.',
    );
  });

  test(
    'QR scanner boundary supports deterministic camera adapter tests',
    () async {
      const scanner = _FakeQrScanner();
      expect(scanner.isSupported, isTrue);
      expect(await scanner.scan(), 'opaque-qr-code');
      const unavailable = UnavailableTruckQrScanner();
      expect(unavailable.isSupported, isFalse);
      expect(await unavailable.scan(), isNull);
    },
  );
}

final class _FakeExternalLauncher implements ExternalIdentityLauncher {
  const _FakeExternalLauncher();
  @override
  bool get isAvailable => true;
  @override
  Future<ExternalIdentityCredential?> authenticate(String provider) async =>
      const ExternalIdentityCredential(idToken: 'fake-verified-id-token');
}

final class _FakeQrScanner implements TruckQrScanner {
  const _FakeQrScanner();
  @override
  bool get isSupported => true;
  @override
  Future<String?> scan() async => 'opaque-qr-code';
}
