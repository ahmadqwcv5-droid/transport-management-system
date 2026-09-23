import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fleet_models.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/operations_view.dart';
import '../../../../l10n/l10n_extensions.dart';

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
              Text(
                context.l10n.drivers,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-driver'),
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.newDriver),
                ),
            ],
          ),
        ),
        Expanded(
          child: data.drivers.isEmpty
              ? EmptyState(context.l10n.noDrivers)
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
            '${context.l10n.phone}: ${driver.phone ?? '—'}\n'
            '${context.l10n.license}: ${driver.licenseNumber}\n'
            '${context.l10n.licenseExpiry}: ${driver.licenseExpiryDate ?? '—'}\n'
            '${context.l10n.status}: ${localizedStatus(context.l10n, driver.status)}\n'
            '${context.l10n.active}: ${driver.isActive ? context.l10n.yes : context.l10n.no}\n'
            '${context.l10n.notes}: ${driver.notes ?? '—'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
          ],
        ),
      ),
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(driver.fullName),
      subtitle: Text(
        '${driver.licenseNumber} • ${localizedStatus(context.l10n, driver.status)}${driver.isActive ? '' : ' • ${context.l10n.inactive}'}',
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
                PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                if (driver.status != 'Available')
                  PopupMenuItem(
                    value: 'Available',
                    child: Text(context.l10n.setAvailable),
                  ),
                if (driver.status != 'Unavailable')
                  PopupMenuItem(
                    value: 'Unavailable',
                    child: Text(context.l10n.setUnavailable),
                  ),
                if (driver.isActive)
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text(context.l10n.deactivate),
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
    title: Text(
      widget.driver == null
          ? context.l10n.createDriver
          : context.l10n.editDriver,
    ),
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
              decoration: InputDecoration(labelText: context.l10n.fullName),
              validator: (value) => requiredText(context, value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              decoration: InputDecoration(labelText: context.l10n.phone),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('driver-license'),
              controller: license,
              decoration: InputDecoration(
                labelText: context.l10n.licenseNumber,
              ),
              validator: (value) => requiredText(context, value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: expiry,
              decoration: InputDecoration(
                labelText: context.l10n.licenseExpiry,
              ),
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
        child: Text(context.l10n.save),
      ),
    ],
  );
}
