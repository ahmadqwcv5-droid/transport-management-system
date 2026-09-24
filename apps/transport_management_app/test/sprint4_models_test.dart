import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/clients/domain/client_models.dart';
import 'package:transport_management_app/features/fleet/domain/fleet_models.dart';
import 'package:transport_management_app/features/trips/domain/trip_models.dart';
import 'package:transport_management_app/l10n/app_localizations_ar.dart';
import 'package:transport_management_app/l10n/app_localizations_en.dart';
import 'package:transport_management_app/l10n/l10n_extensions.dart';

void main() {
  test('client details decode lifecycle contacts sites history and events', () {
    final details = ClientDetails.fromJson({
      'client': {
        'id': 'client-1',
        'name': 'Atlas',
        'isActive': false,
        'lifecycleStatus': 'Suspended',
        'activeSiteCount': 1,
        'activeTripCount': 2,
      },
      'contacts': [
        {'id': 'contact-1', 'name': 'Mona', 'isPrimary': true},
      ],
      'sites': [
        {
          'id': 'site-1',
          'name': 'Warehouse',
          'type': 'Warehouse',
          'latitude': 41.0,
          'longitude': 29.0,
          'isActive': true,
        },
      ],
      'trips': [
        {
          'id': 'trip-1',
          'tripNumber': 'TRP-1',
          'status': 'Assigned',
          'plannedStartAt': '2026-09-23T10:00:00Z',
        },
      ],
      'events': [
        {
          'id': 'event-1',
          'eventCode': 'ClientSuspended',
          'occurredAt': '2026-09-23T09:00:00Z',
        },
      ],
      'plannedTripCount': 1,
      'activeTripCount': 2,
      'completedTripCount': 3,
      'cancelledTripCount': 4,
    });
    expect(details.client.lifecycleStatus, 'Suspended');
    expect(details.contacts.single.isPrimary, isTrue);
    expect(details.sites.single.latitude, 41);
    expect(details.trips.single.tripNumber, 'TRP-1');
    expect(details.events.single.eventCode, 'ClientSuspended');
  });

  test('truck details keep base and derived operational state separate', () {
    final details = TruckDetails.fromJson({
      'truck': {
        'id': 'truck-1',
        'plateNumber': '34 ABC 1',
        'status': 'OnTrip',
        'baseStatus': 'Available',
        'operationalState': 'EnRouteToPickup',
        'isActive': true,
        'fleetCode': 'F-1',
        'type': 'BoxTruck',
        'payloadCapacity': 1800,
        'payloadUnit': 'Kilograms',
        'canBeAssigned': false,
        'ineligibilityReasonCode': 'TRUCK_ALREADY_ASSIGNED',
      },
      'latestPosition': {
        'latitude': 41,
        'longitude': 29,
        'recordedAt': '2026-09-23T09:00:00Z',
        'isOnline': true,
        'locationState': 'Current',
      },
      'trips': <dynamic>[],
      'events': <dynamic>[],
    });
    expect(details.truck.baseStatus, 'Available');
    expect(details.truck.operationalState, 'EnRouteToPickup');
    expect(details.truck.canBeAssigned, isFalse);
    expect(details.latestPosition?.isOnline, isTrue);
  });

  test('assignment option carries fleet enrichment and default suggestion', () {
    final option = AssignmentResourceOption.fromJson({
      'id': 'truck-1',
      'displayName': '34 ABC 1',
      'status': 'Available',
      'isEligible': true,
      'reasonCode': 'AVAILABLE',
      'fleetCode': 'F-1',
      'resourceType': 'Refrigerated',
      'payloadCapacity': 10,
      'payloadUnit': 'Tonnes',
      'defaultDriverId': 'driver-1',
    });
    expect(option.defaultDriverId, 'driver-1');
    expect(option.fleetCode, 'F-1');
    expect(option.payloadCapacity, 10);
  });

  test('new operations labels are localized in English and Arabic', () {
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    expect(localizedStatus(en, 'Suspended'), 'Suspended');
    expect(localizedStatus(ar, 'Suspended'), 'موقوف');
    expect(
      localizedOperationsEvent(en, 'TruckOdometerCorrected'),
      'Odometer corrected',
    );
    expect(localizedOperationsEvent(ar, 'ClientSiteAdded'), 'تمت إضافة موقع');
  });
}
