import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

String localizedStatus(AppLocalizations l10n, String value) => switch (value) {
  'Available' => l10n.available,
  'OnTrip' => l10n.onTrip,
  'Maintenance' => l10n.maintenance,
  'OutOfService' => l10n.outOfService,
  'Unavailable' => l10n.unavailable,
  'Draft' => l10n.draft,
  'Assigned' => l10n.assigned,
  'Started' => l10n.started,
  'InTransit' => l10n.inTransit,
  'Delivered' => l10n.delivered,
  'Completed' => l10n.completed,
  'Cancelled' => l10n.cancelled,
  'Online' => l10n.online,
  'Offline' => l10n.offline,
  _ => value,
};

String localizedErrorCode(AppLocalizations l10n, String? code) =>
    switch (code) {
      'AUTHENTICATION_FAILED' => l10n.authenticationFailed,
      'INVALID_TRIP_TRANSITION' => l10n.invalidTripTransition,
      'TRUCK_ALREADY_ASSIGNED' => l10n.truckAlreadyAssigned,
      'DRIVER_ALREADY_ASSIGNED' => l10n.driverAlreadyAssigned,
      'TRUCK_NOT_AVAILABLE' => l10n.truckNotAvailable,
      'DRIVER_NOT_AVAILABLE' => l10n.driverNotAvailable,
      'CLIENT_NOT_FOUND' => l10n.clientNotFound,
      'SIMULATOR_DISABLED' => l10n.simulatorDisabled,
      _ => l10n.genericError,
    };
