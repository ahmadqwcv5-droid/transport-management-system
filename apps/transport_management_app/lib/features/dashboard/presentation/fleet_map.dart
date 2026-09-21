import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';
import 'fleet_map_coordinator.dart';
import 'maplibre_fleet_adapter.dart';

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

  @override
  State<_ConfiguredFleetMap> createState() => _ConfiguredFleetMapState();
}

class _ConfiguredFleetMapState extends State<_ConfiguredFleetMap> {
  MapLibreMapController? _controller;
  FleetMapAnnotationCoordinator? _coordinator;
  void Function(Symbol)? _symbolTapListener;
  bool _styleLoaded = false;

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
        MapLibreFleetAnnotationAdapter(controller),
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
    onStyleLoadedCallback: () async {
      if (!mounted) return;
      _styleLoaded = true;
      widget.onStyleLoaded();
      try {
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
      await coordinator.synchronize(
        _snapshot(),
        cameraRequest: cameraRequest,
        panelWidth: 290,
      );
    } on Object {
      if (mounted) widget.onFailure();
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

class TrailLegend extends StatelessWidget {
  const TrailLegend({
    required this.showTrail,
    required this.onChanged,
    super.key,
  });
  final bool showTrail;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('fleet-trail-legend'),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 6, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LegendLine(color: Color(0xFF175CD3)),
          Text(context.l10n.plannedRoute),
          const SizedBox(width: 8),
          const _LegendLine(color: Color(0xFF047857)),
          Text(context.l10n.travelledTrail),
          const SizedBox(width: 4),
          Switch(
            key: const Key('fleet-trail-visibility'),
            value: showTrail,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 4,
    margin: const EdgeInsetsDirectional.only(end: 4),
    color: color,
  );
}

class _SelectedTruckCard extends StatelessWidget {
  const _SelectedTruckCard({
    required this.position,
    required this.onClose,
    required this.onRecenter,
    required this.detail,
    required this.loading,
  });
  final TrackedTruck position;
  final FleetTripDetail? detail;
  final bool loading;
  final VoidCallback onClose;
  final VoidCallback onRecenter;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 6,
    child: SizedBox(
      width: 270,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    position.plateNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.close,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _CompactStatusChip(
                  label: localizedStatus(context.l10n, position.truckStatus),
                ),
                _CompactStatusChip(
                  label: position.isOnline
                      ? context.l10n.online
                      : context.l10n.offline,
                ),
                _CompactStatusChip(
                  label: !position.isOnline
                      ? context.l10n.offline
                      : position.speed > 0.5
                      ? context.l10n.moving
                      : context.l10n.stationary,
                ),
              ],
            ),
            Text(
              '${context.l10n.speed}: ${position.speed.toStringAsFixed(0)} km/h',
            ),
            Text(
              '${context.l10n.driver}: ${position.driverName ?? context.l10n.notAssigned}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${context.l10n.activeTrip}: ${position.currentTripId ?? context.l10n.notAssigned}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${context.l10n.lastUpdate}: ${_compactTimestamp(position.recordedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (loading) const LinearProgressIndicator(),
            if (detail != null) ...[
              const Divider(),
              Text(
                key: const Key('fleet-route-progress'),
                '${context.l10n.routeProgress}: ${detail!.progress.progressPercent?.toStringAsFixed(1) ?? '—'}%',
              ),
              Text(
                '${context.l10n.remainingDistance}: ${((detail!.progress.remainingDistanceMeters ?? 0) / 1000).toStringAsFixed(1)} km',
              ),
              Text(
                '${context.l10n.eta}: ${detail!.progress.estimatedArrivalAt ?? '—'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                detail!.progress.isOffRoute == true
                    ? context.l10n.offRoute
                    : context.l10n.onRoute,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const Key('fleet-map-recenter'),
                onPressed: onRecenter,
                icon: const Icon(Icons.center_focus_strong),
                label: Text(
                  detail == null
                      ? context.l10n.recenter
                      : context.l10n.fitRoute,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompactStatusChip extends StatelessWidget {
  const _CompactStatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

String _compactTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final utc = parsed.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

class _FleetPanel extends StatelessWidget {
  const _FleetPanel({
    required this.positions,
    required this.selectedTruckId,
    required this.onTruckSelected,
  });

  final List<TrackedTruck> positions;
  final String? selectedTruckId;
  final ValueChanged<TrackedTruck> onTruckSelected;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('map-annotations-ready'),
    elevation: 5,
    child: SizedBox(
      width: 220,
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
            child: Text(
              context.l10n.fleetList,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: positions.isEmpty
                ? Center(child: Text(context.l10n.noTrackedTrucks))
                : ListView.builder(
                    padding: const EdgeInsetsDirectional.only(bottom: 6),
                    itemCount: positions.length,
                    itemBuilder: (context, index) {
                      final position = positions[index];
                      final selected = position.truckId == selectedTruckId;
                      return Material(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Colors.transparent,
                        child: ListTile(
                          key: Key('real-map-truck-${position.truckId}'),
                          dense: true,
                          selected: selected,
                          leading: Icon(
                            Icons.local_shipping,
                            color: !position.isOnline
                                ? Colors.grey
                                : position.speed > 0.5
                                ? Colors.green
                                : Colors.blue,
                          ),
                          title: Text(position.plateNumber),
                          subtitle: Text(
                            !position.isOnline
                                ? context.l10n.offline
                                : position.speed > 0.5
                                ? context.l10n.moving
                                : context.l10n.stationary,
                          ),
                          onTap: () => onTruckSelected(position),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.actions,
    super.key,
  });

  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    ),
  );
}

class _FallbackMap extends StatelessWidget {
  const _FallbackMap({required this.positions, required this.onTruckSelected});

  final List<TrackedTruck> positions;
  final ValueChanged<TrackedTruck> onTruckSelected;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Container(
        key: const Key('offline-map-surface'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: positions.isEmpty
              ? Text(context.l10n.noTrackedTrucks)
              : const Icon(Icons.grid_view_rounded, size: 72),
        ),
      ),
      PositionedDirectional(
        start: 12,
        top: 12,
        child: Chip(
          key: const Key('map-status-fallback'),
          avatar: const Icon(Icons.info_outline),
          label: Text(context.l10n.fallbackMode),
        ),
      ),
      ...positions.asMap().entries.map(
        (entry) => PositionedDirectional(
          start: 28.0 + (entry.key * 83) % 520,
          top: 78.0 + (entry.key * 57) % 210,
          child: Tooltip(
            message: entry.value.plateNumber,
            child: InkWell(
              key: Key('fallback-truck-marker-${entry.value.truckId}'),
              onTap: () => onTruckSelected(entry.value),
              child: CircleAvatar(
                backgroundColor: entry.value.isOnline
                    ? Colors.green
                    : Colors.grey,
                child: const Icon(Icons.local_shipping, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
