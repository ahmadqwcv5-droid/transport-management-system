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
  'EnRouteToPickup' => l10n.enRouteToPickup,
  'AtPickup' => l10n.atPickup,
  'Started' => l10n.started,
  'InTransit' => l10n.inTransit,
  'Delivered' => l10n.delivered,
  'Completed' => l10n.completed,
  'Cancelled' => l10n.cancelled,
  'Proposed' => l10n.proposed,
  'Active' => l10n.active,
  'Expired' => l10n.expired,
  'Online' => l10n.online,
  'Offline' => l10n.offline,
  'Pickup' => l10n.pickup,
  'Delivery' => l10n.delivery,
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
      'TRUCK_POSITION_REQUIRED' => l10n.truckPositionRequired,
      'TRUCK_POSITION_STALE' => l10n.truckPositionStale,
      'TRUCK_OFFLINE' => l10n.truckOfflineForDispatch,
      'REPOSITIONING_ROUTE_REQUIRED' => l10n.repositioningRouteRequired,
      'REPOSITIONING_ROUTE_STALE' => l10n.repositioningRouteStale,
      'TRUCK_NOT_AT_PICKUP' => l10n.truckNotAtPickup,
      'TRIP_NOT_READY_FOR_ROUTE' => l10n.tripNotReadyForRoute,
      'TRIP_NOT_READY_FOR_ASSIGNMENT' => l10n.tripNotReadyForAssignment,
      'TRIP_DELETE_NOT_ALLOWED' => l10n.tripDeleteNotAllowed,
      'TRIP_CANCEL_REASON_REQUIRED' => l10n.tripCancelReasonRequired,
      'TRIP_ARCHIVE_NOT_ALLOWED' => l10n.tripArchiveNotAllowed,
      'TRIP_REASSIGN_NOT_ALLOWED' => l10n.tripReassignNotAllowed,
      'TRIP_UNASSIGN_NOT_ALLOWED' => l10n.tripUnassignNotAllowed,
      'TRIP_CONCURRENCY_CONFLICT' => l10n.tripConcurrencyConflict,
      'ROUTING_UNAVAILABLE' => l10n.routeProviderUnavailable,
      'ROUTING_PROVIDER_FAILURE' => l10n.routeProviderUnavailable,
      'ROUTING_TIMEOUT' => l10n.routeProviderUnavailable,
      'ROUTING_NO_ROUTE' => l10n.routeProviderUnavailable,
      _ => l10n.genericError,
    };

String localizedTripEvent(AppLocalizations l10n, String value) => switch (value) {
  'TripCreated' => l10n.eventTripCreated,
  'DraftUpdated' => l10n.eventDraftUpdated,
  'StopsUpdated' => l10n.eventStopsUpdated,
  'RouteCalculated' => l10n.eventRouteCalculated,
  'RouteInvalidated' => l10n.eventRouteInvalidated,
  'Assigned' => l10n.eventAssigned,
  'Reassigned' => l10n.eventReassigned,
  'Unassigned' => l10n.eventUnassigned,
  'DispatchedToPickup' => l10n.eventDispatchedToPickup,
  'ArrivedAtPickup' => l10n.eventArrivedAtPickup,
  'TripStarted' => l10n.eventTripStarted,
  'MarkedInTransit' => l10n.eventMarkedInTransit,
  'Delivered' => l10n.eventDelivered,
  'Completed' => l10n.eventCompleted,
  'Cancelled' => l10n.eventCancelled,
  'Archived' => l10n.eventArchived,
  'Unarchived' => l10n.eventUnarchived,
  'ImportedBaseline' => l10n.eventImportedBaseline,
  _ => value,
};
