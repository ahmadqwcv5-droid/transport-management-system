import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../trips/domain/trip_models.dart';
import 'live_operations_controller.dart';

class DriverMyTripScreen extends ConsumerWidget {
  const DriverMyTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(driverTripControllerProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.genericError)),
        data: (mine) {
          final trip = mine.trip;
          if (trip == null) {
            return RefreshIndicator(
              onRefresh: ref
                  .read(driverTripControllerProvider.notifier)
                  .refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 180),
                  Center(child: Text(context.l10n.noAssignedTrip)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: ref.read(driverTripControllerProvider.notifier).refresh,
            child: ListView(
              key: const Key('driver-my-trip'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.l10n.myTrip,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.tripNumber,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            localizedStatus(context.l10n, trip.status),
                          ),
                        ),
                        Text('${context.l10n.truck}: ${trip.truckId ?? '—'}'),
                        const Divider(),
                        ...trip.stops.map((stop) => _StopCard(stop: stop)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (trip.status == 'AtPickup')
                  _ActionButton(
                    label: context.l10n.confirmLoaded,
                    message: context.l10n.confirmLoadedWarning,
                    onConfirm: () => _confirm(context, ref, delivery: false),
                  ),
                if (trip.status == 'AtDelivery')
                  _ActionButton(
                    label: context.l10n.confirmDelivery,
                    message: context.l10n.confirmDeliveryWarning,
                    onConfirm: () => _confirm(context, ref, delivery: true),
                  ),
              ],
            ),
          );
        },
      );

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required bool delivery,
  }) async {
    final ok = await ref
        .read(driverTripControllerProvider.notifier)
        .confirm(delivery: delivery);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? context.l10n.actionConfirmed : context.l10n.genericError,
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});
  final TripStop stop;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(stop.type == 'Pickup' ? Icons.upload : Icons.download),
    title: Text(stop.name),
    subtitle: Text(stop.address ?? '—'),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.message,
    required this.onConfirm,
  });
  final String label, message;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: FilledButton.icon(
      key: Key(label),
      icon: const Icon(Icons.task_alt),
      label: Text(label),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(label),
            content: Text(message),
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
        if (confirmed == true) onConfirm();
      },
    ),
  );
}
