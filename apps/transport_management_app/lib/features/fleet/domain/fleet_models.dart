import '../../clients/domain/client_models.dart'
    show OperationsEvent, ResourceTripSummary;

typedef Json = Map<String, dynamic>;

final class Truck {
  const Truck({
    required this.id,
    required this.plateNumber,
    required this.status,
    required this.isActive,
    this.make,
    this.model,
    this.year,
    this.notes,
    this.fleetCode,
    this.vin,
    this.type,
    this.payloadCapacity,
    this.payloadUnit = 'Kilograms',
    this.fuelType,
    this.odometerKilometers,
    this.defaultDriverId,
    this.defaultDriverName,
    this.baseStatus = 'Available',
    this.operationalState = 'Available',
    this.currentTripId,
    this.currentTripNumber,
    this.currentDriverId,
    this.canBeAssigned = true,
    this.ineligibilityReasonCode = 'AVAILABLE',
    this.photoVersion,
    this.photoThumbnailUrl,
  });
  final String id;
  final String plateNumber, status;
  final bool isActive;
  final String? make,
      model,
      notes,
      fleetCode,
      vin,
      type,
      fuelType,
      defaultDriverId,
      defaultDriverName,
      currentTripId,
      currentTripNumber,
      currentDriverId;
  final String? photoVersion, photoThumbnailUrl;
  final String payloadUnit,
      baseStatus,
      operationalState,
      ineligibilityReasonCode;
  final double? payloadCapacity, odometerKilometers;
  final bool canBeAssigned;
  final int? year;

  factory Truck.fromJson(Json json) => Truck(
    id: json['id'] as String,
    plateNumber: json['plateNumber'] as String,
    status: json['status'] as String,
    isActive: json['isActive'] as bool,
    make: json['make'] as String?,
    model: json['model'] as String?,
    year: json['year'] as int?,
    notes: json['notes'] as String?,
    fleetCode: json['fleetCode'] as String?,
    vin: json['vin'] as String?,
    type: json['type'] as String?,
    fuelType: json['fuelType'] as String?,
    payloadCapacity: (json['payloadCapacity'] as num?)?.toDouble(),
    payloadUnit: json['payloadUnit'] as String? ?? 'Kilograms',
    odometerKilometers: (json['odometerKilometers'] as num?)?.toDouble(),
    defaultDriverId: json['defaultDriverId'] as String?,
    defaultDriverName: json['defaultDriverName'] as String?,
    baseStatus: json['baseStatus'] as String? ?? json['status'] as String,
    operationalState:
        json['operationalState'] as String? ?? json['status'] as String,
    currentTripId: json['currentTripId'] as String?,
    currentTripNumber: json['currentTripNumber'] as String?,
    currentDriverId: json['currentDriverId'] as String?,
    canBeAssigned: json['canBeAssigned'] as bool? ?? false,
    ineligibilityReasonCode:
        json['ineligibilityReasonCode'] as String? ?? 'AVAILABLE',
    photoVersion: json['photoVersion'] as String?,
    photoThumbnailUrl: json['photoThumbnailUrl'] as String?,
  );
}

final class LatestTruckPosition {
  const LatestTruckPosition({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.isOnline,
    required this.locationState,
  });
  final double latitude, longitude;
  final String recordedAt, locationState;
  final bool isOnline;
  factory LatestTruckPosition.fromJson(Json json) => LatestTruckPosition(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    recordedAt: json['recordedAt'] as String,
    isOnline: json['isOnline'] as bool,
    locationState: json['locationState'] as String,
  );
}

final class TruckDetails {
  const TruckDetails({
    required this.truck,
    required this.trips,
    required this.events,
    this.latestPosition,
  });
  final Truck truck;
  final LatestTruckPosition? latestPosition;
  final List<ResourceTripSummary> trips;
  final List<OperationsEvent> events;
  factory TruckDetails.fromJson(Json json) => TruckDetails(
    truck: Truck.fromJson(json['truck'] as Json),
    latestPosition: json['latestPosition'] == null
        ? null
        : LatestTruckPosition.fromJson(json['latestPosition'] as Json),
    trips: (json['trips'] as List<dynamic>)
        .cast<Json>()
        .map(ResourceTripSummary.fromJson)
        .toList(),
    events: (json['events'] as List<dynamic>)
        .cast<Json>()
        .map(OperationsEvent.fromJson)
        .toList(),
  );
}

final class Driver {
  const Driver({
    required this.id,
    required this.fullName,
    required this.licenseNumber,
    required this.status,
    required this.isActive,
    this.phone,
    this.licenseExpiryDate,
    this.notes,
    this.userId,
  });
  final String id;
  final String fullName, licenseNumber, status;
  final bool isActive;
  final String? phone, licenseExpiryDate, notes, userId;

  factory Driver.fromJson(Json json) => Driver(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    licenseNumber: json['licenseNumber'] as String,
    status: json['status'] as String,
    isActive: json['isActive'] as bool,
    phone: json['phone'] as String?,
    licenseExpiryDate: json['licenseExpiryDate'] as String?,
    notes: json['notes'] as String?,
    userId: json['userId'] as String?,
  );
}
