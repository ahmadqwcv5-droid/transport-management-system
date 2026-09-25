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

final class DriverWorkspaceTruck {
  const DriverWorkspaceTruck({
    required this.id,
    required this.plateNumber,
    this.fleetCode,
    this.photoVersion,
    this.photoThumbnailUrl,
  });
  final String id, plateNumber;
  final String? fleetCode, photoVersion, photoThumbnailUrl;
  factory DriverWorkspaceTruck.fromJson(Json json) => DriverWorkspaceTruck(
    id: json['id'] as String,
    plateNumber: json['plateNumber'] as String,
    fleetCode: json['fleetCode'] as String?,
    photoVersion: json['photoVersion'] as String?,
    photoThumbnailUrl: json['photoThumbnailUrl'] as String?,
  );
}

final class DriverWorkspacePosition {
  const DriverWorkspacePosition({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.recordedAt,
    required this.isOnline,
  });
  final double latitude, longitude, speed, heading;
  final String recordedAt;
  final bool isOnline;
  factory DriverWorkspacePosition.fromJson(Json json) =>
      DriverWorkspacePosition(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
        heading: (json['heading'] as num).toDouble(),
        recordedAt: json['recordedAt'] as String,
        isOnline: json['isOnline'] as bool,
      );
}

final class DriverActionReadiness {
  const DriverActionReadiness({
    required this.code,
    required this.visible,
    required this.enabled,
    required this.requiresConfirmation,
    this.blockingReason,
  });

  final String code;
  final bool visible, enabled, requiresConfirmation;
  final String? blockingReason;

  factory DriverActionReadiness.fromJson(Json json) => DriverActionReadiness(
    code: json['code'] as String,
    visible: json['visible'] as bool,
    enabled: json['enabled'] as bool,
    blockingReason: json['blockingReason'] as String?,
    requiresConfirmation: json['requiresConfirmation'] as bool,
  );
}

final class DriverWorkspace {
  const DriverWorkspace({
    required this.state,
    required this.trackingState,
    required this.allowedActions,
    this.actions = const [],
    this.connectionWarning = false,
    this.actionInProgress = false,
    this.driverId,
    this.driverName,
    this.currentTrip,
    this.truck,
    this.currentPosition,
    this.activeRoute,
    this.approachRoute,
    this.nextStop,
    this.remainingDistanceMeters,
    this.estimatedArrivalAt,
  });
  final String state, trackingState;
  final String? driverId, driverName, estimatedArrivalAt;
  final Trip? currentTrip;
  final DriverWorkspaceTruck? truck;
  final DriverWorkspacePosition? currentPosition;
  final TripRoutePlan? activeRoute;
  final TripRepositioningPlan? approachRoute;
  final TripStop? nextStop;
  final double? remainingDistanceMeters;
  final List<String> allowedActions;
  final List<DriverActionReadiness> actions;
  final bool connectionWarning, actionInProgress;

  DriverWorkspace copyWithUiState({
    bool? connectionWarning,
    bool? actionInProgress,
  }) => DriverWorkspace(
    state: state,
    trackingState: trackingState,
    allowedActions: allowedActions,
    actions: actions,
    connectionWarning: connectionWarning ?? this.connectionWarning,
    actionInProgress: actionInProgress ?? this.actionInProgress,
    driverId: driverId,
    driverName: driverName,
    currentTrip: currentTrip,
    truck: truck,
    currentPosition: currentPosition,
    activeRoute: activeRoute,
    approachRoute: approachRoute,
    nextStop: nextStop,
    remainingDistanceMeters: remainingDistanceMeters,
    estimatedArrivalAt: estimatedArrivalAt,
  );

  factory DriverWorkspace.fromJson(Json json) {
    final driver = json['driver'] as Json?;
    return DriverWorkspace(
      state: json['state'] as String,
      trackingState: json['trackingState'] as String,
      allowedActions:
          (json['allowedActions'] as List<dynamic>?)?.cast<String>() ??
          const [],
      actions:
          (json['actions'] as List<dynamic>?)
              ?.cast<Json>()
              .map(DriverActionReadiness.fromJson)
              .toList() ??
          const [],
      driverId: driver?['id'] as String?,
      driverName: driver?['fullName'] as String?,
      currentTrip: json['currentTrip'] == null
          ? null
          : Trip.fromJson(json['currentTrip'] as Json),
      truck: json['truck'] == null
          ? null
          : DriverWorkspaceTruck.fromJson(json['truck'] as Json),
      currentPosition: json['currentPosition'] == null
          ? null
          : DriverWorkspacePosition.fromJson(json['currentPosition'] as Json),
      activeRoute: json['activeRoute'] == null
          ? null
          : TripRoutePlan.fromJson(json['activeRoute'] as Json),
      approachRoute: json['approachRoute'] == null
          ? null
          : TripRepositioningPlan.fromJson(json['approachRoute'] as Json),
      nextStop: json['nextStop'] == null
          ? null
          : TripStop.fromJson(json['nextStop'] as Json),
      remainingDistanceMeters: (json['remainingDistanceMeters'] as num?)
          ?.toDouble(),
      estimatedArrivalAt: json['estimatedArrivalAt'] as String?,
    );
  }
}
