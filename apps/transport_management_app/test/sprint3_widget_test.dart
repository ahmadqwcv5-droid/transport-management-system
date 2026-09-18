import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/network/api_exception.dart';
import 'package:transport_management_app/features/auth/domain/auth_session.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';
import 'package:transport_management_app/features/dashboard/domain/dashboard_models.dart';
import 'package:transport_management_app/features/dashboard/presentation/dashboard_controller.dart';
import 'package:transport_management_app/features/dashboard/presentation/fleet_map.dart';
import 'package:transport_management_app/features/dashboard/presentation/simulator_controls.dart';
import 'package:transport_management_app/features/operations/presentation/operations_view.dart';
import 'package:transport_management_app/features/settings/presentation/settings_screen.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';
import 'package:transport_management_app/l10n/l10n_extensions.dart';

Widget localized(
  Widget child,
  Locale locale, {
  FakeAuthController? fakeAuth,
  FakeDashboardController? fakeDashboard,
}) => ProviderScope(
  overrides: [
    if (fakeAuth != null) authControllerProvider.overrideWith(() => fakeAuth),
    if (fakeDashboard != null)
      dashboardControllerProvider.overrideWith(() => fakeDashboard),
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

class FakeDashboardController extends DashboardController {
  final commands = <({String action, String? truckId, double? speed})>[];

  @override
  FutureOr<DashboardData> build() => const DashboardData(
    fleet: {},
    trips: {},
    tracking: {},
    positions: [],
    recentTrips: [],
  );

  @override
  Future<bool> control(
    String action, {
    String? truckId,
    double? speedMultiplier,
  }) async {
    commands.add((action: action, truckId: truckId, speed: speedMultiplier));
    return true;
  }
}

const trackedTruck = TrackedTruck(
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

  testWidgets('unconfigured map enters clearly labeled fallback with details', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(
        const FleetMap(positions: [trackedTruck], styleUrlOverride: ''),
        const Locale('en'),
      ),
    );
    expect(find.byKey(const Key('map-status-unconfigured')), findsOneWidget);
    expect(find.byKey(const Key('offline-map-surface')), findsNothing);
    await tester.tap(find.byKey(const Key('map-use-fallback')));
    await tester.pump();
    expect(find.byKey(const Key('map-status-fallback')), findsOneWidget);
    expect(find.textContaining('not a geographic map'), findsOneWidget);
    expect(find.byKey(const Key('offline-map-surface')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fallback-truck-marker-t1')));
    await tester.pumpAndSettle();
    expect(find.text('06 TMS 01'), findsOneWidget);
    expect(find.textContaining('42 km/h'), findsOneWidget);
    expect(find.byKey(const Key('fleet-map-recenter')), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const Key('fleet-map-recenter'))).dy,
      lessThanOrEqualTo(
        tester.getBottomRight(find.byKey(const Key('offline-map-surface'))).dy,
      ),
    );
  });

  testWidgets('loaded state requires callback and annotations are separate', (
    tester,
  ) async {
    late VoidCallback styleLoaded;
    late VoidCallback annotationsReady;
    var buildCount = 0;
    await tester.pumpWidget(
      localized(
        FleetMap(
          positions: const [trackedTruck],
          styleUrlOverride: 'fixture://valid-style',
          mapBuilder:
              ({
                required key,
                required styleUrl,
                required positions,
                required onStyleLoaded,
                required onAnnotationsReady,
                required onFailure,
                required onTruckSelected,
              }) {
                buildCount++;
                styleLoaded = onStyleLoaded;
                annotationsReady = onAnnotationsReady;
                return ColoredBox(
                  key: const Key('fake-real-map-canvas'),
                  color: Colors.blue,
                );
              },
        ),
        const Locale('en'),
      ),
    );
    expect(find.byKey(const Key('map-status-loading')), findsOneWidget);
    expect(find.byKey(const Key('map-status-loaded')), findsNothing);
    styleLoaded();
    await tester.pump();
    expect(find.byKey(const Key('map-status-loaded')), findsOneWidget);
    expect(find.byKey(const Key('offline-map-surface')), findsNothing);
    expect(find.byKey(const Key('fallback-truck-marker-t1')), findsNothing);
    annotationsReady();
    await tester.pump();
    expect(find.byKey(const Key('map-annotations-ready')), findsOneWidget);
    expect(buildCount, greaterThanOrEqualTo(1));
    await tester.tap(find.byKey(const Key('real-map-truck-t1')));
    await tester.pumpAndSettle();
    expect(find.text('06 TMS 01'), findsNWidgets(2));
  });

  testWidgets('map timeout supports genuine retry then fallback', (
    tester,
  ) async {
    var attempts = 0;
    final styleCallbacks = <VoidCallback>[];
    await tester.pumpWidget(
      localized(
        FleetMap(
          positions: const [trackedTruck],
          styleUrlOverride: 'fixture://unreachable',
          loadingTimeoutOverride: const Duration(milliseconds: 100),
          mapBuilder:
              ({
                required key,
                required styleUrl,
                required positions,
                required onStyleLoaded,
                required onAnnotationsReady,
                required onFailure,
                required onTruckSelected,
              }) {
                attempts++;
                styleCallbacks.add(onStyleLoaded);
                return SizedBox(key: key);
              },
        ),
        const Locale('en'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.byKey(const Key('map-status-failed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-retry')));
    await tester.pump();
    expect(find.byKey(const Key('map-status-loading')), findsOneWidget);
    expect(attempts, 2);
    styleCallbacks.first();
    await tester.pump();
    expect(
      find.byKey(const Key('map-status-loading')),
      findsOneWidget,
      reason: 'a late callback from the disposed attempt must be ignored',
    );
    await tester.pump(const Duration(milliseconds: 110));
    await tester.tap(find.byKey(const Key('map-use-fallback')));
    await tester.pump();
    expect(find.byKey(const Key('map-status-fallback')), findsOneWidget);
  });

  testWidgets('all simulator commands are exposed and dispatched', (
    tester,
  ) async {
    final fake = FakeDashboardController();
    await tester.pumpWidget(
      localized(
        const SingleChildScrollView(
          child: SimulatorControls(positions: [trackedTruck]),
        ),
        const Locale('en'),
        fakeDashboard: fake,
      ),
    );
    await tester.pumpAndSettle();
    expect(SimulatorControls.enabled, isFalse);
    for (final key in [
      'sim-start',
      'sim-pause',
      'sim-resume',
      'sim-stop',
      'sim-reset',
      'sim-step',
      'sim-speed',
      'sim-online',
      'sim-offline',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('sim-step')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sim-speed')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sim-offline')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sim-online')));
    await tester.pump();
    expect(fake.commands.map((item) => item.action), [
      'step',
      'speed',
      'offline',
      'online',
    ]);
    expect(fake.commands[1].speed, 1);
    expect(fake.commands[2].truckId, 't1');
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
