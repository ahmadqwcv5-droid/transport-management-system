import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dashboardControllerProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is ApiException
                    ? localizedErrorCode(context.l10n, error.code)
                    : context.l10n.genericError,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
          child: ListView(
            key: const Key('fleet-dashboard'),
            padding: const EdgeInsetsDirectional.all(16),
            children: [
              Text(
                context.l10n.dashboard,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _Summary(data),
              const SizedBox(height: 16),
              if (ref.watch(authControllerProvider).value?.user.role == 'Owner')
                const _SimulatorControls(),
              const SizedBox(height: 16),
              FleetMap(positions: data.positions),
              const SizedBox(height: 16),
              Text(
                context.l10n.recentTrips,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (data.recentTrips.isEmpty)
                const SizedBox(height: 72)
              else
                ...data.recentTrips.map(
                  (trip) => ListTile(
                    leading: const Icon(Icons.route),
                    title: Text('${trip.origin} → ${trip.destination}'),
                    trailing: Chip(
                      label: Text(localizedStatus(context.l10n, trip.status)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary(this.data);
  final DashboardData data;
  @override
  Widget build(BuildContext context) {
    final values = [
      (context.l10n.totalTrucks, data.fleet['total']),
      (context.l10n.availableTrucks, data.fleet['available']),
      (context.l10n.onTripTrucks, data.fleet['onTrip']),
      (context.l10n.maintenanceTrucks, data.fleet['maintenance']),
      (context.l10n.outOfServiceTrucks, data.fleet['outOfService']),
      (context.l10n.activeTrips, data.trips['active']),
      (context.l10n.completedToday, data.trips['completedToday']),
      (context.l10n.onlineTracked, data.tracking['online']),
      (context.l10n.offlineTracked, data.tracking['offline']),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values
          .map(
            (value) => SizedBox(
              width: 150,
              child: Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${value.$2}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(value.$1),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SimulatorControls extends ConsumerWidget {
  const _SimulatorControls();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            context.l10n.simulator,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final action in [
            ('start', context.l10n.start),
            ('pause', context.l10n.pause),
            ('resume', context.l10n.resume),
            ('stop', context.l10n.stop),
            ('reset', context.l10n.reset),
          ])
            OutlinedButton(
              key: Key('sim-${action.$1}'),
              onPressed: () => ref
                  .read(dashboardControllerProvider.notifier)
                  .control(action.$1),
              child: Text(action.$2),
            ),
        ],
      ),
    ),
  );
}

class FleetMap extends StatelessWidget {
  const FleetMap({required this.positions, super.key});
  final List<TrackedTruck> positions;
  static const styleUrl = String.fromEnvironment('MAP_STYLE_URL');
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 390,
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
          Expanded(
            child: positions.isEmpty
                ? Center(child: Text(context.l10n.noTrackedTrucks))
                : styleUrl.isNotEmpty
                ? _ConfiguredFleetMap(positions)
                : Stack(
                    children: [
                      Container(
                        key: const Key('offline-map-surface'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              Theme.of(context).colorScheme.primaryContainer,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.map_outlined, size: 72),
                        ),
                      ),
                      ...positions.asMap().entries.map(
                        (entry) => PositionedDirectional(
                          start: 28.0 + (entry.key * 83) % 520,
                          top: 32.0 + (entry.key * 57) % 210,
                          child: _Marker(entry.value),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ConfiguredFleetMap extends StatefulWidget {
  const _ConfiguredFleetMap(this.positions);
  final List<TrackedTruck> positions;

  @override
  State<_ConfiguredFleetMap> createState() => _ConfiguredFleetMapState();
}

class _ConfiguredFleetMapState extends State<_ConfiguredFleetMap> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  @override
  void didUpdateWidget(covariant _ConfiguredFleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) _syncCircles();
  }

  @override
  Widget build(BuildContext context) => MapLibreMap(
    styleString: FleetMap.styleUrl,
    initialCameraPosition: CameraPosition(
      target: LatLng(
        widget.positions.first.latitude,
        widget.positions.first.longitude,
      ),
      zoom: 6,
    ),
    onMapCreated: (controller) {
      _controller = controller;
      controller.onCircleTapped.add((circle) {
        final truckId = circle.data?['truckId'] as String?;
        final position = widget.positions
            .where((item) => item.truckId == truckId)
            .firstOrNull;
        if (position != null && mounted) _showTruckDetails(context, position);
      });
    },
    onStyleLoadedCallback: () {
      _styleLoaded = true;
      _syncCircles();
    },
  );

  Future<void> _syncCircles() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    await controller.clearCircles();
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
  }
}

class _Marker extends StatelessWidget {
  const _Marker(this.position);
  final TrackedTruck position;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: position.plateNumber,
    child: InkWell(
      key: Key('truck-marker-${position.truckId}'),
      onTap: () => _showTruckDetails(context, position),
      child: CircleAvatar(
        backgroundColor: position.isOnline ? Colors.green : Colors.grey,
        child: const Icon(Icons.local_shipping, color: Colors.white),
      ),
    ),
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
