import 'package:flutter/material.dart';

import '../domain/active_operation.dart';
import '../../../l10n/l10n_extensions.dart';

class ActiveOperationCard extends StatelessWidget {
  const ActiveOperationCard({required this.operation, this.onTap, super.key});

  final ActiveOperation operation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = operation.needsAttention
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      key: Key('active-operation-${operation.tripId}'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${operation.tripNumber} · ${operation.truckPlateNumber ?? '—'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(_phase(context, operation.operationalPhase)),
                  ),
                ],
              ),
              Text(
                [
                  operation.clientName,
                  if (operation.driverName != null) operation.driverName!,
                  if (operation.nextStopName != null)
                    '${_milestone(context, operation.nextMilestone)}: ${operation.nextStopName}',
                ].join(' • '),
              ),
              const SizedBox(height: 8),
              if (operation.isMoving) ...[
                LinearProgressIndicator(
                  value: (operation.progressPercent! / 100).clamp(0, 1),
                ),
                const SizedBox(height: 4),
                Text(
                  '${operation.progressPercent!.toStringAsFixed(0)}% · ${_distance(context, operation.remainingDistanceMeters)}'
                  '${operation.estimatedArrivalAt == null ? '' : ' · ${context.l10n.etaShort(_time(operation.estimatedArrivalAt!))}'}',
                ),
              ] else
                Text(_waiting(context, operation.operationalPhase)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    operation.trackingHealth == 'Current'
                        ? Icons.gps_fixed
                        : Icons.gps_off,
                    size: 16,
                  ),
                  Text(_health(context, operation.trackingHealth)),
                  if (operation.needsAttention)
                    Text(
                      _attention(context, operation.attentionCode),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _phase(BuildContext context, String value) => switch (value) {
    'AwaitingDeparture' => context.l10n.phaseAwaitingDeparture,
    'ToPickup' => context.l10n.phaseToPickup,
    'AwaitingLoading' => context.l10n.phaseAwaitingLoading,
    'ToDelivery' => context.l10n.phaseToDelivery,
    'AwaitingDeliveryConfirmation' =>
      context.l10n.phaseAwaitingDeliveryConfirmation,
    'AwaitingCompletion' => context.l10n.phaseAwaitingCompletion,
    _ => localizedStatus(context.l10n, value),
  };

  static String _waiting(BuildContext context, String value) => switch (value) {
    'AwaitingDeparture' => context.l10n.waitingDriverDeparture,
    'AwaitingLoading' => context.l10n.waitingLoadingConfirmation,
    'AwaitingDeliveryConfirmation' => context.l10n.waitingDeliveryConfirmation,
    _ => context.l10n.progressUnavailable,
  };

  static String _milestone(BuildContext context, String value) =>
      switch (value) {
        'Pickup' => context.l10n.pickup,
        'Delivery' => context.l10n.delivery,
        'DriverDeparture' => context.l10n.departToPickup,
        'LoadingConfirmation' => context.l10n.confirmLoadedAndDepart,
        'DeliveryConfirmation' => context.l10n.confirmDelivery,
        _ => localizedStatus(context.l10n, value),
      };

  static String _health(BuildContext context, String value) => switch (value) {
    'Current' => context.l10n.trackingCurrent,
    'Stale' => context.l10n.trackingStale,
    'Offline' => context.l10n.trackingOffline,
    'NoTelemetry' => context.l10n.trackingNotStarted,
    _ => localizedStatus(context.l10n, value),
  };

  static String _attention(
    BuildContext context,
    String value,
  ) => switch (value) {
    'OFF_ROUTE' => context.l10n.offRoute,
    'TRACKING_OFFLINE' => context.l10n.trackingOffline,
    'TRACKING_STALE' => context.l10n.trackingStale,
    'TRACKING_MISSING' => context.l10n.trackingMissing,
    'AWAITING_DRIVER_DEPARTURE' => context.l10n.actionDriverDeparture,
    'AWAITING_LOADING_CONFIRMATION' => context.l10n.actionLoadingConfirmation,
    'AWAITING_DELIVERY_CONFIRMATION' => context.l10n.actionDeliveryConfirmation,
    _ => localizedStatus(context.l10n, value),
  };

  static String _distance(BuildContext context, double? meters) {
    if (meters == null) return context.l10n.notAvailable;
    return meters >= 1000
        ? context.l10n.remainingKilometers((meters / 1000).toStringAsFixed(1))
        : context.l10n.remainingMeters(meters.toStringAsFixed(0));
  }

  static String _time(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
