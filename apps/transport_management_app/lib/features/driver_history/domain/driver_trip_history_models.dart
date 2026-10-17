typedef Json = Map<String, dynamic>;

final class DriverTripHistorySummary {
  const DriverTripHistorySummary({
    required this.id,
    required this.tripNumber,
    required this.status,
    required this.category,
    required this.participationStartedAt,
    required this.participationSource,
    this.plannedStartAt,
    this.actualStartAt,
    this.arrivedPickupAt,
    this.arrivedDeliveryAt,
    this.completedAt,
    this.cancelledAt,
    this.truckPlate,
    this.clientName,
    this.pickup,
    this.delivery,
    this.plannedDistanceMeters,
    this.plannedDurationSeconds,
    this.participationEndedAt,
  });

  final String id, tripNumber, status, category, participationSource;
  final DateTime participationStartedAt;
  final DateTime? plannedStartAt,
      actualStartAt,
      arrivedPickupAt,
      arrivedDeliveryAt,
      completedAt,
      cancelledAt,
      participationEndedAt;
  final String? truckPlate, clientName, pickup, delivery;
  final double? plannedDistanceMeters;
  final int? plannedDurationSeconds;

  factory DriverTripHistorySummary.fromJson(Json json) =>
      DriverTripHistorySummary(
        id: json['id'] as String,
        tripNumber: json['tripNumber'] as String,
        status: json['status'] as String,
        category: json['category'] as String,
        plannedStartAt: _date(json['plannedStartAt']),
        actualStartAt: _date(json['actualStartAt']),
        arrivedPickupAt: _date(json['arrivedPickupAt']),
        arrivedDeliveryAt: _date(json['arrivedDeliveryAt']),
        completedAt: _date(json['completedAt']),
        cancelledAt: _date(json['cancelledAt']),
        truckPlate: json['truckPlate'] as String?,
        clientName: json['clientName'] as String?,
        pickup: json['pickup'] as String?,
        delivery: json['delivery'] as String?,
        plannedDistanceMeters: (json['plannedDistanceMeters'] as num?)
            ?.toDouble(),
        plannedDurationSeconds: json['plannedDurationSeconds'] as int?,
        participationStartedAt: DateTime.parse(
          json['participationStartedAt'] as String,
        ),
        participationEndedAt: _date(json['participationEndedAt']),
        participationSource: json['participationSource'] as String,
      );
}

final class DriverTripHistoryPage {
  const DriverTripHistoryPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<DriverTripHistorySummary> items;
  final int totalCount, page, pageSize, totalPages;

  factory DriverTripHistoryPage.fromJson(Json json) => DriverTripHistoryPage(
    items: (json['items'] as List<dynamic>)
        .cast<Json>()
        .map(DriverTripHistorySummary.fromJson)
        .toList(),
    totalCount: json['totalCount'] as int,
    page: json['page'] as int,
    pageSize: json['pageSize'] as int,
    totalPages: json['totalPages'] as int,
  );
}

final class DriverTripHistoryStop {
  const DriverTripHistoryStop({
    required this.sequence,
    required this.type,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.plannedArrivalAt,
  });

  final int sequence;
  final String type, name;
  final String? address;
  final double? latitude, longitude;
  final DateTime? plannedArrivalAt;
  bool get hasCoordinates => latitude != null && longitude != null;

  factory DriverTripHistoryStop.fromJson(Json json) => DriverTripHistoryStop(
    sequence: json['sequence'] as int,
    type: json['type'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    plannedArrivalAt: _date(json['plannedArrivalAt']),
  );
}

final class DriverTripHistoryEvent {
  const DriverTripHistoryEvent({
    required this.type,
    required this.occurredAt,
    required this.source,
  });
  final String type, source;
  final DateTime occurredAt;
  factory DriverTripHistoryEvent.fromJson(Json json) => DriverTripHistoryEvent(
    type: json['type'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    source: json['source'] as String,
  );
}

final class DriverTripHistoryPosition {
  const DriverTripHistoryPosition({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });
  final double latitude, longitude;
  final DateTime recordedAt;
  factory DriverTripHistoryPosition.fromJson(Json json) =>
      DriverTripHistoryPosition(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

final class DriverTripParticipation {
  const DriverTripParticipation({
    required this.startedAt,
    required this.source,
    required this.startedPhase,
    this.endedAt,
    this.endedPhase,
  });
  final DateTime startedAt;
  final DateTime? endedAt;
  final String source, startedPhase;
  final String? endedPhase;
  factory DriverTripParticipation.fromJson(Json json) =>
      DriverTripParticipation(
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: _date(json['endedAt']),
        source: json['source'] as String,
        startedPhase: json['startedPhase'] as String,
        endedPhase: json['endedPhase'] as String?,
      );
}

final class DriverTripHistoryDetail {
  const DriverTripHistoryDetail({
    required this.summary,
    required this.cargoDescription,
    required this.stops,
    required this.timeline,
    required this.participations,
    required this.trail,
    required this.trailWasDownsampled,
    this.cancellationReason,
    this.routeGeometry,
    this.routeGeometryFormat,
  });
  final DriverTripHistorySummary summary;
  final String cargoDescription;
  final String? cancellationReason, routeGeometry, routeGeometryFormat;
  final List<DriverTripHistoryStop> stops;
  final List<DriverTripHistoryEvent> timeline;
  final List<DriverTripParticipation> participations;
  final List<DriverTripHistoryPosition> trail;
  final bool trailWasDownsampled;

  factory DriverTripHistoryDetail.fromJson(Json json) =>
      DriverTripHistoryDetail(
        summary: DriverTripHistorySummary.fromJson(json['summary'] as Json),
        cargoDescription: json['cargoDescription'] as String,
        cancellationReason: json['cancellationReason'] as String?,
        stops: (json['stops'] as List<dynamic>)
            .cast<Json>()
            .map(DriverTripHistoryStop.fromJson)
            .toList(),
        routeGeometry: json['routeGeometry'] as String?,
        routeGeometryFormat: json['routeGeometryFormat'] as String?,
        timeline: (json['timeline'] as List<dynamic>)
            .cast<Json>()
            .map(DriverTripHistoryEvent.fromJson)
            .toList(),
        participations: (json['participations'] as List<dynamic>)
            .cast<Json>()
            .map(DriverTripParticipation.fromJson)
            .toList(),
        trail: (json['trail'] as List<dynamic>)
            .cast<Json>()
            .map(DriverTripHistoryPosition.fromJson)
            .toList(),
        trailWasDownsampled: json['trailWasDownsampled'] as bool,
      );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;
