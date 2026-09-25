import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../domain/live_operations_models.dart';
import 'driver_workspace_map.dart';
import 'live_operations_controller.dart';

class DriverMyTripScreen extends ConsumerWidget {
  const DriverMyTripScreen({super.key});
  static const _styleUrl = String.fromEnvironment('MAP_STYLE_URL');

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(driverTripControllerProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.genericError)),
        data: (workspace) {
          if (workspace.state == 'ACCOUNT_NOT_LINKED') {
            return _WorkspaceEmptyState(
              icon: Icons.link_off,
              title: context.l10n.driverAccountNotLinked,
              message: context.l10n.contactOwnerToLinkDriver,
              onRefresh: ref
                  .read(driverTripControllerProvider.notifier)
                  .refresh,
            );
          }
          if (workspace.state == 'NO_ACTIVE_TRIP') {
            return _WorkspaceEmptyState(
              icon: Icons.route_outlined,
              title: context.l10n.noAssignedTrip,
              message: context.l10n.noAssignedTripExplanation,
              onRefresh: ref
                  .read(driverTripControllerProvider.notifier)
                  .refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: ref.read(driverTripControllerProvider.notifier).refresh,
            child: ListView(
              key: const Key('driver-my-trip'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.l10n.myTrip,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (workspace.connectionWarning) ...[
                  const SizedBox(height: 12),
                  MaterialBanner(
                    key: const Key('driver-workspace-connection-warning'),
                    content: Text(context.l10n.workspaceConnectionWarning),
                    actions: [
                      TextButton(
                        onPressed: ref
                            .read(driverTripControllerProvider.notifier)
                            .refresh,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ],
                if (_departureAction(workspace) case final action?) ...[
                  const SizedBox(height: 12),
                  _DeparturePanel(
                    action: action,
                    loading: workspace.actionInProgress,
                    onConfirm: () => _depart(context, ref),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 360,
                  child: DriverWorkspaceMap(
                    workspace: workspace,
                    styleUrl: _styleUrl,
                    photoLoader: ref
                        .read(dashboardRepositoryProvider)
                        .authenticatedImage,
                  ),
                ),
                const SizedBox(height: 12),
                _WorkspaceCard(workspace: workspace),
                const SizedBox(height: 16),
                if (workspace.allowedActions.contains(
                  'confirm-loaded-and-depart',
                ))
                  _ActionButton(
                    label: context.l10n.confirmLoadedAndDepart,
                    message: context.l10n.confirmLoadedWarning,
                    onConfirm: () => _confirm(context, ref, delivery: false),
                  ),
                if (workspace.allowedActions.contains('confirm-delivery'))
                  _ActionButton(
                    label: context.l10n.confirmDelivery,
                    message: context.l10n.confirmDeliveryWarning,
                    onConfirm: () => _confirm(context, ref, delivery: true),
                  ),
                if (workspace.allowedActions.contains('end-vehicle-session'))
                  _ActionButton(
                    label: context.l10n.endVehicleSession,
                    message: context.l10n.endVehicleSessionWarning,
                    onConfirm: () => _endSession(context, ref),
                  ),
              ],
            ),
          );
        },
      );

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required bool delivery,
  }) async {
    final ok = await ref
        .read(driverTripControllerProvider.notifier)
        .confirm(delivery: delivery);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? context.l10n.actionConfirmed : context.l10n.genericError,
        ),
      ),
    );
  }

  Future<void> _depart(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(driverTripControllerProvider.notifier)
        .depart();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.succeeded
              ? context.l10n.actionConfirmed
              : localizedErrorCode(context.l10n, result.errorCode),
        ),
      ),
    );
  }

  Future<void> _endSession(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(driverTripControllerProvider.notifier)
        .endVehicleSession();
    if (context.mounted) _result(context, ok);
  }

  void _result(BuildContext context, bool ok) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? context.l10n.actionConfirmed : context.l10n.genericError,
          ),
        ),
      );

  DriverActionReadiness? _departureAction(DriverWorkspace workspace) {
    for (final action in workspace.actions) {
      if (action.code == 'DEPART_TO_PICKUP' && action.visible) return action;
    }
    return workspace.allowedActions.contains('depart-to-pickup')
        ? const DriverActionReadiness(
            code: 'DEPART_TO_PICKUP',
            visible: true,
            enabled: true,
            requiresConfirmation: true,
          )
        : null;
  }
}

class _DeparturePanel extends StatelessWidget {
  const _DeparturePanel({
    required this.action,
    required this.loading,
    required this.onConfirm,
  });

  final DriverActionReadiness action;
  final bool loading;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final guidance = switch (action.blockingReason) {
      'TRUCK_POSITION_REQUIRED' => context.l10n.truckPositionRequiredGuidance,
      'TRUCK_POSITION_STALE' => context.l10n.truckPositionStaleGuidance,
      'TRUCK_OFFLINE' => context.l10n.truckOfflineGuidance,
      'PICKUP_COORDINATES_REQUIRED' =>
        context.l10n.pickupCoordinatesRequiredGuidance,
      final code? => localizedErrorCode(context.l10n, code),
      null => context.l10n.departureRequiredMessage,
    };
    return Card(
      key: const Key('driver-departure-panel'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tripAssignedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(guidance),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const Key('confirm-departure-to-pickup'),
                onPressed: action.enabled && !loading
                    ? () => _confirm(context)
                    : null,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route_outlined),
                label: Text(
                  loading
                      ? context.l10n.preparingApproachRoute
                      : context.l10n.confirmDepartureToPickup,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.confirmDepartureToPickup),
        content: Text(context.l10n.departToPickupWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-driver-departure-dialog'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.workspace});
  final DriverWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final trip = workspace.currentTrip!;
    final truck = workspace.truck;
    final next = workspace.nextStop;
    final updated = DateTime.tryParse(
      workspace.currentPosition?.recordedAt ?? '',
    )?.toLocal();
    final eta = DateTime.tryParse(
      workspace.estimatedArrivalAt ?? '',
    )?.toLocal();
    final distance = workspace.remainingDistanceMeters;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.tripNumber,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(_trackingLabel(context, workspace.state))),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(localizedStatus(context.l10n, trip.status))),
                Chip(
                  avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text(
                    truck == null
                        ? context.l10n.notAvailable
                        : '${truck.plateNumber}${truck.fleetCode == null ? '' : ' · ${truck.fleetCode}'}',
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              context.l10n.nextStop,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(next?.name ?? context.l10n.notAvailable),
            Text(next?.address ?? context.l10n.notAvailable),
            const SizedBox(height: 12),
            _InfoRow(
              context.l10n.remainingDistance,
              distance == null
                  ? context.l10n.notAvailable
                  : '${(distance / 1000).toStringAsFixed(1)} km',
            ),
            _InfoRow(
              context.l10n.estimatedArrival,
              eta == null ? context.l10n.notAvailable : _time(eta),
            ),
            _InfoRow(
              context.l10n.lastPositionUpdate,
              updated == null ? context.l10n.notAvailable : _time(updated),
            ),
            _InfoRow(
              context.l10n.allowedDriverAction,
              workspace.allowedActions.isEmpty
                  ? context.l10n.noActionAvailable
                  : workspace.allowedActions
                        .map((item) => localizedStatus(context.l10n, item))
                        .join(', '),
            ),
          ],
        ),
      ),
    );
  }

  String _trackingLabel(BuildContext context, String state) => switch (state) {
    'TRIP_ASSIGNED_NO_TELEMETRY' => context.l10n.trackingNotStarted,
    'TRUCK_POSITION_STALE' => context.l10n.trackingStale,
    'TRUCK_OFFLINE' => context.l10n.trackingOffline,
    _ => context.l10n.trackingCurrent,
  };

  static String _time(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 170, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRefresh,
  });
  final IconData icon;
  final String title, message;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      children: [
        const SizedBox(height: 150),
        Icon(icon, size: 64),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.message,
    required this.onConfirm,
  });
  final String label, message;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: FilledButton.icon(
      key: Key(label),
      icon: const Icon(Icons.task_alt),
      label: Text(label),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(label),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        );
        if (confirmed == true) onConfirm();
      },
    ),
  );
}
