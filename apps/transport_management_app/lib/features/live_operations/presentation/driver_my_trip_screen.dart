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
          final trip = workspace.currentTrip!;
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
                if (trip.status == 'AtPickup')
                  _ActionButton(
                    label: context.l10n.confirmLoaded,
                    message: context.l10n.confirmLoadedWarning,
                    onConfirm: () => _confirm(context, ref, delivery: false),
                  ),
                if (trip.status == 'AtDelivery')
                  _ActionButton(
                    label: context.l10n.confirmDelivery,
                    message: context.l10n.confirmDeliveryWarning,
                    onConfirm: () => _confirm(context, ref, delivery: true),
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
