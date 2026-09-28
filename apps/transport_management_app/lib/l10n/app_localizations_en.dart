// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Transport Management';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInPrompt => 'Sign in to your company workspace';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signOut => 'Sign out';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get clients => 'Clients';

  @override
  String get trucks => 'Trucks';

  @override
  String get drivers => 'Drivers';

  @override
  String get trips => 'Trips';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get fleetMap => 'Fleet map';

  @override
  String get simulator => 'Tracking simulator';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get stop => 'Stop';

  @override
  String get reset => 'Reset';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get required => 'Required';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading…';

  @override
  String get genericError => 'Unable to complete the request.';

  @override
  String get invalidTripTransition =>
      'This trip action is not allowed in its current status.';

  @override
  String get truckAlreadyAssigned =>
      'This truck is already assigned to another active trip.';

  @override
  String get driverAlreadyAssigned =>
      'This driver is already assigned to another active trip.';

  @override
  String get truckNotAvailable => 'The selected truck is not available.';

  @override
  String get driverNotAvailable => 'The selected driver is not available.';

  @override
  String get clientNotFound => 'The selected client was not found.';

  @override
  String get noTrackedTrucks =>
      'No tracked trucks yet. Start the simulator to create positions.';

  @override
  String get totalTrucks => 'Total trucks';

  @override
  String get availableTrucks => 'Available';

  @override
  String get onTripTrucks => 'On trip';

  @override
  String get maintenanceTrucks => 'Maintenance';

  @override
  String get outOfServiceTrucks => 'Out of service';

  @override
  String get activeTrips => 'Active trips';

  @override
  String get completedToday => 'Completed today';

  @override
  String get onlineTracked => 'Online tracked';

  @override
  String get offlineTracked => 'Offline tracked';

  @override
  String get recentTrips => 'Recent trips';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get speed => 'Speed';

  @override
  String get lastUpdate => 'Last update';

  @override
  String get driver => 'Driver';

  @override
  String get activeTrip => 'Active trip';

  @override
  String get notAssigned => 'Not assigned';

  @override
  String get available => 'Available';

  @override
  String get onTrip => 'On trip';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get outOfService => 'Out of service';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get draft => 'Draft';

  @override
  String get assigned => 'Assigned';

  @override
  String get started => 'Started';

  @override
  String get inTransit => 'In transit';

  @override
  String get delivered => 'Delivered';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get localeSaved => 'Language updated.';

  @override
  String get simulatorDisabled =>
      'The simulator is disabled in this environment.';

  @override
  String get noClients => 'No clients yet.';

  @override
  String get noTrucks => 'No trucks yet.';

  @override
  String get noDrivers => 'No drivers yet.';

  @override
  String get noTrips => 'No trips yet.';

  @override
  String get newClient => 'New client';

  @override
  String get newTruck => 'New truck';

  @override
  String get newDriver => 'New driver';

  @override
  String get newTrip => 'New trip';

  @override
  String get searchClients => 'Search clients';

  @override
  String get name => 'Name';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone';

  @override
  String get contactPerson => 'Contact person';

  @override
  String get address => 'Address';

  @override
  String get plateNumber => 'Plate number';

  @override
  String get make => 'Make';

  @override
  String get model => 'Model';

  @override
  String get year => 'Year';

  @override
  String get licenseNumber => 'License number';

  @override
  String get licenseExpiry => 'License expiry (YYYY-MM-DD)';

  @override
  String get origin => 'Origin';

  @override
  String get destination => 'Destination';

  @override
  String get cargo => 'Cargo';

  @override
  String get plannedStart => 'Planned start (ISO 8601)';

  @override
  String get price => 'Price';

  @override
  String get assign => 'Assign';

  @override
  String get markInTransit => 'Mark in transit';

  @override
  String get deliver => 'Deliver';

  @override
  String get complete => 'Complete';

  @override
  String get edit => 'Edit';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get createClient => 'Create client';

  @override
  String get editClient => 'Edit client';

  @override
  String get createTruck => 'Create truck';

  @override
  String get editTruck => 'Edit truck';

  @override
  String get createDriver => 'Create driver';

  @override
  String get editDriver => 'Edit driver';

  @override
  String get createTrip => 'Create trip';

  @override
  String get editDraftTrip => 'Edit draft trip';

  @override
  String get editDraft => 'Edit draft';

  @override
  String get setAvailable => 'Set available';

  @override
  String get setUnavailable => 'Set unavailable';

  @override
  String get setMaintenance => 'Set maintenance';

  @override
  String get status => 'Status';

  @override
  String get notes => 'Notes';

  @override
  String get license => 'License';

  @override
  String get planned => 'Planned';

  @override
  String get client => 'Client';

  @override
  String get truck => 'Truck';

  @override
  String get unknownClient => 'Unknown client';

  @override
  String get unknown => 'Unknown';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get validYear => 'Enter a valid year.';

  @override
  String get validDate => 'Enter a valid date.';

  @override
  String get validPrice => 'Enter a valid price.';

  @override
  String get savedSuccessfully => 'Saved successfully.';

  @override
  String get clientDeactivated => 'Client deactivated.';

  @override
  String get tripStatusUpdated => 'Trip status updated.';

  @override
  String get resourcesAssigned => 'Truck and driver assigned.';

  @override
  String get tripNotFound => 'Trip not found.';

  @override
  String get backToTrips => 'Back to trips';

  @override
  String get assignResources => 'Assign resources';

  @override
  String get authenticationFailed =>
      'The email address or password is incorrect.';

  @override
  String get mapNotConfigured =>
      'Map style is not configured. Add MAP_STYLE_URL to use the geographic map.';

  @override
  String get loadingMap => 'Loading map style…';

  @override
  String get mapStyleLoaded => 'Map ready (style loaded)';

  @override
  String get mapFailed =>
      'The map style could not be loaded. You can retry or use the simplified tracking view.';

  @override
  String get retryMap => 'Retry map';

  @override
  String get useFallback => 'Use simplified fallback';

  @override
  String get fallbackMode => 'Simplified tracking view — not a geographic map';

  @override
  String get step => 'Step';

  @override
  String get simulationSpeed => 'Simulation speed';

  @override
  String get applySpeed => 'Apply speed';

  @override
  String get selectTruck => 'Select truck';

  @override
  String get setOnline => 'Set online';

  @override
  String get setOffline => 'Set offline';

  @override
  String get simulatorCommandSucceeded => 'Simulator command completed.';

  @override
  String get planTrip => 'Plan trip';

  @override
  String get pickup => 'Pickup';

  @override
  String get delivery => 'Delivery';

  @override
  String get locationName => 'Location name';

  @override
  String get searchLocation => 'Search location';

  @override
  String get searchResults => 'Location results';

  @override
  String get noLocationResults =>
      'No matching locations were found. You can enter coordinates manually.';

  @override
  String get invalidCoordinate => 'Enter a valid coordinate.';

  @override
  String get routePreview => 'Route preview';

  @override
  String get calculateRoute => 'Calculate route';

  @override
  String get calculatingRoute => 'Calculating route…';

  @override
  String get calculateRouteHint =>
      'Choose pickup and delivery locations, then calculate the road route.';

  @override
  String get routeProviderUnavailable =>
      'The route could not be calculated. Check the routing provider and try again.';

  @override
  String get saveTrip => 'Save trip';

  @override
  String get onlineOnly => 'Online only';

  @override
  String get movingOnly => 'Moving only';

  @override
  String get routeProgress => 'Route progress';

  @override
  String get remainingDistance => 'Remaining distance';

  @override
  String get eta => 'ETA';

  @override
  String get offRoute => 'Off route';

  @override
  String get onRoute => 'On route';

  @override
  String get legacyTripRouteWarning =>
      'This legacy trip has location labels only. Select pickup and delivery locations before assignment.';

  @override
  String get routeDistance => 'Route distance';

  @override
  String get routeDuration => 'Estimated duration';

  @override
  String get routeProvider => 'Routing provider';

  @override
  String get selectOnMap => 'Select on map';

  @override
  String get tapMapToSelect => 'Tap the map to select this location';

  @override
  String get moving => 'Moving';

  @override
  String get stationary => 'Stationary';

  @override
  String get recenter => 'Recenter';

  @override
  String get fitRoute => 'Fit route';

  @override
  String get fleetList => 'Fleet';

  @override
  String get plannedRoute => 'Planned route';

  @override
  String get travelledTrail => 'Travelled trail';

  @override
  String get enRouteToPickup => 'En route to pickup';

  @override
  String get atPickup => 'At pickup';

  @override
  String get previewApproach => 'Preview route to pickup';

  @override
  String get dispatchToPickup => 'Dispatch to pickup';

  @override
  String get confirmPickupArrival => 'Confirm pickup arrival';

  @override
  String get alreadyAtPickup =>
      'The truck is already within the pickup arrival area.';

  @override
  String get approachDistance => 'Approach distance';

  @override
  String get approachDuration => 'Approach duration';

  @override
  String get dispatchStarted => 'Truck dispatched to pickup.';

  @override
  String get truckPositionRequired =>
      'Record the truck\'s current position before dispatch.';

  @override
  String get truckPositionStale =>
      'The truck position is too old. Refresh tracking and try again.';

  @override
  String get truckOfflineForDispatch =>
      'The truck must be online before dispatch.';

  @override
  String get repositioningRouteRequired =>
      'Preview a current route to pickup before dispatch.';

  @override
  String get repositioningRouteStale =>
      'The truck moved after the preview. Calculate the route again.';

  @override
  String get truckNotAtPickup =>
      'The truck has not reached the pickup area yet.';

  @override
  String get approachRoute => 'Route to pickup';

  @override
  String get cargoRoute => 'Cargo route';

  @override
  String get proposed => 'Proposed';

  @override
  String get expired => 'Expired';

  @override
  String get confirmLocation => 'Confirm location';

  @override
  String get setSimulatedLocation => 'Set simulated location';

  @override
  String get moveSimulatedTruck => 'Move simulated truck';

  @override
  String get refreshLocation => 'Refresh at same coordinate';

  @override
  String get noLocation => 'No location';

  @override
  String get currentLocation => 'Current';

  @override
  String get staleLocation => 'Stale';

  @override
  String get noActiveTrucks => 'No active trucks are available.';

  @override
  String get noLocationHelp =>
      'This truck has not reported a position. Set a simulated location to place it on the map.';

  @override
  String get currentLocationHelp =>
      'The simulated GPS position is current and maintained by bounded heartbeats.';

  @override
  String get staleLocationHelp =>
      'Refresh this coordinate or choose a new simulated location before dispatch.';

  @override
  String get offlineLocationHelp =>
      'This truck is explicitly offline. Set it online before refreshing or dispatching.';

  @override
  String locationAgeSeconds(int seconds) {
    return 'Updated $seconds seconds ago';
  }

  @override
  String locationForTruck(String plateNumber) {
    return 'Simulated location for $plateNumber';
  }

  @override
  String get fixTruckLocation => 'Fix truck location';

  @override
  String get locationCorrectedRetry =>
      'Truck location updated. Retry the route preview when ready.';

  @override
  String get pickupMarker => 'Pickup marker';

  @override
  String get deliveryMarker => 'Delivery marker';

  @override
  String get tripTabActive => 'Active';

  @override
  String get tripTabPlanned => 'Planned';

  @override
  String get tripTabCompleted => 'Completed';

  @override
  String get tripTabCancelled => 'Cancelled';

  @override
  String get tripTabArchived => 'Archived';

  @override
  String get searchTrips => 'Search trip number, client, stop, or plate';

  @override
  String get tripFilters => 'Trip filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String pageOf(int page, int pages, int total) {
    return 'Page $page of $pages · $total trips';
  }

  @override
  String get incompleteDraft => 'Incomplete Draft';

  @override
  String get draftIncomplete => 'Needs planning details';

  @override
  String get saveDraft => 'Save Draft';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get tripBasics => 'Trip basics';

  @override
  String get pickupAndDelivery => 'Pickup and delivery';

  @override
  String get scheduleAndCommercial => 'Schedule and commercial details';

  @override
  String get routeNotCalculated =>
      'Save the stops, then calculate the authoritative route.';

  @override
  String get assignmentOptional => 'Assignment (optional)';

  @override
  String get assignmentAfterDraft =>
      'Finish the planning checklist, then assign eligible resources from trip details.';

  @override
  String get review => 'Review';

  @override
  String get saveDraftReview =>
      'Review the readiness checklist and save this Draft.';

  @override
  String get delete => 'Delete';

  @override
  String get reassign => 'Reassign';

  @override
  String get unassign => 'Unassign';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get duplicateAsDraft => 'Duplicate as Draft';

  @override
  String get cancelTrip => 'Cancel trip';

  @override
  String get cancellationReason => 'Cancellation reason';

  @override
  String get confirm => 'Confirm';

  @override
  String get timeline => 'Timeline';

  @override
  String deleteDraftWarning(String tripNumber) {
    return 'Permanently delete $tripNumber? This cannot be undone.';
  }

  @override
  String confirmTripAction(String tripNumber) {
    return 'Apply this action to $tripNumber?';
  }

  @override
  String get tripNotReadyForRoute =>
      'Add valid pickup and delivery coordinates before calculating a route.';

  @override
  String get tripNotReadyForAssignment =>
      'Complete the planning checklist and calculate the current route before assignment.';

  @override
  String get tripDeleteNotAllowed =>
      'Only a Draft that has never started dispatch can be permanently deleted.';

  @override
  String get tripCancelReasonRequired =>
      'Enter a cancellation reason of 500 characters or fewer.';

  @override
  String get tripArchiveNotAllowed =>
      'Only completed or cancelled trips can be archived or restored.';

  @override
  String get tripReassignNotAllowed =>
      'This trip can no longer be reassigned because dispatch has started.';

  @override
  String get tripUnassignNotAllowed =>
      'This trip can no longer be unassigned because dispatch has started.';

  @override
  String get tripConcurrencyConflict =>
      'This trip was changed by another user. Reload it and try again.';

  @override
  String get eventTripCreated => 'Trip created';

  @override
  String get eventDraftUpdated => 'Draft updated';

  @override
  String get eventStopsUpdated => 'Stops updated';

  @override
  String get eventRouteCalculated => 'Route calculated';

  @override
  String get eventAssigned => 'Resources assigned';

  @override
  String get eventReassigned => 'Resources reassigned';

  @override
  String get eventUnassigned => 'Resources unassigned';

  @override
  String get eventDispatchedToPickup => 'Dispatched to pickup';

  @override
  String get eventArrivedAtPickup => 'Arrived at pickup';

  @override
  String get eventTripStarted => 'Trip started';

  @override
  String get eventMarkedInTransit => 'Marked in transit';

  @override
  String get eventDelivered => 'Delivered';

  @override
  String get eventCompleted => 'Completed';

  @override
  String get eventCancelled => 'Cancelled';

  @override
  String get eventArchived => 'Archived';

  @override
  String get eventUnarchived => 'Unarchived';

  @override
  String get eventImportedBaseline => 'Imported baseline';

  @override
  String get eventRouteInvalidated => 'Route invalidated';

  @override
  String get identicalStops =>
      'Pickup and delivery must be different locations.';

  @override
  String get routeStale =>
      'The locations changed. Recalculate the route before continuing.';

  @override
  String get routeRequired => 'Calculate the route before continuing.';

  @override
  String get assignmentSelectionRequired =>
      'Select an eligible truck and driver, or skip assignment for now.';

  @override
  String get tripCreatedAndAssigned => 'Trip saved and resources assigned.';

  @override
  String get draftSaved => 'Draft saved.';

  @override
  String get tripDetailsStep => 'Trip details';

  @override
  String get tripNumber => 'Trip number';

  @override
  String get locationsAndRouteStep => 'Pickup, delivery and route';

  @override
  String get truckAndDriverStep => 'Truck and driver';

  @override
  String get reviewAndConfirmStep => 'Review and confirm';

  @override
  String get invalidNumber => 'Enter a valid non-negative number.';

  @override
  String get recalculateRoute => 'Recalculate route';

  @override
  String get refreshAvailability => 'Refresh availability';

  @override
  String get skipForNow => 'Skip assignment for now';

  @override
  String get keepAsUnassignedDraft => 'Keep this trip as an unassigned Draft.';

  @override
  String get noEligibleTruck => 'No eligible truck is currently available.';

  @override
  String get noEligibleDriver => 'No eligible driver is currently available.';

  @override
  String get allocatedAfterSave => 'Allocated after save';

  @override
  String get notAvailable => 'Not available';

  @override
  String get distance => 'Distance';

  @override
  String get estimatedDuration => 'Estimated duration';

  @override
  String get readiness => 'Readiness';

  @override
  String get ready => 'Ready';

  @override
  String get editTripDetails => 'Edit trip details';

  @override
  String get editLocationsAndRoute => 'Edit locations and route';

  @override
  String get editAssignment => 'Edit assignment';

  @override
  String get createAndAssignTrip => 'Create and assign trip';

  @override
  String get assignTrip => 'Assign trip';

  @override
  String get routeSummary => 'Route summary';

  @override
  String get resourceInactive => 'Inactive';

  @override
  String get truckInMaintenance => 'In maintenance';

  @override
  String get truckOutOfServiceReason => 'Out of service';

  @override
  String resourceAssignedToTrip(String tripNumber) {
    return 'Reserved by trip $tripNumber';
  }

  @override
  String get details => 'Details';

  @override
  String get legalName => 'Legal name';

  @override
  String get lifecycle => 'Lifecycle';

  @override
  String get all => 'All';

  @override
  String get suspended => 'Suspended';

  @override
  String get reserved => 'Reserved';

  @override
  String get archived => 'Archived';

  @override
  String get contacts => 'Contacts';

  @override
  String get sites => 'Saved sites';

  @override
  String get addContact => 'Add contact';

  @override
  String get jobTitle => 'Job title';

  @override
  String get whatsApp => 'WhatsApp';

  @override
  String get primaryContact => 'Primary contact';

  @override
  String get addSite => 'Add site';

  @override
  String get siteType => 'Site type';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get instructions => 'Instructions';

  @override
  String get restore => 'Restore';

  @override
  String get suspend => 'Suspend';

  @override
  String get reactivate => 'Reactivate';

  @override
  String get plannedTrips => 'Planned trips';

  @override
  String get completedTrips => 'Completed trips';

  @override
  String get cancelledTrips => 'Cancelled trips';

  @override
  String get activity => 'Activity';

  @override
  String get noActivity => 'No activity yet';

  @override
  String get fleetCode => 'Fleet code';

  @override
  String get searchTrucks => 'Search trucks';

  @override
  String get vin => 'VIN / chassis number';

  @override
  String get truckType => 'Truck type';

  @override
  String get payloadCapacity => 'Payload capacity';

  @override
  String get payloadUnit => 'Payload unit';

  @override
  String get fuelType => 'Fuel type';

  @override
  String get odometer => 'Odometer (km)';

  @override
  String get correctOdometer => 'Correct odometer';

  @override
  String get correctionReason => 'Correction reason';

  @override
  String get defaultDriver => 'Default driver';

  @override
  String get baseStatus => 'Base status';

  @override
  String get operationalState => 'Operational state';

  @override
  String get currentTrip => 'Current trip';

  @override
  String get latestPosition => 'Latest position';

  @override
  String get noPosition => 'No position has been reported';

  @override
  String get clientArchived => 'Client archived.';

  @override
  String get clientRestored => 'Client restored.';

  @override
  String get truckArchived => 'Truck archived.';

  @override
  String get truckRestored => 'Truck restored.';

  @override
  String get factory => 'Factory';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get office => 'Office';

  @override
  String get other => 'Other';

  @override
  String get kilograms => 'Kilograms';

  @override
  String get tonnes => 'Tonnes';

  @override
  String get diesel => 'Diesel';

  @override
  String get petrol => 'Petrol';

  @override
  String get electric => 'Electric';

  @override
  String get hybrid => 'Hybrid';

  @override
  String get boxTruck => 'Box truck';

  @override
  String get flatbed => 'Flatbed';

  @override
  String get refrigerated => 'Refrigerated';

  @override
  String get tanker => 'Tanker';

  @override
  String get tractorTrailer => 'Tractor trailer';

  @override
  String get dumpTruck => 'Dump truck';

  @override
  String get savedSite => 'Saved client site';

  @override
  String get siteSaved => 'Client site saved.';

  @override
  String get defaultDriverSuggested => 'Default driver suggested';

  @override
  String get eventClientCreated => 'Client created';

  @override
  String get eventClientProfileUpdated => 'Client profile updated';

  @override
  String get eventClientSuspended => 'Client suspended';

  @override
  String get eventClientReactivated => 'Client reactivated';

  @override
  String get eventClientArchived => 'Client archived';

  @override
  String get eventClientContactAdded => 'Contact added';

  @override
  String get eventClientContactUpdated => 'Contact updated';

  @override
  String get eventClientContactRemoved => 'Contact removed';

  @override
  String get eventClientPrimaryContactChanged => 'Primary contact changed';

  @override
  String get eventClientSiteAdded => 'Site added';

  @override
  String get eventClientSiteUpdated => 'Site updated';

  @override
  String get eventClientSiteArchived => 'Site archived';

  @override
  String get eventClientSiteRestored => 'Site restored';

  @override
  String get eventTruckCreated => 'Truck created';

  @override
  String get eventTruckProfileUpdated => 'Truck profile updated';

  @override
  String get eventTruckDefaultDriverChanged => 'Default driver changed';

  @override
  String get eventTruckOdometerUpdated => 'Odometer updated';

  @override
  String get eventTruckOdometerCorrected => 'Odometer corrected';

  @override
  String get eventTruckBaseStatusChanged => 'Base status changed';

  @override
  String get eventTruckArchived => 'Truck archived';

  @override
  String get eventTruckRestored => 'Truck restored';

  @override
  String get clientArchiveRequired => 'Archive the client before deleting it.';

  @override
  String get deleteClientWarning =>
      'Permanently delete this unused client? This cannot be undone.';

  @override
  String get clientHasHistory =>
      'This client has trip history and cannot be deleted.';

  @override
  String get truckArchiveRequired => 'Archive the truck before deleting it.';

  @override
  String get deleteTruckWarning =>
      'Permanently delete this unused truck? This cannot be undone.';

  @override
  String get truckHasHistory =>
      'This truck has trip or tracking history and cannot be deleted.';

  @override
  String get truckReserved => 'This truck is reserved by an active trip.';

  @override
  String get odometerCorrectionRequired =>
      'Use the correction flow and provide a reason to reduce the odometer.';

  @override
  String get defaultDriverInactive => 'The default driver must be active.';

  @override
  String get duplicateTruckIdentity =>
      'That plate, VIN, or fleet code is already in use.';

  @override
  String get uploadTruckPhoto => 'Upload truck photo';

  @override
  String get removeTruckPhoto => 'Remove truck photo';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get markRead => 'Mark as read';

  @override
  String get notificationArrivedPickup => 'Truck arrived at pickup';

  @override
  String get notificationArrivedDelivery => 'Truck arrived at delivery';

  @override
  String get notificationDepartureConfirmed =>
      'Cargo loaded and departure confirmed';

  @override
  String get notificationDeliveryConfirmed => 'Delivery confirmed';

  @override
  String get operationalUpdate => 'Operational update';

  @override
  String get myTrip => 'My trip';

  @override
  String get noAssignedTrip => 'No active trip is assigned to you';

  @override
  String get confirmLoaded => 'Confirm loaded and start trip';

  @override
  String get confirmLoadedWarning =>
      'Confirm that cargo is loaded and you are departing the pickup?';

  @override
  String get confirmDelivery => 'Confirm delivery';

  @override
  String get confirmDeliveryWarning =>
      'Confirm that the cargo handoff is complete? This completes the trip.';

  @override
  String get atDelivery => 'At delivery';

  @override
  String get managerOverrideDeparture => 'Override departure confirmation';

  @override
  String get managerOverrideDelivery => 'Override delivery confirmation';

  @override
  String get managerOverride => 'Manager override';

  @override
  String get managerOverrideWarning =>
      'Use this only when the linked driver cannot confirm. The reason and your identity are audited.';

  @override
  String get overrideReason => 'Override reason';

  @override
  String get resumeFollow => 'Resume follow';

  @override
  String get showFullRoute => 'Show full route';

  @override
  String get actionConfirmed => 'Confirmation saved.';

  @override
  String get backToTruck => 'Back to truck';

  @override
  String get companyUsers => 'Company users';

  @override
  String get allUsers => 'All users';

  @override
  String get activeUsers => 'Active users';

  @override
  String get inactiveUsers => 'Inactive users';

  @override
  String get createDriverAccount => 'Create Driver account';

  @override
  String get noCompanyUsers => 'No company users match this filter.';

  @override
  String get noDriverLinked => 'No Driver record linked';

  @override
  String get resetTemporaryPassword => 'Reset temporary password';

  @override
  String get unlinkDriverAccount => 'Unlink Driver account';

  @override
  String get unlinkDriverAccountConfirmation =>
      'Unlink this app account from the Driver record? The Driver will no longer receive or confirm trips in Driver Mode.';

  @override
  String get displayName => 'Display name';

  @override
  String get linkDriver => 'Link Driver record (optional)';

  @override
  String get temporaryPassword => 'Temporary password';

  @override
  String get temporaryPasswordOnce =>
      'This password is shown only now. Copy it and share it securely with the driver.';

  @override
  String get copy => 'Copy';

  @override
  String get done => 'Done';

  @override
  String get create => 'Create';

  @override
  String get noAppAccount => 'No app account';

  @override
  String get appAccountLinked => 'App account linked';

  @override
  String get accountInactive => 'Account inactive';

  @override
  String get accountInactiveWarning =>
      'The linked app account is inactive; this driver cannot use Driver Mode.';

  @override
  String get noAppAccountWarning =>
      'This driver has no app account and cannot receive or confirm the trip in Driver Mode.';

  @override
  String get driverAppAccountWarning => 'Driver app account warning';

  @override
  String get accountInactiveAssignmentConfirmation =>
      'Assign this trip even though the linked Driver account is inactive?';

  @override
  String get unlinkedAssignmentConfirmation =>
      'Assign this trip even though the Driver has no app account?';

  @override
  String get continueLabel => 'Continue';

  @override
  String get driverAppAccount => 'Driver app account';

  @override
  String get createAndLinkAccount => 'Create and link account';

  @override
  String get linkExistingAccount => 'Link existing account';

  @override
  String get noUnlinkedDriverAccounts =>
      'No active unlinked Driver accounts are available.';

  @override
  String get loadingSavedSites => 'Loading saved sites…';

  @override
  String get savedSitesLoadFailed => 'Failed to load saved sites';

  @override
  String get noSavedSites => 'No saved sites for this client';

  @override
  String get driverAccountNotLinked =>
      'Your account is not linked to a Driver record';

  @override
  String get contactOwnerToLinkDriver =>
      'Contact your company owner to link this login to your Driver record.';

  @override
  String get noAssignedTripExplanation =>
      'A new assignment will appear here automatically. Pull to refresh at any time.';

  @override
  String get nextStop => 'Next stop';

  @override
  String get estimatedArrival => 'Estimated arrival';

  @override
  String get lastPositionUpdate => 'Last position update';

  @override
  String get allowedDriverAction => 'Allowed action';

  @override
  String get noActionAvailable => 'No action is currently available';

  @override
  String get trackingNotStarted => 'Tracking not started';

  @override
  String get trackingStale => 'Position stale';

  @override
  String get trackingOffline => 'Truck offline';

  @override
  String get trackingCurrent => 'Position current';

  @override
  String nonProductionEnvironment(String environment) {
    return 'Non-production environment: $environment';
  }

  @override
  String get accountIdentity => 'Account and environment';

  @override
  String get signedInEmail => 'Signed-in email';

  @override
  String get companyName => 'Company name';

  @override
  String get role => 'Role';

  @override
  String get environment => 'Environment';

  @override
  String get notificationSounds => 'Notification sounds';

  @override
  String get notificationSoundsDescription =>
      'Play one short sound for new operational alerts while this app is open.';

  @override
  String get soundTestPlayed => 'Test sound requested.';

  @override
  String get testSound => 'Test sound';

  @override
  String get enableNotificationSound => 'Enable notification sound';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get view => 'View';

  @override
  String get notificationTripAssigned => 'New trip assigned';

  @override
  String get notificationTruckOffline => 'Truck became offline';

  @override
  String get notificationPositionStale => 'Truck position became stale';

  @override
  String get operationalAlertMessage =>
      'A new operational event needs your attention.';

  @override
  String get operationalTripAlertMessage =>
      'A trip-related operational event needs your attention.';

  @override
  String get departToPickup => 'Depart to pickup';

  @override
  String get departToPickupWarning =>
      'Start the approach route to the pickup now?';

  @override
  String get confirmLoadedAndDepart => 'Loaded — depart to delivery';

  @override
  String get endVehicleSession => 'End vehicle session';

  @override
  String get endVehicleSessionWarning =>
      'Remove this truck from your Driver workspace?';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get passwordChangedLoginAgain =>
      'Password changed. Sign in again with the new password.';

  @override
  String get passwordMinimumLength => 'Use at least 12 characters.';

  @override
  String get tripAssignedTitle => 'Trip assigned';

  @override
  String get departureRequiredMessage =>
      'The truck will not start moving until you confirm departure.';

  @override
  String get confirmDepartureToPickup => 'Confirm departure to pickup';

  @override
  String get preparingApproachRoute => 'Preparing route to pickup…';

  @override
  String get openTrip => 'Open trip';

  @override
  String get assignmentRequiresDeparture =>
      'Open the trip and confirm departure before the truck starts moving.';

  @override
  String get truckPositionRequiredGuidance =>
      'Truck location has not been received yet. Ask the manager to set or refresh the simulator location, or wait for GPS.';

  @override
  String get truckPositionStaleGuidance =>
      'Truck location is too old to start safely. Refresh telemetry and retry.';

  @override
  String get truckOfflineGuidance =>
      'Truck tracking is offline. Bring tracking online and retry.';

  @override
  String get pickupCoordinatesRequiredGuidance =>
      'Pickup coordinates are missing. Ask operations to correct the trip.';

  @override
  String get routePreparationFailed =>
      'The route to pickup could not be prepared. Retry without losing the assignment.';

  @override
  String get departureAlreadyInProgress =>
      'Departure is already being prepared. Please wait.';

  @override
  String get workspaceConnectionWarning =>
      'Live updates are temporarily unavailable. Showing the last received trip state.';

  @override
  String get mapUpdateWarning =>
      'The latest map update could not be drawn. Live trip data is still available.';

  @override
  String get mapLoading => 'Loading map…';

  @override
  String get activeOperationsRetry => 'Retry active operations';

  @override
  String get activeOperationsTitle => 'Active operations';

  @override
  String get viewAll => 'View all';

  @override
  String get activeOperationsStale =>
      'Live refresh is temporarily unavailable. Showing the last update.';

  @override
  String activeOperationsCount(int count) {
    return '$count active operations';
  }

  @override
  String get noActiveOperations => 'No active operations.';

  @override
  String get phaseAwaitingDeparture => 'Awaiting departure';

  @override
  String get phaseToPickup => 'To pickup';

  @override
  String get phaseAwaitingLoading => 'Awaiting loading';

  @override
  String get phaseToDelivery => 'To delivery';

  @override
  String get phaseAwaitingDeliveryConfirmation =>
      'Awaiting delivery confirmation';

  @override
  String get phaseAwaitingCompletion => 'Awaiting completion';

  @override
  String get waitingDriverDeparture => 'Waiting for Driver departure';

  @override
  String get waitingLoadingConfirmation => 'Waiting for loading confirmation';

  @override
  String get waitingDeliveryConfirmation => 'Waiting for delivery confirmation';

  @override
  String get progressUnavailable => 'Progress is unavailable';

  @override
  String get trackingMissing => 'Tracking missing';

  @override
  String get actionDriverDeparture => 'Action: Driver departure';

  @override
  String get actionLoadingConfirmation => 'Action: loading confirmation';

  @override
  String get actionDeliveryConfirmation => 'Action: delivery confirmation';

  @override
  String remainingKilometers(String value) {
    return '$value km remaining';
  }

  @override
  String remainingMeters(String value) {
    return '$value m remaining';
  }

  @override
  String etaShort(String time) {
    return 'ETA $time';
  }

  @override
  String get driverSelection => 'Driver selection';

  @override
  String get selectionNone => 'None';

  @override
  String get selectionManual => 'Manual';

  @override
  String get selectionTruckDefault => 'Truck default';

  @override
  String get selectionExistingAssignment => 'Existing assignment';

  @override
  String get selectTruckFirst => 'Select a truck first.';

  @override
  String get truckHasNoDefaultDriver =>
      'This truck has no default Driver. Choose one manually.';

  @override
  String get truckDefaultDriverUnavailable =>
      'The truck default Driver is unavailable. Choose an eligible Driver manually.';

  @override
  String get driverSelectedFromTruckDefault =>
      'Selected because this Driver is linked to the truck.';

  @override
  String notificationAssignedSnapshot(
    String truck,
    String trip,
    String location,
    String time,
  ) {
    return 'Truck $truck was assigned to trip $trip. Pickup: $location. Time: $time.';
  }

  @override
  String notificationPickupSnapshot(
    String truck,
    String trip,
    String location,
    String time,
  ) {
    return 'Truck $truck on trip $trip reached pickup: $location. Time: $time.';
  }

  @override
  String notificationDepartureSnapshot(
    String truck,
    String trip,
    String location,
    String time,
  ) {
    return 'Loading was confirmed for truck $truck, trip $trip; it departed toward $location. Time: $time.';
  }

  @override
  String notificationDeliverySnapshot(
    String truck,
    String trip,
    String location,
    String time,
  ) {
    return 'Truck $truck on trip $trip reached delivery: $location. Time: $time.';
  }

  @override
  String notificationCompletedSnapshot(
    String truck,
    String trip,
    String location,
    String time,
  ) {
    return 'Delivery was confirmed and trip $trip was completed by truck $truck at $location. Time: $time.';
  }

  @override
  String notificationHealthSnapshot(
    String truck,
    String trip,
    String location,
    String time,
  ) {
    return 'Truck $truck on trip $trip needs tracking attention near $location. Time: $time.';
  }

  @override
  String get legacyNotificationFallback =>
      'Operational update details are unavailable for this older notification.';

  @override
  String notificationClient(String value) {
    return 'Client: $value';
  }

  @override
  String notificationDriver(String value) {
    return 'Driver: $value';
  }

  @override
  String notificationCargo(String value) {
    return 'Cargo: $value';
  }

  @override
  String get operationalArea => 'Operational country / area';

  @override
  String get operationalAreaDescription =>
      'Sets the default fleet overview. Trucks outside the area remain visible.';

  @override
  String get noOperationalArea =>
      'Not configured. The map uses connected trucks or the regional fallback.';

  @override
  String get configureOperationalArea => 'Configure area';

  @override
  String get clearOperationalArea => 'Clear area';

  @override
  String get operationalAreaSaved => 'Operational area saved.';

  @override
  String get countryCode => 'ISO country code';

  @override
  String get countryCodeHint => 'Two letters, for example TR or SY';

  @override
  String get selectAreaWithBounds =>
      'Enter a valid two-letter country code and select a search result with geographic bounds.';

  @override
  String get fleetOverview => 'Fleet overview';

  @override
  String trucksOutsideOperationalArea(int count) {
    return '$count truck(s) outside the operational area';
  }

  @override
  String get noVehicleAssigned => 'No vehicle assigned';

  @override
  String get noVehicleAssignedExplanation =>
      'Ask the Owner to link one active truck to your Driver profile.';

  @override
  String get vehicleAssignmentAmbiguous => 'Vehicle assignment needs attention';

  @override
  String get vehicleAssignmentAmbiguousExplanation =>
      'More than one truck is linked to your Driver profile. Ask the Owner to keep one default truck.';

  @override
  String get heading => 'Heading';

  @override
  String get workspaceChooser => 'Choose a workspace';

  @override
  String get chooseWorkspace => 'Select the company workspace you want to use.';

  @override
  String get noWorkspace => 'You do not have an active workspace yet.';

  @override
  String get joinCompany => 'Join a company';

  @override
  String get companyCode => 'Private company code';

  @override
  String get exactCodePrivacy =>
      'Only an exact private code can reveal the company name.';

  @override
  String get resolveCompany => 'Check code';

  @override
  String get requestConnection => 'Request connection';

  @override
  String get pendingRequests => 'Pending requests';

  @override
  String get switchWorkspace => 'Switch workspace';

  @override
  String get roles => 'Roles';

  @override
  String get invitationAccept => 'Company invitation';

  @override
  String get invitationFor => 'Invitation for';

  @override
  String get expiresAt => 'Expires';

  @override
  String get createAccount => 'Create your account';

  @override
  String get acceptInvitation => 'Accept invitation';

  @override
  String get declineInvitation => 'Decline invitation';

  @override
  String get invitationAccepted =>
      'Invitation accepted. Sign in or switch workspace to continue.';

  @override
  String get loginToAccept =>
      'Sign in with the invited email, or create your personal account below.';

  @override
  String get googleSignIn => 'Continue with Google';

  @override
  String get googleNotConfigured =>
      'Google sign-in is not configured for this environment.';

  @override
  String get signInMethods => 'Sign-in methods';

  @override
  String get linked => 'Linked';

  @override
  String get unlink => 'Unlink';

  @override
  String get phoneComingSoon =>
      'Phone sign-in is planned but is not available yet.';

  @override
  String get invitations => 'Invitations';

  @override
  String get invitePerson => 'Invite person';

  @override
  String get invitationLink => 'Invitation link';

  @override
  String get copyInvitationLink => 'Copy invitation link';

  @override
  String get revoke => 'Revoke';

  @override
  String get connectionRequests => 'Connection requests';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get companyConnectionCode => 'Company connection code';

  @override
  String get rotateCode => 'Rotate code';

  @override
  String get qrCode => 'Truck QR';

  @override
  String get regenerateTruckQr => 'Generate / regenerate truck QR';

  @override
  String get truckQrExplanation =>
      'This QR identifies the truck, not a trip. Regenerating invalidates the previous label.';

  @override
  String get scanTruckQr => 'Scan truck QR';

  @override
  String get manualCode => 'Enter code manually';

  @override
  String get previewTruck => 'Review truck';

  @override
  String get confirmTruckSwitch => 'Confirm truck switch';

  @override
  String get handoverApprovalRequired =>
      'This truck has another Driver\'s active trip. Approval is required before anything changes.';

  @override
  String get requestSent => 'Request sent';

  @override
  String get handoverRequests => 'Handover requests';

  @override
  String get currentDriver => 'Current Driver';

  @override
  String get requestingDriver => 'Requesting Driver';

  @override
  String get approveHandover => 'Approve handover';

  @override
  String get rejectHandover => 'Reject handover';

  @override
  String get reason => 'Reason';

  @override
  String get selectDriver => 'Select Driver';

  @override
  String get copied => 'Copied';

  @override
  String get invitationPending => 'Invitation pending';

  @override
  String get accountConnected => 'Account connected';

  @override
  String get driverRecordOnly => 'Driver record without app access';

  @override
  String get googleLinkRequiresProvider =>
      'Use a verified Google authorization result to link this method.';

  @override
  String get accountEmailConflict => 'An account already uses this email.';

  @override
  String get externalLoginAlreadyLinked =>
      'This Google identity is already linked.';

  @override
  String get externalLoginConfirmationRequired =>
      'Sign in to the existing account before linking Google.';

  @override
  String get googleTokenInvalid => 'Google could not verify this sign-in.';

  @override
  String get membershipNotActive => 'This company membership is not active.';

  @override
  String get workspaceAccessDenied =>
      'You do not have access to this workspace.';

  @override
  String get invitationInvalid => 'This invitation is invalid.';

  @override
  String get invitationExpired => 'This invitation has expired.';

  @override
  String get invitationAlreadyUsed => 'This invitation has already been used.';

  @override
  String get invitationEmailMismatch =>
      'Sign in with the email address that received this invitation.';

  @override
  String get companyCodeInvalid => 'The company code is invalid.';

  @override
  String get connectionAlreadyPending =>
      'A connection request is already pending.';

  @override
  String get driverAccountAlreadyLinked =>
      'This Driver record is already linked to an account.';

  @override
  String get driverLinkRequired =>
      'Select the exact Driver record before approval.';

  @override
  String get truckQrInvalid => 'The truck QR code is invalid or unavailable.';

  @override
  String get truckQrRevoked =>
      'This truck QR code was replaced. Scan the new label.';

  @override
  String get truckSessionConflict =>
      'The Driver or truck already has a conflicting active session.';

  @override
  String get handoverRequestStale =>
      'This handover no longer matches the current trip assignment.';

  @override
  String get handoverAlreadyResolved =>
      'This handover request was already resolved.';

  @override
  String get tripAssignmentChanged =>
      'The trip assignment changed. Refresh and review it again.';

  @override
  String get noData => 'No records yet.';

  @override
  String get useCamera => 'Use camera';
}
