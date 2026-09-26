import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../domain/live_operations_models.dart';

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

String notificationSnapshotDetail(
  BuildContext context,
  OperationNotification notification,
) {
  final data = notificationSnapshot(notification);
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  final driver = data['DriverName'] ?? data['driverName'];
  final stop =
      data['StopName'] ??
      data['stopName'] ??
      data['PickupName'] ??
      data['pickupName'];
  final address = data['StopAddress'] ?? data['stopAddress'];
  final details = <String>[
    notificationSnapshotIdentity(notification),
    if (driver is String && driver.isNotEmpty)
      '${arabic ? 'السائق' : 'Driver'}: $driver',
    if (stop is String && stop.isNotEmpty)
      '${arabic ? 'الموقع' : 'Stop'}: $stop',
    if (address is String && address.isNotEmpty) address,
  ];
  return details.where((value) => value.isNotEmpty).join('\n');
}
