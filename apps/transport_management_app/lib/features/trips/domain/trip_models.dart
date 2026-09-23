import 'dart:convert';

typedef Json = Map<String, dynamic>;

final class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  Json toJson() => {'latitude': latitude, 'longitude': longitude};
  factory GeoPoint.fromJson(Json json) => GeoPoint(
    (json['latitude'] as num).toDouble(),
    (json['longitude'] as num).toDouble(),
  );
}

final class TripStop {
  const TripStop({
    required this.sequence,
    required this.type,
    required this.name,
    this.id,
    this.address,
    this.latitude,
    this.longitude,
  });
  final String? id, address;
  final int sequence;
  final String type, name;
  final double? latitude, longitude;
  bool get hasCoordinates => latitude != null && longitude != null;
  Json toJson() => {
    'sequence': sequence,
    'type': type,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };
  factory TripStop.fromJson(Json json) => TripStop(
    id: json['id'] as String?,
    sequence: json['sequence'] as int,
    type: json['type'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

final class TripRoutePlan {
  const TripRoutePlan({
    required this.coordinates,
    required this.geometry,
    required this.distanceMeters,
    required this.estimatedDurationSeconds,
    required this.providerName,
    required this.routeProfile,
    required this.calculatedAt,
    required this.warnings,
    this.id,
    this.stopsFingerprint,
  });
  final String? id, stopsFingerprint;
  final List<GeoPoint> coordinates;
  final String geometry, providerName, routeProfile, calculatedAt;
  final double distanceMeters;
  final int estimatedDurationSeconds;
  final List<String> warnings;
  factory TripRoutePlan.fromJson(Json json) {
    final direct = json['coordinates'] as List<dynamic>?;
    final geoJson = direct == null
        ? jsonDecode(json['geometry'] as String) as Json
        : null;
    final coordinates = direct != null
        ? direct.cast<Json>().map(GeoPoint.fromJson).toList()
        : (geoJson!['coordinates'] as List<dynamic>)
              .cast<List<dynamic>>()
              .map(
                (value) => GeoPoint(
                  (value[1] as num).toDouble(),
                  (value[0] as num).toDouble(),
                ),
              )
              .toList();
    return TripRoutePlan(
      coordinates: coordinates,
      geometry: json['geometry'] as String,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      estimatedDurationSeconds: json['estimatedDurationSeconds'] as int,
      providerName: json['providerName'] as String,
      routeProfile: json['routeProfile'] as String,
      calculatedAt: json['calculatedAt'] as String,
      warnings: json['warnings'] is List<dynamic>
          ? (json['warnings'] as List<dynamic>).cast<String>()
          : const [],
      id: json['id'] as String?,
      stopsFingerprint: json['stopsFingerprint'] as String?,
    );
  }
}

final class AssignmentResourceOption {
  const AssignmentResourceOption({
    required this.id,
    required this.displayName,
    required this.status,
    required this.isEligible,
    required this.reasonCode,
    this.conflictingTripId,
    this.conflictingTripNumber,
  });
  final String id, displayName, status, reasonCode;
  final bool isEligible;
  final String? conflictingTripId, conflictingTripNumber;
  factory AssignmentResourceOption.fromJson(Json json) =>
      AssignmentResourceOption(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        status: json['status'] as String,
        isEligible: json['isEligible'] as bool,
        reasonCode: json['reasonCode'] as String,
        conflictingTripId: json['conflictingTripId'] as String?,
        conflictingTripNumber: json['conflictingTripNumber'] as String?,
      );
}

final class AssignmentOptions {
  const AssignmentOptions({
    required this.tripId,
    required this.canAssign,
    required this.trucks,
    required this.drivers,
    this.currentTruckId,
    this.currentDriverId,
  });
  final String tripId;
  final String? currentTruckId, currentDriverId;
  final bool canAssign;
  final List<AssignmentResourceOption> trucks, drivers;
  factory AssignmentOptions.fromJson(Json json) => AssignmentOptions(
    tripId: json['tripId'] as String,
    currentTruckId: json['currentTruckId'] as String?,
    currentDriverId: json['currentDriverId'] as String?,
    canAssign: json['canAssign'] as bool,
    trucks: (json['trucks'] as List<dynamic>)
        .cast<Json>()
        .map(AssignmentResourceOption.fromJson)
        .toList(),
    drivers: (json['drivers'] as List<dynamic>)
        .cast<Json>()
        .map(AssignmentResourceOption.fromJson)
        .toList(),
  );
}

final class TripRepositioningPlan {
  const TripRepositioningPlan({
    required this.id,
    required this.route,
    required this.status,
  });
  final String id, status;
  final TripRoutePlan route;
  factory TripRepositioningPlan.fromJson(Json json) => TripRepositioningPlan(
    id: json['id'] as String,
    status: json['status'] as String,
    route: TripRoutePlan.fromJson({...json, 'warnings': const <String>[]}),
  );
}

final class RepositioningPreview {
  const RepositioningPreview({
    required this.alreadyAtPickup,
    required this.directDistanceToPickupMeters,
    required this.sourcePositionAgeSeconds,
    this.plan,
  });
  final bool alreadyAtPickup;
  final double directDistanceToPickupMeters;
  final int sourcePositionAgeSeconds;
  final TripRepositioningPlan? plan;
  factory RepositioningPreview.fromJson(Json json) => RepositioningPreview(
    alreadyAtPickup: json['alreadyAtPickup'] as bool,
    directDistanceToPickupMeters: (json['directDistanceToPickupMeters'] as num)
        .toDouble(),
    sourcePositionAgeSeconds: json['sourcePositionAgeSeconds'] as int,
    plan: json['plan'] == null
        ? null
        : TripRepositioningPlan.fromJson(json['plan'] as Json),
  );
}

final class LocationResult {
  const LocationResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.providerName,
    this.address,
  });
  final String displayName, providerName;
  final String? address;
  final double latitude, longitude;
  factory LocationResult.fromJson(Json json) => LocationResult(
    displayName: json['displayName'] as String,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    providerName: json['providerName'] as String,
  );
}

final class RouteProgress {
  const RouteProgress({
    required this.tripId,
    required this.plannedDistanceMeters,
    required this.operationalPhase,
    this.truckId,
    this.travelledDistanceMeters,
    this.remainingDistanceMeters,
    this.progressPercent,
    this.estimatedArrivalAt,
    this.distanceFromPlannedRouteMeters,
    this.isOffRoute,
    this.currentSegmentIndex,
    this.lastPositionAt,
  });
  final String tripId, operationalPhase;
  final String? truckId, estimatedArrivalAt, lastPositionAt;
  final double plannedDistanceMeters;
  final double? travelledDistanceMeters,
      remainingDistanceMeters,
      progressPercent,
      distanceFromPlannedRouteMeters;
  final bool? isOffRoute;
  final int? currentSegmentIndex;
  factory RouteProgress.fromJson(Json json) => RouteProgress(
    tripId: json['tripId'] as String,
    truckId: json['truckId'] as String?,
    plannedDistanceMeters: (json['plannedDistanceMeters'] as num).toDouble(),
    travelledDistanceMeters: (json['travelledDistanceMeters'] as num?)
        ?.toDouble(),
    remainingDistanceMeters: (json['remainingDistanceMeters'] as num?)
        ?.toDouble(),
    progressPercent: (json['progressPercent'] as num?)?.toDouble(),
    estimatedArrivalAt: json['estimatedArrivalAt'] as String?,
    distanceFromPlannedRouteMeters:
        (json['distanceFromPlannedRouteMeters'] as num?)?.toDouble(),
    isOffRoute: json['isOffRoute'] as bool?,
    currentSegmentIndex: json['currentSegmentIndex'] as int?,
    operationalPhase: json['operationalPhase'] as String,
    lastPositionAt: json['lastPositionAt'] as String?,
  );
}

final class Trip {
  const Trip({
    required this.id,
    this.tripNumber = 'TRP-TEST-000001',
    required this.clientId,
    required this.cargoDescription,
    required this.status,
    required this.allowedActions,
    this.version = 1,
    this.readiness = const TripReadiness(
      canCalculateRoute: false,
      canAssign: false,
      canDispatch: false,
      missingRequirements: [],
    ),
    this.origin,
    this.destination,
    this.plannedStartAt,
    this.price,
    this.truckId,
    this.driverId,
    this.actualStartAt,
    this.arrivedPickupAt,
    this.deliveredAt,
    this.completedAt,
    this.notes,
    this.stops = const [],
    this.routePlan,
    this.repositioningPlan,
    this.requiresLocationSelection = true,
    this.isArchived = false,
    this.archivedAt,
    this.cancellationReason,
    this.cancelledAt,
  });
  final String id, tripNumber, clientId, cargoDescription, status;
  final String? origin,
      destination,
      plannedStartAt,
      truckId,
      driverId,
      actualStartAt,
      arrivedPickupAt,
      deliveredAt,
      completedAt,
      notes,
      archivedAt,
      cancellationReason,
      cancelledAt;
  final num? price;
  final int version;
  final TripReadiness readiness;
  final bool isArchived;
  final List<String> allowedActions;
  final List<TripStop> stops;
  final TripRoutePlan? routePlan;
  final TripRepositioningPlan? repositioningPlan;
  final bool requiresLocationSelection;
  factory Trip.fromJson(Json json) => Trip(
    id: json['id'] as String,
    tripNumber: json['tripNumber'] as String? ?? 'TRP-TEST-000001',
    clientId: json['clientId'] as String,
    truckId: json['truckId'] as String?,
    driverId: json['driverId'] as String?,
    origin: json['origin'] as String?,
    destination: json['destination'] as String?,
    cargoDescription: json['cargoDescription'] as String,
    plannedStartAt: json['plannedStartAt'] as String?,
    actualStartAt: json['actualStartAt'] as String?,
    arrivedPickupAt: json['arrivedPickupAt'] as String?,
    deliveredAt: json['deliveredAt'] as String?,
    completedAt: json['completedAt'] as String?,
    price: json['price'] as num?,
    notes: json['notes'] as String?,
    status: json['status'] as String,
    allowedActions: (json['allowedActions'] as List<dynamic>).cast<String>(),
    stops: (json['stops'] as List<dynamic>? ?? const [])
        .cast<Json>()
        .map(TripStop.fromJson)
        .toList(),
    routePlan: json['routePlan'] == null
        ? null
        : TripRoutePlan.fromJson(json['routePlan'] as Json),
    repositioningPlan: json['repositioningPlan'] == null
        ? null
        : TripRepositioningPlan.fromJson(json['repositioningPlan'] as Json),
    requiresLocationSelection:
        json['requiresLocationSelection'] as bool? ?? true,
    isArchived: json['isArchived'] as bool? ?? false,
    archivedAt: json['archivedAt'] as String?,
    cancellationReason: json['cancellationReason'] as String?,
    cancelledAt: json['cancelledAt'] as String?,
    version: json['version'] as int? ?? 1,
    readiness: TripReadiness.fromJson(json['readiness'] as Json? ?? const {}),
  );
}

final class TripReadiness {
  const TripReadiness({
    required this.canCalculateRoute,
    required this.canAssign,
    required this.canDispatch,
    required this.missingRequirements,
  });
  final bool canCalculateRoute, canAssign, canDispatch;
  final List<String> missingRequirements;
  factory TripReadiness.fromJson(Json json) => TripReadiness(
    canCalculateRoute: json['canCalculateRoute'] as bool? ?? false,
    canAssign: json['canAssign'] as bool? ?? false,
    canDispatch: json['canDispatch'] as bool? ?? false,
    missingRequirements:
        (json['missingRequirements'] as List<dynamic>? ?? const [])
            .cast<String>(),
  );
}

final class TripPage {
  const TripPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
  final List<Trip> items;
  final int totalCount, page, pageSize, totalPages;
  factory TripPage.fromJson(Json json) => TripPage(
    items: (json['items'] as List<dynamic>)
        .cast<Json>()
        .map(Trip.fromJson)
        .toList(),
    totalCount: json['totalCount'] as int,
    page: json['page'] as int,
    pageSize: json['pageSize'] as int,
    totalPages: json['totalPages'] as int,
  );
}

final class TripEvent {
  const TripEvent({
    required this.eventType,
    required this.occurredAt,
    required this.actorDisplayName,
    required this.source,
    this.metadata,
  });
  final String eventType, occurredAt, actorDisplayName, source;
  final String? metadata;
  factory TripEvent.fromJson(Json json) => TripEvent(
    eventType: json['eventType'] as String,
    occurredAt: json['occurredAt'] as String,
    actorDisplayName: json['actorDisplayName'] as String,
    source: json['source'] as String,
    metadata: json['metadata'] as String?,
  );
}
