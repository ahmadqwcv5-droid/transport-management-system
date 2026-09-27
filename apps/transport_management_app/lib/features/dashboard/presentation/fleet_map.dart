import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/maps/locale_aware_map_style.dart';
import '../../../core/maps/map_camera_movement_classifier.dart';
import '../../../core/maps/map_interaction_controller.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../shared/widgets/truck_avatar.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';
import 'fleet_map_coordinator.dart';
import 'maplibre_fleet_adapter.dart';

part 'fleet_map_adapter.dart';
part 'fleet_map_panels.dart';

enum FleetMapMode { unconfigured, loading, loaded, failed, fallback }

typedef FleetMapBuilder =
    Widget Function({
      required Key key,
      required String styleUrl,
      required List<TrackedTruck> positions,
      required VoidCallback onStyleLoaded,
      required VoidCallback onAnnotationsReady,
      required VoidCallback onFailure,
      required ValueChanged<TrackedTruck> onTruckSelected,
    });

class FleetMap extends ConsumerStatefulWidget {
  const FleetMap({
    required this.positions,
    this.operationalArea,
    this.styleUrlOverride,
    this.loadingTimeoutOverride,
    this.mapBuilder,
    this.telemetry,
    super.key,
  });

  static const configuredStyleUrl = String.fromEnvironment('MAP_STYLE_URL');
  static const _configuredTimeoutSeconds = int.fromEnvironment(
    'MAP_LOADING_TIMEOUT_SECONDS',
    defaultValue: 12,
  );
  static final double _fallbackLatitude =
      double.tryParse(const String.fromEnvironment('MAP_FALLBACK_LATITUDE')) ??
      20;
  static final double _fallbackLongitude =
      double.tryParse(const String.fromEnvironment('MAP_FALLBACK_LONGITUDE')) ??
      0;
  static final double _fallbackZoom =
      double.tryParse(const String.fromEnvironment('MAP_FALLBACK_ZOOM')) ?? 2;

  final List<TrackedTruck> positions;
  final OperationalArea? operationalArea;
  final String? styleUrlOverride;
  final Duration? loadingTimeoutOverride;
  final FleetMapBuilder? mapBuilder;
  final MapOperationTelemetry? telemetry;

  @override
  ConsumerState<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends ConsumerState<FleetMap> {
  late FleetMapMode _mode;
  Timer? _loadingTimer;
  int _attempt = 0;
  int _rendererGeneration = 0;
  bool _onlineOnly = false;
  bool _movingOnly = false;
  bool _showTrail = true;
  String? _selectedTruckId;
  FleetTripDetail? _tripDetail;
  bool _loadingDetail = false;
  int _cameraRevision = 0;
  FleetCameraRequest _cameraRequest = FleetCameraRequest.none;
  late final MapInteractionController _camera;
  ({TrackedTruck truck, bool fitCamera})? _pendingDetailRefresh;
  bool _detailRefreshRunning = false;
  String? _resolvedStyle;
  String? _styleLocale;
  int _styleResolution = 0;
  bool _annotationWarning = false;

  List<TrackedTruck> get _visiblePositions => widget.positions.where((item) {
    if (_onlineOnly && !item.isOnline) return false;
    if (_movingOnly && item.speed <= 0) return false;
    return true;
  }).toList();

  TrackedTruck? get _selected => widget.positions
      .where((item) => item.truckId == _selectedTruckId)
      .firstOrNull;

  int get _outsideAreaCount {
    final area = widget.operationalArea;
    if (area == null) return 0;
    return widget.positions
        .where(
          (item) =>
              item.isOnline && !area.contains(item.latitude, item.longitude),
        )
        .length;
  }

  String get _configuredStyle =>
      widget.styleUrlOverride ?? FleetMap.configuredStyleUrl;
  String get _styleUrl => _resolvedStyle ?? _configuredStyle;
  Duration get _loadingTimeout =>
      widget.loadingTimeoutOverride ??
      Duration(
        seconds: FleetMap._configuredTimeoutSeconds > 0
            ? FleetMap._configuredTimeoutSeconds
            : 12,
      );

  @override
  void initState() {
    super.initState();
    _camera = MapInteractionController();
    _mode = _configuredStyle.trim().isEmpty
        ? FleetMapMode.unconfigured
        : FleetMapMode.loading;
    if (_mode == FleetMapMode.loading) _armTimeout();
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
    if (widget.mapBuilder != null || _configuredStyle.trim().isEmpty) {
      _resolvedStyle = _configuredStyle;
      return;
    }
    final generation = ++_styleResolution;
    try {
      final style = await LocaleAwareMapStyle.resolve(_configuredStyle, locale);
      if (!mounted || generation != _styleResolution) return;
      setState(() {
        _resolvedStyle = style;
        _attempt++;
        _mode = FleetMapMode.loading;
      });
      _armTimeout();
    } on Object catch (_) {
      if (mounted && generation == _styleResolution) _onFailure(_attempt);
    }
  }

  @override
  void didUpdateWidget(covariant FleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStyle = oldWidget.styleUrlOverride ?? FleetMap.configuredStyleUrl;
    if (oldStyle != _configuredStyle) {
      _resolvedStyle = null;
      if (_configuredStyle.trim().isEmpty) {
        _loadingTimer?.cancel();
        setState(() {
          _mode = FleetMapMode.unconfigured;
        });
      } else {
        _resolveStyle(_styleLocale ?? 'en');
      }
    }
    final selectedId = _selectedTruckId;
    if (selectedId != null) {
      final oldSelected = oldWidget.positions
          .where((item) => item.truckId == selectedId)
          .firstOrNull;
      final currentSelected = widget.positions
          .where((item) => item.truckId == selectedId)
          .firstOrNull;
      if (currentSelected?.currentTripId != null &&
          (oldSelected?.recordedAt != currentSelected!.recordedAt ||
              oldSelected?.currentTripId != currentSelected.currentTripId)) {
        _queueDetailRefresh(currentSelected, fitCamera: false);
      }
      final selectedMoved =
          oldSelected == null ||
          currentSelected == null ||
          oldSelected.latitude != currentSelected.latitude ||
          oldSelected.longitude != currentSelected.longitude;
      if (_camera.followsVehicle && selectedMoved && currentSelected != null) {
        setState(() {
          _cameraRevision++;
          _cameraRequest = FleetCameraRequest.recenter;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _pendingDetailRefresh = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 430,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.fleetMap,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilterChip(
                  label: Text(context.l10n.onlineOnly),
                  selected: _onlineOnly,
                  onSelected: (value) => _setFilter(onlineOnly: value),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.l10n.movingOnly),
                  selected: _movingOnly,
                  onSelected: (value) => _setFilter(movingOnly: value),
                ),
              ],
            ),
          ),
          Expanded(child: _buildState(context)),
        ],
      ),
    ),
  );

  Widget _buildState(BuildContext context) => switch (_mode) {
    FleetMapMode.unconfigured => _MessageState(
      key: const Key('map-status-unconfigured'),
      icon: Icons.map_outlined,
      message: context.l10n.mapNotConfigured,
      actions: [
        FilledButton.tonal(
          key: const Key('map-use-fallback'),
          onPressed: _useFallback,
          child: Text(context.l10n.useFallback),
        ),
      ],
    ),
    FleetMapMode.failed => _MessageState(
      key: const Key('map-status-failed'),
      icon: Icons.map_outlined,
      message: context.l10n.mapFailed,
      actions: [
        FilledButton(
          key: const Key('map-retry'),
          onPressed: _retry,
          child: Text(context.l10n.retryMap),
        ),
        OutlinedButton(
          key: const Key('map-use-fallback'),
          onPressed: _useFallback,
          child: Text(context.l10n.useFallback),
        ),
      ],
    ),
    FleetMapMode.fallback => Stack(
      fit: StackFit.expand,
      children: [
        _FallbackMap(
          positions: _visiblePositions,
          onTruckSelected: _selectTruck,
        ),
        if (_selected != null)
          PositionedDirectional(
            end: 12,
            top: 12,
            child: _SelectedTruckCard(
              position: _selected!,
              detail: _tripDetail,
              loading: _loadingDetail,
              onClose: _clearSelection,
              onRecenter: _recenter,
            ),
          ),
      ],
    ),
    FleetMapMode.loading || FleetMapMode.loaded => _buildRealMap(context),
  };

  Widget _buildRealMap(BuildContext context) {
    final attempt = _attempt;
    if (widget.mapBuilder == null && _resolvedStyle == null) {
      return Center(
        key: const Key('map-style-resolving'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.l10n.loadingMap),
          ],
        ),
      );
    }
    final map = widget.mapBuilder == null
        ? _productionMapBuilder(
            key: ValueKey('maplibre-renderer-$_rendererGeneration'),
            styleUrl: _styleUrl,
            positions: _visiblePositions,
            operationalArea: widget.operationalArea,
            onStyleLoaded: () => _onStyleLoaded(attempt),
            onAnnotationsReady: () => _onAnnotationsReady(attempt),
            onFailure: () => _onFailure(attempt),
            onAnnotationFailure: _onAnnotationFailure,
            onAnnotationsRecovered: _onAnnotationsRecovered,
            onTruckSelected: _selectTruck,
            tripDetail: _tripDetail,
            showTrail: _showTrail,
            selectedTruckId: _selectedTruckId,
            cameraRevision: _cameraRevision,
            cameraRequest: _cameraRequest,
            onManualCameraInteraction: _pauseFollow,
            onManualCameraZoom: _camera.userZoom,
            thumbnailLoader: ref
                .read(dashboardRepositoryProvider)
                .authenticatedImage,
            telemetry: widget.telemetry,
          )
        : widget.mapBuilder!(
            key: ValueKey('maplibre-renderer-$_rendererGeneration'),
            styleUrl: _styleUrl,
            positions: _visiblePositions,
            onStyleLoaded: () => _onStyleLoaded(attempt),
            onAnnotationsReady: () => _onAnnotationsReady(attempt),
            onFailure: () => _onFailure(attempt),
            onTruckSelected: _selectTruck,
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        if (_mode == FleetMapMode.loading)
          ColoredBox(
            key: const Key('map-status-loading'),
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.88),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(context.l10n.loadingMap),
                ],
              ),
            ),
          ),
        if (_mode == FleetMapMode.loaded)
          PositionedDirectional(
            start: 12,
            top: 12,
            child: Semantics(
              liveRegion: true,
              label: context.l10n.mapStyleLoaded,
              child: Chip(
                key: const Key('map-status-loaded'),
                avatar: const Icon(Icons.check_circle, color: Colors.green),
                label: Text(context.l10n.mapStyleLoaded),
              ),
            ),
          ),
        if (_mode == FleetMapMode.loaded)
          PositionedDirectional(
            start: 12,
            bottom: 12,
            child: _FleetPanel(
              positions: _visiblePositions,
              selectedTruckId: _selectedTruckId,
              onTruckSelected: _selectTruck,
            ),
          ),
        if (_mode == FleetMapMode.loaded && _annotationWarning)
          PositionedDirectional(
            start: 12,
            end: 12,
            top: 58,
            child: MaterialBanner(
              key: const Key('fleet-map-annotation-warning'),
              content: Text(context.l10n.mapUpdateWarning),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _annotationWarning = false),
                  child: Text(context.l10n.dismiss),
                ),
              ],
            ),
          ),
        if (_mode == FleetMapMode.loaded && _tripDetail != null)
          PositionedDirectional(
            start: 12,
            top: 58,
            child: TrailLegend(
              showTrail: _showTrail,
              onChanged: (value) => setState(() => _showTrail = value),
            ),
          ),
        if (_selected != null)
          PositionedDirectional(
            end: 12,
            top: 12,
            child: _SelectedTruckCard(
              position: _selected!,
              detail: _tripDetail,
              loading: _loadingDetail,
              onClose: _clearSelection,
              onRecenter: _recenter,
            ),
          ),
        if (_selected != null && _mode == FleetMapMode.loaded)
          PositionedDirectional(
            end: 12,
            bottom: 12,
            child: Wrap(
              spacing: 8,
              children: [
                if (!_camera.followsVehicle)
                  FilledButton.tonalIcon(
                    key: const Key('map-resume-follow'),
                    onPressed: _recenter,
                    icon: const Icon(Icons.my_location),
                    label: Text(context.l10n.resumeFollow),
                  ),
                if (_tripDetail != null)
                  OutlinedButton.icon(
                    key: const Key('map-show-full-route'),
                    onPressed: _showFullRoute,
                    icon: const Icon(Icons.zoom_out_map),
                    label: Text(context.l10n.showFullRoute),
                  ),
              ],
            ),
          ),
        if (_mode == FleetMapMode.loaded)
          PositionedDirectional(
            end: 12,
            bottom: _selected == null ? 12 : 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_outsideAreaCount > 0)
                  Chip(
                    key: const Key('trucks-outside-operational-area'),
                    avatar: const Icon(Icons.public_off, size: 18),
                    label: Text(
                      context.l10n.trucksOutsideOperationalArea(
                        _outsideAreaCount,
                      ),
                    ),
                  ),
                FloatingActionButton.small(
                  key: const Key('fleet-overview'),
                  heroTag: 'fleet-overview',
                  tooltip: context.l10n.fleetOverview,
                  onPressed: _showFleetOverview,
                  child: const Icon(Icons.public),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _selectTruck(TrackedTruck position) async {
    _pendingDetailRefresh = null;
    setState(() {
      _selectedTruckId = position.truckId;
      _tripDetail = null;
      _loadingDetail = position.currentTripId != null;
      _cameraRevision++;
      _cameraRequest = FleetCameraRequest.selection;
      _camera.followVehicle();
    });
    if (position.currentTripId == null) return;
    _queueDetailRefresh(position, fitCamera: true);
  }

  void _queueDetailRefresh(TrackedTruck truck, {required bool fitCamera}) {
    _pendingDetailRefresh = (truck: truck, fitCamera: fitCamera);
    if (!_detailRefreshRunning) unawaited(_drainDetailRefresh());
  }

  Future<void> _drainDetailRefresh() async {
    _detailRefreshRunning = true;
    try {
      while (mounted && _pendingDetailRefresh != null) {
        final request = _pendingDetailRefresh!;
        _pendingDetailRefresh = null;
        try {
          final detail = await ref
              .read(dashboardRepositoryProvider)
              .tripDetail(request.truck.currentTripId!);
          if (mounted &&
              _selectedTruckId == request.truck.truckId &&
              _selected?.currentTripId == request.truck.currentTripId) {
            setState(() {
              _tripDetail = detail;
              _loadingDetail = false;
              // Loading route detail never changes the selected-truck camera.
            });
          }
        } on Object {
          // Keep the last good route/trail when a selected-only refresh fails.
          if (mounted &&
              _selectedTruckId == request.truck.truckId &&
              request.fitCamera) {
            setState(() => _loadingDetail = false);
          }
        }
      }
    } finally {
      _detailRefreshRunning = false;
      if (mounted && _pendingDetailRefresh != null) {
        unawaited(_drainDetailRefresh());
      }
    }
  }

  void _setFilter({bool? onlineOnly, bool? movingOnly}) {
    setState(() {
      if (onlineOnly != null) _onlineOnly = onlineOnly;
      if (movingOnly != null) _movingOnly = movingOnly;
      _cameraRevision++;
      _cameraRequest = FleetCameraRequest.filteredFleet;
    });
  }

  void _clearSelection() {
    _pendingDetailRefresh = null;
    setState(() {
      _selectedTruckId = null;
      _tripDetail = null;
      _loadingDetail = false;
      _camera.userPan();
    });
  }

  void _showFleetOverview() {
    setState(() {
      _cameraRevision++;
      _cameraRequest = FleetCameraRequest.initialFleet;
      _camera.fleetOverview();
    });
  }

  void _recenter() {
    setState(() {
      _cameraRevision++;
      _cameraRequest = FleetCameraRequest.recenter;
      _camera.followVehicle();
    });
  }

  void _showFullRoute() {
    setState(() {
      _cameraRevision++;
      _cameraRequest = FleetCameraRequest.routeOverview;
      _camera.routeOverview();
    });
  }

  void _pauseFollow() {
    if (_camera.mode == FleetInteractionMode.freeExplore) return;
    setState(_camera.userPan);
  }

  void _armTimeout() {
    _loadingTimer?.cancel();
    final attempt = _attempt;
    _loadingTimer = Timer(_loadingTimeout, () => _onFailure(attempt));
  }

  void _retry() {
    _loadingTimer?.cancel();
    setState(() {
      _rendererGeneration++;
      _attempt++;
      _mode = FleetMapMode.loading;
    });
    _armTimeout();
  }

  void _useFallback() {
    _loadingTimer?.cancel();
    setState(() => _mode = FleetMapMode.fallback);
  }

  void _onStyleLoaded(int attempt) {
    if (!mounted || attempt != _attempt || _mode != FleetMapMode.loading) {
      return;
    }
    _loadingTimer?.cancel();
    setState(() => _mode = FleetMapMode.loaded);
  }

  void _onAnnotationsReady(int attempt) {
    if (!mounted || attempt != _attempt || _mode != FleetMapMode.loaded) return;
  }

  void _onFailure(int attempt) {
    if (!mounted || attempt != _attempt || _mode == FleetMapMode.fallback) {
      return;
    }
    _loadingTimer?.cancel();
    widget.telemetry?.fatalRendererErrors++;
    setState(() => _mode = FleetMapMode.failed);
  }

  void _onAnnotationFailure(Object error, String operation) {
    widget.telemetry?.recoverableAnnotationErrors++;
    debugPrint(
      'FleetMap recoverable annotation error: operation=$operation '
      'tripId=${_selected?.currentTripId} mode=$_mode '
      'exception=${error.runtimeType}: $error',
    );
    if (mounted && !_annotationWarning) {
      setState(() => _annotationWarning = true);
    }
  }

  void _onAnnotationsRecovered() {
    if (mounted && _annotationWarning) {
      setState(() => _annotationWarning = false);
    }
  }
}

Widget _productionMapBuilder({
  required Key key,
  required String styleUrl,
  required List<TrackedTruck> positions,
  OperationalArea? operationalArea,
  VoidCallback? onManualCameraZoom,
  required VoidCallback onStyleLoaded,
  required VoidCallback onAnnotationsReady,
  required VoidCallback onFailure,
  required void Function(Object error, String operation) onAnnotationFailure,
  required VoidCallback onAnnotationsRecovered,
  required ValueChanged<TrackedTruck> onTruckSelected,
  FleetTripDetail? tripDetail,
  bool showTrail = true,
  String? selectedTruckId,
  int cameraRevision = 0,
  FleetCameraRequest cameraRequest = FleetCameraRequest.none,
  VoidCallback? onManualCameraInteraction,
  required AuthenticatedThumbnailLoader thumbnailLoader,
  MapOperationTelemetry? telemetry,
}) => _ConfiguredFleetMap(
  key: key,
  styleUrl: styleUrl,
  positions: positions,
  operationalArea: operationalArea,
  onStyleLoaded: onStyleLoaded,
  onManualCameraZoom: onManualCameraZoom,
  onAnnotationsReady: onAnnotationsReady,
  onFailure: onFailure,
  onAnnotationFailure: onAnnotationFailure,
  onAnnotationsRecovered: onAnnotationsRecovered,
  onTruckSelected: onTruckSelected,
  tripDetail: tripDetail,
  showTrail: showTrail,
  selectedTruckId: selectedTruckId,
  cameraRevision: cameraRevision,
  cameraRequest: cameraRequest,
  onManualCameraInteraction: onManualCameraInteraction,
  thumbnailLoader: thumbnailLoader,
  telemetry: telemetry,
);
