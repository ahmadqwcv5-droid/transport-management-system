import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
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
              const Text('Trip not found.'),
              TextButton(
                onPressed: () => context.go('/trips'),
                child: const Text('Back to trips'),
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
                tooltip: 'Back to trips',
                onPressed: () => context.go('/trips'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${trip.origin} → ${trip.destination}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Chip(label: Text(trip.status)),
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
                  _Fact('Client', client?.name ?? 'Unknown'),
                  _Fact('Cargo', trip.cargoDescription),
                  _Fact('Truck', truck?.plateNumber ?? 'Not assigned'),
                  _Fact('Driver', driver?.fullName ?? 'Not assigned'),
                  _Fact('Planned', trip.plannedStartAt),
                  _Fact('Price', trip.price.toStringAsFixed(2)),
                  if (trip.actualStartAt != null)
                    _Fact('Started', trip.actualStartAt!),
                  if (trip.deliveredAt != null)
                    _Fact('Delivered', trip.deliveredAt!),
                  if (trip.completedAt != null)
                    _Fact('Completed', trip.completedAt!),
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
                    label: const Text('Edit draft'),
                  ),
                for (final action in trip.allowedActions)
                  FilledButton(
                    key: Key('trip-action-$action'),
                    onPressed: () => action == 'assign'
                        ? _assign(context, ref, data, trip)
                        : _act(context, ref, trip, action),
                    child: Text(_label(action)),
                  ),
              ],
            ),
        ],
      );
    },
  );
  static String _label(String value) => switch (value) {
    'mark-in-transit' => 'Mark in transit',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
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
      showResult(context, ok, successMessage: 'Trip status updated.');
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
      showResult(context, ok, successMessage: 'Truck and driver assigned.');
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
    title: const Text('Assign resources'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('assign-truck'),
            initialValue: truckId,
            decoration: const InputDecoration(labelText: 'Truck'),
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
            decoration: const InputDecoration(labelText: 'Driver'),
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
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm-assignment'),
        onPressed: truckId == null || driverId == null
            ? null
            : () => Navigator.pop(context, [truckId!, driverId!]),
        child: const Text('Assign'),
      ),
    ],
  );
}
