import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/maps/locale_aware_map_style.dart';
import '../../../core/maps/map_camera_movement_classifier.dart';
import '../../../core/maps/map_interaction_controller.dart';
import '../../../core/maps/vehicle_motion_interpolator.dart';
import '../../dashboard/presentation/fleet_map.dart';
import '../../dashboard/presentation/circular_marker_image.dart';
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
  late final MapInteractionController _camera;
  String? _resolvedStyle;
  String? _styleLocale;
  int _styleResolution = 0;
  final _cameraMovement = MapCameraMovementClassifier();
  bool _programmaticCamera = false;
  Timer? _programmaticCameraRelease;

  VehicleMotionInterpolator _motion = VehicleMotionInterpolator();
  int _motionRevision = 0;
  DateTime? _lastRecordedAt;
  @override
  void initState() {
    super.initState();
    _camera = MapInteractionController(
      initialMode: FleetInteractionMode.followVehicle,
    );
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
  void dispose() {
    _programmaticCameraRelease?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_styleLocale == locale && _resolvedStyle != null) return;
    _styleLocale = locale;
    _resolveStyle(locale);
  }

  Future<void> _resolveStyle(String locale) async {
    if (widget.styleUrl.trim().isEmpty) return;
    final generation = ++_styleResolution;
    try {
      final style = await LocaleAwareMapStyle.resolve(widget.styleUrl, locale);
      if (!mounted || generation != _styleResolution) return;
      setState(() {
        _programmaticCameraRelease?.cancel();
        _programmaticCamera = false;
        _cameraMovement.reset();
        _resolvedStyle = style;
        _controller = null;
        _truck = null;
        _motionRevision++;
        _motion = VehicleMotionInterpolator();
        _lastRecordedAt = null;
        _route = null;
        _approach = null;
        _stops.clear();
        _images.clear();
        _styleLoaded = false;
        _failed = false;
        _mapGeneration++;
      });
    } on Object {
      if (mounted && generation == _styleResolution) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant DriverWorkspaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) _requestSync();
    if (oldWidget.styleUrl != widget.styleUrl) {
      _resolvedStyle = null;
      _resolveStyle(_styleLocale ?? 'en');
    }
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
    if (_resolvedStyle == null) {
      return const Center(
        key: Key('driver-map-style-resolving'),
        child: CircularProgressIndicator(),
      );
    }
    final target = position == null
        ? LatLng(next!.latitude!, next.longitude!)
        : LatLng(position.latitude, position.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ManualMapInteractionListener(
        key: const Key('driver-map-input-listener'),
        onPan: () {
          if (_camera.mode != FleetInteractionMode.freeExplore) {
            setState(_camera.userPan);
          }
        },
        onZoom: _camera.userZoom,
        child: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                key: ValueKey('driver-workspace-map-$_mapGeneration'),
                styleString: _resolvedStyle!,
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
                onCameraMove: _handleCameraMove,
                onCameraIdle: _scheduleProgrammaticRelease,
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
                  } on Object catch (error) {
                    debugPrint(
                      'DriverWorkspaceMap recoverable annotation error: '
                      'operation=initial-style-overlay '
                      'tripId=${widget.workspace.currentTrip?.id} '
                      'phase=${widget.workspace.currentTrip?.status} '
                      'exception=${error.runtimeType}: $error',
                    );
                    if (mounted) setState(() => _updateWarning = true);
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
                      _camera.followsVehicle
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

  void _beginProgrammaticCamera() {
    _programmaticCameraRelease?.cancel();
    _programmaticCamera = true;
    _scheduleProgrammaticRelease();
  }

  void _scheduleProgrammaticRelease() {
    if (!_programmaticCamera) return;
    _programmaticCameraRelease?.cancel();
    _programmaticCameraRelease = Timer(
      const Duration(milliseconds: 750),
      () => _programmaticCamera = false,
    );
  }

  void _handleCameraMove(CameraPosition position) {
    if (_programmaticCamera) _scheduleProgrammaticRelease();
    final movement = _cameraMovement.observe(
      MapCameraView(
        latitude: position.target.latitude,
        longitude: position.target.longitude,
        zoom: position.zoom,
        bearing: position.bearing,
        tilt: position.tilt,
      ),
      programmatic: _programmaticCamera,
    );
    switch (movement) {
      case MapCameraMovement.none:
        return;
      case MapCameraMovement.zoom:
        _camera.userZoom();
        return;
      case MapCameraMovement.explore:
        if (_camera.mode != FleetInteractionMode.freeExplore && mounted) {
          setState(_camera.userPan);
        }
        return;
    }
  }

  void _requestSync() {
    _synchronizer.schedule(_sync);
  }

  void _retry() {
    setState(() {
      _programmaticCameraRelease?.cancel();
      _programmaticCamera = false;
      _cameraMovement.reset();
      _controller = null;
      _truck = null;
      _route = null;
      _approach = null;
      _stops.clear();
      _motionRevision++;
      _motion = VehicleMotionInterpolator();
      _lastRecordedAt = null;
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
      await _retargetTruck(controller, position, imageName);
      if (_camera.followsVehicle) {
        _beginProgrammaticCamera();
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

  Future<void> _retargetTruck(
    MapLibreMapController controller,
    DriverWorkspacePosition position,
    String imageName,
  ) async {
    final target = VehicleVisualState(
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading,
    );
    final recordedAt = DateTime.tryParse(position.recordedAt);
    final previousRecordedAt = _lastRecordedAt;
    final sampleGap = recordedAt == null || previousRecordedAt == null
        ? null
        : recordedAt.difference(previousRecordedAt).abs();
    _lastRecordedAt = recordedAt;
    if (_truck == null) {
      _motion.retarget(target: target, now: DateTime.now(), animate: false);
      _truck = await controller.addSymbol(
        _driverTruckOptions(target, imageName),
      );
      return;
    }

    _motion.retarget(
      target: target,
      now: DateTime.now(),
      sampleGap: sampleGap,
      animate:
          position.isOnline &&
          widget.workspace.trackingState == 'Current' &&
          position.speed > 0.5,
    );
    final revision = _motion.revision;
    _motionRevision = revision;
    final generation = _mapGeneration;
    unawaited(() async {
      try {
        while (mounted &&
            generation == _mapGeneration &&
            revision == _motionRevision) {
          final visual = _motion.sample(DateTime.now());
          if (visual == null || _truck == null) return;
          await controller.updateSymbol(
            _truck!,
            _driverTruckOptions(visual, imageName),
          );
          if ((visual.latitude - target.latitude).abs() < 0.0000001 &&
              (visual.longitude - target.longitude).abs() < 0.0000001 &&
              (visual.heading - target.heading).abs() < 0.0001) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      } on Object {
        // A style swap invalidates the old annotation; the new style resyncs it.
      }
    }());
  }

  SymbolOptions _driverTruckOptions(
    VehicleVisualState visual,
    String imageName,
  ) => SymbolOptions(
    geometry: LatLng(visual.latitude, visual.longitude),
    iconImage: imageName,
    iconSize: imageName == truckMarkerImageName ? 0.7 : 0.78,
    iconRotate: imageName == truckMarkerImageName ? visual.heading : 0,
    iconAnchor: 'center',
  );

  Future<void> _followTruck() async {
    setState(_camera.followVehicle);
    final position = widget.workspace.currentPosition;
    if (position != null) {
      _beginProgrammaticCamera();
      await _controller?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    }
  }

  Future<void> _routeOverview() async {
    setState(_camera.routeOverview);
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
      _beginProgrammaticCamera();
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
