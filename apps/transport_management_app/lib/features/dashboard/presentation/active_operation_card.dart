import 'package:flutter/material.dart';

import '../domain/active_operation.dart';

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
                  Chip(label: Text(_phase(operation.operationalPhase))),
                ],
              ),
              Text(
                [
                  operation.clientName,
                  if (operation.driverName != null) operation.driverName!,
                  if (operation.nextStopName != null)
                    '${_milestone(operation.nextMilestone)}: ${operation.nextStopName}',
                ].join(' • '),
              ),
              const SizedBox(height: 8),
              if (operation.isMoving) ...[
                LinearProgressIndicator(
                  value: (operation.progressPercent! / 100).clamp(0, 1),
                ),
                const SizedBox(height: 4),
                Text(
                  '${operation.progressPercent!.toStringAsFixed(0)}% · ${_distance(operation.remainingDistanceMeters)}'
                  '${operation.estimatedArrivalAt == null ? '' : ' · ETA ${_time(operation.estimatedArrivalAt!)}'}',
                ),
              ] else
                Text(_waiting(operation.operationalPhase)),
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
                  Text(_health(operation.trackingHealth)),
                  if (operation.needsAttention)
                    Text(
                      _attention(operation.attentionCode),
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

  static String _phase(String value) => switch (value) {
    'AwaitingDeparture' => 'Awaiting departure',
    'ToPickup' => 'To pickup',
    'AwaitingLoading' => 'Awaiting loading',
    'ToDelivery' => 'To delivery',
    'AwaitingDeliveryConfirmation' => 'Awaiting delivery confirmation',
    'AwaitingCompletion' => 'Awaiting completion',
    _ => value,
  };

  static String _waiting(String value) => switch (value) {
    'AwaitingDeparture' => 'Waiting for Driver departure',
    'AwaitingLoading' => 'Waiting for loading confirmation',
    'AwaitingDeliveryConfirmation' => 'Waiting for delivery confirmation',
    _ => 'Progress is unavailable',
  };

  static String _milestone(String value) => switch (value) {
    'Pickup' => 'Pickup',
    'Delivery' => 'Delivery',
    'DriverDeparture' => 'Departure',
    'LoadingConfirmation' => 'Loading',
    'DeliveryConfirmation' => 'Delivery confirmation',
    _ => value,
  };

  static String _health(String value) => switch (value) {
    'Current' => 'Tracking current',
    'Stale' => 'Tracking stale',
    'Offline' => 'Tracking offline',
    'NoTelemetry' => 'No telemetry',
    _ => value,
  };

  static String _attention(String value) => switch (value) {
    'OFF_ROUTE' => 'Off route',
    'TRACKING_OFFLINE' => 'Tracking offline',
    'TRACKING_STALE' => 'Tracking stale',
    'TRACKING_MISSING' => 'Tracking missing',
    'AWAITING_DRIVER_DEPARTURE' => 'Action: Driver departure',
    'AWAITING_LOADING_CONFIRMATION' => 'Action: loading confirmation',
    'AWAITING_DELIVERY_CONFIRMATION' => 'Action: delivery confirmation',
    _ => value,
  };

  static String _distance(double? meters) {
    if (meters == null) return 'Distance unavailable';
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km remaining'
        : '${meters.toStringAsFixed(0)} m remaining';
  }

  static String _time(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
