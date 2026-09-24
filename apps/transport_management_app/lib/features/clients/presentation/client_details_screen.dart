import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../locations/presentation/location_picker_dialog.dart';
import '../../operations/presentation/mutation_refresh_coordinator.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
import '../domain/client_models.dart';
import 'clients_screen.dart';

class ClientDetailsScreen extends ConsumerWidget {
  const ClientDetailsScreen({required this.clientId, super.key});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(clientDetailsProvider(clientId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.genericError)),
        data: (details) => RefreshIndicator(
          onRefresh: () => ref
              .read(mutationRefreshCoordinatorProvider)
              .refresh(clientId: clientId),
          child: ListView(
            key: const Key('client-details'),
            padding: const EdgeInsets.all(16),
            children: [
              _Header(details: details, clientId: clientId),
              const SizedBox(height: 12),
              _Profile(details.client),
              const SizedBox(height: 12),
              _Counts(details),
              const SizedBox(height: 12),
              _Contacts(clientId: clientId, items: details.contacts),
              const SizedBox(height: 12),
              _Sites(clientId: clientId, items: details.sites),
              const SizedBox(height: 12),
              _Trips(items: details.trips),
              const SizedBox(height: 12),
              _Events(items: details.events),
            ],
          ),
        ),
      );
}

class _Header extends ConsumerWidget {
  const _Header({required this.details, required this.clientId});
  final ClientDetails details;
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details.client.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Chip(
              label: Text(
                localizedStatus(context.l10n, details.client.lifecycleStatus),
              ),
            ),
          ],
        ),
      ),
      if (canManageOperations(ref))
        IconButton(
          key: const Key('edit-client-details'),
          icon: const Icon(Icons.edit_outlined),
          tooltip: context.l10n.edit,
          onPressed: () async {
            final data = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => ClientFormDialog(client: details.client),
            );
            if (data == null) return;
            final ok = await ref
                .read(mutationRefreshCoordinatorProvider)
                .mutate(
                  () => ref
                      .read(operationsRepositoryProvider)
                      .saveClient(data, clientId),
                  clientId: clientId,
                );
            if (context.mounted) showResult(context, ok);
          },
        ),
      if (canManageOperations(ref))
        PopupMenuButton<String>(
          key: const Key('client-lifecycle-menu'),
          onSelected: (status) async {
            if (status == 'Delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(context.l10n.delete),
                  content: Text(context.l10n.deleteClientWarning),
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
              if (confirmed != true) return;
            }
            final ok = await ref
                .read(mutationRefreshCoordinatorProvider)
                .mutate(
                  () => status == 'Delete'
                      ? ref
                            .read(operationsRepositoryProvider)
                            .deleteResource('clients', clientId)
                      : ref
                            .read(operationsRepositoryProvider)
                            .setClientLifecycle(clientId, status),
                  clientId: status == 'Delete' ? null : clientId,
                );
            if (context.mounted) {
              showResult(context, ok);
              if (ok && status == 'Delete') context.go('/clients');
            }
          },
          itemBuilder: (_) => [
            if (details.client.lifecycleStatus != 'Active')
              PopupMenuItem(
                value: 'Active',
                child: Text(context.l10n.reactivate),
              ),
            if (details.client.lifecycleStatus == 'Active')
              PopupMenuItem(
                value: 'Suspended',
                child: Text(context.l10n.suspend),
              ),
            if (details.client.lifecycleStatus != 'Archived')
              PopupMenuItem(
                value: 'Archived',
                child: Text(context.l10n.archive),
              ),
            if (details.client.lifecycleStatus == 'Archived')
              PopupMenuItem(value: 'Delete', child: Text(context.l10n.delete)),
          ],
        ),
    ],
  );
}

class _Profile extends StatelessWidget {
  const _Profile(this.client);
  final Client client;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.details,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _line(context.l10n.legalName, client.legalName),
          _line(context.l10n.contactPerson, client.contactPerson),
          _line(context.l10n.phone, client.phone),
          _line(context.l10n.email, client.email),
          _line(context.l10n.address, client.address),
          _line(context.l10n.notes, client.notes),
        ],
      ),
    ),
  );
}

class _Counts extends StatelessWidget {
  const _Counts(this.details);
  final ClientDetails details;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      Chip(
        label: Text(
          '${context.l10n.plannedTrips}: ${details.plannedTripCount}',
        ),
      ),
      Chip(
        label: Text('${context.l10n.activeTrips}: ${details.activeTripCount}'),
      ),
      Chip(
        label: Text(
          '${context.l10n.completedTrips}: ${details.completedTripCount}',
        ),
      ),
      Chip(
        label: Text(
          '${context.l10n.cancelledTrips}: ${details.cancelledTripCount}',
        ),
      ),
    ],
  );
}

class _Contacts extends ConsumerWidget {
  const _Contacts({required this.clientId, required this.items});
  final String clientId;
  final List<ClientContact> items;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.contacts,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (canManageOperations(ref))
                IconButton(
                  key: const Key('add-client-contact'),
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.addContact,
                  onPressed: () => _edit(context, ref),
                ),
            ],
          ),
          ...items.map(
            (item) => ListTile(
              leading: Icon(item.isPrimary ? Icons.star : Icons.person_outline),
              title: Text(item.name),
              subtitle: Text(
                [
                  item.jobTitle,
                  item.phone,
                  item.email,
                ].whereType<String>().join(' • '),
              ),
              onTap: canManageOperations(ref)
                  ? () => _edit(context, ref, item)
                  : null,
              trailing: !canManageOperations(ref)
                  ? null
                  : IconButton(
                      tooltip: context.l10n.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(mutationRefreshCoordinatorProvider)
                          .mutate(
                            () => ref
                                .read(operationsRepositoryProvider)
                                .deleteClientContact(clientId, item.id),
                            clientId: clientId,
                          ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ClientContact? item,
  ]) async {
    final name = TextEditingController(text: item?.name);
    final phone = TextEditingController(text: item?.phone);
    final email = TextEditingController(text: item?.email);
    var primary = item?.isPrimary ?? items.isEmpty;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.addContact),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('contact-name'),
                controller: name,
                decoration: InputDecoration(labelText: context.l10n.name),
              ),
              TextField(
                controller: phone,
                decoration: InputDecoration(labelText: context.l10n.phone),
              ),
              TextField(
                controller: email,
                decoration: InputDecoration(labelText: context.l10n.email),
              ),
              CheckboxListTile(
                value: primary,
                title: Text(context.l10n.primaryContact),
                onChanged: (value) => setState(() => primary = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'phone': blankToNull(phone.text),
                  'email': blankToNull(email.text),
                  'isPrimary': primary,
                });
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (data == null) return;
    await ref
        .read(mutationRefreshCoordinatorProvider)
        .mutate(
          () => ref
              .read(operationsRepositoryProvider)
              .saveClientContact(clientId, data, item?.id),
          clientId: clientId,
        );
  }
}

class _Sites extends ConsumerWidget {
  const _Sites({required this.clientId, required this.items});
  final String clientId;
  final List<ClientSite> items;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.sites,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (canManageOperations(ref))
                IconButton(
                  key: const Key('add-client-site'),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  tooltip: context.l10n.addSite,
                  onPressed: () => _edit(context, ref),
                ),
            ],
          ),
          ...items.map(
            (item) => ListTile(
              leading: Icon(
                item.isActive
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
              ),
              title: Text(item.name),
              subtitle: Text(
                '${localizedStatus(context.l10n, item.type)} • ${item.address ?? '${item.latitude}, ${item.longitude}'}',
              ),
              onTap: canManageOperations(ref)
                  ? () => _edit(context, ref, item)
                  : null,
              trailing: !canManageOperations(ref)
                  ? null
                  : IconButton(
                      tooltip: item.isActive
                          ? context.l10n.archive
                          : context.l10n.restore,
                      icon: Icon(
                        item.isActive
                            ? Icons.archive_outlined
                            : Icons.unarchive_outlined,
                      ),
                      onPressed: () => ref
                          .read(mutationRefreshCoordinatorProvider)
                          .mutate(
                            () => ref
                                .read(operationsRepositoryProvider)
                                .setClientSiteActive(
                                  clientId,
                                  item.id,
                                  !item.isActive,
                                ),
                            clientId: clientId,
                          ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ClientSite? item,
  ]) async {
    final name = TextEditingController(text: item?.name);
    final address = TextEditingController(text: item?.address);
    final latitude = TextEditingController(text: item?.latitude.toString());
    final longitude = TextEditingController(text: item?.longitude.toString());
    var type = item?.type ?? 'Other';
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.addSite),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('site-name'),
                  controller: name,
                  decoration: InputDecoration(labelText: context.l10n.name),
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: context.l10n.siteType),
                  items:
                      const [
                            'Factory',
                            'Warehouse',
                            'Pickup',
                            'Delivery',
                            'Office',
                            'Other',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(localizedStatus(context.l10n, value)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => type = value!),
                ),
                TextField(
                  controller: address,
                  decoration: InputDecoration(labelText: context.l10n.address),
                ),
                TextField(
                  key: const Key('site-latitude'),
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: context.l10n.latitude),
                ),
                TextField(
                  key: const Key('site-longitude'),
                  controller: longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.longitude,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const Key('site-select-map'),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(context.l10n.selectOnMap),
                    onPressed: () async {
                      final currentLat = double.tryParse(latitude.text);
                      final currentLng = double.tryParse(longitude.text);
                      final selected = await showLocationPickerDialog(
                        context: dialogContext,
                        title: context.l10n.selectOnMap,
                        search: (query) => ref
                            .read(operationsRepositoryProvider)
                            .searchLocations(query),
                        initial: currentLat == null || currentLng == null
                            ? null
                            : LocationSelection(
                                latitude: currentLat,
                                longitude: currentLng,
                              ),
                      );
                      if (selected == null) return;
                      latitude.text = selected.latitude.toStringAsFixed(6);
                      longitude.text = selected.longitude.toStringAsFixed(6);
                      if (address.text.trim().isEmpty &&
                          selected.label != null) {
                        address.text = selected.label!;
                      }
                    },
                  ),
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
              onPressed: () {
                final lat = double.tryParse(latitude.text),
                    lng = double.tryParse(longitude.text);
                if (name.text.trim().isEmpty || lat == null || lng == null) {
                  return;
                }
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'type': type,
                  'address': blankToNull(address.text),
                  'latitude': lat,
                  'longitude': lng,
                });
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (data == null) return;
    await ref
        .read(mutationRefreshCoordinatorProvider)
        .mutate(
          () => ref
              .read(operationsRepositoryProvider)
              .saveClientSite(clientId, data, item?.id),
          clientId: clientId,
        );
  }
}

class _Trips extends StatelessWidget {
  const _Trips({required this.items});
  final List<ResourceTripSummary> items;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.trips,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...items.map(
            (trip) => ListTile(
              title: Text(trip.tripNumber),
              subtitle: Text(
                [
                  '${trip.origin ?? '—'} → ${trip.destination ?? '—'}',
                  trip.truckPlate,
                  trip.driverName,
                ].whereType<String>().join(' • '),
              ),
              trailing: Text(localizedStatus(context.l10n, trip.status)),
              onTap: () => context.go('/trips/${trip.id}'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Events extends StatelessWidget {
  const _Events({required this.items});
  final List<OperationsEvent> items;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.activity,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (items.isEmpty) Text(context.l10n.noActivity),
          ...items.map(
            (event) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                localizedOperationsEvent(context.l10n, event.eventCode),
              ),
              subtitle: Text(event.occurredAt),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _line(String label, String? value) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Text('$label: ${value ?? '—'}'),
);
