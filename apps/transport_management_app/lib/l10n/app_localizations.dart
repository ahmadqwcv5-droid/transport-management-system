import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Transport Management'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your company workspace'**
  String get signInPrompt;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @trucks.
  ///
  /// In en, this message translates to:
  /// **'Trucks'**
  String get trucks;

  /// No description provided for @drivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get drivers;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @fleetMap.
  ///
  /// In en, this message translates to:
  /// **'Fleet map'**
  String get fleetMap;

  /// No description provided for @simulator.
  ///
  /// In en, this message translates to:
  /// **'Tracking simulator'**
  String get simulator;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete the request.'**
  String get genericError;

  /// No description provided for @invalidTripTransition.
  ///
  /// In en, this message translates to:
  /// **'This trip action is not allowed in its current status.'**
  String get invalidTripTransition;

  /// No description provided for @truckAlreadyAssigned.
  ///
  /// In en, this message translates to:
  /// **'This truck is already assigned to another active trip.'**
  String get truckAlreadyAssigned;

  /// No description provided for @driverAlreadyAssigned.
  ///
  /// In en, this message translates to:
  /// **'This driver is already assigned to another active trip.'**
  String get driverAlreadyAssigned;

  /// No description provided for @truckNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'The selected truck is not available.'**
  String get truckNotAvailable;

  /// No description provided for @driverNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'The selected driver is not available.'**
  String get driverNotAvailable;

  /// No description provided for @clientNotFound.
  ///
  /// In en, this message translates to:
  /// **'The selected client was not found.'**
  String get clientNotFound;

  /// No description provided for @noTrackedTrucks.
  ///
  /// In en, this message translates to:
  /// **'No tracked trucks yet. Start the simulator to create positions.'**
  String get noTrackedTrucks;

  /// No description provided for @totalTrucks.
  ///
  /// In en, this message translates to:
  /// **'Total trucks'**
  String get totalTrucks;

  /// No description provided for @availableTrucks.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableTrucks;

  /// No description provided for @onTripTrucks.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get onTripTrucks;

  /// No description provided for @maintenanceTrucks.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTrucks;

  /// No description provided for @outOfServiceTrucks.
  ///
  /// In en, this message translates to:
  /// **'Out of service'**
  String get outOfServiceTrucks;

  /// No description provided for @activeTrips.
  ///
  /// In en, this message translates to:
  /// **'Active trips'**
  String get activeTrips;

  /// No description provided for @completedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get completedToday;

  /// No description provided for @onlineTracked.
  ///
  /// In en, this message translates to:
  /// **'Online tracked'**
  String get onlineTracked;

  /// No description provided for @offlineTracked.
  ///
  /// In en, this message translates to:
  /// **'Offline tracked'**
  String get offlineTracked;

  /// No description provided for @recentTrips.
  ///
  /// In en, this message translates to:
  /// **'Recent trips'**
  String get recentTrips;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get lastUpdate;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @activeTrip.
  ///
  /// In en, this message translates to:
  /// **'Active trip'**
  String get activeTrip;

  /// No description provided for @notAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get notAssigned;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @onTrip.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get onTrip;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @outOfService.
  ///
  /// In en, this message translates to:
  /// **'Out of service'**
  String get outOfService;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get inTransit;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @localeSaved.
  ///
  /// In en, this message translates to:
  /// **'Language updated.'**
  String get localeSaved;

  /// No description provided for @simulatorDisabled.
  ///
  /// In en, this message translates to:
  /// **'The simulator is disabled in this environment.'**
  String get simulatorDisabled;

  /// No description provided for @noClients.
  ///
  /// In en, this message translates to:
  /// **'No clients yet.'**
  String get noClients;

  /// No description provided for @noTrucks.
  ///
  /// In en, this message translates to:
  /// **'No trucks yet.'**
  String get noTrucks;

  /// No description provided for @noDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers yet.'**
  String get noDrivers;

  /// No description provided for @noTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips yet.'**
  String get noTrips;

  /// No description provided for @newClient.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get newClient;

  /// No description provided for @newTruck.
  ///
  /// In en, this message translates to:
  /// **'New truck'**
  String get newTruck;

  /// No description provided for @newDriver.
  ///
  /// In en, this message translates to:
  /// **'New driver'**
  String get newDriver;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @searchClients.
  ///
  /// In en, this message translates to:
  /// **'Search clients'**
  String get searchClients;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get contactPerson;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @plateNumber.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get plateNumber;

  /// No description provided for @make.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get make;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @licenseNumber.
  ///
  /// In en, this message translates to:
  /// **'License number'**
  String get licenseNumber;

  /// No description provided for @licenseExpiry.
  ///
  /// In en, this message translates to:
  /// **'License expiry (YYYY-MM-DD)'**
  String get licenseExpiry;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @cargo.
  ///
  /// In en, this message translates to:
  /// **'Cargo'**
  String get cargo;

  /// No description provided for @plannedStart.
  ///
  /// In en, this message translates to:
  /// **'Planned start (ISO 8601)'**
  String get plannedStart;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @markInTransit.
  ///
  /// In en, this message translates to:
  /// **'Mark in transit'**
  String get markInTransit;

  /// No description provided for @deliver.
  ///
  /// In en, this message translates to:
  /// **'Deliver'**
  String get deliver;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @createClient.
  ///
  /// In en, this message translates to:
  /// **'Create client'**
  String get createClient;

  /// No description provided for @editClient.
  ///
  /// In en, this message translates to:
  /// **'Edit client'**
  String get editClient;

  /// No description provided for @createTruck.
  ///
  /// In en, this message translates to:
  /// **'Create truck'**
  String get createTruck;

  /// No description provided for @editTruck.
  ///
  /// In en, this message translates to:
  /// **'Edit truck'**
  String get editTruck;

  /// No description provided for @createDriver.
  ///
  /// In en, this message translates to:
  /// **'Create driver'**
  String get createDriver;

  /// No description provided for @editDriver.
  ///
  /// In en, this message translates to:
  /// **'Edit driver'**
  String get editDriver;

  /// No description provided for @createTrip.
  ///
  /// In en, this message translates to:
  /// **'Create trip'**
  String get createTrip;

  /// No description provided for @editDraftTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit draft trip'**
  String get editDraftTrip;

  /// No description provided for @editDraft.
  ///
  /// In en, this message translates to:
  /// **'Edit draft'**
  String get editDraft;

  /// No description provided for @setAvailable.
  ///
  /// In en, this message translates to:
  /// **'Set available'**
  String get setAvailable;

  /// No description provided for @setUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set unavailable'**
  String get setUnavailable;

  /// No description provided for @setMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Set maintenance'**
  String get setMaintenance;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planned;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @truck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get truck;

  /// No description provided for @unknownClient.
  ///
  /// In en, this message translates to:
  /// **'Unknown client'**
  String get unknownClient;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @validYear.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid year.'**
  String get validYear;

  /// No description provided for @validDate.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get validDate;

  /// No description provided for @validPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price.'**
  String get validPrice;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully.'**
  String get savedSuccessfully;

  /// No description provided for @clientDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Client deactivated.'**
  String get clientDeactivated;

  /// No description provided for @tripStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Trip status updated.'**
  String get tripStatusUpdated;

  /// No description provided for @resourcesAssigned.
  ///
  /// In en, this message translates to:
  /// **'Truck and driver assigned.'**
  String get resourcesAssigned;

  /// No description provided for @tripNotFound.
  ///
  /// In en, this message translates to:
  /// **'Trip not found.'**
  String get tripNotFound;

  /// No description provided for @backToTrips.
  ///
  /// In en, this message translates to:
  /// **'Back to trips'**
  String get backToTrips;

  /// No description provided for @assignResources.
  ///
  /// In en, this message translates to:
  /// **'Assign resources'**
  String get assignResources;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'The email address or password is incorrect.'**
  String get authenticationFailed;

  /// No description provided for @mapNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Map style is not configured. Add MAP_STYLE_URL to use the geographic map.'**
  String get mapNotConfigured;

  /// No description provided for @loadingMap.
  ///
  /// In en, this message translates to:
  /// **'Loading map style…'**
  String get loadingMap;

  /// No description provided for @mapStyleLoaded.
  ///
  /// In en, this message translates to:
  /// **'Map ready (style loaded)'**
  String get mapStyleLoaded;

  /// No description provided for @mapFailed.
  ///
  /// In en, this message translates to:
  /// **'The map style could not be loaded. You can retry or use the simplified tracking view.'**
  String get mapFailed;

  /// No description provided for @retryMap.
  ///
  /// In en, this message translates to:
  /// **'Retry map'**
  String get retryMap;

  /// No description provided for @useFallback.
  ///
  /// In en, this message translates to:
  /// **'Use simplified fallback'**
  String get useFallback;

  /// No description provided for @fallbackMode.
  ///
  /// In en, this message translates to:
  /// **'Simplified tracking view — not a geographic map'**
  String get fallbackMode;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @simulationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Simulation speed'**
  String get simulationSpeed;

  /// No description provided for @applySpeed.
  ///
  /// In en, this message translates to:
  /// **'Apply speed'**
  String get applySpeed;

  /// No description provided for @selectTruck.
  ///
  /// In en, this message translates to:
  /// **'Select truck'**
  String get selectTruck;

  /// No description provided for @setOnline.
  ///
  /// In en, this message translates to:
  /// **'Set online'**
  String get setOnline;

  /// No description provided for @setOffline.
  ///
  /// In en, this message translates to:
  /// **'Set offline'**
  String get setOffline;

  /// No description provided for @simulatorCommandSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Simulator command completed.'**
  String get simulatorCommandSucceeded;

  /// No description provided for @planTrip.
  ///
  /// In en, this message translates to:
  /// **'Plan trip'**
  String get planTrip;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @locationName.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get locationName;

  /// No description provided for @searchLocation.
  ///
  /// In en, this message translates to:
  /// **'Search location'**
  String get searchLocation;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Location results'**
  String get searchResults;

  /// No description provided for @noLocationResults.
  ///
  /// In en, this message translates to:
  /// **'No matching locations were found. You can enter coordinates manually.'**
  String get noLocationResults;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @invalidCoordinate.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid coordinate.'**
  String get invalidCoordinate;

  /// No description provided for @routePreview.
  ///
  /// In en, this message translates to:
  /// **'Route preview'**
  String get routePreview;

  /// No description provided for @calculateRoute.
  ///
  /// In en, this message translates to:
  /// **'Calculate route'**
  String get calculateRoute;

  /// No description provided for @calculatingRoute.
  ///
  /// In en, this message translates to:
  /// **'Calculating route…'**
  String get calculatingRoute;

  /// No description provided for @calculateRouteHint.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup and delivery locations, then calculate the road route.'**
  String get calculateRouteHint;

  /// No description provided for @routeProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The route could not be calculated. Check the routing provider and try again.'**
  String get routeProviderUnavailable;

  /// No description provided for @saveTrip.
  ///
  /// In en, this message translates to:
  /// **'Save trip'**
  String get saveTrip;

  /// No description provided for @onlineOnly.
  ///
  /// In en, this message translates to:
  /// **'Online only'**
  String get onlineOnly;

  /// No description provided for @movingOnly.
  ///
  /// In en, this message translates to:
  /// **'Moving only'**
  String get movingOnly;

  /// No description provided for @routeProgress.
  ///
  /// In en, this message translates to:
  /// **'Route progress'**
  String get routeProgress;

  /// No description provided for @remainingDistance.
  ///
  /// In en, this message translates to:
  /// **'Remaining distance'**
  String get remainingDistance;

  /// No description provided for @eta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get eta;

  /// No description provided for @offRoute.
  ///
  /// In en, this message translates to:
  /// **'Off route'**
  String get offRoute;

  /// No description provided for @onRoute.
  ///
  /// In en, this message translates to:
  /// **'On route'**
  String get onRoute;

  /// No description provided for @legacyTripRouteWarning.
  ///
  /// In en, this message translates to:
  /// **'This legacy trip has location labels only. Select pickup and delivery locations before assignment.'**
  String get legacyTripRouteWarning;

  /// No description provided for @routeDistance.
  ///
  /// In en, this message translates to:
  /// **'Route distance'**
  String get routeDistance;

  /// No description provided for @routeDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated duration'**
  String get routeDuration;

  /// No description provided for @routeProvider.
  ///
  /// In en, this message translates to:
  /// **'Routing provider'**
  String get routeProvider;

  /// No description provided for @selectOnMap.
  ///
  /// In en, this message translates to:
  /// **'Select on map'**
  String get selectOnMap;

  /// No description provided for @tapMapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to select this location'**
  String get tapMapToSelect;

  /// No description provided for @moving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get moving;

  /// No description provided for @stationary.
  ///
  /// In en, this message translates to:
  /// **'Stationary'**
  String get stationary;

  /// No description provided for @recenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get recenter;

  /// No description provided for @fitRoute.
  ///
  /// In en, this message translates to:
  /// **'Fit route'**
  String get fitRoute;

  /// No description provided for @fleetList.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get fleetList;

  /// No description provided for @plannedRoute.
  ///
  /// In en, this message translates to:
  /// **'Planned route'**
  String get plannedRoute;

  /// No description provided for @travelledTrail.
  ///
  /// In en, this message translates to:
  /// **'Travelled trail'**
  String get travelledTrail;

  /// No description provided for @enRouteToPickup.
  ///
  /// In en, this message translates to:
  /// **'En route to pickup'**
  String get enRouteToPickup;

  /// No description provided for @atPickup.
  ///
  /// In en, this message translates to:
  /// **'At pickup'**
  String get atPickup;

  /// No description provided for @previewApproach.
  ///
  /// In en, this message translates to:
  /// **'Preview route to pickup'**
  String get previewApproach;

  /// No description provided for @dispatchToPickup.
  ///
  /// In en, this message translates to:
  /// **'Dispatch to pickup'**
  String get dispatchToPickup;

  /// No description provided for @confirmPickupArrival.
  ///
  /// In en, this message translates to:
  /// **'Confirm pickup arrival'**
  String get confirmPickupArrival;

  /// No description provided for @alreadyAtPickup.
  ///
  /// In en, this message translates to:
  /// **'The truck is already within the pickup arrival area.'**
  String get alreadyAtPickup;

  /// No description provided for @approachDistance.
  ///
  /// In en, this message translates to:
  /// **'Approach distance'**
  String get approachDistance;

  /// No description provided for @approachDuration.
  ///
  /// In en, this message translates to:
  /// **'Approach duration'**
  String get approachDuration;

  /// No description provided for @dispatchStarted.
  ///
  /// In en, this message translates to:
  /// **'Truck dispatched to pickup.'**
  String get dispatchStarted;

  /// No description provided for @truckPositionRequired.
  ///
  /// In en, this message translates to:
  /// **'Record the truck\'s current position before dispatch.'**
  String get truckPositionRequired;

  /// No description provided for @truckPositionStale.
  ///
  /// In en, this message translates to:
  /// **'The truck position is too old. Refresh tracking and try again.'**
  String get truckPositionStale;

  /// No description provided for @truckOfflineForDispatch.
  ///
  /// In en, this message translates to:
  /// **'The truck must be online before dispatch.'**
  String get truckOfflineForDispatch;

  /// No description provided for @repositioningRouteRequired.
  ///
  /// In en, this message translates to:
  /// **'Preview a current route to pickup before dispatch.'**
  String get repositioningRouteRequired;

  /// No description provided for @repositioningRouteStale.
  ///
  /// In en, this message translates to:
  /// **'The truck moved after the preview. Calculate the route again.'**
  String get repositioningRouteStale;

  /// No description provided for @truckNotAtPickup.
  ///
  /// In en, this message translates to:
  /// **'The truck has not reached the pickup area yet.'**
  String get truckNotAtPickup;

  /// No description provided for @approachRoute.
  ///
  /// In en, this message translates to:
  /// **'Route to pickup'**
  String get approachRoute;

  /// No description provided for @cargoRoute.
  ///
  /// In en, this message translates to:
  /// **'Cargo route'**
  String get cargoRoute;

  /// No description provided for @proposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get proposed;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get confirmLocation;

  /// No description provided for @setSimulatedLocation.
  ///
  /// In en, this message translates to:
  /// **'Set simulated location'**
  String get setSimulatedLocation;

  /// No description provided for @moveSimulatedTruck.
  ///
  /// In en, this message translates to:
  /// **'Move simulated truck'**
  String get moveSimulatedTruck;

  /// No description provided for @refreshLocation.
  ///
  /// In en, this message translates to:
  /// **'Refresh at same coordinate'**
  String get refreshLocation;

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentLocation;

  /// No description provided for @staleLocation.
  ///
  /// In en, this message translates to:
  /// **'Stale'**
  String get staleLocation;

  /// No description provided for @noActiveTrucks.
  ///
  /// In en, this message translates to:
  /// **'No active trucks are available.'**
  String get noActiveTrucks;

  /// No description provided for @noLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'This truck has not reported a position. Set a simulated location to place it on the map.'**
  String get noLocationHelp;

  /// No description provided for @currentLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'The simulated GPS position is current and maintained by bounded heartbeats.'**
  String get currentLocationHelp;

  /// No description provided for @staleLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Refresh this coordinate or choose a new simulated location before dispatch.'**
  String get staleLocationHelp;

  /// No description provided for @offlineLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'This truck is explicitly offline. Set it online before refreshing or dispatching.'**
  String get offlineLocationHelp;

  /// No description provided for @locationAgeSeconds.
  ///
  /// In en, this message translates to:
  /// **'Updated {seconds} seconds ago'**
  String locationAgeSeconds(int seconds);

  /// No description provided for @locationForTruck.
  ///
  /// In en, this message translates to:
  /// **'Simulated location for {plateNumber}'**
  String locationForTruck(String plateNumber);

  /// No description provided for @fixTruckLocation.
  ///
  /// In en, this message translates to:
  /// **'Fix truck location'**
  String get fixTruckLocation;

  /// No description provided for @locationCorrectedRetry.
  ///
  /// In en, this message translates to:
  /// **'Truck location updated. Retry the route preview when ready.'**
  String get locationCorrectedRetry;

  /// No description provided for @pickupMarker.
  ///
  /// In en, this message translates to:
  /// **'Pickup marker'**
  String get pickupMarker;

  /// No description provided for @deliveryMarker.
  ///
  /// In en, this message translates to:
  /// **'Delivery marker'**
  String get deliveryMarker;

  /// No description provided for @tripTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tripTabActive;

  /// No description provided for @tripTabPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get tripTabPlanned;

  /// No description provided for @tripTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tripTabCompleted;

  /// No description provided for @tripTabCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tripTabCancelled;

  /// No description provided for @tripTabArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get tripTabArchived;

  /// No description provided for @searchTrips.
  ///
  /// In en, this message translates to:
  /// **'Search trip number, client, stop, or plate'**
  String get searchTrips;

  /// No description provided for @tripFilters.
  ///
  /// In en, this message translates to:
  /// **'Trip filters'**
  String get tripFilters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages} · {total} trips'**
  String pageOf(int page, int pages, int total);

  /// No description provided for @incompleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Incomplete Draft'**
  String get incompleteDraft;

  /// No description provided for @draftIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Needs planning details'**
  String get draftIncomplete;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get saveDraft;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @tripBasics.
  ///
  /// In en, this message translates to:
  /// **'Trip basics'**
  String get tripBasics;

  /// No description provided for @pickupAndDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pickup and delivery'**
  String get pickupAndDelivery;

  /// No description provided for @scheduleAndCommercial.
  ///
  /// In en, this message translates to:
  /// **'Schedule and commercial details'**
  String get scheduleAndCommercial;

  /// No description provided for @routeNotCalculated.
  ///
  /// In en, this message translates to:
  /// **'Save the stops, then calculate the authoritative route.'**
  String get routeNotCalculated;

  /// No description provided for @assignmentOptional.
  ///
  /// In en, this message translates to:
  /// **'Assignment (optional)'**
  String get assignmentOptional;

  /// No description provided for @assignmentAfterDraft.
  ///
  /// In en, this message translates to:
  /// **'Finish the planning checklist, then assign eligible resources from trip details.'**
  String get assignmentAfterDraft;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @saveDraftReview.
  ///
  /// In en, this message translates to:
  /// **'Review the readiness checklist and save this Draft.'**
  String get saveDraftReview;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @reassign.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get reassign;

  /// No description provided for @unassign.
  ///
  /// In en, this message translates to:
  /// **'Unassign'**
  String get unassign;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @duplicateAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as Draft'**
  String get duplicateAsDraft;

  /// No description provided for @cancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get cancelTrip;

  /// No description provided for @cancellationReason.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get cancellationReason;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @deleteDraftWarning.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {tripNumber}? This cannot be undone.'**
  String deleteDraftWarning(String tripNumber);

  /// No description provided for @confirmTripAction.
  ///
  /// In en, this message translates to:
  /// **'Apply this action to {tripNumber}?'**
  String confirmTripAction(String tripNumber);

  /// No description provided for @tripNotReadyForRoute.
  ///
  /// In en, this message translates to:
  /// **'Add valid pickup and delivery coordinates before calculating a route.'**
  String get tripNotReadyForRoute;

  /// No description provided for @tripNotReadyForAssignment.
  ///
  /// In en, this message translates to:
  /// **'Complete the planning checklist and calculate the current route before assignment.'**
  String get tripNotReadyForAssignment;

  /// No description provided for @tripDeleteNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only a Draft that has never started dispatch can be permanently deleted.'**
  String get tripDeleteNotAllowed;

  /// No description provided for @tripCancelReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a cancellation reason of 500 characters or fewer.'**
  String get tripCancelReasonRequired;

  /// No description provided for @tripArchiveNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only completed or cancelled trips can be archived or restored.'**
  String get tripArchiveNotAllowed;

  /// No description provided for @tripReassignNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This trip can no longer be reassigned because dispatch has started.'**
  String get tripReassignNotAllowed;

  /// No description provided for @tripUnassignNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This trip can no longer be unassigned because dispatch has started.'**
  String get tripUnassignNotAllowed;

  /// No description provided for @tripConcurrencyConflict.
  ///
  /// In en, this message translates to:
  /// **'This trip was changed by another user. Reload it and try again.'**
  String get tripConcurrencyConflict;

  /// No description provided for @eventTripCreated.
  ///
  /// In en, this message translates to:
  /// **'Trip created'**
  String get eventTripCreated;

  /// No description provided for @eventDraftUpdated.
  ///
  /// In en, this message translates to:
  /// **'Draft updated'**
  String get eventDraftUpdated;

  /// No description provided for @eventStopsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Stops updated'**
  String get eventStopsUpdated;

  /// No description provided for @eventRouteCalculated.
  ///
  /// In en, this message translates to:
  /// **'Route calculated'**
  String get eventRouteCalculated;

  /// No description provided for @eventAssigned.
  ///
  /// In en, this message translates to:
  /// **'Resources assigned'**
  String get eventAssigned;

  /// No description provided for @eventReassigned.
  ///
  /// In en, this message translates to:
  /// **'Resources reassigned'**
  String get eventReassigned;

  /// No description provided for @eventUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Resources unassigned'**
  String get eventUnassigned;

  /// No description provided for @eventDispatchedToPickup.
  ///
  /// In en, this message translates to:
  /// **'Dispatched to pickup'**
  String get eventDispatchedToPickup;

  /// No description provided for @eventArrivedAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get eventArrivedAtPickup;

  /// No description provided for @eventTripStarted.
  ///
  /// In en, this message translates to:
  /// **'Trip started'**
  String get eventTripStarted;

  /// No description provided for @eventMarkedInTransit.
  ///
  /// In en, this message translates to:
  /// **'Marked in transit'**
  String get eventMarkedInTransit;

  /// No description provided for @eventDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get eventDelivered;

  /// No description provided for @eventCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get eventCompleted;

  /// No description provided for @eventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get eventCancelled;

  /// No description provided for @eventArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get eventArchived;

  /// No description provided for @eventUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Unarchived'**
  String get eventUnarchived;

  /// No description provided for @eventImportedBaseline.
  ///
  /// In en, this message translates to:
  /// **'Imported baseline'**
  String get eventImportedBaseline;

  /// No description provided for @eventRouteInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Route invalidated'**
  String get eventRouteInvalidated;

  /// No description provided for @identicalStops.
  ///
  /// In en, this message translates to:
  /// **'Pickup and delivery must be different locations.'**
  String get identicalStops;

  /// No description provided for @routeStale.
  ///
  /// In en, this message translates to:
  /// **'The locations changed. Recalculate the route before continuing.'**
  String get routeStale;

  /// No description provided for @routeRequired.
  ///
  /// In en, this message translates to:
  /// **'Calculate the route before continuing.'**
  String get routeRequired;

  /// No description provided for @assignmentSelectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an eligible truck and driver, or skip assignment for now.'**
  String get assignmentSelectionRequired;

  /// No description provided for @tripCreatedAndAssigned.
  ///
  /// In en, this message translates to:
  /// **'Trip saved and resources assigned.'**
  String get tripCreatedAndAssigned;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved.'**
  String get draftSaved;

  /// No description provided for @tripDetailsStep.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetailsStep;

  /// No description provided for @tripNumber.
  ///
  /// In en, this message translates to:
  /// **'Trip number'**
  String get tripNumber;

  /// No description provided for @locationsAndRouteStep.
  ///
  /// In en, this message translates to:
  /// **'Pickup, delivery and route'**
  String get locationsAndRouteStep;

  /// No description provided for @truckAndDriverStep.
  ///
  /// In en, this message translates to:
  /// **'Truck and driver'**
  String get truckAndDriverStep;

  /// No description provided for @reviewAndConfirmStep.
  ///
  /// In en, this message translates to:
  /// **'Review and confirm'**
  String get reviewAndConfirmStep;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid non-negative number.'**
  String get invalidNumber;

  /// No description provided for @recalculateRoute.
  ///
  /// In en, this message translates to:
  /// **'Recalculate route'**
  String get recalculateRoute;

  /// No description provided for @refreshAvailability.
  ///
  /// In en, this message translates to:
  /// **'Refresh availability'**
  String get refreshAvailability;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip assignment for now'**
  String get skipForNow;

  /// No description provided for @keepAsUnassignedDraft.
  ///
  /// In en, this message translates to:
  /// **'Keep this trip as an unassigned Draft.'**
  String get keepAsUnassignedDraft;

  /// No description provided for @noEligibleTruck.
  ///
  /// In en, this message translates to:
  /// **'No eligible truck is currently available.'**
  String get noEligibleTruck;

  /// No description provided for @noEligibleDriver.
  ///
  /// In en, this message translates to:
  /// **'No eligible driver is currently available.'**
  String get noEligibleDriver;

  /// No description provided for @allocatedAfterSave.
  ///
  /// In en, this message translates to:
  /// **'Allocated after save'**
  String get allocatedAfterSave;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @estimatedDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated duration'**
  String get estimatedDuration;

  /// No description provided for @readiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get readiness;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @editTripDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit trip details'**
  String get editTripDetails;

  /// No description provided for @editLocationsAndRoute.
  ///
  /// In en, this message translates to:
  /// **'Edit locations and route'**
  String get editLocationsAndRoute;

  /// No description provided for @editAssignment.
  ///
  /// In en, this message translates to:
  /// **'Edit assignment'**
  String get editAssignment;

  /// No description provided for @createAndAssignTrip.
  ///
  /// In en, this message translates to:
  /// **'Create and assign trip'**
  String get createAndAssignTrip;

  /// No description provided for @assignTrip.
  ///
  /// In en, this message translates to:
  /// **'Assign trip'**
  String get assignTrip;

  /// No description provided for @routeSummary.
  ///
  /// In en, this message translates to:
  /// **'Route summary'**
  String get routeSummary;

  /// No description provided for @resourceInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get resourceInactive;

  /// No description provided for @truckInMaintenance.
  ///
  /// In en, this message translates to:
  /// **'In maintenance'**
  String get truckInMaintenance;

  /// No description provided for @truckOutOfServiceReason.
  ///
  /// In en, this message translates to:
  /// **'Out of service'**
  String get truckOutOfServiceReason;

  /// No description provided for @resourceAssignedToTrip.
  ///
  /// In en, this message translates to:
  /// **'Reserved by trip {tripNumber}'**
  String resourceAssignedToTrip(String tripNumber);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
