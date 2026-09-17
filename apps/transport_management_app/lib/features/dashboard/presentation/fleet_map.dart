import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../domain/dashboard_models.dart';

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

class FleetMap extends StatefulWidget {
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
  State<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends State<FleetMap> {
  late FleetMapMode _mode;
  Timer? _loadingTimer;
  int _attempt = 0;
  bool _annotationsReady = false;

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
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
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
            child: Text(
              context.l10n.fleetMap,
              style: Theme.of(context).textTheme.titleLarge,
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
    FleetMapMode.fallback => _FallbackMap(
      positions: widget.positions,
      onTruckSelected: (position) => _showTruckDetails(context, position),
    ),
    FleetMapMode.loading || FleetMapMode.loaded => _buildRealMap(context),
  };

  Widget _buildRealMap(BuildContext context) {
    final builder = widget.mapBuilder ?? _productionMapBuilder;
    final attempt = _attempt;
    return Stack(
      fit: StackFit.expand,
      children: [
        builder(
          key: ValueKey('maplibre-attempt-$_attempt'),
          styleUrl: _styleUrl,
          positions: widget.positions,
          onStyleLoaded: () => _onStyleLoaded(attempt),
          onAnnotationsReady: () => _onAnnotationsReady(attempt),
          onFailure: () => _onFailure(attempt),
          onTruckSelected: (position) => _showTruckDetails(context, position),
        ),
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
            end: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Wrap(
                  key: const Key('map-annotations-ready'),
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.positions.isEmpty
                      ? [Text(context.l10n.noTrackedTrucks)]
                      : widget.positions
                            .map(
                              (position) => ActionChip(
                                key: Key('real-map-truck-${position.truckId}'),
                                avatar: Icon(
                                  Icons.local_shipping,
                                  color: position.isOnline
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                label: Text(position.plateNumber),
                                onPressed: () =>
                                    _showTruckDetails(context, position),
                              ),
                            )
                            .toList(),
                ),
              ),
            ),
          ),
      ],
    );
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
}) => _ConfiguredFleetMap(
  key: key,
  styleUrl: styleUrl,
  positions: positions,
  onStyleLoaded: onStyleLoaded,
  onAnnotationsReady: onAnnotationsReady,
  onFailure: onFailure,
  onTruckSelected: onTruckSelected,
);

class _ConfiguredFleetMap extends StatefulWidget {
  const _ConfiguredFleetMap({
    required this.styleUrl,
    required this.positions,
    required this.onStyleLoaded,
    required this.onAnnotationsReady,
    required this.onFailure,
    required this.onTruckSelected,
    super.key,
  });

  final String styleUrl;
  final List<TrackedTruck> positions;
  final VoidCallback onStyleLoaded;
  final VoidCallback onAnnotationsReady;
  final VoidCallback onFailure;
  final ValueChanged<TrackedTruck> onTruckSelected;

  @override
  State<_ConfiguredFleetMap> createState() => _ConfiguredFleetMapState();
}

class _ConfiguredFleetMapState extends State<_ConfiguredFleetMap> {
  MapLibreMapController? _controller;
  void Function(Circle)? _circleTapListener;
  bool _styleLoaded = false;
  int _syncGeneration = 0;

  @override
  void didUpdateWidget(covariant _ConfiguredFleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) _syncCircles();
  }

  @override
  void dispose() {
    _syncGeneration++;
    final controller = _controller;
    final listener = _circleTapListener;
    if (controller != null && listener != null) {
      controller.onCircleTapped.remove(listener);
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
      zoom: widget.positions.isEmpty ? 4 : 6,
    ),
    onMapCreated: (controller) {
      _controller = controller;
      void listener(Circle circle) {
        final truckId = circle.data?['truckId'] as String?;
        final position = widget.positions
            .where((item) => item.truckId == truckId)
            .firstOrNull;
        if (position != null && mounted) widget.onTruckSelected(position);
      }

      _circleTapListener = listener;
      controller.onCircleTapped.add(listener);
    },
    onStyleLoadedCallback: () {
      if (!mounted) return;
      _styleLoaded = true;
      widget.onStyleLoaded();
      _syncCircles();
    },
  );

  Future<void> _syncCircles() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    final generation = ++_syncGeneration;
    try {
      await controller.clearCircles();
      if (!mounted || generation != _syncGeneration) return;
      await controller.addCircles(
        widget.positions
            .map(
              (position) => CircleOptions(
                geometry: LatLng(position.latitude, position.longitude),
                circleRadius: 9,
                circleColor: position.isOnline ? '#16A34A' : '#6B7280',
                circleStrokeColor: '#FFFFFF',
                circleStrokeWidth: 2,
              ),
            )
            .toList(),
        widget.positions
            .map((position) => <String, dynamic>{'truckId': position.truckId})
            .toList(),
      );
      if (mounted && generation == _syncGeneration) {
        widget.onAnnotationsReady();
      }
    } on Object {
      if (mounted && generation == _syncGeneration) widget.onFailure();
    }
  }
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

void _showTruckDetails(BuildContext context, TrackedTruck position) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(position.plateNumber),
      content: Text(
        '${localizedStatus(context.l10n, position.truckStatus)}\n${position.isOnline ? context.l10n.online : context.l10n.offline}\n${context.l10n.speed}: ${position.speed.toStringAsFixed(0)} km/h\n${context.l10n.driver}: ${position.driverName ?? context.l10n.notAssigned}\n${context.l10n.activeTrip}: ${position.currentTripId ?? context.l10n.notAssigned}\n${context.l10n.lastUpdate}: ${position.recordedAt}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}
