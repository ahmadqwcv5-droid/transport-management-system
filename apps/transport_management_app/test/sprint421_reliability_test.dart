import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/dashboard/domain/dashboard_models.dart';
import 'package:transport_management_app/features/dashboard/presentation/fleet_map.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/notification_snapshot_text.dart';
import 'package:transport_management_app/features/trips/domain/assignment_selection_policy.dart';
import 'package:transport_management_app/features/trips/domain/trip_models.dart';
import 'package:transport_management_app/l10n/app_localizations.dart';

void main() {
  testWidgets('one map instance survives 30 polling and phase updates', (
    tester,
  ) async {
    var created = 0;
    var disposed = 0;
    VoidCallback? styleLoaded;
    late StateSetter updateHost;
    var positions = [_tracked('Assigned', 1)];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return FleetMap(
                positions: positions,
                styleUrlOverride: 'test-style',
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
                      return _MapProbe(
                        key: key,
                        onCreate: () => created++,
                        onDispose: () => disposed++,
                      );
                    },
              );
            },
          ),
        ),
      ),
    );
    styleLoaded!();
    await tester.pump();

    for (var index = 2; index <= 31; index++) {
      updateHost(() {
        positions = [_tracked(index < 18 ? 'AtPickup' : 'InTransit', index)];
      });
      await tester.pump();
    }

    expect(created, 1);
    expect(disposed, 0);
    expect(find.byKey(const Key('map-status-failed')), findsNothing);
  });

  test('shared assignment policy never selects the first arbitrary driver', () {
    final options = _options(defaultDriverId: null);
    final initial = AssignmentSelectionPolicy.initial(options);
    expect(initial.truckId, isNull);
    expect(initial.driverId, isNull);

    final selected = AssignmentSelectionPolicy.selectTruck(
      options,
      'truck',
      currentDriverId: null,
      currentSource: DriverSelectionSource.none,
    );
    expect(selected.driverId, isNull);
  });

  test(
    'shared assignment policy proposes linked eligible driver and preserves override',
    () {
      final options = _options(defaultDriverId: 'linked');
      final linked = AssignmentSelectionPolicy.selectTruck(
        options,
        'truck',
        currentDriverId: null,
        currentSource: DriverSelectionSource.none,
      );
      expect(linked.driverId, 'linked');
      expect(linked.source, DriverSelectionSource.truckDefault);

      final manual = AssignmentSelectionPolicy.selectTruck(
        options,
        'truck',
        currentDriverId: 'manual',
        currentSource: DriverSelectionSource.manual,
      );
      expect(manual.driverId, 'manual');
      expect(manual.source, DriverSelectionSource.manual);
    },
  );

  testWidgets(
    'Arabic notification is contextual and legacy fallback is localized',
    (tester) async {
      late String specific;
      late String legacy;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              specific = notificationSnapshotMessage(
                context,
                OperationNotification(
                  id: 'new',
                  type: 'TruckArrivedAtPickup',
                  severity: 'Info',
                  createdAt: '2026-09-27T00:00:00Z',
                  dataJson: jsonEncode({
                    'tripNumber': 'TR-104',
                    'plateNumber': 'ABC-123',
                    'stopName': 'مستودع العميل في حمص',
                    'eventAt': '2026-09-27T00:00:00Z',
                  }),
                ),
              );
              legacy = notificationSnapshotMessage(
                context,
                const OperationNotification(
                  id: 'old',
                  type: 'Legacy',
                  severity: 'Info',
                  createdAt: '2020-01-01T00:00:00Z',
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(specific, contains('ABC-123'));
      expect(specific, contains('TR-104'));
      expect(specific, contains('مستودع العميل في حمص'));
      expect(legacy, contains('الإشعار القديم'));
    },
  );
}

class _MapProbe extends StatefulWidget {
  const _MapProbe({required this.onCreate, required this.onDispose, super.key});
  final VoidCallback onCreate, onDispose;
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
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

TrackedTruck _tracked(String status, int tick) => TrackedTruck(
  truckId: 'truck',
  plateNumber: 'ABC-123',
  latitude: 34 + tick / 10000,
  longitude: 36,
  speed: 20,
  heading: 90,
  isOnline: true,
  recordedAt: '2026-09-27T00:00:${tick.toString().padLeft(2, '0')}Z',
  truckStatus: 'Available',
  currentTripId: 'trip',
  movementPhase: status,
);

AssignmentOptions _options({required String? defaultDriverId}) =>
    AssignmentOptions(
      tripId: 'trip',
      canAssign: true,
      trucks: [
        AssignmentResourceOption(
          id: 'truck',
          displayName: 'ABC-123',
          status: 'Available',
          isEligible: true,
          reasonCode: 'AVAILABLE',
          defaultDriverId: defaultDriverId,
        ),
      ],
      drivers: const [
        AssignmentResourceOption(
          id: 'linked',
          displayName: 'Linked',
          status: 'Available',
          isEligible: true,
          reasonCode: 'AVAILABLE',
        ),
        AssignmentResourceOption(
          id: 'manual',
          displayName: 'Manual',
          status: 'Available',
          isEligible: true,
          reasonCode: 'AVAILABLE',
        ),
      ],
    );
