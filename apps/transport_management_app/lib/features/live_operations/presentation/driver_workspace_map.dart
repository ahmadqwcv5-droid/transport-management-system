import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../dashboard/presentation/circular_marker_image.dart';
import '../../dashboard/presentation/fleet_map_coordinator.dart';
import '../../dashboard/presentation/maplibre_fleet_adapter.dart';
import '../../../l10n/l10n_extensions.dart';
import '../domain/live_operations_models.dart';
import 'latest_wins_map_synchronizer.dart';

typedef DriverPhotoLoader = Future<Uint8List> Function(String url);

class DriverWorkspaceMap extends StatefulWidget {
  const DriverWorkspaceMap({
    required this.workspace,
    required this.styleUrl,
    required this.photoLoader,
    super.key,
  });
  final DriverWorkspace workspace;
  final String styleUrl;
  final DriverPhotoLoader photoLoader;

  @override
  State<DriverWorkspaceMap> createState() => _DriverWorkspaceMapState();
}

class _DriverWorkspaceMapState extends State<DriverWorkspaceMap> {
  final _processor = const CircularMarkerImageProcessor();
  MapLibreMapController? _controller;
  Symbol? _truck;
  Line? _route;
  Line? _approach;
  final List<Circle> _stops = [];
  final Set<String> _images = {};
  bool _styleLoaded = false;
  bool _failed = false;
  bool _updateWarning = false;
  int _mapGeneration = 0;
  late final LatestWinsMapSynchronizer _synchronizer;
  FleetInteractionMode _cameraMode = FleetInteractionMode.followSelectedTruck;

  @override
  void initState() {
    super.initState();
    _synchronizer = LatestWinsMapSynchronizer(
      onFailure: (_) {
        if (mounted && !_updateWarning) {
          setState(() => _updateWarning = true);
        }
      },
      onRecovered: () {
        if (mounted && _updateWarning) {
          setState(() => _updateWarning = false);
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant DriverWorkspaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) _requestSync();
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.workspace.currentPosition;
    final next = widget.workspace.nextStop;
    final nextHasCoordinates =
        next?.latitude != null && next?.longitude != null;
    if (widget.styleUrl.isEmpty || (position == null && !nextHasCoordinates)) {
      return DecoratedBox(
        key: const Key('driver-map-unavailable'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.styleUrl.isEmpty
                  ? context.l10n.mapNotConfigured
                  : context.l10n.truckPositionRequiredGuidance,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_failed) {
      return DecoratedBox(
        key: const Key('driver-map-load-failed'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 52),
              const SizedBox(height: 8),
              Text(context.l10n.mapFailed, textAlign: TextAlign.center),
              TextButton.icon(
                key: const Key('driver-map-retry'),
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retryMap),
              ),
            ],
          ),
        ),
      );
    }
    final target = position == null
        ? LatLng(next!.latitude!, next.longitude!)
        : LatLng(position.latitude, position.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Listener(
        key: const Key('driver-map-input-listener'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (_cameraMode != FleetInteractionMode.free) {
            setState(() => _cameraMode = FleetInteractionMode.free);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                key: ValueKey('driver-workspace-map-$_mapGeneration'),
                styleString: widget.styleUrl,
                initialCameraPosition: CameraPosition(
                  target: target,
                  zoom: 13.5,
                ),
                annotationOrder: const [
                  AnnotationType.line,
                  AnnotationType.circle,
                  AnnotationType.symbol,
                ],
                onMapCreated: (controller) => _controller = controller,
                onStyleLoadedCallback: () async {
                  try {
                    _styleLoaded = true;
                    final controller = _controller;
                    if (controller == null) return;
                    final fallback = await rootBundle.load(truckMarkerAsset);
                    await controller.addImage(
                      truckMarkerImageName,
                      fallback.buffer.asUint8List(
                        fallback.offsetInBytes,
                        fallback.lengthInBytes,
                      ),
                    );
                    if (mounted) setState(() {});
                    _requestSync();
                  } on Object {
                    _markFailed();
                  }
                },
              ),
            ),
            if (!_styleLoaded)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.82),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(context.l10n.mapLoading),
                    ),
                  ),
                ),
              ),
            if (_updateWarning)
              PositionedDirectional(
                start: 12,
                end: 12,
                bottom: 12,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      context.l10n.mapUpdateWarning,
                      key: const Key('driver-map-update-warning'),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              top: 12,
              end: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    key: const Key('driver-map-follow'),
                    heroTag: 'driver-map-follow',
                    onPressed: _followTruck,
                    child: Icon(
                      _cameraMode == FleetInteractionMode.followSelectedTruck
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    key: const Key('driver-map-route-overview'),
                    heroTag: 'driver-map-route-overview',
                    onPressed: _routeOverview,
                    child: const Icon(Icons.zoom_out_map),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requestSync() {
    _synchronizer.schedule(_sync);
  }

  void _markFailed() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  void _retry() {
    setState(() {
      _controller = null;
      _truck = null;
      _route = null;
      _approach = null;
      _stops.clear();
      _images.clear();
      _styleLoaded = false;
      _failed = false;
      _updateWarning = false;
      _mapGeneration++;
    });
  }

  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !mounted) return;
    final position = widget.workspace.currentPosition;
    final truck = widget.workspace.truck;
    if (position != null && truck != null) {
      var imageName = truckMarkerImageName;
      final photoUrl = truck.photoThumbnailUrl;
      final photoVersion = truck.photoVersion;
      if (photoUrl != null && photoVersion != null) {
        final candidate = truckPhotoMarkerImageName(truck.id, photoVersion);
        try {
          if (_images.add(candidate)) {
            final source = await widget.photoLoader(photoUrl);
            await controller.addImage(
              candidate,
              await _processor.process(source),
            );
          }
          imageName = candidate;
        } on Object {
          _images.remove(candidate);
        }
      }
      final options = SymbolOptions(
        geometry: LatLng(position.latitude, position.longitude),
        iconImage: imageName,
        iconSize: imageName == truckMarkerImageName ? 0.7 : 0.78,
        iconRotate: imageName == truckMarkerImageName ? position.heading : 0,
        iconAnchor: 'center',
      );
      if (_truck == null) {
        _truck = await controller.addSymbol(options);
      } else {
        await controller.updateSymbol(_truck!, options);
      }
      if (_cameraMode == FleetInteractionMode.followSelectedTruck) {
        await controller.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    }

    final status = widget.workspace.currentTrip?.status;
    final cargo = status == 'EnRouteToPickup' || status == 'AtPickup'
        ? const <LatLng>[]
        : widget.workspace.activeRoute?.coordinates
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList() ??
              const [];
    final approach = status == 'Assigned' || status == 'EnRouteToPickup'
        ? widget.workspace.approachRoute?.route.coordinates
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList() ??
              const []
        : const <LatLng>[];
    _route = await _syncLine(_route, cargo, '#175CD3');
    _approach = await _syncLine(_approach, approach, '#D97706');

    if (_stops.isEmpty) {
      for (final stop in widget.workspace.currentTrip?.stops ?? const []) {
        if (!stop.hasCoordinates) continue;
        _stops.add(
          await controller.addCircle(
            CircleOptions(
              geometry: LatLng(stop.latitude!, stop.longitude!),
              circleRadius: stop.type == 'Pickup' ? 8 : 9,
              circleColor: stop.type == 'Pickup' ? '#16A34A' : '#DC2626',
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2,
            ),
          ),
        );
      }
    }
  }

  Future<void> _followTruck() async {
    setState(() => _cameraMode = FleetInteractionMode.followSelectedTruck);
    final position = widget.workspace.currentPosition;
    if (position != null) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          13.5,
        ),
      );
    }
  }

  Future<void> _routeOverview() async {
    setState(() => _cameraMode = FleetInteractionMode.routeOverview);
    final points = <LatLng>[
      ...?widget.workspace.activeRoute?.coordinates.map(
        (point) => LatLng(point.latitude, point.longitude),
      ),
      ...?widget.workspace.approachRoute?.route.coordinates.map(
        (point) => LatLng(point.latitude, point.longitude),
      ),
    ];
    if (points.length >= 2) {
      final latitudes = points.map((point) => point.latitude);
      final longitudes = points.map((point) => point.longitude);
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
      await _controller?.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 42,
          top: 42,
          right: 42,
          bottom: 42,
        ),
      );
    }
  }

  Future<Line?> _syncLine(Line? line, List<LatLng> points, String color) async {
    final controller = _controller!;
    if (points.length < 2) {
      if (line != null) await controller.removeLine(line);
      return null;
    }
    if (line == null) {
      return controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: color,
          lineWidth: 5,
          lineOpacity: 0.9,
        ),
      );
    }
    await controller.updateLine(line, LineOptions(geometry: points));
    return line;
  }
}
