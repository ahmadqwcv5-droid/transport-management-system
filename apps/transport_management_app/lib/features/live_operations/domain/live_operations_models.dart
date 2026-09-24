import '../../trips/domain/trip_models.dart';

typedef Json = Map<String, dynamic>;

final class OperationNotification {
  const OperationNotification({
    required this.id,
    required this.type,
    required this.severity,
    required this.createdAt,
    this.tripId,
    this.truckId,
    this.driverId,
    this.dataJson,
    this.readAt,
  });

  final String id, type, severity, createdAt;
  final String? tripId, truckId, driverId, dataJson, readAt;
  bool get isUnread => readAt == null;

  factory OperationNotification.fromJson(Json json) => OperationNotification(
    id: json['id'] as String,
    type: json['type'] as String,
    severity: json['severity'] as String,
    createdAt: json['createdAt'] as String,
    tripId: json['tripId'] as String?,
    truckId: json['truckId'] as String?,
    driverId: json['driverId'] as String?,
    dataJson: json['dataJson'] as String?,
    readAt: json['readAt'] as String?,
  );
}

final class NotificationPage {
  const NotificationPage({required this.items, required this.totalCount});
  final List<OperationNotification> items;
  final int totalCount;
  factory NotificationPage.fromJson(Json json) => NotificationPage(
    items: (json['items'] as List<dynamic>)
        .cast<Json>()
        .map(OperationNotification.fromJson)
        .toList(),
    totalCount: json['totalCount'] as int,
  );
}

final class DriverMyTrip {
  const DriverMyTrip({
    required this.driverId,
    required this.driverName,
    this.trip,
  });
  final String driverId, driverName;
  final Trip? trip;
  factory DriverMyTrip.fromJson(Json json) => DriverMyTrip(
    driverId: json['driverId'] as String,
    driverName: json['driverName'] as String,
    trip: json['trip'] == null ? null : Trip.fromJson(json['trip'] as Json),
  );
}
