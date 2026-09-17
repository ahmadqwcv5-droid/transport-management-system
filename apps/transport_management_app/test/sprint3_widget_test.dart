import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/network/api_exception.dart';
import 'package:transport_management_app/features/auth/domain/auth_session.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';
import 'package:transport_management_app/features/dashboard/domain/dashboard_models.dart';
import 'package:transport_management_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:transport_management_app/features/operations/presentation/operations_view.dart';
import 'package:transport_management_app/features/settings/presentation/settings_screen.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';
import 'package:transport_management_app/l10n/l10n_extensions.dart';

Widget localized(Widget child, Locale locale, {FakeAuthController? fakeAuth}) =>
    ProviderScope(
      overrides: [
        if (fakeAuth != null)
          authControllerProvider.overrideWith(() => fakeAuth),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );

class FakeAuthController extends AuthController {
  String selected = 'en';
  CurrentUser get user => CurrentUser(
    id: 'u',
    companyId: 'c',
    email: 'a@b.test',
    displayName: 'Owner',
    role: 'Owner',
    preferredLocale: selected,
  );
  @override
  FutureOr<AuthSession?> build() => AuthSession(user: user);
  @override
  Future<bool> updateLocale(String locale) async {
    selected = locale;
    state = AsyncData(AuthSession(user: user));
    return true;
  }
}

void main() {
  testWidgets(
    'English is LTR and Arabic is RTL with translated dashboard label',
    (tester) async {
      for (final value in [
        ('en', TextDirection.ltr, 'Dashboard'),
        ('ar', TextDirection.rtl, 'لوحة التشغيل'),
      ]) {
        await tester.pumpWidget(
          localized(
            Builder(builder: (context) => Text(context.l10n.dashboard)),
            Locale(value.$1),
          ),
        );
        expect(find.text(value.$3), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.text(value.$3))),
          value.$2,
        );
      }
    },
  );

  testWidgets('language selection updates and persists in auth state', (
    tester,
  ) async {
    final fake = FakeAuthController();
    await tester.pumpWidget(
      localized(const SettingsScreen(), const Locale('en'), fakeAuth: fake),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    expect(fake.selected, 'ar');
  });

  testWidgets('fleet map handles empty state and truck details', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(const FleetMap(positions: []), const Locale('en')),
    );
    expect(find.textContaining('No tracked trucks'), findsOneWidget);
    const truck = TrackedTruck(
      truckId: 't1',
      plateNumber: '06 TMS 01',
      truckStatus: 'Available',
      latitude: 40,
      longitude: 30,
      speed: 42,
      recordedAt: '2026-09-17T00:00:00Z',
      isOnline: true,
      driverName: 'Driver',
    );
    await tester.pumpWidget(
      localized(const FleetMap(positions: [truck]), const Locale('en')),
    );
    await tester.tap(find.byKey(const Key('truck-marker-t1')));
    await tester.pumpAndSettle();
    expect(find.text('06 TMS 01'), findsOneWidget);
    expect(find.textContaining('42 km/h'), findsOneWidget);
  });

  testWidgets('known backend error code maps to Arabic', (tester) async {
    await tester.pumpWidget(
      localized(
        Builder(
          builder: (context) => Text(
            localizedApiError(
              context,
              const ApiException('raw', code: 'TRUCK_ALREADY_ASSIGNED'),
            ),
          ),
        ),
        const Locale('ar'),
      ),
    );
    expect(find.text('هذه الشاحنة مرتبطة برحلة نشطة أخرى.'), findsOneWidget);
  });
}
