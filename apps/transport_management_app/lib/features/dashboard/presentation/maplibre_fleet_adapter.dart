import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'fleet_map_coordinator.dart';

const truckMarkerAsset = 'assets/map/truck_top_down.png';
const truckMarkerImageName = 'tms-truck-top-down';
const truckMarkerHeadingOffset = 0.0;

double mapMarkerRotation(double trackingHeading) =>
    (trackingHeading + truckMarkerHeadingOffset) % 360;

SymbolOptions truckSymbolOptions(TruckMarkerModel truck) => SymbolOptions(
  geometry: _latLng(truck.point),
  iconImage: truckMarkerImageName,
  iconSize: truck.selected ? 0.82 : 0.70,
  iconRotate: mapMarkerRotation(truck.heading),
  iconAnchor: 'center',
  iconOpacity: switch (truck.state) {
    TruckMarkerState.offline => 0.5,
    TruckMarkerState.maintenance => 0.72,
    _ => 1,
  },
  zIndex: truck.selected ? 20 : 10,
);

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

final class MapLibreFleetAnnotationAdapter
    implements FleetMapAnnotationAdapter {
  MapLibreFleetAnnotationAdapter(this.controller);

  final MapLibreMapController controller;
  final Map<String, Symbol> _trucks = {};
  final Map<String, Circle> _statuses = {};
  final Map<String, Circle> _stops = {};
  Line? _plannedRoute;
  static const _approachSourceId = 'tms-approach-route-source';
  static const _approachLayerId = 'tms-approach-route-layer';
  bool _approachRouteAdded = false;
  final Map<String, Line> _trails = {};

  @override
  Future<void> prepareStyle() async {
    _trucks.clear();
    _statuses.clear();
    _stops.clear();
    _plannedRoute = null;
    _approachRouteAdded = false;
    _trails.clear();

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
    _trucks[truck.id] = await controller.addSymbol(
      truckSymbolOptions(truck),
      <String, dynamic>{'truckId': truck.id},
    );
  }

  @override
  Future<void> updateTruck(TruckMarkerModel truck) async {
    final symbol = _trucks[truck.id];
    if (symbol == null) return addTruck(truck);
    await controller.updateSymbol(symbol, truckSymbolOptions(truck));
  }

  @override
  Future<void> removeTruck(String truckId) async {
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
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_latLng(plan.points.first), 13.5),
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
    final horizontalPadding = 48 + plan.panelWidth;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: horizontalPadding,
        top: 64,
        right: horizontalPadding,
        bottom: 64,
      ),
      duration: const Duration(milliseconds: 650),
    );
  }
}

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
