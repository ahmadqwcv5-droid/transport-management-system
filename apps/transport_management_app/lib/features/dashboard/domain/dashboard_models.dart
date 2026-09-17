typedef Json = Map<String, dynamic>;

final class TrackedTruck {
  const TrackedTruck({
    required this.truckId,
    required this.plateNumber,
    required this.truckStatus,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.recordedAt,
    required this.isOnline,
    this.driverName,
    this.currentTripId,
  });
  final String truckId, plateNumber, truckStatus, recordedAt;
  final double latitude, longitude, speed;
  final bool isOnline;
  final String? driverName, currentTripId;
  factory TrackedTruck.fromJson(Json json) => TrackedTruck(
    truckId: json['truckId'] as String,
    plateNumber: json['plateNumber'] as String,
    truckStatus: json['truckStatus'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    speed: (json['speed'] as num).toDouble(),
    recordedAt: json['recordedAt'] as String,
    isOnline: json['isOnline'] as bool,
    driverName: json['driverName'] as String?,
    currentTripId: json['currentTripId'] as String?,
  );
}

final class RecentTrip {
  const RecentTrip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.status,
  });
  final String id, origin, destination, status;
  factory RecentTrip.fromJson(Json json) => RecentTrip(
    id: json['id'] as String,
    origin: json['origin'] as String,
    destination: json['destination'] as String,
    status: json['status'] as String,
  );
}

final class DashboardData {
  const DashboardData({
    required this.fleet,
    required this.trips,
    required this.tracking,
    required this.positions,
    required this.recentTrips,
  });
  final Json fleet, trips, tracking;
  final List<TrackedTruck> positions;
  final List<RecentTrip> recentTrips;
  factory DashboardData.fromJson(Json json) => DashboardData(
    fleet: json['fleet'] as Json,
    trips: json['trips'] as Json,
    tracking: json['tracking'] as Json,
    positions: (json['positions'] as List<dynamic>)
        .cast<Json>()
        .map(TrackedTruck.fromJson)
        .toList(),
    recentTrips: (json['recentTrips'] as List<dynamic>)
        .cast<Json>()
        .map(RecentTrip.fromJson)
        .toList(),
  );
}
