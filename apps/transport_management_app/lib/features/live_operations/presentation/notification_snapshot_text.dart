import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/live_operations_models.dart';
import '../../../l10n/l10n_extensions.dart';

Map<String, dynamic> notificationSnapshot(OperationNotification notification) {
  try {
    return notification.dataJson == null
        ? const {}
        : jsonDecode(notification.dataJson!) as Map<String, dynamic>;
  } on Object {
    return const {};
  }
}

String notificationSnapshotIdentity(OperationNotification notification) {
  final data = notificationSnapshot(notification);
  return [
    data['TripNumber'] ?? data['tripNumber'],
    data['PlateNumber'] ?? data['plateNumber'],
    data['FleetCode'] ?? data['fleetCode'],
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}

String notificationSnapshotMessage(
  BuildContext context,
  OperationNotification notification,
) {
  final data = notificationSnapshot(notification);
  if (data.isEmpty) return context.l10n.legacyNotificationFallback;
  final truck =
      _text(data, 'PlateNumber', 'plateNumber') ?? context.l10n.notAvailable;
  final trip =
      _text(data, 'TripNumber', 'tripNumber') ?? context.l10n.notAvailable;
  final location = _location(data, context);
  final time = _eventTime(data, notification.createdAt, context);
  return switch (notification.type) {
    'TripAssignedToDriver' => context.l10n.notificationAssignedSnapshot(
      truck,
      trip,
      location,
      time,
    ),
    'TruckArrivedAtPickup' => context.l10n.notificationPickupSnapshot(
      truck,
      trip,
      location,
      time,
    ),
    'DriverConfirmedDeparture' => context.l10n.notificationDepartureSnapshot(
      truck,
      trip,
      location,
      time,
    ),
    'TruckArrivedAtDelivery' => context.l10n.notificationDeliverySnapshot(
      truck,
      trip,
      location,
      time,
    ),
    'DriverConfirmedDelivery' => context.l10n.notificationCompletedSnapshot(
      truck,
      trip,
      location,
      time,
    ),
    'TruckBecameOffline' || 'TruckPositionBecameStale' =>
      context.l10n.notificationHealthSnapshot(truck, trip, location, time),
    _ => context.l10n.operationalTripAlertMessage,
  };
}

String notificationSnapshotDetail(
  BuildContext context,
  OperationNotification notification,
) {
  final data = notificationSnapshot(notification);
  final driver = _text(data, 'DriverName', 'driverName');
  final client = _text(data, 'ClientName', 'clientName');
  final cargo = _text(data, 'CargoSummary', 'cargoSummary');
  final details = <String>[
    notificationSnapshotMessage(context, notification),
    if (client != null) context.l10n.notificationClient(client),
    if (driver != null) context.l10n.notificationDriver(driver),
    if (cargo != null) context.l10n.notificationCargo(cargo),
  ];
  return details.where((value) => value.isNotEmpty).join('\n');
}

String? _text(Map<String, dynamic> data, String pascal, String camel) {
  final value = data[pascal] ?? data[camel];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _location(Map<String, dynamic> data, BuildContext context) {
  final name =
      _text(data, 'StopName', 'stopName') ??
      _text(data, 'PickupName', 'pickupName') ??
      _text(data, 'DeliveryName', 'deliveryName');
  final address =
      _text(data, 'StopAddress', 'stopAddress') ??
      _text(data, 'PickupAddress', 'pickupAddress') ??
      _text(data, 'DeliveryAddress', 'deliveryAddress');
  if (name != null && address != null) return '$name — $address';
  if (name != null) return name;
  if (address != null) return address;
  final latitude =
      data['StopLatitude'] ??
      data['stopLatitude'] ??
      data['Latitude'] ??
      data['latitude'];
  final longitude =
      data['StopLongitude'] ??
      data['stopLongitude'] ??
      data['Longitude'] ??
      data['longitude'];
  if (latitude is num && longitude is num) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
  return context.l10n.notAvailable;
}

String _eventTime(
  Map<String, dynamic> data,
  String fallback,
  BuildContext context,
) {
  final raw =
      data['EventAt'] ??
      data['eventAt'] ??
      data['ReachedAt'] ??
      data['reachedAt'] ??
      data['ConfirmedAt'] ??
      data['confirmedAt'] ??
      fallback;
  final parsed = DateTime.tryParse(raw.toString())?.toLocal();
  if (parsed == null) return raw.toString();
  final date = MaterialLocalizations.of(context).formatShortDate(parsed);
  final time = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(parsed));
  return '$date $time';
}
