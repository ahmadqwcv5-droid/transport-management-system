part of 'fleet_map.dart';

class _ConfiguredFleetMap extends StatefulWidget {
  const _ConfiguredFleetMap({
    required this.styleUrl,
    required this.positions,
    required this.onStyleLoaded,
    required this.onAnnotationsReady,
    required this.onFailure,
    required this.onTruckSelected,
    this.tripDetail,
    required this.showTrail,
    this.selectedTruckId,
    required this.cameraRevision,
    required this.cameraRequest,
    required this.thumbnailLoader,
    this.onManualCameraInteraction,
    super.key,
  });

  final String styleUrl;
  final List<TrackedTruck> positions;
  final VoidCallback onStyleLoaded;
  final VoidCallback onAnnotationsReady;
  final VoidCallback onFailure;
  final ValueChanged<TrackedTruck> onTruckSelected;
  final FleetTripDetail? tripDetail;
  final bool showTrail;
  final String? selectedTruckId;
  final int cameraRevision;
  final FleetCameraRequest cameraRequest;
  final VoidCallback? onManualCameraInteraction;
  final AuthenticatedThumbnailLoader thumbnailLoader;

  @override
  State<_ConfiguredFleetMap> createState() => _ConfiguredFleetMapState();
}

class _ConfiguredFleetMapState extends State<_ConfiguredFleetMap> {
  MapLibreMapController? _controller;
  FleetMapAnnotationCoordinator? _coordinator;
  void Function(Symbol)? _symbolTapListener;
  bool _styleLoaded = false;
  bool _programmaticCamera = false;
  Timer? _programmaticCameraRelease;

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
  Widget build(BuildContext context) => MapLibreMap(
    key: const Key('real-maplibre-map'),
    styleString: widget.styleUrl,
    initialCameraPosition: CameraPosition(
      target: widget.positions.isEmpty
          ? const LatLng(39.0, 35.0)
          : LatLng(
              widget.positions.first.latitude,
              widget.positions.first.longitude,
            ),
      zoom: widget.positions.isEmpty ? 4 : 11,
    ),
    annotationOrder: const [
      AnnotationType.line,
      AnnotationType.circle,
      AnnotationType.symbol,
    ],
    onMapCreated: (controller) {
      _controller = controller;
      _coordinator = FleetMapAnnotationCoordinator(
        MapLibreFleetAnnotationAdapter(controller, widget.thumbnailLoader),
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
    onCameraMove: (_) {
      if (_programmaticCamera) {
        _scheduleProgrammaticRelease();
      } else {
        widget.onManualCameraInteraction?.call();
      }
    },
    onCameraIdle: _scheduleProgrammaticRelease,
    onStyleLoadedCallback: () async {
      if (!mounted) return;
      _styleLoaded = true;
      widget.onStyleLoaded();
      try {
        _beginProgrammaticCamera();
        await _coordinator?.onStyleLoaded(_snapshot(), panelWidth: 290);
        if (mounted) widget.onAnnotationsReady();
      } on Object {
        if (mounted) widget.onFailure();
      }
    },
  );

  Future<void> _synchronize({required FleetCameraRequest cameraRequest}) async {
    final coordinator = _coordinator;
    if (coordinator == null || !_styleLoaded || !mounted) return;
    try {
      if (cameraRequest != FleetCameraRequest.none) _beginProgrammaticCamera();
      await coordinator.synchronize(
        _snapshot(),
        cameraRequest: cameraRequest,
        panelWidth: 290,
      );
    } on Object {
      _programmaticCameraRelease?.cancel();
      _programmaticCamera = false;
      if (mounted) widget.onFailure();
    }
  }

  void _beginProgrammaticCamera() {
    _programmaticCameraRelease?.cancel();
    _programmaticCamera = true;
  }

  void _scheduleProgrammaticRelease() {
    if (!_programmaticCamera) return;
    _programmaticCameraRelease?.cancel();
    _programmaticCameraRelease = Timer(
      const Duration(milliseconds: 750),
      () => _programmaticCamera = false,
    );
  }

  FleetMapSnapshot _snapshot() {
    final trucks = widget.positions.map(
      (position) => TruckMarkerModel(
        id: position.truckId,
        point: MapPoint(position.latitude, position.longitude),
        heading: position.heading,
        state: TruckMarkerModel.stateFor(position),
        selected: position.truckId == widget.selectedTruckId,
        photoVersion: position.photoVersion,
        photoThumbnailUrl: position.photoThumbnailUrl,
      ),
    );
    final detail = widget.tripDetail;
    final selected = widget.positions
        .where((position) => position.truckId == widget.selectedTruckId)
        .firstOrNull;
    return FleetMapSnapshot(
      trucks: trucks,
      selectedTruckId: widget.selectedTruckId,
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
