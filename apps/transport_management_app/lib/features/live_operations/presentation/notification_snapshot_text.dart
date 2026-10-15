import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extensions.dart';
import '../domain/live_operations_models.dart';

enum NotificationCategory { trip, fleet, peopleAccess, security, system }

const emittedNotificationTypes = <String>{
  'TripAssignedToDriver',
  'TruckArrivedAtPickup',
  'TruckArrivedAtDelivery',
  'DriverConfirmedDeparture',
  'DriverConfirmedDelivery',
  'TruckBecameOffline',
  'TruckPositionBecameStale',
  'CompanyInvitationCreated',
  'CompanyInvitationAccepted',
  'CompanyInvitationDeclined',
  'CompanyInvitationRevoked',
  'CompanyInvitationExpired',
  'CompanyConnectionRequested',
  'CompanyConnectionApproved',
  'CompanyConnectionRejected',
  'CompanyConnectionCancelled',
  'MembershipActive',
  'MembershipReactivated',
  'MembershipSuspended',
  'MembershipRevoked',
  'MembershipRolesUpdated',
  'DriverLinked',
  'DriverUnlinked',
  'TruckQrGenerated',
  'TruckQrRegenerated',
  'TruckSessionStarted',
  'TruckSessionEnded',
  'TruckSessionSwitched',
  'TruckDefaultDriverChanged',
  'DriverHandoverRequested',
  'DriverHandoverPending',
  'DriverHandoverApproved',
  'DriverHandoverRejected',
  'ExternalLoginLinked',
  'ExternalLoginUnlinked',
  'PasswordChanged',
};

const supportedLegacyNotificationTypes = <String>{};

final class NotificationPresentation {
  const NotificationPresentation({
    required this.category,
    required this.title,
    required this.body,
    required this.icon,
    required this.highVisibility,
    this.destination,
  });

  final NotificationCategory category;
  final String title;
  final String body;
  final IconData icon;
  final bool highVisibility;
  final String? destination;
}

NotificationPresentation notificationPresentation(
  BuildContext context,
  OperationNotification notification, {
  String? role,
}) {
  final type = notification.type;
  final data = notificationSnapshot(notification);
  final category = notificationTypeCategory(type);
  final title = notificationTypeTitle(context, type);
  final identity = notificationSnapshotIdentity(notification);
  final body =
      _operationalMessage(context, notification, data) ??
      (emittedNotificationTypes.contains(type) ||
              supportedLegacyNotificationTypes.contains(type)
          ? context.l10n.notificationEventDetail(
              title,
              identity.isEmpty ? context.l10n.notAvailable : identity,
            )
          : '${context.l10n.legacyNotificationFallback} (${_safeType(type)})');
  return NotificationPresentation(
    category: category,
    title: title,
    body: body,
    icon: notificationTypeIcon(type),
    highVisibility: notificationTypeIsActionable(type),
    destination: notificationDestination(notification, role: role),
  );
}

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
  final values = <String?>[
    _text(data, 'DisplayName', 'displayName'),
    _text(data, 'Email', 'email'),
    _text(data, 'DriverName', 'driverName'),
    _text(data, 'TripNumber', 'tripNumber'),
    _text(data, 'PlateNumber', 'plateNumber'),
    _text(data, 'FleetCode', 'fleetCode'),
    _text(data, 'Provider', 'provider'),
  ];
  return values
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(' · ');
}

String notificationSnapshotMessage(
  BuildContext context,
  OperationNotification notification,
) => notificationPresentation(context, notification).body;

String notificationSnapshotDetail(
  BuildContext context,
  OperationNotification notification,
) {
  final presentation = notificationPresentation(context, notification);
  final data = notificationSnapshot(notification);
  final driver = _text(data, 'DriverName', 'driverName');
  final client = _text(data, 'ClientName', 'clientName');
  final cargo = _text(data, 'CargoSummary', 'cargoSummary');
  return <String>[
    presentation.body,
    if (client != null) context.l10n.notificationClient(client),
    if (driver != null && !presentation.body.contains(driver))
      context.l10n.notificationDriver(driver),
    if (cargo != null) context.l10n.notificationCargo(cargo),
  ].where((value) => value.isNotEmpty).join('\n');
}

NotificationCategory notificationTypeCategory(String type) {
  if (const {
    'TripAssignedToDriver',
    'TruckArrivedAtPickup',
    'TruckArrivedAtDelivery',
    'DriverConfirmedDeparture',
    'DriverConfirmedDelivery',
    'DriverHandoverRequested',
    'DriverHandoverPending',
    'DriverHandoverApproved',
    'DriverHandoverRejected',
  }.contains(type)) {
    return NotificationCategory.trip;
  }
  if (const {
    'TruckBecameOffline',
    'TruckPositionBecameStale',
    'TruckQrGenerated',
    'TruckQrRegenerated',
    'TruckSessionStarted',
    'TruckSessionEnded',
    'TruckSessionSwitched',
    'TruckDefaultDriverChanged',
  }.contains(type)) {
    return NotificationCategory.fleet;
  }
  if (const {
    'CompanyInvitationCreated',
    'CompanyInvitationAccepted',
    'CompanyInvitationDeclined',
    'CompanyInvitationRevoked',
    'CompanyInvitationExpired',
    'CompanyConnectionRequested',
    'CompanyConnectionApproved',
    'CompanyConnectionRejected',
    'CompanyConnectionCancelled',
    'MembershipActive',
    'MembershipReactivated',
    'MembershipSuspended',
    'MembershipRevoked',
    'MembershipRolesUpdated',
    'DriverLinked',
    'DriverUnlinked',
  }.contains(type)) {
    return NotificationCategory.peopleAccess;
  }
  if (const {
    'ExternalLoginLinked',
    'ExternalLoginUnlinked',
    'PasswordChanged',
  }.contains(type)) {
    return NotificationCategory.security;
  }
  return NotificationCategory.system;
}

String notificationCategoryLabel(
  BuildContext context,
  NotificationCategory category,
) => switch (category) {
  NotificationCategory.trip => context.l10n.notificationCategoryTrip,
  NotificationCategory.fleet => context.l10n.notificationCategoryFleet,
  NotificationCategory.peopleAccess =>
    context.l10n.notificationCategoryPeopleAccess,
  NotificationCategory.security => context.l10n.notificationCategorySecurity,
  NotificationCategory.system => context.l10n.notificationCategorySystem,
};

String notificationTypeTitle(
  BuildContext context,
  String type,
) => switch (type) {
  'TruckArrivedAtPickup' => context.l10n.notificationArrivedPickup,
  'TruckArrivedAtDelivery' => context.l10n.notificationArrivedDelivery,
  'DriverConfirmedDeparture' => context.l10n.notificationDepartureConfirmed,
  'DriverConfirmedDelivery' => context.l10n.notificationDeliveryConfirmed,
  'TripAssignedToDriver' => context.l10n.notificationTripAssigned,
  'TruckBecameOffline' => context.l10n.notificationTruckOffline,
  'TruckPositionBecameStale' => context.l10n.notificationPositionStale,
  'CompanyInvitationCreated' => context.l10n.notificationInvitationCreated,
  'CompanyInvitationAccepted' => context.l10n.notificationInvitationAccepted,
  'CompanyInvitationDeclined' => context.l10n.notificationInvitationDeclined,
  'CompanyInvitationRevoked' => context.l10n.notificationInvitationRevoked,
  'CompanyInvitationExpired' => context.l10n.notificationInvitationExpired,
  'CompanyConnectionRequested' => context.l10n.notificationConnectionRequested,
  'CompanyConnectionApproved' => context.l10n.notificationConnectionApproved,
  'CompanyConnectionRejected' => context.l10n.notificationConnectionRejected,
  'CompanyConnectionCancelled' => context.l10n.notificationConnectionCancelled,
  'MembershipActive' ||
  'MembershipReactivated' => context.l10n.notificationMembershipActivated,
  'MembershipSuspended' => context.l10n.notificationMembershipSuspended,
  'MembershipRevoked' => context.l10n.notificationMembershipRevoked,
  'MembershipRolesUpdated' => context.l10n.notificationMembershipRolesUpdated,
  'DriverLinked' => context.l10n.notificationDriverLinked,
  'DriverUnlinked' => context.l10n.notificationDriverUnlinked,
  'TruckQrGenerated' => context.l10n.notificationQrGenerated,
  'TruckQrRegenerated' => context.l10n.notificationQrRegenerated,
  'TruckSessionStarted' => context.l10n.notificationSessionStarted,
  'TruckSessionEnded' => context.l10n.notificationSessionEnded,
  'TruckSessionSwitched' => context.l10n.notificationSessionSwitched,
  'TruckDefaultDriverChanged' => context.l10n.notificationDefaultDriverChanged,
  'DriverHandoverRequested' => context.l10n.notificationHandoverRequested,
  'DriverHandoverPending' => context.l10n.notificationHandoverPending,
  'DriverHandoverApproved' => context.l10n.notificationHandoverApproved,
  'DriverHandoverRejected' => context.l10n.notificationHandoverRejected,
  'ExternalLoginLinked' => context.l10n.notificationExternalLoginLinked,
  'ExternalLoginUnlinked' => context.l10n.notificationExternalLoginUnlinked,
  'PasswordChanged' => context.l10n.notificationPasswordChanged,
  _ => context.l10n.notificationSystemEvent,
};

IconData notificationTypeIcon(String type) =>
    switch (notificationTypeCategory(type)) {
      NotificationCategory.trip =>
        type.contains('Arrived')
            ? Icons.location_on
            : type.contains('Handover')
            ? Icons.swap_horiz
            : Icons.assignment_ind_outlined,
      NotificationCategory.fleet =>
        type.contains('Offline') || type.contains('Stale')
            ? Icons.signal_wifi_connected_no_internet_4
            : type.contains('Qr')
            ? Icons.qr_code_2
            : Icons.local_shipping_outlined,
      NotificationCategory.peopleAccess => Icons.manage_accounts_outlined,
      NotificationCategory.security => Icons.security_outlined,
      NotificationCategory.system => Icons.info_outline,
    };

bool notificationTypeIsActionable(String type) => const {
  'TripAssignedToDriver',
  'TruckArrivedAtPickup',
  'TruckArrivedAtDelivery',
  'TruckBecameOffline',
  'TruckPositionBecameStale',
  'CompanyConnectionRequested',
  'DriverHandoverRequested',
  'DriverHandoverPending',
  'ExternalLoginLinked',
  'ExternalLoginUnlinked',
  'PasswordChanged',
}.contains(type);

String? notificationDestination(
  OperationNotification notification, {
  String? role,
}) {
  final category = notificationTypeCategory(notification.type);
  if (role == 'Driver' &&
      (category == NotificationCategory.trip ||
          notification.type.startsWith('TruckSession'))) {
    return '/my-trip';
  }
  if (category == NotificationCategory.peopleAccess) return '/company-users';
  if (category == NotificationCategory.security) return '/settings';
  if (notification.tripId != null) return '/trips/${notification.tripId}';
  if (notification.truckId != null) return '/trucks/${notification.truckId}';
  return null;
}

String? _operationalMessage(
  BuildContext context,
  OperationNotification notification,
  Map<String, dynamic> data,
) {
  if (!const {
    'TripAssignedToDriver',
    'TruckArrivedAtPickup',
    'DriverConfirmedDeparture',
    'TruckArrivedAtDelivery',
    'DriverConfirmedDelivery',
    'TruckBecameOffline',
    'TruckPositionBecameStale',
  }.contains(notification.type)) {
    return null;
  }
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
    _ => context.l10n.notificationHealthSnapshot(truck, trip, location, time),
  };
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
  final value =
      data['eventAt'] ??
      data['EventAt'] ??
      data['reachedAt'] ??
      data['ReachedAt'] ??
      data['confirmedAt'] ??
      data['ConfirmedAt'] ??
      fallback;
  final parsed = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (parsed == null) return context.l10n.notAvailable;
  return '${parsed.year}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')} '
      '${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}

String _safeType(String type) {
  final safe = type.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return safe.length <= 80 ? safe : safe.substring(0, 80);
}
