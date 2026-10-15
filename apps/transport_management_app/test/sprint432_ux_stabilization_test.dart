import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/network/api_client.dart';
import 'package:transport_management_app/core/qr/qr_png_encoder.dart';
import 'package:transport_management_app/core/storage/token_store.dart';
import 'package:transport_management_app/features/auth/presentation/anonymous_locale_controller.dart';
import 'package:transport_management_app/features/company_users/data/company_users_repository.dart';
import 'package:transport_management_app/features/company_users/domain/company_user.dart';
import 'package:transport_management_app/features/company_users/presentation/company_users_controller.dart';
import 'package:transport_management_app/features/company_users/presentation/company_users_screen.dart';
import 'package:transport_management_app/features/fleet/trucks/presentation/truck_details_screen.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/notification_snapshot_text.dart';
import 'package:transport_management_app/features/memberships/domain/membership_models.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';
import 'package:transport_management_app/shared/widgets/app_password_field.dart';

void main() {
  test(
    'anonymous locale resolution is saved, browser locale, then English',
    () {
      expect(resolveAnonymousLocale('ar', const [Locale('en')]), 'ar');
      expect(resolveAnonymousLocale(null, const [Locale('ar', 'SA')]), 'ar');
      expect(resolveAnonymousLocale(null, const [Locale('fr')]), 'en');
      expect(resolveAnonymousLocale('fr', const [Locale('en')]), 'en');
    },
  );

  test('anonymous locale persists locally', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = AnonymousLocaleStore();
    await store.write('ar');
    expect(await store.read(), 'ar');
  });

  test(
    'Company Users refreshes serialize and stale data is not published',
    () async {
      final repository = _QueuedCompanyUsersRepository();
      final container = ProviderContainer(
        overrides: [
          companyUsersRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final initial = container.read(companyUsersControllerProvider.future);
      repository.completeNext([_companyUser('initial')]);
      await initial;

      final controller = container.read(
        companyUsersControllerProvider.notifier,
      );
      final first = controller.refresh();
      final second = controller.refresh();
      expect(repository.maxConcurrent, 1);
      repository.completeNext([_companyUser('stale')]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.callCount, 3);
      expect(
        container.read(companyUsersControllerProvider).value!.single.id,
        'initial',
      );
      repository.completeNext([_companyUser('latest')]);
      await Future.wait([first, second]);
      expect(repository.maxConcurrent, 1);
      expect(
        container.read(companyUsersControllerProvider).value!.single.id,
        'latest',
      );
    },
  );

  testWidgets('password fields hide, toggle independently, and localize', (
    tester,
  ) async {
    final current = TextEditingController(text: 'current-secret');
    final next = TextEditingController(text: 'next-secret');
    addTearDown(current.dispose);
    addTearDown(next.dispose);

    await tester.pumpWidget(
      _localized(
        locale: const Locale('en'),
        home: Scaffold(
          body: Column(
            children: [
              AppPasswordField(
                key: const Key('current'),
                controller: current,
                labelText: 'Current',
              ),
              AppPasswordField(
                key: const Key('next'),
                controller: next,
                labelText: 'Next',
              ),
            ],
          ),
        ),
      ),
    );

    var fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.every((field) => field.obscureText), isTrue);
    expect(find.byTooltip('Show password'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.first.obscureText, isFalse);
    expect(fields.last.obscureText, isTrue);
    expect(current.text, 'current-secret');

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).first).obscureText,
      isTrue,
    );

    await tester.pumpWidget(
      _localized(
        locale: const Locale('ar'),
        home: Scaffold(
          body: AppPasswordField(controller: current, labelText: 'كلمة المرور'),
        ),
      ),
    );
    expect(find.byTooltip('إظهار كلمة المرور'), findsOneWidget);
  });

  testWidgets('pending invitation is distinct from accepted history', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 28);
    await tester.pumpWidget(
      ProviderScope(
        child: _localized(
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: InvitationLifecycleList([
                Invitation(
                  id: 'pending',
                  email: 'pending@example.test',
                  roles: const ['Driver'],
                  status: 'Pending',
                  expiresAt: now.add(const Duration(days: 1)),
                ),
                Invitation(
                  id: 'accepted',
                  email: 'accepted@example.test',
                  roles: const ['Employee'],
                  status: 'Accepted',
                  expiresAt: now,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Pending invitations'), findsOneWidget);
    expect(find.text('Invitation history'), findsOneWidget);
    expect(find.byKey(const Key('invitation-pending')), findsOneWidget);
    expect(find.byKey(const Key('invitation-accepted')), findsOneWidget);
    expect(find.textContaining('Driver'), findsOneWidget);
  });

  testWidgets('QR payload produces a decodable PNG and real dialog', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => const FlutterQrPngEncoder().encode('tms-truck://qr/test-only-code'),
    );
    expect(bytes, isNotNull);
    expect(bytes!, isNotEmpty);
    final dimensions = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final result = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return result;
    });
    expect(dimensions!.$1, greaterThan(0));
    expect(dimensions.$2, greaterThan(0));

    final credential = TruckQrCredential(
      truckId: 'truck',
      plateNumber: 'TEST-123',
      code: 'manual-test-code',
      codeHint: 'est-code',
      qrPayload: 'tms-truck://qr/test-only-code',
      generatedAt: DateTime.utc(2026, 9, 28),
    );
    await tester.pumpWidget(
      _localized(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-real-qr-dialog'),
              onPressed: () =>
                  showGeneratedQrDialog(context, credential, bytes),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-real-qr-dialog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('generated-truck-qr-image')), findsOneWidget);
    expect(find.text('manual-test-code'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-truck-qr-dialog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-real-qr-dialog')), findsOneWidget);
  });

  testWidgets(
    'canonical notification types map specifically in English and Arabic',
    (tester) async {
      final fixture =
          jsonDecode(
                File(
                  '../../docs/contracts/operation_notification_types.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final fixtureTypes = (fixture['emittedTypes'] as List<dynamic>)
          .cast<String>()
          .toSet();
      expect(fixtureTypes, emittedNotificationTypes);

      for (final locale in const [Locale('en'), Locale('ar')]) {
        late BuildContext context;
        await tester.pumpWidget(
          _localized(
            locale: locale,
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        );
        for (final type in fixtureTypes) {
          final notification = _notification(type);
          final presentation = notificationPresentation(context, notification);
          expect(
            presentation.category,
            isNot(NotificationCategory.system),
            reason: type,
          );
          expect(presentation.title, isNotEmpty, reason: type);
          expect(presentation.body, isNotEmpty, reason: type);
        }
      }

      late BuildContext unknownContext;
      await tester.pumpWidget(
        _localized(
          locale: const Locale('en'),
          home: Builder(
            builder: (value) {
              unknownContext = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final unknown = notificationPresentation(
        unknownContext,
        _notification('FutureUnknownEvent'),
      );
      expect(unknown.category, NotificationCategory.system);
      expect(unknown.body.toLowerCase(), isNot(contains('trip')));
    },
  );
}

Widget _localized({required Locale locale, required Widget home}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

CompanyUser _companyUser(String id) => CompanyUser(
  id: id,
  email: '$id@example.test',
  displayName: id,
  role: 'Employee',
  isActive: true,
  notificationSoundsEnabled: true,
  membershipStatus: 'Active',
  roles: const ['Employee'],
);

OperationNotification _notification(String type) => OperationNotification(
  id: type,
  type: type,
  severity: 'Information',
  createdAt: '2026-09-28T00:00:00Z',
  eventKey: '$type:key',
  dataJson: jsonEncode({
    'eventCode': type,
    'email': 'person@example.test',
    'displayName': 'Person',
    'tripNumber': 'TR-102',
    'plateNumber': 'ABC-123',
    'eventAt': '2026-09-28T00:00:00Z',
  }),
);

final class _QueuedCompanyUsersRepository extends CompanyUsersRepository {
  _QueuedCompanyUsersRepository() : super(ApiClient(TokenStore()));

  final List<Completer<List<CompanyUser>>> _requests = [];
  int _active = 0;
  int maxConcurrent = 0;

  int get callCount => _requests.length;

  @override
  Future<List<CompanyUser>> list({String? role, bool? active}) {
    final completer = Completer<List<CompanyUser>>();
    _requests.add(completer);
    _active++;
    if (_active > maxConcurrent) maxConcurrent = _active;
    return completer.future.whenComplete(() => _active--);
  }

  void completeNext(List<CompanyUser> value) {
    _requests.firstWhere((request) => !request.isCompleted).complete(value);
  }
}
