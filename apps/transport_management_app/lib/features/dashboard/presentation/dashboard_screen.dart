import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';
import 'active_operation_card.dart';
import 'fleet_map.dart';
import 'simulator_controls.dart';

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
              if (ref.read(dashboardControllerProvider.notifier).isStale)
                const MaterialBanner(
                  key: Key('dashboard-stale-warning'),
                  content: Text(
                    'Live refresh is temporarily unavailable. Showing the last update.',
                  ),
                  actions: [SizedBox.shrink()],
                ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Active operations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const Key('view-all-active-operations'),
                    onPressed: () => context.go('/trips'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              if (data.activeTrips.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No active operations.'),
                )
              else
                ...data.activeTrips.map(
                  (operation) => ActiveOperationCard(
                    operation: operation,
                    onTap: () => context.go('/trips/${operation.tripId}'),
                  ),
                ),
              const SizedBox(height: 16),
              if (ref.watch(authControllerProvider).value?.user.role ==
                      'Owner' &&
                  SimulatorControls.enabled)
                SimulatorControls(trucks: data.simulatorTrucks),
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
                    title: Text(
                      '${trip.tripNumber} · ${trip.origin ?? context.l10n.incompleteDraft}${trip.destination == null ? '' : ' → ${trip.destination}'}',
                    ),
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
