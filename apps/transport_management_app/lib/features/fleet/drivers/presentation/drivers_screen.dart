import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../operations/domain/operations_models.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/operations_view.dart';

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationsView(
    builder: (context, ref, data) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Drivers', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-driver'),
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New driver'),
                ),
            ],
          ),
        ),
        Expanded(
          child: data.drivers.isEmpty
              ? const EmptyState('drivers')
              : RefreshIndicator(
                  onRefresh: ref
                      .read(operationsControllerProvider.notifier)
                      .reload,
                  child: ListView.builder(
                    itemCount: data.drivers.length,
                    itemBuilder: (_, i) => _DriverTile(data.drivers[i]),
                  ),
                ),
        ),
      ],
    ),
  );
  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Driver? driver,
  ]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DriverForm(driver: driver),
    );
    if (data == null || !context.mounted) return;
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate((repo) => repo.saveDriver(data, driver?.id));
    if (context.mounted) showResult(context, ok);
  }
}

class _DriverTile extends ConsumerWidget {
  const _DriverTile(this.driver);
  final Driver driver;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(driver.fullName),
          content: Text(
            'Phone: ${driver.phone ?? '—'}\n'
            'License: ${driver.licenseNumber}\n'
            'License expiry: ${driver.licenseExpiryDate ?? '—'}\n'
            'Status: ${driver.status}\n'
            'Active: ${driver.isActive ? 'Yes' : 'No'}\n'
            'Notes: ${driver.notes ?? '—'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(driver.fullName),
      subtitle: Text(
        '${driver.licenseNumber} • ${driver.status}${driver.isActive ? '' : ' • Inactive'}',
      ),
      trailing: !canManageOperations(ref)
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  return DriversScreen._edit(context, ref, driver);
                }
                final ok = await ref
                    .read(operationsControllerProvider.notifier)
                    .mutate(
                      (repo) => value == 'deactivate'
                          ? repo.deactivate('drivers', driver.id)
                          : repo.setFleetStatus('drivers', driver.id, value),
                    );
                if (context.mounted) showResult(context, ok);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (driver.status != 'Available')
                  const PopupMenuItem(
                    value: 'Available',
                    child: Text('Set available'),
                  ),
                if (driver.status != 'Unavailable')
                  const PopupMenuItem(
                    value: 'Unavailable',
                    child: Text('Set unavailable'),
                  ),
                if (driver.isActive)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text('Deactivate'),
                  ),
              ],
            ),
    ),
  );
}

class _DriverForm extends StatefulWidget {
  const _DriverForm({this.driver});
  final Driver? driver;
  @override
  State<_DriverForm> createState() => _DriverFormState();
}

class _DriverFormState extends State<_DriverForm> {
  final key = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.driver?.fullName);
  late final phone = TextEditingController(text: widget.driver?.phone);
  late final license = TextEditingController(
    text: widget.driver?.licenseNumber,
  );
  late final expiry = TextEditingController(
    text: widget.driver?.licenseExpiryDate,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.driver == null ? 'Create driver' : 'Edit driver'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('driver-name'),
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('driver-license'),
              controller: license,
              decoration: const InputDecoration(labelText: 'License number'),
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: expiry,
              decoration: const InputDecoration(
                labelText: 'License expiry (YYYY-MM-DD)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-driver'),
        onPressed: () {
          if (key.currentState!.validate()) {
            Navigator.pop(context, {
              'fullName': name.text.trim(),
              'phone': blankToNull(phone.text),
              'licenseNumber': license.text.trim(),
              'licenseExpiryDate': expiry.text.trim().isEmpty
                  ? null
                  : expiry.text.trim(),
              'notes': widget.driver?.notes,
            });
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
