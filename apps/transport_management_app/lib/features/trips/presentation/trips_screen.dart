import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationsView(
    builder: (context, ref, data) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Trips', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-trip'),
                  onPressed: () => editTrip(context, ref, data),
                  icon: const Icon(Icons.add),
                  label: const Text('New trip'),
                ),
            ],
          ),
        ),
        Expanded(
          child: data.trips.isEmpty
              ? const EmptyState('trips')
              : RefreshIndicator(
                  onRefresh: ref
                      .read(operationsControllerProvider.notifier)
                      .reload,
                  child: ListView.builder(
                    itemCount: data.trips.length,
                    itemBuilder: (_, i) {
                      final trip = data.trips[i];
                      final client = data.clients
                          .where((item) => item.id == trip.clientId)
                          .firstOrNull;
                      return Card(
                        child: ListTile(
                          key: Key('trip-${trip.id}'),
                          onTap: () => context.go('/trips/${trip.id}'),
                          leading: const CircleAvatar(child: Icon(Icons.route)),
                          title: Text('${trip.origin} → ${trip.destination}'),
                          subtitle: Text(
                            '${client?.name ?? 'Unknown client'} • ${trip.status}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

Future<void> editTrip(
  BuildContext context,
  WidgetRef ref,
  OperationsData data, [
  Trip? trip,
]) async {
  final request = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => TripForm(data: data, trip: trip),
  );
  if (request == null || !context.mounted) return;
  final ok = await ref
      .read(operationsControllerProvider.notifier)
      .mutate((repo) => repo.saveTrip(request, trip?.id));
  if (context.mounted) showResult(context, ok);
}

class TripForm extends StatefulWidget {
  const TripForm({required this.data, this.trip, super.key});
  final OperationsData data;
  final Trip? trip;
  @override
  State<TripForm> createState() => _TripFormState();
}

class _TripFormState extends State<TripForm> {
  final key = GlobalKey<FormState>();
  late String? clientId =
      widget.trip?.clientId ??
      widget.data.clients.where((c) => c.isActive).firstOrNull?.id;
  late final origin = TextEditingController(text: widget.trip?.origin);
  late final destination = TextEditingController(
    text: widget.trip?.destination,
  );
  late final cargo = TextEditingController(text: widget.trip?.cargoDescription);
  late final price = TextEditingController(
    text: widget.trip?.price.toString() ?? '0',
  );
  late final planned = TextEditingController(
    text:
        widget.trip?.plannedStartAt ??
        DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.trip == null ? 'Create trip' : 'Edit draft trip'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('trip-client'),
                initialValue: clientId,
                decoration: const InputDecoration(labelText: 'Client'),
                items: widget.data.clients
                    .where((c) => c.isActive)
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (value) => clientId = value,
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('trip-origin'),
                controller: origin,
                decoration: const InputDecoration(labelText: 'Origin'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('trip-destination'),
                controller: destination,
                decoration: const InputDecoration(labelText: 'Destination'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('trip-cargo'),
                controller: cargo,
                decoration: const InputDecoration(labelText: 'Cargo'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: planned,
                decoration: const InputDecoration(
                  labelText: 'Planned start (ISO 8601)',
                ),
                validator: (value) => DateTime.tryParse(value ?? '') == null
                    ? 'Enter a valid date'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('trip-price'),
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (value) {
                  final amount = num.tryParse(value ?? '');
                  return amount == null || amount < 0
                      ? 'Enter a valid price'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-trip'),
        onPressed: () {
          if (key.currentState!.validate()) {
            Navigator.pop(context, {
              'clientId': clientId,
              'origin': origin.text.trim(),
              'destination': destination.text.trim(),
              'cargoDescription': cargo.text.trim(),
              'plannedStartAt': DateTime.parse(
                planned.text,
              ).toUtc().toIso8601String(),
              'price': num.parse(price.text),
              'notes': widget.trip?.notes,
            });
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
