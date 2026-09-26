import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../operations/presentation/operations_controller.dart';
import 'trips_controller.dart';
import 'active_operations_controller.dart';
import 'active_operations_list.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(tripsControllerProvider);
    final controller = ref.read(tripsControllerProvider.notifier);
    final references = ref.watch(operationsControllerProvider).value;
    final groups = <String, String>{
      'active': context.l10n.tripTabActive,
      'planned': context.l10n.tripTabPlanned,
      'completed': context.l10n.tripTabCompleted,
      'cancelled': context.l10n.tripTabCancelled,
      'archived': context.l10n.tripTabArchived,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.l10n.trips,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  key: const Key('trip-search'),
                  onChanged: (value) {
                    controller.setSearch(value);
                    ref
                        .read(activeOperationsControllerProvider.notifier)
                        .setSearch(value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: context.l10n.searchTrips,
                  ),
                ),
              ),
              if (references != null)
                PopupMenuButton<String>(
                  key: const Key('trip-filter'),
                  tooltip: context.l10n.tripFilters,
                  icon: const Icon(Icons.filter_alt_outlined),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'clear',
                      child: Text(context.l10n.clearFilters),
                    ),
                    ...references.clients
                        .where((x) => x.isActive)
                        .map(
                          (item) => PopupMenuItem(
                            value: 'client:${item.id}',
                            child: Text(item.name),
                          ),
                        ),
                    ...references.trucks
                        .where((x) => x.isActive)
                        .map(
                          (item) => PopupMenuItem(
                            value: 'truck:${item.id}',
                            child: Text(item.plateNumber),
                          ),
                        ),
                    ...references.drivers
                        .where((x) => x.isActive)
                        .map(
                          (item) => PopupMenuItem(
                            value: 'driver:${item.id}',
                            child: Text(item.fullName),
                          ),
                        ),
                  ],
                  onSelected: (value) {
                    if (value == 'clear') {
                      controller.clearFilters();
                      ref
                          .read(activeOperationsControllerProvider.notifier)
                          .clearFilters();
                    }
                    if (value.startsWith('client:')) {
                      controller.setFilters(client: value.substring(7));
                      ref
                          .read(activeOperationsControllerProvider.notifier)
                          .setFilters(client: value.substring(7));
                    }
                    if (value.startsWith('truck:')) {
                      controller.setFilters(truck: value.substring(6));
                      ref
                          .read(activeOperationsControllerProvider.notifier)
                          .setFilters(truck: value.substring(6));
                    }
                    if (value.startsWith('driver:')) {
                      controller.setFilters(driver: value.substring(7));
                      ref
                          .read(activeOperationsControllerProvider.notifier)
                          .setFilters(driver: value.substring(7));
                    }
                  },
                ),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-trip'),
                  onPressed: () => context.go('/trips/new'),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.newTrip),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: groups.entries
                .map(
                  (entry) =>
                      ButtonSegment(value: entry.key, label: Text(entry.value)),
                )
                .toList(),
            selected: {controller.group},
            onSelectionChanged: (selection) =>
                controller.setGroup(selection.single),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: controller.group == 'active'
              ? const ActiveOperationsList()
              : page.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.l10n.genericError),
                        TextButton(
                          onPressed: controller.refresh,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                  ),
                  data: (result) {
                    if (result.items.isEmpty) {
                      return Center(child: Text(context.l10n.noTrips));
                    }
                    return RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView.builder(
                        itemCount: result.items.length + 1,
                        itemBuilder: (_, index) {
                          if (index == result.items.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    key: const Key('trips-previous-page'),
                                    tooltip: context.l10n.previousPage,
                                    onPressed: result.page > 1
                                        ? () => controller.goToPage(
                                            result.page - 1,
                                          )
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Text(
                                    context.l10n.pageOf(
                                      result.page,
                                      result.totalPages,
                                      result.totalCount,
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('trips-next-page'),
                                    tooltip: context.l10n.nextPage,
                                    onPressed: result.page < result.totalPages
                                        ? () => controller.goToPage(
                                            result.page + 1,
                                          )
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            );
                          }
                          final trip = result.items[index];
                          final client = references?.clients
                              .where((x) => x.id == trip.clientId)
                              .firstOrNull;
                          final truck = references?.trucks
                              .where((x) => x.id == trip.truckId)
                              .firstOrNull;
                          final driver = references?.drivers
                              .where((x) => x.id == trip.driverId)
                              .firstOrNull;
                          final route =
                              trip.origin == null || trip.destination == null
                              ? context.l10n.incompleteDraft
                              : '${trip.origin} → ${trip.destination}';
                          return Card(
                            child: ListTile(
                              key: Key('trip-${trip.id}'),
                              onTap: () => context.go('/trips/${trip.id}'),
                              leading: const CircleAvatar(
                                child: Icon(Icons.route),
                              ),
                              title: Text('${trip.tripNumber}  $route'),
                              subtitle: Text(
                                [
                                  client?.name ?? context.l10n.unknownClient,
                                  localizedStatus(context.l10n, trip.status),
                                  if (trip.plannedStartAt != null)
                                    trip.plannedStartAt!,
                                  if (truck != null) truck.plateNumber,
                                  if (driver != null) driver.fullName,
                                  if (!trip.readiness.canAssign &&
                                      trip.status == 'Draft')
                                    context.l10n.draftIncomplete,
                                ].join(' • '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
