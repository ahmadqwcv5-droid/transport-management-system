import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../l10n/l10n_extensions.dart';
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
    this.styleUrlOverride,
    this.loadingTimeoutOverride,
    this.mapBuilder,
    super.key,
  });

  static const configuredStyleUrl = String.fromEnvironment('MAP_STYLE_URL');
  static const _configuredTimeoutSeconds = int.fromEnvironment(
    'MAP_LOADING_TIMEOUT_SECONDS',
    defaultValue: 12,
  );

  final List<TrackedTruck> positions;
  final String? styleUrlOverride;
  final Duration? loadingTimeoutOverride;
  final FleetMapBuilder? mapBuilder;

  @override
  ConsumerState<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends ConsumerState<FleetMap> {
  late FleetMapMode _mode;
  Timer? _loadingTimer;
  int _attempt = 0;
  bool _annotationsReady = false;
  bool _onlineOnly = false;
  bool _movingOnly = false;
  bool _showTrail = true;
  String? _selectedTruckId;
  FleetTripDetail? _tripDetail;
  bool _loadingDetail = false;
  int _cameraRevision = 0;
  FleetCameraRequest _cameraRequest = FleetCameraRequest.none;
  ({TrackedTruck truck, bool fitCamera})? _pendingDetailRefresh;
  bool _detailRefreshRunning = false;

  List<TrackedTruck> get _visiblePositions => widget.positions.where((item) {
    if (_onlineOnly && !item.isOnline) return false;
    if (_movingOnly && item.speed <= 0) return false;
    return true;
  }).toList();

  TrackedTruck? get _selected => widget.positions
      .where((item) => item.truckId == _selectedTruckId)
      .firstOrNull;

  String get _styleUrl =>
      widget.styleUrlOverride ?? FleetMap.configuredStyleUrl;
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
    _mode = _styleUrl.trim().isEmpty
        ? FleetMapMode.unconfigured
        : FleetMapMode.loading;
    if (_mode == FleetMapMode.loading) _armTimeout();
  }

  @override
  void didUpdateWidget(covariant FleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStyle = oldWidget.styleUrlOverride ?? FleetMap.configuredStyleUrl;
    if (oldStyle != _styleUrl) {
      if (_styleUrl.trim().isEmpty) {
        _loadingTimer?.cancel();
        setState(() {
          _mode = FleetMapMode.unconfigured;
          _annotationsReady = false;
        });
      } else {
        _retry();
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
    final map = widget.mapBuilder == null
        ? _productionMapBuilder(
            key: ValueKey('maplibre-attempt-$_attempt'),
            styleUrl: _styleUrl,
            positions: _visiblePositions,
            onStyleLoaded: () => _onStyleLoaded(attempt),
            onAnnotationsReady: () => _onAnnotationsReady(attempt),
            onFailure: () => _onFailure(attempt),
            onTruckSelected: _selectTruck,
            tripDetail: _tripDetail,
            showTrail: _showTrail,
            selectedTruckId: _selectedTruckId,
            cameraRevision: _cameraRevision,
            cameraRequest: _cameraRequest,
          )
        : widget.mapBuilder!(
            key: ValueKey('maplibre-attempt-$_attempt'),
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
        if (_mode == FleetMapMode.loaded && _annotationsReady)
          PositionedDirectional(
            start: 12,
            bottom: 12,
            child: _FleetPanel(
              positions: _visiblePositions,
              selectedTruckId: _selectedTruckId,
              onTruckSelected: _selectTruck,
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
              if (request.fitCamera) {
                _cameraRevision++;
                _cameraRequest = FleetCameraRequest.selection;
              }
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
    });
  }

  void _recenter() {
    setState(() {
      _cameraRevision++;
      _cameraRequest = FleetCameraRequest.recenter;
    });
  }

  void _armTimeout() {
    _loadingTimer?.cancel();
    final attempt = _attempt;
    _loadingTimer = Timer(_loadingTimeout, () => _onFailure(attempt));
  }

  void _retry() {
    _loadingTimer?.cancel();
    setState(() {
      _attempt++;
      _mode = FleetMapMode.loading;
      _annotationsReady = false;
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
    setState(() => _annotationsReady = true);
  }

  void _onFailure(int attempt) {
    if (!mounted || attempt != _attempt || _mode == FleetMapMode.fallback) {
      return;
    }
    _loadingTimer?.cancel();
    setState(() {
      _mode = FleetMapMode.failed;
      _annotationsReady = false;
    });
  }
}

Widget _productionMapBuilder({
  required Key key,
  required String styleUrl,
  required List<TrackedTruck> positions,
  required VoidCallback onStyleLoaded,
  required VoidCallback onAnnotationsReady,
  required VoidCallback onFailure,
  required ValueChanged<TrackedTruck> onTruckSelected,
  FleetTripDetail? tripDetail,
  bool showTrail = true,
  String? selectedTruckId,
  int cameraRevision = 0,
  FleetCameraRequest cameraRequest = FleetCameraRequest.none,
}) => _ConfiguredFleetMap(
  key: key,
  styleUrl: styleUrl,
  positions: positions,
  onStyleLoaded: onStyleLoaded,
  onAnnotationsReady: onAnnotationsReady,
  onFailure: onFailure,
  onTruckSelected: onTruckSelected,
  tripDetail: tripDetail,
  showTrail: showTrail,
  selectedTruckId: selectedTruckId,
  cameraRevision: cameraRevision,
  cameraRequest: cameraRequest,
);
