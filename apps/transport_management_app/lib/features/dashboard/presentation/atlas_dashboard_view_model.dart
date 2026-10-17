import '../domain/active_operation.dart';
import '../domain/dashboard_models.dart';

enum AtlasMetricKind { connected, moving, available, activeTrips, attention }

enum FleetViewFilter { all, connected, moving, stationary, offline, attention }

final class AtlasMetricValue {
  const AtlasMetricValue(this.kind, this.value);

  final AtlasMetricKind kind;
  final int? value;
  bool get isAvailable => value != null;
}

/// Pure presentation adapter for the Atlas Pulse dashboard. Operational
/// semantics remain owned by the API response and map/tracking controllers.
final class AtlasDashboardViewModel {
  const AtlasDashboardViewModel(this.data);

  final DashboardData data;

  List<AtlasMetricValue> get metrics => [
    AtlasMetricValue(
      AtlasMetricKind.connected,
      _integer(data.tracking, 'online'),
    ),
    AtlasMetricValue(
      AtlasMetricKind.moving,
      data.positions.where(_isMoving).length,
    ),
    AtlasMetricValue(
      AtlasMetricKind.available,
      _integer(data.fleet, 'available'),
    ),
    AtlasMetricValue(
      AtlasMetricKind.activeTrips,
      _integer(data.trips, 'active'),
    ),
    AtlasMetricValue(
      AtlasMetricKind.attention,
      data.activeTrips.where((operation) => operation.needsAttention).length,
    ),
  ];

  List<TrackedTruck> filtered(FleetViewFilter filter) {
    final attentionTruckIds = data.activeTrips
        .where((operation) => operation.needsAttention)
        .map((operation) => operation.truckId)
        .whereType<String>()
        .toSet();
    return data.positions
        .where((truck) {
          return switch (filter) {
            FleetViewFilter.all => true,
            FleetViewFilter.connected => truck.isOnline,
            FleetViewFilter.moving => _isMoving(truck),
            FleetViewFilter.stationary => truck.isOnline && !_isMoving(truck),
            FleetViewFilter.offline => !truck.isOnline,
            FleetViewFilter.attention => attentionTruckIds.contains(
              truck.truckId,
            ),
          };
        })
        .toList(growable: false);
  }

  TrackedTruck? truck(String? id) {
    if (id == null) return null;
    return data.positions.where((truck) => truck.truckId == id).firstOrNull;
  }

  ActiveOperation? operationForTruck(String? truckId) {
    if (truckId == null) return null;
    return data.activeTrips
        .where((operation) => operation.truckId == truckId)
        .firstOrNull;
  }

  String? retainSelection(String? selectedTruckId) =>
      truck(selectedTruckId)?.truckId;

  List<ActiveOperation> get activeTrips {
    final copy = [...data.activeTrips];
    copy.sort((left, right) {
      final attention = left.attentionPriority.compareTo(
        right.attentionPriority,
      );
      if (attention != 0) return attention;
      final leftEta = DateTime.tryParse(left.estimatedArrivalAt ?? '');
      final rightEta = DateTime.tryParse(right.estimatedArrivalAt ?? '');
      if (leftEta != null && rightEta != null) {
        return leftEta.compareTo(rightEta);
      }
      if (leftEta != null) return -1;
      if (rightEta != null) return 1;
      return right.progressPercent?.compareTo(left.progressPercent ?? -1) ?? 0;
    });
    return copy;
  }

  List<ActiveOperation> get exceptions => activeTrips
      .where((operation) => operation.needsAttention)
      .toList(growable: false);

  static bool _isMoving(TrackedTruck truck) =>
      truck.isOnline && truck.speed > .5;

  static int? _integer(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is num ? value.toInt() : null;
  }
}
