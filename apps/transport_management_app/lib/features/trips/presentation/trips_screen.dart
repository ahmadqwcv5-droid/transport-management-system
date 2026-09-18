import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
import '../../../l10n/l10n_extensions.dart';

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
              Text(
                context.l10n.trips,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
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
        Expanded(
          child: data.trips.isEmpty
              ? EmptyState(context.l10n.noTrips)
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
                            '${client?.name ?? context.l10n.unknownClient} • ${localizedStatus(context.l10n, trip.status)}',
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
