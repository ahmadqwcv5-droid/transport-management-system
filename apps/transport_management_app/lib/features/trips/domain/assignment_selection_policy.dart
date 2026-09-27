import 'trip_models.dart';

enum DriverSelectionSource { none, manual, truckDefault, existingAssignment }

final class AssignmentSelection {
  const AssignmentSelection({
    required this.truckId,
    required this.driverId,
    required this.source,
  });

  final String? truckId;
  final String? driverId;
  final DriverSelectionSource source;
}

abstract final class AssignmentSelectionPolicy {
  static AssignmentSelection initial(AssignmentOptions options) {
    final truckId = _eligible(options.trucks, options.currentTruckId);
    final currentDriver = _eligible(options.drivers, options.currentDriverId);
    if (currentDriver != null) {
      return AssignmentSelection(
        truckId: truckId,
        driverId: currentDriver,
        source: DriverSelectionSource.existingAssignment,
      );
    }
    final suggested = eligibleDefaultDriver(options, truckId);
    return AssignmentSelection(
      truckId: truckId,
      driverId: suggested,
      source: suggested == null
          ? DriverSelectionSource.none
          : DriverSelectionSource.truckDefault,
    );
  }

  static AssignmentSelection selectTruck(
    AssignmentOptions options,
    String? truckId, {
    required String? currentDriverId,
    required DriverSelectionSource currentSource,
  }) {
    final manualStillEligible =
        currentSource == DriverSelectionSource.manual &&
        _eligible(options.drivers, currentDriverId) != null;
    if (manualStillEligible) {
      return AssignmentSelection(
        truckId: truckId,
        driverId: currentDriverId,
        source: DriverSelectionSource.manual,
      );
    }
    final suggested = eligibleDefaultDriver(options, truckId);
    return AssignmentSelection(
      truckId: truckId,
      driverId: suggested,
      source: suggested == null
          ? DriverSelectionSource.none
          : DriverSelectionSource.truckDefault,
    );
  }

  static String? eligibleDefaultDriver(
    AssignmentOptions options,
    String? truckId,
  ) {
    final defaultId = options.trucks
        .where((truck) => truck.id == truckId)
        .firstOrNull
        ?.defaultDriverId;
    return _eligible(options.drivers, defaultId);
  }

  static String? _eligible(
    List<AssignmentResourceOption> options,
    String? id,
  ) => id != null && options.any((item) => item.id == id && item.isEligible)
      ? id
      : null;
}
