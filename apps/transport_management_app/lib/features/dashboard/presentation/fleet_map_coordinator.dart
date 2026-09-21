import 'dart:async';

import '../domain/dashboard_models.dart';

enum TruckMarkerState { moving, stationary, offline, maintenance }

enum FleetCameraRequest {
  none,
  initialFleet,
  filteredFleet,
  selection,
  recenter,
}

enum FleetCameraMode { localTruck, fleetBounds, routeBounds }

final class MapPoint {
  const MapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is MapPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

final class TruckMarkerModel {
  const TruckMarkerModel({
    required this.id,
    required this.point,
    required this.heading,
    required this.state,
    required this.selected,
  });

  final String id;
  final MapPoint point;
  final double heading;
  final TruckMarkerState state;
  final bool selected;

  static TruckMarkerState stateFor(TrackedTruck truck) {
    final status = truck.truckStatus.toLowerCase();
    if (status.contains('maintenance') ||
        status.contains('outofservice') ||
        status.contains('out_of_service') ||
        status.contains('out of service')) {
      return TruckMarkerState.maintenance;
    }
    if (!truck.isOnline) return TruckMarkerState.offline;
    return truck.speed > 0.5
        ? TruckMarkerState.moving
        : TruckMarkerState.stationary;
  }

  @override
  bool operator ==(Object other) =>
      other is TruckMarkerModel &&
      other.id == id &&
      other.point == point &&
      other.heading == heading &&
      other.state == state &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(id, point, heading, state, selected);
}

final class RouteOverlayModel {
  const RouteOverlayModel({
    required this.tripId,
    required this.route,
    required this.trails,
  });

  final String tripId;
  final List<MapPoint> route;
  final List<TrailSegmentModel> trails;

  String get routeRevision => _pointRevision(route);
}

final class TrailSegmentModel {
  const TrailSegmentModel({required this.id, required this.points});
  final String id;
  final List<MapPoint> points;

  String get revision => _pointRevision(points);
}

final class FleetMapSnapshot {
  FleetMapSnapshot({
    required Iterable<TruckMarkerModel> trucks,
    this.selectedTruckId,
    this.route,
  }) : trucks = {for (final truck in trucks) truck.id: truck};

  final Map<String, TruckMarkerModel> trucks;
  final String? selectedTruckId;
  final RouteOverlayModel? route;
}

final class FleetCameraPlan {
  const FleetCameraPlan({
    required this.mode,
    required this.points,
    this.panelWidth = 0,
  });

  final FleetCameraMode mode;
  final List<MapPoint> points;
  final double panelWidth;
}

final class MapOperationTelemetry {
  int imageRegistrations = 0;
  int symbolAdditions = 0;
  int symbolUpdates = 0;
  int symbolRemovals = 0;
  int statusAdditions = 0;
  int statusUpdates = 0;
  int statusRemovals = 0;
  int plannedRouteAdditions = 0;
  int plannedRouteUpdates = 0;
  int plannedRouteRemovals = 0;
  int trailAdditions = 0;
  int trailUpdates = 0;
  int trailRemovals = 0;
  int stopMarkerAdditions = 0;
  int stopMarkerRemovals = 0;
  int globalSymbolClears = 0;
  int globalLineClears = 0;
  int globalCircleClears = 0;
  int cameraMoves = 0;
  int cameraMovesCausedByPolling = 0;

  Map<String, int> toJson() => {
    'imageRegistrations': imageRegistrations,
    'symbolAdditions': symbolAdditions,
    'symbolUpdates': symbolUpdates,
    'symbolRemovals': symbolRemovals,
    'statusAdditions': statusAdditions,
    'statusUpdates': statusUpdates,
    'statusRemovals': statusRemovals,
    'plannedRouteAdditions': plannedRouteAdditions,
    'plannedRouteUpdates': plannedRouteUpdates,
    'plannedRouteRemovals': plannedRouteRemovals,
    'trailAdditions': trailAdditions,
    'trailUpdates': trailUpdates,
    'trailRemovals': trailRemovals,
    'stopMarkerAdditions': stopMarkerAdditions,
    'stopMarkerRemovals': stopMarkerRemovals,
    'globalSymbolClears': globalSymbolClears,
    'globalLineClears': globalLineClears,
    'globalCircleClears': globalCircleClears,
    'cameraMoves': cameraMoves,
    'cameraMovesCausedByPolling': cameraMovesCausedByPolling,
  };
}

abstract interface class FleetMapAnnotationAdapter {
  Future<void> prepareStyle();
  Future<void> addTruck(TruckMarkerModel truck);
  Future<void> updateTruck(TruckMarkerModel truck);
  Future<void> removeTruck(String truckId);
  Future<void> addStatus(TruckMarkerModel truck);
  Future<void> updateStatus(TruckMarkerModel truck);
  Future<void> removeStatus(String truckId);
  Future<void> addPlannedRoute(List<MapPoint> route);
  Future<void> updatePlannedRoute(List<MapPoint> route);
  Future<void> removePlannedRoute();
  Future<void> addTrail(String id, List<MapPoint> trail);
  Future<void> updateTrail(String id, List<MapPoint> trail);
  Future<void> removeTrail(String id);
  Future<void> addStop(String id, MapPoint point, {required bool pickup});
  Future<void> removeStop(String id);
  Future<void> animateCamera(FleetCameraPlan plan);
}

final class FleetMapAnnotationCoordinator {
  FleetMapAnnotationCoordinator(
    this._adapter, {
    MapOperationTelemetry? telemetry,
  }) : telemetry = telemetry ?? MapOperationTelemetry();

  final FleetMapAnnotationAdapter _adapter;
  final MapOperationTelemetry telemetry;

  FleetMapSnapshot? _applied;
  _SyncRequest? _pending;
  bool _syncing = false;
  bool _disposed = false;
  int _styleGeneration = 0;
  Completer<void>? _drainCompleter;

  Future<void> onStyleLoaded(
    FleetMapSnapshot snapshot, {
    double panelWidth = 0,
  }) async {
    if (_disposed) return;
    final generation = ++_styleGeneration;
    _pending = null;
    final activeDrain = _drainCompleter;
    if (activeDrain != null) {
      try {
        await activeDrain.future;
      } on Object {
        // A stale style operation may fail while MapLibre replaces its style.
      }
    }
    if (_disposed || generation != _styleGeneration) return;
    _applied = null;
    await _adapter.prepareStyle();
    if (_disposed || generation != _styleGeneration) return;
    telemetry.imageRegistrations++;
    await synchronize(
      snapshot,
      cameraRequest: FleetCameraRequest.initialFleet,
      panelWidth: panelWidth,
    );
  }

  Future<void> synchronize(
    FleetMapSnapshot snapshot, {
    FleetCameraRequest cameraRequest = FleetCameraRequest.none,
    double panelWidth = 0,
  }) async {
    if (_disposed) return;
    _pending = _SyncRequest(snapshot, cameraRequest, panelWidth);
    if (_syncing) return;
    _syncing = true;
    final drainCompleter = Completer<void>();
    _drainCompleter = drainCompleter;
    try {
      while (!_disposed && _pending != null) {
        final request = _pending!;
        _pending = null;
        await _apply(request);
      }
    } finally {
      _syncing = false;
      if (!drainCompleter.isCompleted) drainCompleter.complete();
      if (identical(_drainCompleter, drainCompleter)) _drainCompleter = null;
      if (!_disposed && _pending != null) {
        unawaited(
          synchronize(
            _pending!.snapshot,
            cameraRequest: _pending!.cameraRequest,
            panelWidth: _pending!.panelWidth,
          ).catchError((_) {}),
        );
      }
    }
  }

  Future<void> _apply(_SyncRequest request) async {
    final previous = _applied;
    final next = request.snapshot;
    final previousTrucks =
        previous?.trucks ?? const <String, TruckMarkerModel>{};

    for (final id in previousTrucks.keys.where(
      (id) => !next.trucks.containsKey(id),
    )) {
      await _adapter.removeTruck(id);
      telemetry.symbolRemovals++;
      await _adapter.removeStatus(id);
      telemetry.statusRemovals++;
    }

    for (final entry in next.trucks.entries) {
      final oldTruck = previousTrucks[entry.key];
      if (oldTruck == null) {
        await _adapter.addStatus(entry.value);
        telemetry.statusAdditions++;
        await _adapter.addTruck(entry.value);
        telemetry.symbolAdditions++;
      } else if (oldTruck != entry.value) {
        await _adapter.updateStatus(entry.value);
        telemetry.statusUpdates++;
        await _adapter.updateTruck(entry.value);
        telemetry.symbolUpdates++;
      }
    }

    await _syncRoute(previous?.route, next.route);
    _applied = next;
    await _moveCamera(request);
  }

  Future<void> _syncRoute(
    RouteOverlayModel? oldRoute,
    RouteOverlayModel? route,
  ) async {
    if (route == null) {
      if (oldRoute == null) return;
      for (final segment in oldRoute.trails.where(
        (segment) => segment.points.length > 1,
      )) {
        await _adapter.removeTrail(segment.id);
        telemetry.trailRemovals++;
      }
      if (oldRoute.route.length > 1) {
        await _adapter.removePlannedRoute();
        telemetry.plannedRouteRemovals++;
        await _adapter.removeStop('pickup');
        await _adapter.removeStop('delivery');
        telemetry.stopMarkerRemovals += 2;
      }
      return;
    }

    final routeChanged =
        oldRoute == null ||
        oldRoute.tripId != route.tripId ||
        oldRoute.routeRevision != route.routeRevision;
    if (routeChanged) {
      if (oldRoute != null && oldRoute.route.length > 1) {
        await _adapter.removePlannedRoute();
        telemetry.plannedRouteRemovals++;
        await _adapter.removeStop('pickup');
        await _adapter.removeStop('delivery');
        telemetry.stopMarkerRemovals += 2;
      }
      if (oldRoute != null) {
        for (final segment in oldRoute.trails.where(
          (segment) => segment.points.length > 1,
        )) {
          await _adapter.removeTrail(segment.id);
          telemetry.trailRemovals++;
        }
      }
      if (route.route.length > 1) {
        await _adapter.addPlannedRoute(route.route);
        telemetry.plannedRouteAdditions++;
        await _adapter.addStop('pickup', route.route.first, pickup: true);
        await _adapter.addStop('delivery', route.route.last, pickup: false);
        telemetry.stopMarkerAdditions += 2;
      }
      for (final segment in route.trails.where(
        (segment) => segment.points.length > 1,
      )) {
        await _adapter.addTrail(segment.id, segment.points);
        telemetry.trailAdditions++;
      }
      return;
    }

    final oldSegments = {
      for (final segment in oldRoute.trails) segment.id: segment,
    };
    final nextSegments = {
      for (final segment in route.trails) segment.id: segment,
    };
    for (final old in oldSegments.values.where(
      (segment) => !nextSegments.containsKey(segment.id),
    )) {
      if (old.points.length > 1) {
        await _adapter.removeTrail(old.id);
        telemetry.trailRemovals++;
      }
    }
    for (final segment in nextSegments.values) {
      final old = oldSegments[segment.id];
      if (old == null) {
        if (segment.points.length > 1) {
          await _adapter.addTrail(segment.id, segment.points);
          telemetry.trailAdditions++;
        }
      } else if (old.revision != segment.revision) {
        if (old.points.length <= 1 && segment.points.length > 1) {
          await _adapter.addTrail(segment.id, segment.points);
          telemetry.trailAdditions++;
        } else if (old.points.length > 1 && segment.points.length <= 1) {
          await _adapter.removeTrail(segment.id);
          telemetry.trailRemovals++;
        } else if (segment.points.length > 1) {
          await _adapter.updateTrail(segment.id, segment.points);
          telemetry.trailUpdates++;
        }
      }
    }
  }

  Future<void> _moveCamera(_SyncRequest request) async {
    if (request.cameraRequest == FleetCameraRequest.none) return;
    final snapshot = request.snapshot;
    FleetCameraPlan? plan;
    if (request.cameraRequest == FleetCameraRequest.selection ||
        request.cameraRequest == FleetCameraRequest.recenter) {
      final route = snapshot.route;
      if (route != null && route.route.isNotEmpty) {
        plan = FleetCameraPlan(
          mode: FleetCameraMode.routeBounds,
          points: route.route,
          panelWidth: request.panelWidth,
        );
      } else {
        final truck = snapshot.trucks[snapshot.selectedTruckId];
        if (truck != null) {
          plan = FleetCameraPlan(
            mode: FleetCameraMode.localTruck,
            points: [truck.point],
            panelWidth: request.panelWidth,
          );
        }
      }
    } else if (snapshot.trucks.isNotEmpty) {
      final points = snapshot.trucks.values
          .map((truck) => truck.point)
          .toList();
      plan = FleetCameraPlan(
        mode: points.length == 1
            ? FleetCameraMode.localTruck
            : FleetCameraMode.fleetBounds,
        points: points,
        panelWidth: request.panelWidth,
      );
    }
    if (plan == null) return;
    await _adapter.animateCamera(plan);
    telemetry.cameraMoves++;
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    _styleGeneration++;
  }
}

final class _SyncRequest {
  const _SyncRequest(this.snapshot, this.cameraRequest, this.panelWidth);
  final FleetMapSnapshot snapshot;
  final FleetCameraRequest cameraRequest;
  final double panelWidth;
}

String _pointRevision(List<MapPoint> points) => points
    .map(
      (point) =>
          '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
    )
    .join(';');
