import '../../operations/domain/operations_models.dart' as ops;

typedef Json = Map<String, dynamic>;

final class FleetTripDetail {
  const FleetTripDetail({
    required this.route,
    required this.trail,
    required this.progress,
    this.approachRoute,
    this.approachProgress,
    required this.tripStatus,
  });
  final ops.TripRoutePlan route;
  final ops.TripRoutePlan? approachRoute;
  final List<TripTrailSegment> trail;
  final ops.RouteProgress progress;
  final ops.RouteProgress? approachProgress;
  final String tripStatus;

  ops.RouteProgress get displayedProgress =>
      tripStatus == 'EnRouteToPickup' && approachProgress != null
      ? approachProgress!
      : progress;
}

final class TripTrailSegment {
  const TripTrailSegment({required this.id, required this.points});
  final String id;
  final List<ops.GeoPoint> points;

  factory TripTrailSegment.fromJson(Json json) => TripTrailSegment(
    id: json['id'] as String,
    points: (json['points'] as List<dynamic>)
        .cast<Json>()
        .map(
          (item) => ops.GeoPoint(
            (item['latitude'] as num).toDouble(),
            (item['longitude'] as num).toDouble(),
          ),
        )
        .toList(),
  );
}

final class TrackedTruck {
  const TrackedTruck({
    required this.truckId,
    required this.plateNumber,
    required this.truckStatus,
    required this.latitude,
    required this.longitude,
    required this.speed,
    this.heading = 0,
    required this.recordedAt,
    required this.isOnline,
    this.driverName,
    this.currentTripId,
    this.movementPhase,
    this.repositioningPlanId,
  });
  final String truckId, plateNumber, truckStatus, recordedAt;
  final double latitude, longitude, speed, heading;
  final bool isOnline;
  final String? driverName, currentTripId, movementPhase, repositioningPlanId;
  factory TrackedTruck.fromJson(Json json) => TrackedTruck(
    truckId: json['truckId'] as String,
    plateNumber: json['plateNumber'] as String,
    truckStatus: json['truckStatus'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    speed: (json['speed'] as num).toDouble(),
    heading: (json['heading'] as num?)?.toDouble() ?? 0,
    recordedAt: json['recordedAt'] as String,
    isOnline: json['isOnline'] as bool,
    driverName: json['driverName'] as String?,
    currentTripId: json['currentTripId'] as String?,
    movementPhase: json['movementPhase'] as String?,
    repositioningPlanId: json['repositioningPlanId'] as String?,
  );
}

final class SimulatorTruck {
  const SimulatorTruck({
    required this.truckId,
    required this.plateNumber,
    required this.truckStatus,
    required this.locationState,
    required this.maximumPositionAgeSeconds,
    this.latitude,
    this.longitude,
    this.heading,
    this.recordedAt,
    this.positionAgeSeconds,
    this.isOnline,
    this.currentTripId,
    this.movementPhase,
  });
  final String truckId, plateNumber, truckStatus, locationState;
  final double? latitude, longitude, heading;
  final String? recordedAt, currentTripId, movementPhase;
  final int? positionAgeSeconds;
  final int maximumPositionAgeSeconds;
  final bool? isOnline;

  bool get hasLocation => latitude != null && longitude != null;

  factory SimulatorTruck.fromJson(Json json) => SimulatorTruck(
    truckId: json['truckId'] as String,
    plateNumber: json['plateNumber'] as String,
    truckStatus: json['truckStatus'] as String,
    locationState: json['locationState'] as String,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
    recordedAt: json['recordedAt'] as String?,
    positionAgeSeconds: json['positionAgeSeconds'] as int?,
    maximumPositionAgeSeconds: json['maximumPositionAgeSeconds'] as int,
    isOnline: json['isOnline'] as bool?,
    currentTripId: json['currentTripId'] as String?,
    movementPhase: json['movementPhase'] as String?,
  );
}

final class RecentTrip {
  const RecentTrip({
    required this.id,
    required this.tripNumber,
    required this.status,
    this.origin,
    this.destination,
  });
  final String id, tripNumber, status;
  final String? origin, destination;
  factory RecentTrip.fromJson(Json json) => RecentTrip(
    id: json['id'] as String,
    tripNumber: json['tripNumber'] as String,
    origin: json['origin'] as String?,
    destination: json['destination'] as String?,
    status: json['status'] as String,
  );
}

final class DashboardData {
  const DashboardData({
    required this.fleet,
    required this.trips,
    required this.tracking,
    required this.positions,
    required this.simulatorTrucks,
    required this.recentTrips,
  });
  final Json fleet, trips, tracking;
  final List<TrackedTruck> positions;
  final List<SimulatorTruck> simulatorTrucks;
  final List<RecentTrip> recentTrips;
  factory DashboardData.fromJson(Json json) => DashboardData(
    fleet: json['fleet'] as Json,
    trips: json['trips'] as Json,
    tracking: json['tracking'] as Json,
    positions: (json['positions'] as List<dynamic>)
        .cast<Json>()
        .map(TrackedTruck.fromJson)
        .toList(),
    simulatorTrucks: (json['simulatorTrucks'] as List<dynamic>? ?? const [])
        .cast<Json>()
        .map(SimulatorTruck.fromJson)
        .toList(),
    recentTrips: (json['recentTrips'] as List<dynamic>)
        .cast<Json>()
        .map(RecentTrip.fromJson)
        .toList(),
  );
}
