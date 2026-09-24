import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/dashboard/presentation/fleet_map_coordinator.dart';
import 'package:transport_management_app/features/dashboard/presentation/maplibre_fleet_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('truck marker asset', () {
    test('is declared, loadable, image-based, and north aligned', () async {
      final data = await rootBundle.load(truckMarkerAsset);
      expect(data.lengthInBytes, greaterThan(100));
      expect(truckMarkerImageName, isNot(contains('➤')));
      expect(truckMarkerHeadingOffset, 0);
      expect(
        [0.0, 90.0, 180.0, 270.0].map(mapMarkerRotation),
        orderedEquals([0.0, 90.0, 180.0, 270.0]),
      );
      final options = truckSymbolOptions(truck('marker'));
      expect(options.iconImage, truckMarkerImageName);
      expect(options.textField, isNull);
    });

    test('normalizes heading across north', () {
      expect(mapMarkerRotation(360), 0);
      expect(mapMarkerRotation(450), 90);
    });

    test('photo marker stays upright and exposes a separate heading cue', () {
      final photoTruck = truck(
        'photo',
        heading: 135,
        photoVersion: 'version-2',
        photoThumbnailUrl: '/api/trucks/photo/photo/thumbnail?v=version-2',
      );

      expect(photoTruck.photoImageName, 'truck-photo:photo:version-2');
      final options = truckSymbolOptions(photoTruck);
      expect(options.iconImage, photoTruck.photoImageName);
      expect(options.iconRotate, 0);
      expect(options.textField, '▲');
      expect(options.textRotate, 135);

      final fallback = truckSymbolOptions(photoTruck, forceFallback: true);
      expect(fallback.iconImage, truckMarkerImageName);
      expect(fallback.iconRotate, 135);
      expect(fallback.textField, isNull);
    });

    test('selection and operating states have non-color-only treatment', () {
      final moving = truckStatusCircleOptions(truck('moving'));
      final stationary = truckStatusCircleOptions(
        truck('stationary', state: TruckMarkerState.stationary),
      );
      final offline = truckStatusCircleOptions(
        truck('offline', state: TruckMarkerState.offline),
      );
      final maintenance = truckStatusCircleOptions(
        truck('maintenance', state: TruckMarkerState.maintenance),
      );
      final selected = truckStatusCircleOptions(
        truck('selected', selected: true),
      );

      expect(
        stationary.circleStrokeWidth,
        greaterThan(moving.circleStrokeWidth!),
      );
      expect(offline.circleOpacity, lessThan(moving.circleOpacity!));
      expect(maintenance.circleRadius, isNot(moving.circleRadius));
      expect(selected.circleRadius, greaterThan(moving.circleRadius!));
      expect(
        truckSymbolOptions(
          truck('offline', state: TruckMarkerState.offline),
        ).iconOpacity,
        lessThan(1),
      );
    });
  });

  group('incremental annotation lifecycle', () {
    test(
      'initial load registers once and unchanged snapshot is a no-op',
      () async {
        final adapter = FakeFleetMapAdapter();
        final coordinator = FleetMapAnnotationCoordinator(adapter);
        final snapshot = fleetSnapshot([truck('one'), truck('two')]);

        await coordinator.onStyleLoaded(snapshot);
        final before = Map<String, int>.from(coordinator.telemetry.toJson());
        await coordinator.synchronize(snapshot);

        expect(coordinator.telemetry.imageRegistrations, 1);
        expect(coordinator.telemetry.symbolAdditions, 2);
        expect(coordinator.telemetry.statusAdditions, 2);
        expect(coordinator.telemetry.toJson(), before);
        expect(
          adapter.operations.where((value) => value.startsWith('clear')),
          isEmpty,
        );
      },
    );

    test(
      'position, heading, and status update only the affected truck',
      () async {
        final adapter = FakeFleetMapAdapter();
        final coordinator = FleetMapAnnotationCoordinator(adapter);
        await coordinator.onStyleLoaded(
          fleetSnapshot([truck('one'), truck('two')]),
        );
        adapter.operations.clear();

        await coordinator.synchronize(
          fleetSnapshot([
            truck(
              'one',
              latitude: 40.1,
              heading: 270,
              state: TruckMarkerState.offline,
            ),
            truck('two'),
          ]),
        );

        expect(adapter.operations, ['status:update:one', 'truck:update:one']);
        expect(coordinator.telemetry.symbolUpdates, 1);
        expect(coordinator.telemetry.statusUpdates, 1);
        expect(adapter.trucks['one']!.heading, 270);
        expect(adapter.trucks['one']!.state, TruckMarkerState.offline);
      },
    );

    test('adding and filtering a truck touches only that marker', () async {
      final adapter = FakeFleetMapAdapter();
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      await coordinator.onStyleLoaded(fleetSnapshot([truck('one')]));
      adapter.operations.clear();
      await coordinator.synchronize(
        fleetSnapshot([truck('one'), truck('two')]),
      );
      expect(adapter.operations, ['status:add:two', 'truck:add:two']);

      adapter.operations.clear();
      await coordinator.synchronize(fleetSnapshot([truck('two')]));
      expect(adapter.operations, ['truck:remove:one', 'status:remove:one']);
    });

    test(
      'polling preserves route and stops while updating trail in place',
      () async {
        final adapter = FakeFleetMapAdapter();
        final coordinator = FleetMapAnnotationCoordinator(adapter);
        await coordinator.onStyleLoaded(
          fleetSnapshot([truck('one')], route: route(trailLength: 2)),
        );
        adapter.operations.clear();

        await coordinator.synchronize(
          fleetSnapshot([
            truck('one', latitude: 40.01),
          ], route: route(trailLength: 3)),
        );

        expect(adapter.operations, [
          'status:update:one',
          'truck:update:one',
          'trail:update:run-a',
        ]);
        expect(coordinator.telemetry.plannedRouteAdditions, 1);
        expect(coordinator.telemetry.plannedRouteUpdates, 0);
        expect(coordinator.telemetry.plannedRouteRemovals, 0);
        expect(coordinator.telemetry.stopMarkerAdditions, 2);
        expect(coordinator.telemetry.stopMarkerRemovals, 0);
        expect(coordinator.telemetry.trailUpdates, 1);
      },
    );

    test('approach overlay is independent and stable across polling', () async {
      final adapter = FakeFleetMapAdapter();
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      await coordinator.onStyleLoaded(
        fleetSnapshot([truck('one')], route: route(withApproach: true)),
      );
      adapter.operations.clear();

      for (var index = 1; index <= 10; index++) {
        await coordinator.synchronize(
          fleetSnapshot([
            truck('one', latitude: 40 + index / 1000),
          ], route: route(withApproach: true, trailLength: index + 2)),
        );
      }

      expect(coordinator.telemetry.approachRouteAdditions, 1);
      expect(coordinator.telemetry.approachRouteUpdates, 0);
      expect(coordinator.telemetry.approachRouteRemovals, 0);
      expect(
        adapter.operations.where((value) => value.startsWith('approach:')),
        isEmpty,
      );
      expect(coordinator.telemetry.globalLineClears, 0);
      expect(coordinator.telemetry.cameraMovesCausedByPolling, 0);
    });

    test(
      'selecting a different trip changes route-specific annotations',
      () async {
        final adapter = FakeFleetMapAdapter();
        final coordinator = FleetMapAnnotationCoordinator(adapter);
        await coordinator.onStyleLoaded(
          fleetSnapshot([truck('one')], route: route(tripId: 'trip-a')),
        );
        adapter.operations.clear();

        await coordinator.synchronize(
          fleetSnapshot([
            truck('one'),
          ], route: route(tripId: 'trip-b', longitudeOffset: 1)),
        );

        expect(
          adapter.operations.where((value) => value.startsWith('truck:')),
          isEmpty,
        );
        expect(
          adapter.operations,
          containsAll([
            'route:remove',
            'stop:remove:pickup',
            'stop:remove:delivery',
            'trail:remove:run-a',
            'route:add',
            'stop:add:pickup',
            'stop:add:delivery',
            'trail:add:run-a',
          ]),
        );
      },
    );

    test('genuine style reload performs one controlled rebuild', () async {
      final adapter = FakeFleetMapAdapter();
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      final snapshot = fleetSnapshot([truck('one')], route: route());
      await coordinator.onStyleLoaded(snapshot);
      adapter.operations.clear();

      await coordinator.onStyleLoaded(snapshot);

      expect(coordinator.telemetry.imageRegistrations, 2);
      expect(adapter.operations.first, 'style:prepare');
      expect(
        adapter.operations.where((value) => value == 'truck:add:one'),
        hasLength(1),
      );
      expect(
        adapter.operations.where((value) => value.startsWith('clear')),
        isEmpty,
      );
    });

    test('rapid snapshots are serialized and coalesced to latest', () async {
      final gate = Completer<void>();
      final adapter = FakeFleetMapAdapter(updateGate: gate);
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      await coordinator.onStyleLoaded(fleetSnapshot([truck('one')]));
      adapter.operations.clear();

      final first = coordinator.synchronize(
        fleetSnapshot([truck('one', latitude: 40.1)]),
      );
      await adapter.updateStarted.future;
      await coordinator.synchronize(
        fleetSnapshot([truck('one', latitude: 40.2)]),
      );
      await coordinator.synchronize(
        fleetSnapshot([truck('one', latitude: 40.3)]),
      );
      gate.complete();
      await first;

      expect(adapter.maxConcurrentOperations, 1);
      expect(adapter.trucks['one']!.point.latitude, 40.3);
      expect(
        adapter.operations.where((value) => value == 'truck:update:one'),
        hasLength(2),
      );
    });
  });

  group('camera state', () {
    test('one truck uses local zoom and multiple trucks use bounds', () async {
      final adapter = FakeFleetMapAdapter();
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      await coordinator.onStyleLoaded(fleetSnapshot([truck('one')]));
      expect(adapter.cameraPlans.single.mode, FleetCameraMode.localTruck);

      await coordinator.synchronize(
        fleetSnapshot([truck('one'), truck('two')]),
        cameraRequest: FleetCameraRequest.filteredFleet,
      );
      expect(adapter.cameraPlans.last.mode, FleetCameraMode.fleetBounds);
    });

    test(
      'selection follows locally and route overview fits exactly on request',
      () async {
        final adapter = FakeFleetMapAdapter();
        final coordinator = FleetMapAnnotationCoordinator(adapter);
        final snapshot = fleetSnapshot(
          [truck('one', selected: true)],
          selectedTruckId: 'one',
          route: route(),
        );
        await coordinator.onStyleLoaded(snapshot);
        adapter.cameraPlans.clear();

        await coordinator.synchronize(
          snapshot,
          cameraRequest: FleetCameraRequest.recenter,
          panelWidth: 290,
        );

        expect(adapter.cameraPlans.single.mode, FleetCameraMode.localTruck);
        expect(adapter.cameraPlans.single.points, hasLength(1));
        expect(adapter.cameraPlans.single.panelWidth, 290);

        adapter.cameraPlans.clear();
        await coordinator.synchronize(
          snapshot,
          cameraRequest: FleetCameraRequest.routeOverview,
          panelWidth: 290,
        );

        expect(adapter.cameraPlans.single.mode, FleetCameraMode.routeBounds);
        expect(adapter.cameraPlans.single.points, hasLength(3));

        adapter.cameraPlans.clear();
        await coordinator.synchronize(snapshot);
        expect(adapter.cameraPlans, isEmpty);
      },
    );

    test('polling never steals camera after manual pan', () async {
      final adapter = FakeFleetMapAdapter();
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      await coordinator.onStyleLoaded(fleetSnapshot([truck('one')]));
      adapter.cameraPlans.clear();

      await coordinator.synchronize(
        fleetSnapshot([truck('one', latitude: 40.1)]),
      );

      expect(adapter.cameraPlans, isEmpty);
      expect(coordinator.telemetry.cameraMovesCausedByPolling, 0);
    });
  });

  test('ten moving polls produce stable operation-count evidence', () async {
    final adapter = FakeFleetMapAdapter();
    final coordinator = FleetMapAnnotationCoordinator(adapter);
    await coordinator.onStyleLoaded(
      fleetSnapshot([truck('one')], route: route(trailLength: 2)),
    );

    for (var index = 1; index <= 10; index++) {
      await coordinator.synchronize(
        fleetSnapshot([
          truck('one', latitude: 40 + index / 1000),
        ], route: route(trailLength: index + 2)),
      );
    }

    final counts = coordinator.telemetry;
    expect(counts.imageRegistrations, 1);
    expect(counts.symbolAdditions, 1);
    expect(counts.symbolUpdates, 10);
    expect(counts.symbolRemovals, 0);
    expect(counts.plannedRouteAdditions, 1);
    expect(counts.plannedRouteUpdates, 0);
    expect(counts.plannedRouteRemovals, 0);
    expect(counts.trailAdditions, 1);
    expect(counts.trailUpdates, 10);
    expect(counts.trailRemovals, 0);
    expect(counts.stopMarkerAdditions, 2);
    expect(counts.stopMarkerRemovals, 0);
    expect(counts.globalSymbolClears, 0);
    expect(counts.globalLineClears, 0);
    expect(counts.globalCircleClears, 0);
    expect(counts.cameraMovesCausedByPolling, 0);
  });

  test(
    'independent trail segments keep stable identifiers during polling',
    () async {
      final adapter = FakeFleetMapAdapter();
      final coordinator = FleetMapAnnotationCoordinator(adapter);
      await coordinator.onStyleLoaded(
        fleetSnapshot([truck('one')], route: route(segmentCount: 2)),
      );
      expect(
        adapter.operations,
        containsAll(['trail:add:run-a', 'trail:add:run-b']),
      );
      adapter.operations.clear();

      await coordinator.synchronize(
        fleetSnapshot([
          truck('one', latitude: 40.01),
        ], route: route(segmentCount: 2, trailLength: 3)),
      );

      expect(adapter.operations, contains('trail:update:run-a'));
      expect(adapter.operations, contains('trail:update:run-b'));
      expect(
        adapter.operations.where((value) => value.startsWith('trail:add')),
        isEmpty,
      );
      expect(
        adapter.operations.where((value) => value.startsWith('trail:remove')),
        isEmpty,
      );
    },
  );
}

TruckMarkerModel truck(
  String id, {
  double latitude = 40,
  double longitude = 30,
  double heading = 0,
  TruckMarkerState state = TruckMarkerState.moving,
  bool selected = false,
  String? photoVersion,
  String? photoThumbnailUrl,
}) => TruckMarkerModel(
  id: id,
  point: MapPoint(latitude, longitude),
  heading: heading,
  state: state,
  selected: selected,
  photoVersion: photoVersion,
  photoThumbnailUrl: photoThumbnailUrl,
);

FleetMapSnapshot fleetSnapshot(
  List<TruckMarkerModel> trucks, {
  String? selectedTruckId,
  RouteOverlayModel? route,
}) => FleetMapSnapshot(
  trucks: trucks,
  selectedTruckId: selectedTruckId,
  route: route,
);

RouteOverlayModel route({
  String tripId = 'trip-a',
  int trailLength = 2,
  int segmentCount = 1,
  double longitudeOffset = 0,
  bool withApproach = false,
}) => RouteOverlayModel(
  tripId: tripId,
  route: [
    MapPoint(40, 30 + longitudeOffset),
    MapPoint(40.5, 30.5 + longitudeOffset),
    MapPoint(41, 31 + longitudeOffset),
  ],
  approachRoute: withApproach
      ? [const MapPoint(39.5, 29.5), const MapPoint(40, 30)]
      : const [],
  trails: List.generate(
    segmentCount,
    (segment) => TrailSegmentModel(
      id: segment == 0 ? 'run-a' : 'run-b',
      points: List.generate(
        trailLength,
        (index) => MapPoint(
          40 + segment / 10 + index / 100,
          30 + segment / 10 + index / 100,
        ),
      ),
    ),
  ),
);

final class FakeFleetMapAdapter implements FleetMapAnnotationAdapter {
  FakeFleetMapAdapter({this.updateGate});

  final Completer<void>? updateGate;
  final Completer<void> updateStarted = Completer<void>();
  final List<String> operations = [];
  final Map<String, TruckMarkerModel> trucks = {};
  final Map<String, TruckMarkerModel> statuses = {};
  final List<FleetCameraPlan> cameraPlans = [];
  int _activeOperations = 0;
  int maxConcurrentOperations = 0;

  Future<void> _operation(String value, [Future<void>? wait]) async {
    _activeOperations++;
    if (_activeOperations > maxConcurrentOperations) {
      maxConcurrentOperations = _activeOperations;
    }
    operations.add(value);
    if (wait != null) await wait;
    _activeOperations--;
  }

  @override
  Future<void> prepareStyle() async {
    trucks.clear();
    statuses.clear();
    await _operation('style:prepare');
  }

  @override
  Future<void> addTruck(TruckMarkerModel truck) async {
    trucks[truck.id] = truck;
    await _operation('truck:add:${truck.id}');
  }

  @override
  Future<void> updateTruck(TruckMarkerModel truck) async {
    if (!updateStarted.isCompleted) updateStarted.complete();
    await _operation('truck:update:${truck.id}', updateGate?.future);
    trucks[truck.id] = truck;
  }

  @override
  Future<void> removeTruck(String truckId) async {
    trucks.remove(truckId);
    await _operation('truck:remove:$truckId');
  }

  @override
  Future<void> addStatus(TruckMarkerModel truck) async {
    statuses[truck.id] = truck;
    await _operation('status:add:${truck.id}');
  }

  @override
  Future<void> updateStatus(TruckMarkerModel truck) async {
    statuses[truck.id] = truck;
    await _operation('status:update:${truck.id}');
  }

  @override
  Future<void> removeStatus(String truckId) async {
    statuses.remove(truckId);
    await _operation('status:remove:$truckId');
  }

  @override
  Future<void> addPlannedRoute(List<MapPoint> route) => _operation('route:add');
  @override
  Future<void> updatePlannedRoute(List<MapPoint> route) =>
      _operation('route:update');
  @override
  Future<void> removePlannedRoute() => _operation('route:remove');
  @override
  Future<void> addApproachRoute(List<MapPoint> route) =>
      _operation('approach:add');
  @override
  Future<void> updateApproachRoute(List<MapPoint> route) =>
      _operation('approach:update');
  @override
  Future<void> removeApproachRoute() => _operation('approach:remove');
  @override
  Future<void> addTrail(String id, List<MapPoint> trail) =>
      _operation('trail:add:$id');
  @override
  Future<void> updateTrail(String id, List<MapPoint> trail) =>
      _operation('trail:update:$id');
  @override
  Future<void> removeTrail(String id) => _operation('trail:remove:$id');
  @override
  Future<void> addStop(String id, MapPoint point, {required bool pickup}) =>
      _operation('stop:add:$id');
  @override
  Future<void> removeStop(String id) => _operation('stop:remove:$id');
  @override
  Future<void> animateCamera(FleetCameraPlan plan) async {
    cameraPlans.add(plan);
    await _operation('camera:${plan.mode.name}');
  }
}
