import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../operations/domain/operations_models.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/operations_view.dart';
import '../../../../l10n/l10n_extensions.dart';

class TrucksScreen extends ConsumerWidget {
  const TrucksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationsView(
    builder: (context, ref, data) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                context.l10n.trucks,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-truck'),
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.newTruck),
                ),
            ],
          ),
        ),
        Expanded(
          child: data.trucks.isEmpty
              ? EmptyState(context.l10n.noTrucks)
              : RefreshIndicator(
                  onRefresh: ref
                      .read(operationsControllerProvider.notifier)
                      .reload,
                  child: ListView.builder(
                    itemCount: data.trucks.length,
                    itemBuilder: (_, i) => _TruckTile(data.trucks[i]),
                  ),
                ),
        ),
      ],
    ),
  );

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Truck? truck,
  ]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TruckForm(truck: truck),
    );
    if (data == null || !context.mounted) return;
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate((repo) => repo.saveTruck(data, truck?.id));
    if (context.mounted) showResult(context, ok);
  }
}

class _TruckTile extends ConsumerWidget {
  const _TruckTile(this.truck);
  final Truck truck;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(truck.plateNumber),
          content: Text(
            '${context.l10n.make}: ${truck.make ?? '—'}\n'
            '${context.l10n.model}: ${truck.model ?? '—'}\n'
            '${context.l10n.year}: ${truck.year ?? '—'}\n'
            '${context.l10n.status}: ${localizedStatus(context.l10n, truck.status)}\n'
            '${context.l10n.active}: ${truck.isActive ? context.l10n.yes : context.l10n.no}\n'
            '${context.l10n.notes}: ${truck.notes ?? '—'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
          ],
        ),
      ),
      leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
      title: Text(truck.plateNumber),
      subtitle: Text(
        '${[truck.make, truck.model, truck.year?.toString()].whereType<String>().join(' ')} • ${localizedStatus(context.l10n, truck.status)}${truck.isActive ? '' : ' • ${context.l10n.inactive}'}',
      ),
      trailing: !canManageOperations(ref)
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  return TrucksScreen._edit(context, ref, truck);
                }
                final ok = await ref
                    .read(operationsControllerProvider.notifier)
                    .mutate(
                      (repo) => value == 'deactivate'
                          ? repo.deactivate('trucks', truck.id)
                          : repo.setFleetStatus('trucks', truck.id, value),
                    );
                if (context.mounted) showResult(context, ok);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                if (truck.status != 'Available')
                  PopupMenuItem(
                    value: 'Available',
                    child: Text(context.l10n.setAvailable),
                  ),
                if (truck.status != 'Maintenance')
                  PopupMenuItem(
                    value: 'Maintenance',
                    child: Text(context.l10n.setMaintenance),
                  ),
                if (truck.isActive)
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text(context.l10n.deactivate),
                  ),
              ],
            ),
    ),
  );
}

class _TruckForm extends StatefulWidget {
  const _TruckForm({this.truck});
  final Truck? truck;
  @override
  State<_TruckForm> createState() => _TruckFormState();
}

class _TruckFormState extends State<_TruckForm> {
  final key = GlobalKey<FormState>();
  late final plate = TextEditingController(text: widget.truck?.plateNumber);
  late final make = TextEditingController(text: widget.truck?.make);
  late final model = TextEditingController(text: widget.truck?.model);
  late final year = TextEditingController(text: widget.truck?.year?.toString());
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.truck == null ? context.l10n.createTruck : context.l10n.editTruck,
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('truck-plate'),
              controller: plate,
              decoration: InputDecoration(labelText: context.l10n.plateNumber),
              validator: (value) => requiredText(context, value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: make,
              decoration: InputDecoration(labelText: context.l10n.make),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: model,
              decoration: InputDecoration(labelText: context.l10n.model),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.l10n.year),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('save-truck'),
        onPressed: () {
          if (!key.currentState!.validate()) return;
          final parsedYear = int.tryParse(year.text);
          if (year.text.isNotEmpty &&
              (parsedYear == null || parsedYear < 1900 || parsedYear > 2100)) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.validYear)));
            return;
          }
          Navigator.pop(context, {
            'plateNumber': plate.text.trim(),
            'make': blankToNull(make.text),
            'model': blankToNull(model.text),
            'year': parsedYear,
            'notes': widget.truck?.notes,
          });
        },
        child: Text(context.l10n.save),
      ),
    ],
  );
}
