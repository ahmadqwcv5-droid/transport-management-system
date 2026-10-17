import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/maps/map_interaction_controller.dart';
import 'package:transport_management_app/design_system/app_design_preset.dart';
import 'package:transport_management_app/design_system/app_motion.dart';
import 'package:transport_management_app/design_system/components/atlas_pulse_components.dart';
import 'package:transport_management_app/features/auth/domain/auth_session.dart';
import 'package:transport_management_app/features/auth/presentation/auth_controller.dart';
import 'package:transport_management_app/features/dashboard/domain/active_operation.dart';
import 'package:transport_management_app/features/dashboard/domain/dashboard_models.dart';
import 'package:transport_management_app/features/dashboard/presentation/atlas_dashboard_view_model.dart';
import 'package:transport_management_app/features/dashboard/presentation/dashboard_controller.dart';
import 'package:transport_management_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:transport_management_app/features/dashboard/presentation/fleet_map.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';

void main() {
  test('KPI unavailable is distinct from a truthful zero', () {
    final unavailable = AtlasDashboardViewModel(_data(fleet: const {}));
    final zero = AtlasDashboardViewModel(_data(fleet: const {'available': 0}));

    expect(
      unavailable.metrics
          .firstWhere((metric) => metric.kind == AtlasMetricKind.available)
          .value,
      isNull,
    );
    expect(
      zero.metrics
          .firstWhere((metric) => metric.kind == AtlasMetricKind.available)
          .value,
      0,
    );
  });

  test('fleet filters use real tracking and attention state', () {
    final viewModel = AtlasDashboardViewModel(_data());
    expect(viewModel.filtered(FleetViewFilter.all), hasLength(3));
    expect(viewModel.filtered(FleetViewFilter.connected), hasLength(2));
    expect(viewModel.filtered(FleetViewFilter.moving).single.truckId, 'moving');
    expect(
      viewModel.filtered(FleetViewFilter.stationary).single.truckId,
      'idle',
    );
    expect(viewModel.filtered(FleetViewFilter.offline).single.truckId, 'off');
    expect(
      viewModel.filtered(FleetViewFilter.attention).single.truckId,
      'moving',
    );
  });

  test('selection persists by truck identity across tracking updates', () {
    final initial = AtlasDashboardViewModel(_data());
    final updated = AtlasDashboardViewModel(
      _data(
        positions: [
          _truck('moving', online: true, speed: 44, tick: 2),
          _truck('idle', online: true, speed: 0, tick: 2),
          _truck('off', online: false, speed: 0, tick: 2),
        ],
      ),
    );

    expect(initial.retainSelection('moving'), 'moving');
    expect(updated.retainSelection('moving'), 'moving');
    expect(updated.truck('moving')!.speed, 44);
    expect(updated.retainSelection('missing'), isNull);
  });

  test('pan pauses follow while wheel zoom preserves it', () {
    final camera = MapInteractionController(
      initialMode: FleetInteractionMode.followVehicle,
    );
    camera.userZoom();
    expect(camera.followsVehicle, isTrue);
    camera.userPan();
    expect(camera.mode, FleetInteractionMode.freeExplore);
    camera.userZoom();
    expect(camera.mode, FleetInteractionMode.freeExplore);
  });

  testWidgets('idle inspector never invents a trip', (tester) async {
    await tester.pumpWidget(
      _localized(
        const FleetMap(
          positions: [
            TrackedTruck(
              truckId: 'idle',
              plateNumber: '06 IDLE 1',
              truckStatus: 'Available',
              latitude: 40,
              longitude: 30,
              speed: 0,
              recordedAt: '2026-10-17T08:00:00Z',
              isOnline: true,
            ),
          ],
          styleUrlOverride: '',
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('map-use-fallback')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fallback-truck-marker-idle')));
    await tester.pump();

    expect(find.textContaining('Not assigned'), findsNWidgets(2));
    expect(find.byKey(const Key('fleet-route-progress')), findsNothing);
    expect(find.byKey(const Key('atlas-open-trip')), findsNothing);
  });

  testWidgets('map and fleet dock drive one externally controlled selection', (
    tester,
  ) async {
    late VoidCallback styleLoaded;
    late ValueChanged<TrackedTruck> mapSelection;
    String? selected;
    late StateSetter updateHost;
    var mapCreations = 0;
    final selectable = [
      _truck('moving', online: true, speed: 38, tick: 1),
      _truck('idle', online: true, speed: 0, tick: 1),
    ];

    await tester.pumpWidget(
      _localized(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return FleetMap(
              positions: selectable,
              selectedTruckId: selected,
              selectionManagedExternally: true,
              onSelectionChanged: (value) => setState(() => selected = value),
              styleUrlOverride: 'fixture://atlas',
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
                    styleLoaded = onStyleLoaded;
                    mapSelection = onTruckSelected;
                    return _MapProbe(key: key, onCreate: () => mapCreations++);
                  },
            );
          },
        ),
      ),
    );
    styleLoaded();
    await tester.pump();

    await tester.tap(find.byKey(const Key('real-map-truck-idle')));
    await tester.pump();
    expect(selected, 'idle');

    mapSelection(selectable.first);
    await tester.pump();
    expect(selected, 'moving');

    updateHost(() {});
    await tester.pump();
    expect(selected, 'moving');
    expect(mapCreations, 1);
  });

  testWidgets('wheel over map is resolved before ancestor scrolling', (
    tester,
  ) async {
    final scroll = ScrollController();
    var zooms = 0;
    var hovering = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            controller: scroll,
            physics: hovering
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => hovering = true),
                  onExit: (_) => setState(() => hovering = false),
                  child: SizedBox(
                    height: 400,
                    child: ManualMapInteractionListener(
                      onPan: () {},
                      onZoom: () => zooms++,
                      child: const ColoredBox(
                        key: Key('wheel-map'),
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('wheel-map')));
    final region = tester.widget<MouseRegion>(
      find
          .ancestor(
            of: find.byKey(const Key('wheel-map')),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    region.onEnter!(PointerEnterEvent(position: center));
    await tester.pump();
    expect(hovering, isTrue);
    final listener = tester.widget<Listener>(
      find
          .ancestor(
            of: find.byKey(const Key('wheel-map')),
            matching: find.byType(Listener),
          )
          .first,
    );
    listener.onPointerSignal!(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 120)),
    );
    await tester.pump();
    expect(zooms, 1);
    expect(scroll.offset, 0);
  });

  testWidgets('Latin identifier remains LTR inside Arabic hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AtlasIdentifier('TR-104 · 06-ABC-42'),
        ),
      ),
    );
    final text = find.text('TR-104 · 06-ABC-42');
    expect(Directionality.of(tester.element(text)), TextDirection.ltr);
  });

  testWidgets('reduced motion returns immediate command-center transitions', (
    tester,
  ) async {
    late Duration effective;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignPreset.commandCenter().theme(const Locale('en')),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              effective = context.motion.effective(
                context,
                context.motion.standard,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(effective, Duration.zero);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final size in const [
      Size(1440, 900),
      Size(1024, 768),
      Size(390, 844),
    ]) {
      testWidgets(
        'dashboard has no overflow at ${size.width}x${size.height} ${locale.languageCode}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dashboardControllerProvider.overrideWith(
                  () => _FakeDashboardController(_data()),
                ),
                authControllerProvider.overrideWith(_FakeOwnerAuth.new),
              ],
              child: MaterialApp(
                locale: locale,
                theme: AppDesignPreset.commandCenter().theme(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: const Scaffold(body: DashboardScreen()),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const Key('atlas-command-heading')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('atlas-kpi-ribbon')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('primary-fleet-map')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expect(
            Directionality.of(
              tester.element(find.byKey(const Key('atlas-command-heading'))),
            ),
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
        },
      );
    }
  }
}

Widget _localized(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppDesignPreset.commandCenter().theme(const Locale('en')),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  ),
);

final class _FakeDashboardController extends DashboardController {
  _FakeDashboardController(this.data);
  final DashboardData data;

  @override
  FutureOr<DashboardData> build() => data;
}

final class _FakeOwnerAuth extends AuthController {
  @override
  FutureOr<AuthSession?> build() => const AuthSession(
    user: CurrentUser(
      id: 'owner',
      companyId: 'company',
      companyName: 'Atlas Test',
      email: 'owner@example.test',
      displayName: 'Owner',
      role: 'Owner',
      roles: ['Owner'],
      preferredLocale: 'en',
    ),
  );
}

class _MapProbe extends StatefulWidget {
  const _MapProbe({required this.onCreate, super.key});
  final VoidCallback onCreate;

  @override
  State<_MapProbe> createState() => _MapProbeState();
}

class _MapProbeState extends State<_MapProbe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

DashboardData _data({
  Map<String, dynamic> fleet = const {'total': 3, 'available': 1},
  List<TrackedTruck>? positions,
}) => DashboardData(
  fleet: fleet,
  trips: const {'active': 1, 'completedToday': 0},
  tracking: const {'online': 2, 'offline': 1},
  positions:
      positions ??
      [
        _truck('moving', online: true, speed: 38, tick: 1, trip: 'trip-1'),
        _truck('idle', online: true, speed: 0, tick: 1),
        _truck('off', online: false, speed: 0, tick: 1),
      ],
  simulatorTrucks: const [],
  recentTrips: const [],
  activeTrips: const [
    ActiveOperation(
      tripId: 'trip-1',
      tripNumber: 'TR-104',
      clientId: 'client',
      clientName: 'Client',
      truckId: 'moving',
      truckPlateNumber: '06-MOV-1',
      driverName: 'Driver',
      status: 'InTransit',
      operationalPhase: 'ToDelivery',
      nextMilestone: 'Delivery',
      nextStopName: 'Depot',
      progressPercent: 42,
      remainingDistanceMeters: 12000,
      trackingHealth: 'Stale',
      attentionCode: 'TRACKING_STALE',
      attentionPriority: 2,
    ),
  ],
);

TrackedTruck _truck(
  String id, {
  required bool online,
  required double speed,
  required int tick,
  String? trip,
}) => TrackedTruck(
  truckId: id,
  plateNumber: '06-${id.toUpperCase()}',
  truckStatus: trip == null ? 'Available' : 'OnTrip',
  latitude: 40 + tick / 1000,
  longitude: 30,
  speed: speed,
  recordedAt: '2026-10-17T08:00:0${tick}Z',
  isOnline: online,
  currentTripId: trip,
  movementPhase: trip == null ? null : 'ToDelivery',
);
