import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../design_system/app_design_preset.dart';
import '../../../design_system/app_design_tokens.dart';
import '../../../design_system/components/app_state_panel.dart';
import '../../../design_system/components/atlas_pulse_components.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/active_operation.dart';
import '../domain/dashboard_models.dart';
import 'atlas_dashboard_view_model.dart';
import 'dashboard_controller.dart';
import 'fleet_map.dart';
import 'fleet_map_coordinator.dart';
import 'simulator_controls.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedTruckId;
  bool _pointerOverMap = false;
  final MapOperationTelemetry _mapTelemetry = MapOperationTelemetry();

  @override
  Widget build(BuildContext context) {
    final preset = ref.watch(appDesignPresetProvider);
    final locale = Localizations.localeOf(context);
    return Theme(
      data: preset.commandCenterTheme(locale),
      child: Builder(
        builder: (commandContext) => ColoredBox(
          color: commandContext.tokens.commandBackground,
          child: ref
              .watch(dashboardControllerProvider)
              .when(
                loading: () => AppStatePanel(
                  key: const Key('atlas-dashboard-loading'),
                  kind: AppStateKind.loading,
                  title: commandContext.l10n.loading,
                ),
                error: (error, _) => _error(commandContext, error),
                data: (data) => _dashboard(commandContext, data),
              ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, Object error) {
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
      onAction: () => ref.read(dashboardControllerProvider.notifier).refresh(),
    );
  }

  Widget _dashboard(BuildContext context, DashboardData data) {
    final viewModel = AtlasDashboardViewModel(data);
    final retainedSelection = viewModel.retainSelection(_selectedTruckId);
    if (retainedSelection != _selectedTruckId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedTruckId != retainedSelection) {
          setState(() => _selectedTruckId = retainedSelection);
        }
      });
    }
    final hasPartialMetrics = viewModel.metrics.any(
      (metric) => !metric.isAvailable,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final expanded = constraints.maxWidth >= 1080;
        final viewportHeight = MediaQuery.sizeOf(context).height;
        final mapHeight = (viewportHeight * (narrow ? .62 : .68)).clamp(
          narrow ? 500.0 : 540.0,
          expanded ? 720.0 : 640.0,
        );
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
          child: ListView(
            key: const Key('fleet-dashboard'),
            physics: _pointerOverMap
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              narrow ? context.tokens.space2 : context.tokens.space3,
            ),
            children: [
              _CommandHeading(
                compact: narrow,
                onRefresh: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
              ),
              SizedBox(height: context.tokens.space2),
              _KpiRibbon(metrics: viewModel.metrics, compact: narrow),
              if (hasPartialMetrics) ...[
                SizedBox(height: context.tokens.space2),
                AtlasCommandSurface(
                  key: const Key('atlas-partial-data'),
                  padding: EdgeInsets.all(context.tokens.space2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: context.tokens.iconMedium,
                        color: context.tokens.warning,
                      ),
                      SizedBox(width: context.tokens.space2),
                      Expanded(
                        child: Text(context.l10n.partialOperationalData),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: context.tokens.space2),
              Semantics(
                label: context.l10n.mapStage,
                child: FleetMap(
                  key: const ValueKey('primary-fleet-map'),
                  positions: data.positions,
                  activeOperations: data.activeTrips,
                  operationalArea: data.operationalArea,
                  selectedTruckId: retainedSelection,
                  selectionManagedExternally: true,
                  onSelectionChanged: (truckId) {
                    if (_selectedTruckId != truckId) {
                      setState(() => _selectedTruckId = truckId);
                    }
                  },
                  onOpenTruck: (truckId) => context.go('/trucks/$truckId'),
                  onOpenTrip: (tripId) => context.go('/trips/$tripId'),
                  telemetry: _mapTelemetry,
                  onPointerHoverChanged: (hovering) {
                    if (_pointerOverMap != hovering) {
                      setState(() => _pointerOverMap = hovering);
                    }
                  },
                  height: mapHeight,
                ),
              ),
              if (SimulatorControls.enabled)
                Semantics(
                  key: const Key('atlas-map-telemetry'),
                  container: true,
                  label: jsonEncode(_mapTelemetry.toJson()),
                  child: const SizedBox(width: 1, height: 1),
                ),
              SizedBox(height: context.tokens.space2),
              _OperationsRail(
                viewModel: viewModel,
                expanded: expanded,
                selectedTruckId: retainedSelection,
                onOperationSelected: (operation) {
                  final truckId = operation.truckId;
                  if (truckId != null && viewModel.truck(truckId) != null) {
                    setState(() => _selectedTruckId = truckId);
                  } else {
                    context.go('/trips/${operation.tripId}');
                  }
                },
                onOpenOperation: (operation) =>
                    context.go('/trips/${operation.tripId}'),
              ),
              if (ref.watch(authControllerProvider).value?.user.role ==
                      'Owner' &&
                  SimulatorControls.enabled) ...[
                SizedBox(height: context.tokens.space3),
                SimulatorControls(trucks: data.simulatorTrucks),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommandHeading extends StatelessWidget {
  const _CommandHeading({required this.compact, required this.onRefresh});

  final bool compact;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => AtlasCommandSurface(
    key: const Key('atlas-command-heading'),
    padding: EdgeInsets.symmetric(
      horizontal: context.tokens.space4,
      vertical: context.tokens.space3,
    ),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.tokens.commandAccent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(context.tokens.radiusSmall),
          ),
          child: Padding(
            padding: EdgeInsets.all(context.tokens.space2),
            child: Icon(
              Icons.radar,
              color: context.tokens.commandAccent,
              size: context.tokens.iconLarge,
            ),
          ),
        ),
        SizedBox(width: context.tokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.atlasCommandCenter,
                style:
                    (compact
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                context.l10n.atlasLiveOperations,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.tokens.commandTextMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('atlas-dashboard-refresh'),
          tooltip: context.l10n.refresh,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}

class _KpiRibbon extends StatelessWidget {
  const _KpiRibbon({required this.metrics, required this.compact});

  final List<AtlasMetricValue> metrics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final metric in metrics)
        SizedBox(
          width: compact ? 150 : 178,
          child: AtlasKpiItem(
            key: Key('atlas-kpi-${metric.kind.name}'),
            label: _label(context, metric.kind),
            value: metric.value,
            unavailableLabel: context.l10n.unavailable,
            icon: _icon(metric.kind),
            tone: _tone(context, metric.kind),
          ),
        ),
    ];
    return AtlasCommandSurface(
      key: const Key('atlas-kpi-ribbon'),
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              items[index],
              if (index < items.length - 1)
                SizedBox(
                  height: 42,
                  child: VerticalDivider(color: context.tokens.commandBorder),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _label(BuildContext context, AtlasMetricKind kind) => switch (kind) {
    AtlasMetricKind.connected => context.l10n.connectedVehicles,
    AtlasMetricKind.moving => context.l10n.movingVehicles,
    AtlasMetricKind.available => context.l10n.availableTrucks,
    AtlasMetricKind.activeTrips => context.l10n.activeTrips,
    AtlasMetricKind.attention => context.l10n.attentionItems,
  };

  IconData _icon(AtlasMetricKind kind) => switch (kind) {
    AtlasMetricKind.connected => Icons.sensors,
    AtlasMetricKind.moving => Icons.near_me_outlined,
    AtlasMetricKind.available => Icons.check_circle_outline,
    AtlasMetricKind.activeTrips => Icons.route_outlined,
    AtlasMetricKind.attention => Icons.warning_amber_rounded,
  };

  Color _tone(BuildContext context, AtlasMetricKind kind) => switch (kind) {
    AtlasMetricKind.attention => context.tokens.warning,
    AtlasMetricKind.activeTrips => context.tokens.routePlanned,
    AtlasMetricKind.available => context.tokens.success,
    _ => context.tokens.commandAccent,
  };
}

class _OperationsRail extends StatelessWidget {
  const _OperationsRail({
    required this.viewModel,
    required this.expanded,
    required this.selectedTruckId,
    required this.onOperationSelected,
    required this.onOpenOperation,
  });

  final AtlasDashboardViewModel viewModel;
  final bool expanded;
  final String? selectedTruckId;
  final ValueChanged<ActiveOperation> onOperationSelected;
  final ValueChanged<ActiveOperation> onOpenOperation;

  @override
  Widget build(BuildContext context) {
    final active = _RailSection(
      key: const Key('atlas-active-trips-rail'),
      title: context.l10n.activeOperationsTitle,
      operations: viewModel.activeTrips,
      emptyText: context.l10n.noActiveOperations,
      selectedTruckId: selectedTruckId,
      onSelected: onOperationSelected,
      onOpen: onOpenOperation,
    );
    final exceptions = _RailSection(
      key: const Key('atlas-exceptions-rail'),
      title: context.l10n.operationalExceptions,
      operations: viewModel.exceptions,
      emptyText: context.l10n.noOperationalExceptions,
      selectedTruckId: selectedTruckId,
      onSelected: onOperationSelected,
      onOpen: onOpenOperation,
      exception: true,
    );
    if (!expanded) {
      return Column(
        children: [
          active,
          SizedBox(height: context.tokens.space2),
          exceptions,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: active),
        SizedBox(width: context.tokens.space2),
        Expanded(child: exceptions),
      ],
    );
  }
}

class _RailSection extends StatelessWidget {
  const _RailSection({
    required this.title,
    required this.operations,
    required this.emptyText,
    required this.selectedTruckId,
    required this.onSelected,
    required this.onOpen,
    this.exception = false,
    super.key,
  });

  final String title;
  final List<ActiveOperation> operations;
  final String emptyText;
  final String? selectedTruckId;
  final ValueChanged<ActiveOperation> onSelected;
  final ValueChanged<ActiveOperation> onOpen;
  final bool exception;

  @override
  Widget build(BuildContext context) => AtlasCommandSurface(
    padding: EdgeInsets.all(context.tokens.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtlasSectionHeader(
          title: title,
          trailing: TextButton(
            onPressed: () => context.go('/trips'),
            child: Text(context.l10n.viewAll),
          ),
        ),
        SizedBox(height: context.tokens.space2),
        if (operations.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.tokens.space4),
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.commandTextMuted),
            ),
          )
        else
          SizedBox(
            height: exception ? 180 : 210,
            child: ListView.separated(
              itemCount: operations.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: context.tokens.commandBorder),
              itemBuilder: (context, index) {
                final operation = operations[index];
                return _OperationRow(
                  operation: operation,
                  selected: operation.truckId == selectedTruckId,
                  exception: exception,
                  onSelected: () => onSelected(operation),
                  onOpen: () => onOpen(operation),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.operation,
    required this.selected,
    required this.exception,
    required this.onSelected,
    required this.onOpen,
  });

  final ActiveOperation operation;
  final bool selected;
  final bool exception;
  final VoidCallback onSelected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = operation.needsAttention
        ? context.tokens.warning
        : context.tokens.commandAccent;
    return Material(
      color: selected
          ? context.tokens.commandAccent.withValues(alpha: .1)
          : Colors.transparent,
      child: InkWell(
        key: Key('atlas-operation-${operation.tripId}'),
        onTap: onSelected,
        onLongPress: onOpen,
        focusColor: context.tokens.commandAccent.withValues(alpha: .12),
        hoverColor: context.tokens.commandSurfaceSecondary,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.tokens.space2),
          child: Row(
            children: [
              Icon(
                exception ? Icons.warning_amber_rounded : Icons.route_outlined,
                size: context.tokens.iconMedium,
                color: tone,
              ),
              SizedBox(width: context.tokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: AtlasIdentifier(
                            operation.tripNumber,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (operation.truckPlateNumber != null) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: context.tokens.commandTextMuted,
                            ),
                          ),
                          Flexible(
                            child: AtlasIdentifier(
                              operation.truckPlateNumber!,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      operation.nextStopName ?? operation.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.tokens.commandTextMuted,
                      ),
                    ),
                    if (operation.progressPercent != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 4),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          value: (operation.progressPercent! / 100).clamp(0, 1),
                          color: tone,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.openTrip,
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
