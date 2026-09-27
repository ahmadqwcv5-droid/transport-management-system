import 'dart:async';

import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/maps/vehicle_motion_interpolator.dart';
import 'fleet_map_coordinator.dart';
import 'circular_marker_image.dart';

const truckMarkerAsset = 'assets/map/truck_top_down.png';
const truckMarkerImageName = 'tms-truck-top-down';
const truckMarkerHeadingOffset = 0.0;

double mapMarkerRotation(double trackingHeading) =>
    (trackingHeading + truckMarkerHeadingOffset) % 360;

SymbolOptions truckSymbolOptions(
  TruckMarkerModel truck, {
  bool forceFallback = false,
}) {
  final usesPhoto = !forceFallback && truck.photoImageName != null;
  return SymbolOptions(
    geometry: _latLng(truck.point),
    iconImage: forceFallback
        ? truckMarkerImageName
        : truck.photoImageName ?? truckMarkerImageName,
    iconSize: truck.selected ? 0.82 : 0.70,
    // Keep human-recognizable photos upright. The small arrow supplies heading.
    iconRotate: usesPhoto ? 0 : mapMarkerRotation(truck.heading),
    iconAnchor: 'center',
    iconOpacity: switch (truck.state) {
      TruckMarkerState.offline => 0.5,
      TruckMarkerState.maintenance => 0.72,
      _ => 1,
    },
    zIndex: truck.selected ? 20 : 10,
    textField: usesPhoto ? '▲' : null,
    textSize: usesPhoto ? 13 : null,
    textRotate: usesPhoto ? mapMarkerRotation(truck.heading) : null,
    textOffset: usesPhoto ? const Offset(0, -1.8) : null,
    textColor: usesPhoto ? '#0F172A' : null,
    textHaloColor: usesPhoto ? '#FFFFFF' : null,
    textHaloWidth: usesPhoto ? 1.5 : null,
  );
}

CircleOptions truckStatusCircleOptions(TruckMarkerModel truck) {
  final selectedExtra = truck.selected ? 6.0 : 0.0;
  final (
    radius,
    color,
    opacity,
    strokeWidth,
    strokeColor,
  ) = switch (truck.state) {
    TruckMarkerState.moving => (19.0, '#16A34A', 0.24, 2.0, '#15803D'),
    TruckMarkerState.stationary => (18.0, '#2563EB', 0.22, 4.0, '#1D4ED8'),
    TruckMarkerState.offline => (16.0, '#6B7280', 0.16, 2.0, '#4B5563'),
    TruckMarkerState.maintenance => (20.0, '#F59E0B', 0.26, 4.0, '#78350F'),
  };
  return CircleOptions(
    geometry: _latLng(truck.point),
    circleRadius: radius + selectedExtra,
    circleColor: color,
    circleOpacity: opacity,
    circleStrokeWidth: truck.selected ? 5 : strokeWidth,
    circleStrokeColor: truck.selected ? '#0F172A' : strokeColor,
    circleStrokeOpacity: 0.95,
  );
}

typedef AuthenticatedThumbnailLoader = Future<Uint8List> Function(String url);

final class MapLibreFleetAnnotationAdapter
    implements FleetMapAnnotationAdapter {
  MapLibreFleetAnnotationAdapter(
    this.controller,
    this.thumbnailLoader, {
    CircularMarkerImageProcessor markerProcessor =
        const CircularMarkerImageProcessor(),
    this.telemetry,
  }) : _markerProcessor = markerProcessor;

  final MapLibreMapController controller;
  final AuthenticatedThumbnailLoader thumbnailLoader;
  final CircularMarkerImageProcessor _markerProcessor;
  final Map<String, Symbol> _trucks = {};
  final MapOperationTelemetry? telemetry;
  final Map<String, Circle> _statuses = {};
  final Map<String, Circle> _stops = {};
  final Map<String, VehicleMotionInterpolator> _motions = {};
  final Map<String, TruckMarkerModel> _targets = {};
  final Map<String, int> _animationRevisions = {};
  final Set<String> _animating = {};
  Line? _plannedRoute;
  static const _approachSourceId = 'tms-approach-route-source';
  static const _approachLayerId = 'tms-approach-route-layer';
  bool _approachRouteAdded = false;
  final Map<String, Line> _trails = {};
  final Set<String> _registeredPhotoImages = {};
  final Set<String> _failedPhotoImages = {};

  @override
  Future<void> prepareStyle() async {
    _trucks.clear();
    _statuses.clear();
    _stops.clear();
    _plannedRoute = null;
    _approachRouteAdded = false;
    _trails.clear();
    _motions.clear();
    _targets.clear();
    _animationRevisions.clear();
    _animating.clear();
    _registeredPhotoImages.clear();
    _failedPhotoImages.clear();

    final bytes = await rootBundle.load(truckMarkerAsset);
    await controller.addImage(
      truckMarkerImageName,
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );

    final manager = controller.symbolManager;
    if (manager != null) {
      await manager.setIconAllowOverlap(true);
      await manager.setIconIgnorePlacement(true);
      final base = manager.allLayerProperties.first as SymbolLayerProperties;
      final properties = base.copyWith(
        const SymbolLayerProperties(
          iconRotationAlignment: 'map',
          iconPitchAlignment: 'map',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
      );
      for (final layerId in manager.layerIds) {
        await controller.setLayerProperties(layerId, properties);
      }
    }
  }

  @override
  Future<void> addTruck(TruckMarkerModel truck) async {
    final photoReady = await _ensurePhoto(truck);
    final motion = VehicleMotionInterpolator();
    motion.retarget(
      target: _visualState(truck),
      now: DateTime.now(),
      animate: false,
    );
    _motions[truck.id] = motion;
    _targets[truck.id] = truck;
    _animationRevisions[truck.id] = motion.revision;
    _trucks[truck.id] = await controller.addSymbol(
      truckSymbolOptions(truck, forceFallback: !photoReady),
      <String, dynamic>{'truckId': truck.id},
    );
  }

  @override
  Future<void> updateTruck(TruckMarkerModel truck) async {
    final photoReady = await _ensurePhoto(truck);
    final symbol = _trucks[truck.id];
    if (symbol == null) return addTruck(truck);
    final previous = _targets[truck.id];
    _targets[truck.id] = truck;
    final motion = _motions.putIfAbsent(
      truck.id,
      VehicleMotionInterpolator.new,
    );
    final now = DateTime.now();
    final sampleGap = previous?.recordedAt == null || truck.recordedAt == null
        ? null
        : truck.recordedAt!.difference(previous!.recordedAt!).abs();
    final animate =
        truck.state == TruckMarkerState.moving &&
        previous != null &&
        previous.state != TruckMarkerState.offline &&
        previous.state != TruckMarkerState.maintenance;
    final visual = motion.retarget(
      target: _visualState(truck),
      now: now,
      sampleGap: sampleGap,
      animate: animate,
    );
    final revision = motion.revision;
    _animationRevisions[truck.id] = revision;
    if (_animating.contains(truck.id)) {
      telemetry?.interpolationCancellations++;
    }
    if (_sameVisual(visual, _visualState(truck))) {
      _animating.remove(truck.id);
      telemetry?.interpolationSnaps++;
      await _updateVisual(truck, symbol, photoReady);
      return;
    }

    telemetry?.interpolationStarts++;
    _animating.add(truck.id);
    unawaited(_animate(truck, symbol, photoReady, motion, revision));
  }

  Future<void> _animate(
    TruckMarkerModel target,
    Symbol symbol,
    bool photoReady,
    VehicleMotionInterpolator motion,
    int revision,
  ) async {
    try {
      while (_animationRevisions[target.id] == revision) {
        final visual = motion.sample(DateTime.now());
        if (visual == null) return;
        await _updateVisual(_withVisual(target, visual), symbol, photoReady);
        if (_sameVisual(visual, _visualState(target))) {
          _animating.remove(target.id);
          telemetry?.interpolationCompletions++;
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } on Object {
      _animating.remove(target.id);
    }
  }

  Future<void> _updateVisual(
    TruckMarkerModel truck,
    Symbol symbol,
    bool photoReady,
  ) async {
    await controller.updateSymbol(
      symbol,
      truckSymbolOptions(truck, forceFallback: !photoReady),
    );
    final status = _statuses[truck.id];
    if (status != null) {
      await controller.updateCircle(status, truckStatusCircleOptions(truck));
    }
  }

  Future<bool> _ensurePhoto(TruckMarkerModel truck) async {
    final name = truck.photoImageName;
    final url = truck.photoThumbnailUrl;
    if (name == null || url == null || _registeredPhotoImages.contains(name)) {
      return name == null || _registeredPhotoImages.contains(name);
    }
    if (_failedPhotoImages.contains(name)) return false;
    try {
      final source = await thumbnailLoader(url);
      await controller.addImage(name, await _markerProcessor.process(source));
      _registeredPhotoImages.add(name);
      return true;
    } on Object {
      _failedPhotoImages.add(name);
      return false;
    }
  }

  @override
  Future<void> removeTruck(String truckId) async {
    _animationRevisions[truckId] = (_animationRevisions[truckId] ?? 0) + 1;
    _animating.remove(truckId);
    _motions.remove(truckId);
    _targets.remove(truckId);
    final symbol = _trucks.remove(truckId);
    if (symbol != null) await controller.removeSymbol(symbol);
  }

  @override
  Future<void> addStatus(TruckMarkerModel truck) async {
    _statuses[truck.id] = await controller.addCircle(
      truckStatusCircleOptions(truck),
    );
  }

  @override
  Future<void> updateStatus(TruckMarkerModel truck) async {
    final circle = _statuses[truck.id];
    if (circle == null) return addStatus(truck);
    await controller.updateCircle(circle, truckStatusCircleOptions(truck));
  }

  @override
  Future<void> removeStatus(String truckId) async {
    final circle = _statuses.remove(truckId);
    if (circle != null) await controller.removeCircle(circle);
  }

  @override
  Future<void> addPlannedRoute(List<MapPoint> route) async {
    _plannedRoute = await controller.addLine(
      LineOptions(
        geometry: route.map(_latLng).toList(),
        lineColor: '#175CD3',
        lineWidth: 5,
        lineOpacity: 0.9,
      ),
    );
  }

  @override
  Future<void> updatePlannedRoute(List<MapPoint> route) async {
    final line = _plannedRoute;
    if (line == null) return addPlannedRoute(route);
    await controller.updateLine(
      line,
      LineOptions(geometry: route.map(_latLng).toList()),
    );
  }

  @override
  Future<void> removePlannedRoute() async {
    final line = _plannedRoute;
    _plannedRoute = null;
    if (line != null) await controller.removeLine(line);
  }

  @override
  Future<void> addApproachRoute(List<MapPoint> route) async {
    final geoJson = _lineGeoJson(route);
    await controller.addGeoJsonSource(_approachSourceId, geoJson);
    await controller.addLineLayer(
      _approachSourceId,
      _approachLayerId,
      const LineLayerProperties(
        lineColor: '#D97706',
        lineWidth: 5,
        lineOpacity: 0.9,
        lineDasharray: [2, 2],
      ),
    );
    _approachRouteAdded = true;
  }

  @override
  Future<void> updateApproachRoute(List<MapPoint> route) async {
    if (!_approachRouteAdded) return addApproachRoute(route);
    await controller.setGeoJsonSource(_approachSourceId, _lineGeoJson(route));
  }

  @override
  Future<void> removeApproachRoute() async {
    if (!_approachRouteAdded) return;
    await controller.removeLayer(_approachLayerId);
    await controller.removeSource(_approachSourceId);
    _approachRouteAdded = false;
  }

  @override
  Future<void> addTrail(String id, List<MapPoint> trail) async {
    _trails[id] = await controller.addLine(
      LineOptions(
        geometry: trail.map(_latLng).toList(),
        lineColor: '#047857',
        lineWidth: 4,
        lineOpacity: 0.9,
      ),
    );
  }

  @override
  Future<void> updateTrail(String id, List<MapPoint> trail) async {
    final line = _trails[id];
    if (line == null) return addTrail(id, trail);
    await controller.updateLine(
      line,
      LineOptions(geometry: trail.map(_latLng).toList()),
    );
  }

  @override
  Future<void> removeTrail(String id) async {
    final line = _trails.remove(id);
    if (line != null) await controller.removeLine(line);
  }

  @override
  Future<void> addStop(
    String id,
    MapPoint point, {
    required bool pickup,
  }) async {
    _stops[id] = await controller.addCircle(
      CircleOptions(
        geometry: _latLng(point),
        circleColor: pickup ? '#16A34A' : '#DC2626',
        circleRadius: 8,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );
  }

  @override
  Future<void> removeStop(String id) async {
    final circle = _stops.remove(id);
    if (circle != null) await controller.removeCircle(circle);
  }

  @override
  Future<void> animateCamera(FleetCameraPlan plan) async {
    if (plan.points.isEmpty) return;
    if (plan.mode == FleetCameraMode.localTruck || plan.points.length == 1) {
      final target = _latLng(plan.points.first);
      await controller.animateCamera(
        plan.targetZoom == null
            ? CameraUpdate.newLatLng(target)
            : CameraUpdate.newLatLngZoom(target, plan.targetZoom!),
        duration: const Duration(milliseconds: 500),
      );
      return;
    }

    final latitudes = plan.points.map((point) => point.latitude);
    final longitudes = plan.points.map((point) => point.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );
    final panelPadding = plan.panelWidth.abs();
    final leftPadding = 48.0 + (plan.panelWidth < 0 ? panelPadding : 0.0);
    final rightPadding = 48.0 + (plan.panelWidth > 0 ? panelPadding : 0.0);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: leftPadding,
        top: 64,
        right: rightPadding,
        bottom: 64,
      ),
      duration: const Duration(milliseconds: 650),
    );
  }
}

VehicleVisualState _visualState(TruckMarkerModel truck) => VehicleVisualState(
  latitude: truck.point.latitude,
  longitude: truck.point.longitude,
  heading: truck.heading,
);

bool _sameVisual(VehicleVisualState left, VehicleVisualState right) =>
    (left.latitude - right.latitude).abs() < 0.0000001 &&
    (left.longitude - right.longitude).abs() < 0.0000001 &&
    (left.heading - right.heading).abs() < 0.0001;

TruckMarkerModel _withVisual(
  TruckMarkerModel source,
  VehicleVisualState visual,
) => TruckMarkerModel(
  id: source.id,
  point: MapPoint(visual.latitude, visual.longitude),
  heading: visual.heading,
  state: source.state,
  selected: source.selected,
  recordedAt: source.recordedAt,
  photoVersion: source.photoVersion,
  photoThumbnailUrl: source.photoThumbnailUrl,
);

Map<String, dynamic> _lineGeoJson(List<MapPoint> route) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {
        'type': 'LineString',
        'coordinates': route
            .map((point) => [point.longitude, point.latitude])
            .toList(),
      },
    },
  ],
};

LatLng _latLng(MapPoint point) => LatLng(point.latitude, point.longitude);
