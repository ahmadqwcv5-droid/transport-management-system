part of 'fleet_map.dart';

/// Classifies physical zoom separately from deliberate single-pointer panning.
class ManualMapInteractionListener extends StatefulWidget {
  const ManualMapInteractionListener({
    required this.child,
    required this.onPan,
    required this.onZoom,
    super.key,
  });

  final Widget child;
  final VoidCallback onPan, onZoom;

  @override
  State<ManualMapInteractionListener> createState() =>
      _ManualMapInteractionListenerState();
}

class _ManualMapInteractionListenerState
    extends State<ManualMapInteractionListener> {
  final Map<int, Offset> _pointers = {};
  bool _panReported = false;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      _pointers[event.pointer] = event.position;
      if (_pointers.length == 1) _panReported = false;
    },
    onPointerMove: (event) {
      final previous = _pointers[event.pointer];
      _pointers[event.pointer] = event.position;
      if (_pointers.length != 1 || previous == null || _panReported) return;
      if ((event.position - previous).distance >= 4) {
        _panReported = true;
        widget.onPan();
      }
    },
    onPointerUp: (event) => _pointers.remove(event.pointer),
    onPointerCancel: (event) => _pointers.remove(event.pointer),
    onPointerSignal: (_) => widget.onZoom(),
    child: widget.child,
  );
}

class _ConfiguredFleetMap extends StatefulWidget {
  const _ConfiguredFleetMap({
    required this.styleUrl,
    required this.positions,
    this.operationalArea,
    required this.onStyleLoaded,
    required this.onAnnotationsReady,
    required this.onFailure,
    required this.onAnnotationFailure,
    required this.onAnnotationsRecovered,
    required this.onTruckSelected,
    this.tripDetail,
    required this.showTrail,
    this.selectedTruckId,
    required this.cameraRevision,
    required this.cameraRequest,
    required this.thumbnailLoader,
    this.telemetry,
    this.onManualCameraInteraction,
    this.onManualCameraZoom,
    super.key,
  });

  final String styleUrl;
  final List<TrackedTruck> positions;
  final OperationalArea? operationalArea;
  final VoidCallback onStyleLoaded;
  final VoidCallback onAnnotationsReady;
  final VoidCallback onFailure;
  final void Function(Object error, String operation) onAnnotationFailure;
  final VoidCallback onAnnotationsRecovered;
  final ValueChanged<TrackedTruck> onTruckSelected;
  final FleetTripDetail? tripDetail;
  final bool showTrail;
  final String? selectedTruckId;
  final int cameraRevision;
  final FleetCameraRequest cameraRequest;
  final VoidCallback? onManualCameraInteraction;
  final VoidCallback? onManualCameraZoom;
  final AuthenticatedThumbnailLoader thumbnailLoader;
  final MapOperationTelemetry? telemetry;

  @override
  State<_ConfiguredFleetMap> createState() => _ConfiguredFleetMapState();
}

class _ConfiguredFleetMapState extends State<_ConfiguredFleetMap> {
  MapLibreMapController? _controller;
  FleetMapAnnotationCoordinator? _coordinator;
  bool _hasCompletedStyleLoad = false;
  void Function(Symbol)? _symbolTapListener;
  bool _styleLoaded = false;
  bool _programmaticCamera = false;
  Timer? _programmaticCameraRelease;
  final _cameraMovement = MapCameraMovementClassifier();

  @override
  void initState() {
    super.initState();
    widget.telemetry?.mapInstancesCreated++;
  }

  @override
  void didUpdateWidget(covariant _ConfiguredFleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleLoaded) return;
    _synchronize(
      cameraRequest: oldWidget.cameraRevision == widget.cameraRevision
          ? FleetCameraRequest.none
          : widget.cameraRequest,
    );
  }

  @override
  void dispose() {
    widget.telemetry?.mapInstancesDisposed++;
    _programmaticCameraRelease?.cancel();
    _coordinator?.dispose();
    final controller = _controller;
    final listener = _symbolTapListener;
    if (controller != null && listener != null) {
      controller.onSymbolTapped.remove(listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManualMapInteractionListener(
    key: const Key('fleet-map-input-listener'),
    onPan: () => widget.onManualCameraInteraction?.call(),
    onZoom: () => widget.onManualCameraZoom?.call(),
    child: MapLibreMap(
      key: const Key('real-maplibre-map'),
      styleString: widget.styleUrl,
      initialCameraPosition: CameraPosition(
        target: widget.positions.isEmpty
            ? LatLng(
                widget.operationalArea?.centerLatitude ??
                    (widget.operationalArea == null
                        ? FleetMap._fallbackLatitude
                        : (widget.operationalArea!.south +
                                  widget.operationalArea!.north) /
                              2),
                widget.operationalArea?.centerLongitude ??
                    (widget.operationalArea == null
                        ? FleetMap._fallbackLongitude
                        : (widget.operationalArea!.west +
                                  widget.operationalArea!.east) /
                              2),
              )
            : LatLng(
                widget.positions.first.latitude,
                widget.positions.first.longitude,
              ),
        zoom: widget.positions.isEmpty
            ? widget.operationalArea?.preferredZoom ?? FleetMap._fallbackZoom
            : 11,
      ),
      annotationOrder: const [
        AnnotationType.line,
        AnnotationType.circle,
        AnnotationType.symbol,
      ],
      onMapCreated: (controller) {
        _controller = controller;
        _coordinator = FleetMapAnnotationCoordinator(
          MapLibreFleetAnnotationAdapter(
            controller,
            widget.thumbnailLoader,
            telemetry: widget.telemetry,
          ),
          telemetry: widget.telemetry,
        );
        void listener(Symbol symbol) {
          final truckId = symbol.data?['truckId'] as String?;
          final position = widget.positions
              .where((item) => item.truckId == truckId)
              .firstOrNull;
          if (position != null && mounted) widget.onTruckSelected(position);
        }

        _symbolTapListener = listener;
        controller.onSymbolTapped.add(listener);
      },
      onCameraMove: _handleCameraMove,
      onCameraIdle: _scheduleProgrammaticRelease,
      onStyleLoadedCallback: () async {
        if (!mounted) return;
        _cameraMovement.reset();
        _styleLoaded = true;
        widget.telemetry?.styleLoads++;
        widget.onStyleLoaded();
        try {
          final cameraRequest = _hasCompletedStyleLoad
              ? FleetCameraRequest.none
              : FleetCameraRequest.initialFleet;
          if (cameraRequest != FleetCameraRequest.none) {
            _beginProgrammaticCamera();
          }
          await _coordinator?.onStyleLoaded(
            _snapshot(),
            cameraRequest: cameraRequest,
            panelWidth: _directionalPanelWidth(),
          );
          _hasCompletedStyleLoad = true;
          if (mounted) widget.onAnnotationsReady();
        } on Object catch (error) {
          if (mounted) {
            widget.onAnnotationFailure(error, 'initial-style-overlay');
          }
        }
      },
    ),
  );

  Future<void> _synchronize({required FleetCameraRequest cameraRequest}) async {
    final coordinator = _coordinator;
    if (coordinator == null || !_styleLoaded || !mounted) return;
    try {
      if (cameraRequest != FleetCameraRequest.none) _beginProgrammaticCamera();
      await coordinator.synchronize(
        _snapshot(),
        cameraRequest: cameraRequest,
        panelWidth: _directionalPanelWidth(),
      );
      if (mounted) widget.onAnnotationsRecovered();
    } on Object catch (error) {
      _programmaticCameraRelease?.cancel();
      _programmaticCamera = false;
      if (mounted) widget.onAnnotationFailure(error, 'incremental-sync');
    }
  }

  double _directionalPanelWidth() =>
      Directionality.of(context) == TextDirection.rtl ? 290 : -290;

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
        widget.onManualCameraZoom?.call();
        return;
      case MapCameraMovement.explore:
        widget.onManualCameraInteraction?.call();
        return;
    }
  }

  FleetMapSnapshot _snapshot() {
    final trucks = widget.positions.map(
      (position) => TruckMarkerModel(
        id: position.truckId,
        point: MapPoint(position.latitude, position.longitude),
        heading: position.heading,
        state: TruckMarkerModel.stateFor(position),
        selected: position.truckId == widget.selectedTruckId,
        recordedAt: DateTime.tryParse(position.recordedAt),
        photoVersion: position.photoVersion,
        photoThumbnailUrl: position.photoThumbnailUrl,
      ),
    );
    final detail = widget.tripDetail;
    final selected = widget.positions
        .where((position) => position.truckId == widget.selectedTruckId)
        .firstOrNull;
    final area = widget.operationalArea;
    final overviewPoints = <MapPoint>[
      if (area != null) ...[
        MapPoint(area.south, area.west),
        MapPoint(area.south, area.east),
        MapPoint(area.north, area.west),
        MapPoint(area.north, area.east),
      ],
      ...widget.positions
          .where((position) => position.isOnline)
          .map((position) => MapPoint(position.latitude, position.longitude)),
    ];
    return FleetMapSnapshot(
      trucks: trucks,
      selectedTruckId: widget.selectedTruckId,
      overviewPoints: overviewPoints,
      route: detail == null
          ? null
          : RouteOverlayModel(
              tripId: selected?.currentTripId ?? 'selected-trip',
              route: detail.route.coordinates
                  .map((point) => MapPoint(point.latitude, point.longitude))
                  .toList(),
              approachRoute:
                  detail.approachRoute?.coordinates
                      .map((point) => MapPoint(point.latitude, point.longitude))
                      .toList() ??
                  const [],
              trails: widget.showTrail
                  ? detail.trail
                        .map(
                          (segment) => TrailSegmentModel(
                            id: segment.id,
                            points: segment.points
                                .map(
                                  (point) =>
                                      MapPoint(point.latitude, point.longitude),
                                )
                                .toList(),
                          ),
                        )
                        .toList()
                  : const [],
            ),
    );
  }
}
