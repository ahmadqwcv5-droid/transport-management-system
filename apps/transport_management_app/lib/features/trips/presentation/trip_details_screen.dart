import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
import '../../../l10n/l10n_extensions.dart';
import 'trips_screen.dart';

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({required this.tripId, super.key});
  final String tripId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationsView(
    builder: (context, ref, data) {
      final trip = data.trips.where((item) => item.id == tripId).firstOrNull;
      if (trip == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.tripNotFound),
              TextButton(
                onPressed: () => context.go('/trips'),
                child: Text(context.l10n.backToTrips),
              ),
            ],
          ),
        );
      }
      final client = data.clients
          .where((item) => item.id == trip.clientId)
          .firstOrNull;
      final truck = data.trucks
          .where((item) => item.id == trip.truckId)
          .firstOrNull;
      final driver = data.drivers
          .where((item) => item.id == trip.driverId)
          .firstOrNull;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: context.l10n.backToTrips,
                onPressed: () => context.go('/trips'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${trip.origin} → ${trip.destination}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Chip(label: Text(localizedStatus(context.l10n, trip.status))),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  _Fact(
                    context.l10n.client,
                    client?.name ?? context.l10n.unknown,
                  ),
                  _Fact(context.l10n.cargo, trip.cargoDescription),
                  _Fact(
                    context.l10n.truck,
                    truck?.plateNumber ?? context.l10n.notAssigned,
                  ),
                  _Fact(
                    context.l10n.driver,
                    driver?.fullName ?? context.l10n.notAssigned,
                  ),
                  _Fact(context.l10n.planned, trip.plannedStartAt),
                  _Fact(context.l10n.price, trip.price.toStringAsFixed(2)),
                  if (trip.actualStartAt != null)
                    _Fact(context.l10n.started, trip.actualStartAt!),
                  if (trip.deliveredAt != null)
                    _Fact(context.l10n.delivered, trip.deliveredAt!),
                  if (trip.completedAt != null)
                    _Fact(context.l10n.completed, trip.completedAt!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (canManageOperations(ref))
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (trip.status == 'Draft')
                  OutlinedButton.icon(
                    onPressed: () => editTrip(context, ref, data, trip),
                    icon: const Icon(Icons.edit),
                    label: Text(context.l10n.editDraft),
                  ),
                for (final action in trip.allowedActions)
                  FilledButton(
                    key: Key('trip-action-$action'),
                    onPressed: () => action == 'assign'
                        ? _assign(context, ref, data, trip)
                        : _act(context, ref, trip, action),
                    child: Text(_label(context, action)),
                  ),
              ],
            ),
        ],
      );
    },
  );
  static String _label(BuildContext context, String value) => switch (value) {
    'assign' => context.l10n.assign,
    'start' => context.l10n.start,
    'mark-in-transit' => context.l10n.markInTransit,
    'deliver' => context.l10n.deliver,
    'complete' => context.l10n.complete,
    'cancel' => context.l10n.cancel,
    _ => value,
  };
  static Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    String action,
  ) async {
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate((repo) => repo.tripAction(trip.id, action));
    if (context.mounted) {
      showResult(context, ok, successMessage: context.l10n.tripStatusUpdated);
    }
  }

  static Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    OperationsData data,
    Trip trip,
  ) async {
    final assignment = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AssignmentDialog(data),
    );
    if (assignment == null || !context.mounted) return;
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate(
          (repo) => repo.assignTrip(trip.id, assignment[0], assignment[1]),
        );
    if (context.mounted) {
      showResult(context, ok, successMessage: context.l10n.resourcesAssigned);
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog(this.data);
  final OperationsData data;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late String? truckId = widget.data.trucks
      .where((item) => item.isActive && item.status == 'Available')
      .firstOrNull
      ?.id;
  late String? driverId = widget.data.drivers
      .where((item) => item.isActive && item.status == 'Available')
      .firstOrNull
      ?.id;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.assignResources),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('assign-truck'),
            initialValue: truckId,
            decoration: InputDecoration(labelText: context.l10n.truck),
            items: widget.data.trucks
                .where((item) => item.isActive && item.status == 'Available')
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.plateNumber),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => truckId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('assign-driver'),
            initialValue: driverId,
            decoration: InputDecoration(labelText: context.l10n.driver),
            items: widget.data.drivers
                .where((item) => item.isActive && item.status == 'Available')
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.fullName),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => driverId = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('confirm-assignment'),
        onPressed: truckId == null || driverId == null
            ? null
            : () => Navigator.pop(context, [truckId!, driverId!]),
        child: Text(context.l10n.assign),
      ),
    ],
  );
}
