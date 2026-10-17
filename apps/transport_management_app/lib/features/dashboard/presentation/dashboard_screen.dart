import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../design_system/app_breakpoints.dart';
import '../../../design_system/app_design_tokens.dart';
import '../../../design_system/components/app_metric_card.dart';
import '../../../design_system/components/app_page_header.dart';
import '../../../design_system/components/app_state_panel.dart';
import '../../../design_system/components/app_status_badge.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/dashboard_models.dart';
import 'active_operation_card.dart';
import 'dashboard_controller.dart';
import 'fleet_map.dart';
import 'simulator_controls.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dashboardControllerProvider)
      .when(
        loading: () => AppStatePanel(
          kind: AppStateKind.loading,
          title: context.l10n.loading,
        ),
        error: (error, _) {
          final stale = ref.read(dashboardControllerProvider.notifier).isStale;
          return AppStatePanel(
            key: stale
                ? const Key('dashboard-stale-warning')
                : const Key('dashboard-error'),
            kind: stale ? AppStateKind.stale : AppStateKind.error,
            title: stale
                ? context.l10n.activeOperationsStale
                : context.l10n.genericError,
            message: error is ApiException
                ? localizedErrorCode(context.l10n, error.code)
                : context.l10n.genericError,
            actionLabel: context.l10n.retry,
            onAction: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
          );
        },
        data: (data) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
          child: ListView(
            key: const Key('fleet-dashboard'),
            padding: EdgeInsets.all(context.tokens.space4),
            children: [
              AppPageHeader(
                title: context.l10n.dashboard,
                subtitle: context.l10n.activeOperationsTitle,
              ),
              SizedBox(height: context.tokens.space4),
              _Summary(data),
              SizedBox(height: context.tokens.space4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = MediaQuery.sizeOf(context).height;
                  final compact = AppBreakpoints.isCompact(context);
                  final target = viewport * (compact ? .66 : .64);
                  return FleetMap(
                    key: const ValueKey('primary-fleet-map'),
                    positions: data.positions,
                    operationalArea: data.operationalArea,
                    height: target.clamp(compact ? 480 : 520, 760),
                  );
                },
              ),
              SizedBox(height: context.tokens.space5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.activeOperationsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const Key('view-all-active-operations'),
                    onPressed: () => context.go('/trips'),
                    child: Text(context.l10n.viewAll),
                  ),
                ],
              ),
              if (data.activeTrips.isEmpty)
                AppStatePanel(
                  compact: true,
                  kind: AppStateKind.empty,
                  title: context.l10n.noActiveOperations,
                )
              else
                ...data.activeTrips.map(
                  (operation) => Padding(
                    padding: EdgeInsets.only(bottom: context.tokens.space3),
                    child: ActiveOperationCard(
                      operation: operation,
                      onTap: () => context.go('/trips/${operation.tripId}'),
                    ),
                  ),
                ),
              if (ref.watch(authControllerProvider).value?.user.role ==
                      'Owner' &&
                  SimulatorControls.enabled) ...[
                SizedBox(height: context.tokens.space4),
                SimulatorControls(trucks: data.simulatorTrucks),
              ],
              SizedBox(height: context.tokens.space5),
              Text(
                context.l10n.recentTrips,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (data.recentTrips.isEmpty)
                AppStatePanel(
                  compact: true,
                  kind: AppStateKind.empty,
                  title: context.l10n.recentTrips,
                )
              else
                ...data.recentTrips.map(
                  (trip) => ListTile(
                    leading: const Icon(Icons.route),
                    title: Text(
                      '${trip.tripNumber} · ${trip.origin ?? context.l10n.incompleteDraft}'
                      '${trip.destination == null ? '' : ' → ${trip.destination}'}',
                    ),
                    trailing: AppStatusBadge(
                      label: localizedStatus(context.l10n, trip.status),
                      tone: trip.status == 'Completed'
                          ? AppStatusTone.success
                          : AppStatusTone.information,
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
    final compact = AppBreakpoints.isCompact(context);
    return GridView.count(
      crossAxisCount: compact ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: context.tokens.space3,
      crossAxisSpacing: context.tokens.space3,
      childAspectRatio: compact ? 1.45 : 2.4,
      children: [
        for (var index = 0; index < values.length; index++)
          AppMetricCard(
            label: values[index].$1,
            value: '${values[index].$2}',
            icon: _metricIcon(index),
          ),
      ],
    );
  }

  IconData _metricIcon(int index) => switch (index) {
    0 => Icons.local_shipping_outlined,
    1 => Icons.check_circle_outline,
    2 => Icons.route_outlined,
    3 => Icons.build_outlined,
    4 => Icons.block_outlined,
    5 => Icons.alt_route,
    6 => Icons.task_alt,
    7 => Icons.sensors,
    _ => Icons.cloud_off_outlined,
  };
}
