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
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

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
}
