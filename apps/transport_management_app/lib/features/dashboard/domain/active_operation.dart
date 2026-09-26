final class ActiveOperation {
  const ActiveOperation({
    required this.tripId,
    required this.tripNumber,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.operationalPhase,
    required this.nextMilestone,
    required this.trackingHealth,
    required this.attentionCode,
    required this.attentionPriority,
    this.truckId,
    this.truckPlateNumber,
    this.truckFleetCode,
    this.truckPhotoThumbnailUrl,
    this.driverId,
    this.driverName,
    this.nextStopName,
    this.progressPercent,
    this.remainingDistanceMeters,
    this.estimatedArrivalAt,
    this.lastPositionAt,
    this.isOnline,
    this.isOffRoute,
    this.waitingSince,
  });

  final String tripId, tripNumber, clientId, clientName, status;
  final String operationalPhase, nextMilestone, trackingHealth, attentionCode;
  final int attentionPriority;
  final String? truckId, truckPlateNumber, truckFleetCode;
  final String? truckPhotoThumbnailUrl, driverId, driverName, nextStopName;
  final double? progressPercent, remainingDistanceMeters;
  final String? estimatedArrivalAt, lastPositionAt, waitingSince;
  final bool? isOnline, isOffRoute;

  bool get needsAttention => attentionCode != 'NONE';
  bool get isMoving => progressPercent != null;

  factory ActiveOperation.fromJson(Map<String, dynamic> json) =>
      ActiveOperation(
        tripId: json['tripId'] as String,
        tripNumber: json['tripNumber'] as String,
        clientId: json['clientId'] as String,
        clientName: json['clientName'] as String,
        truckId: json['truckId'] as String?,
        truckPlateNumber: json['truckPlateNumber'] as String?,
        truckFleetCode: json['truckFleetCode'] as String?,
        truckPhotoThumbnailUrl: json['truckPhotoThumbnailUrl'] as String?,
        driverId: json['driverId'] as String?,
        driverName: json['driverName'] as String?,
        status: json['status'] as String,
        operationalPhase: json['operationalPhase'] as String,
        nextMilestone: json['nextMilestone'] as String,
        nextStopName: json['nextStopName'] as String?,
        progressPercent: (json['progressPercent'] as num?)?.toDouble(),
        remainingDistanceMeters: (json['remainingDistanceMeters'] as num?)
            ?.toDouble(),
        estimatedArrivalAt: json['estimatedArrivalAt'] as String?,
        lastPositionAt: json['lastPositionAt'] as String?,
        trackingHealth: json['trackingHealth'] as String,
        isOnline: json['isOnline'] as bool?,
        isOffRoute: json['isOffRoute'] as bool?,
        attentionCode: json['attentionCode'] as String,
        attentionPriority: json['attentionPriority'] as int,
        waitingSince: json['waitingSince'] as String?,
      );
}

final class ActiveOperationsPage {
  const ActiveOperationsPage({
    required this.items,
    required this.totalCount,
    required this.generatedAt,
  });
  final List<ActiveOperation> items;
  final int totalCount;
  final String generatedAt;

  factory ActiveOperationsPage.fromJson(Map<String, dynamic> json) =>
      ActiveOperationsPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ActiveOperation.fromJson)
            .toList(),
        totalCount: json['totalCount'] as int? ?? 0,
        generatedAt: json['generatedAt'] as String? ?? '',
      );
}
