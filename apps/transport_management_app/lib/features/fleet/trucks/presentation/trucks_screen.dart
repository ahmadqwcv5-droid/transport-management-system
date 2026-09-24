import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/fleet_models.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/mutation_refresh_coordinator.dart';
import '../../../operations/presentation/operations_view.dart';
import '../../../../l10n/l10n_extensions.dart';
import '../../../../shared/widgets/truck_avatar.dart';

class TrucksScreen extends ConsumerStatefulWidget {
  const TrucksScreen({super.key});
  @override
  ConsumerState<TrucksScreen> createState() => _TrucksScreenState();

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Truck? truck,
  ]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TruckFormDialog(
        truck: truck,
        drivers:
            ref.read(operationsControllerProvider).value?.drivers ?? const [],
      ),
    );
    if (data == null || !context.mounted) return;
    final ok = await ref
        .read(mutationRefreshCoordinatorProvider)
        .mutate(
          () =>
              ref.read(operationsRepositoryProvider).saveTruck(data, truck?.id),
          truckId: truck?.id,
        );
    if (context.mounted) showResult(context, ok);
  }
}

class _TrucksScreenState extends ConsumerState<TrucksScreen> {
  String search = '';
  String? status, type, operationalState;

  void _filter() => ref
      .read(operationsControllerProvider.notifier)
      .filterTrucks(
        search,
        status: status,
        type: type,
        operationalState: operationalState,
      );

  @override
  Widget build(BuildContext context) => OperationsView(
    builder: (context, ref, data) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  key: const Key('trucks-search'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: context.l10n.searchTrucks,
                  ),
                  onChanged: (value) {
                    search = value;
                    _filter();
                  },
                ),
              ),
              DropdownButton<String?>(
                value: status,
                hint: Text(context.l10n.baseStatus),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.l10n.all),
                  ),
                  ...[
                    'Available',
                    'Maintenance',
                    'OutOfService',
                    'Archived',
                  ].map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: Text(localizedStatus(context.l10n, value)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => status = value);
                  _filter();
                },
              ),
              DropdownButton<String?>(
                value: type,
                hint: Text(context.l10n.truckType),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.l10n.all),
                  ),
                  ...[
                    'BoxTruck',
                    'Flatbed',
                    'Refrigerated',
                    'Tanker',
                    'TractorTrailer',
                    'DumpTruck',
                    'Other',
                  ].map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: Text(localizedStatus(context.l10n, value)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => type = value);
                  _filter();
                },
              ),
              DropdownButton<String?>(
                value: operationalState,
                hint: Text(context.l10n.operationalState),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.l10n.all),
                  ),
                  ...[
                    'Available',
                    'Reserved',
                    'EnRouteToPickup',
                    'AtPickup',
                    'OnTrip',
                  ].map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: Text(localizedStatus(context.l10n, value)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => operationalState = value);
                  _filter();
                },
              ),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-truck'),
                  onPressed: () => TrucksScreen._edit(context, ref),
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
}

class _TruckTile extends ConsumerWidget {
  const _TruckTile(this.truck);
  final Truck truck;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      onTap: () => context.go('/trucks/${truck.id}'),
      leading: TruckAvatar(
        photoUrl: truck.photoThumbnailUrl,
        photoVersion: truck.photoVersion,
      ),
      title: Text(truck.plateNumber),
      subtitle: Text(
        '${[truck.fleetCode, truck.make, truck.model, truck.type].whereType<String>().join(' ')} • ${localizedStatus(context.l10n, truck.operationalState)}',
      ),
      trailing: !canManageOperations(ref)
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  return TrucksScreen._edit(context, ref, truck);
                }
                final ok = await ref
                    .read(mutationRefreshCoordinatorProvider)
                    .mutate(
                      () => value == 'deactivate'
                          ? ref
                                .read(operationsRepositoryProvider)
                                .setFleetStatus('trucks', truck.id, 'Archived')
                          : ref
                                .read(operationsRepositoryProvider)
                                .setFleetStatus('trucks', truck.id, value),
                      truckId: truck.id,
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

class TruckFormDialog extends StatefulWidget {
  const TruckFormDialog({this.truck, required this.drivers, super.key});
  final Truck? truck;
  final List<Driver> drivers;
  @override
  State<TruckFormDialog> createState() => _TruckFormState();
}

class _TruckFormState extends State<TruckFormDialog> {
  final key = GlobalKey<FormState>();
  late final plate = TextEditingController(text: widget.truck?.plateNumber);
  late final make = TextEditingController(text: widget.truck?.make);
  late final model = TextEditingController(text: widget.truck?.model);
  late final year = TextEditingController(text: widget.truck?.year?.toString());
  late final fleetCode = TextEditingController(text: widget.truck?.fleetCode);
  late final vin = TextEditingController(text: widget.truck?.vin);
  late final payload = TextEditingController(
    text: widget.truck?.payloadCapacity?.toString(),
  );
  late final odometer = TextEditingController(
    text: widget.truck?.odometerKilometers?.toString(),
  );
  late String? type = widget.truck?.type;
  late String? fuelType = widget.truck?.fuelType;
  late String payloadUnit = widget.truck?.payloadUnit ?? 'Kilograms';
  late String? defaultDriverId = widget.truck?.defaultDriverId;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.truck == null ? context.l10n.createTruck : context.l10n.editTruck,
    ),
    content: SizedBox(
      width: 560,
      child: Form(
        key: key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('truck-plate'),
                controller: plate,
                decoration: InputDecoration(
                  labelText: context.l10n.plateNumber,
                ),
                validator: (value) => requiredText(context, value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('truck-fleet-code'),
                controller: fleetCode,
                decoration: InputDecoration(labelText: context.l10n.fleetCode),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('truck-vin'),
                controller: vin,
                decoration: InputDecoration(labelText: context.l10n.vin),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(labelText: context.l10n.truckType),
                items:
                    const [
                          'BoxTruck',
                          'Flatbed',
                          'Refrigerated',
                          'Tanker',
                          'TractorTrailer',
                          'DumpTruck',
                          'Other',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(localizedStatus(context.l10n, value)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => type = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: payload,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.payloadCapacity,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: payloadUnit,
                      decoration: InputDecoration(
                        labelText: context.l10n.payloadUnit,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Kilograms',
                          child: Text(context.l10n.kilograms),
                        ),
                        DropdownMenuItem(
                          value: 'Tonnes',
                          child: Text(context.l10n.tonnes),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => payloadUnit = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: fuelType,
                decoration: InputDecoration(labelText: context.l10n.fuelType),
                items: const ['Diesel', 'Petrol', 'Electric', 'Hybrid', 'Other']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(localizedStatus(context.l10n, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => fuelType = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: odometer,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: context.l10n.odometer),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: defaultDriverId,
                decoration: InputDecoration(
                  labelText: context.l10n.defaultDriver,
                ),
                items: widget.drivers
                    .where((driver) => driver.isActive)
                    .map(
                      (driver) => DropdownMenuItem(
                        value: driver.id,
                        child: Text(driver.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => defaultDriverId = value),
              ),
            ],
          ),
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
          final parsedPayload = double.tryParse(payload.text);
          final parsedOdometer = double.tryParse(odometer.text);
          if (year.text.isNotEmpty &&
              (parsedYear == null || parsedYear < 1900 || parsedYear > 2100)) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.validYear)));
            return;
          }
          if ((payload.text.isNotEmpty &&
                  (parsedPayload == null || parsedPayload < 0)) ||
              (odometer.text.isNotEmpty &&
                  (parsedOdometer == null || parsedOdometer < 0))) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.invalidNumber)));
            return;
          }
          Navigator.pop(context, {
            'plateNumber': plate.text.trim(),
            'fleetCode': blankToNull(fleetCode.text),
            'vin': blankToNull(vin.text),
            'make': blankToNull(make.text),
            'model': blankToNull(model.text),
            'year': parsedYear,
            'type': type,
            'payloadCapacity': parsedPayload,
            'payloadUnit': payloadUnit,
            'fuelType': fuelType,
            'odometerKilometers': parsedOdometer,
            'defaultDriverId': defaultDriverId,
            'notes': widget.truck?.notes,
          });
        },
        child: Text(context.l10n.save),
      ),
    ],
  );
}
