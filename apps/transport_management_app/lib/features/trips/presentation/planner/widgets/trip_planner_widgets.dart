part of '../trip_planner_controller.dart';

String localizedAssignmentReason(
  dynamic l10n,
  AssignmentResourceOption option,
) => switch (option.reasonCode) {
  'AVAILABLE' => l10n.available,
  'RESOURCE_INACTIVE' => l10n.resourceInactive,
  'TRUCK_MAINTENANCE' => l10n.truckInMaintenance,
  'TRUCK_OUT_OF_SERVICE' => l10n.truckOutOfServiceReason,
  'TRUCK_ALREADY_ASSIGNED' =>
    option.conflictingTripNumber == null
        ? l10n.truckAlreadyAssigned
        : l10n.resourceAssignedToTrip(option.conflictingTripNumber!),
  'DRIVER_ALREADY_ASSIGNED' || 'DRIVER_ON_TRIP' =>
    option.conflictingTripNumber == null
        ? l10n.driverAlreadyAssigned
        : l10n.resourceAssignedToTrip(option.conflictingTripNumber!),
  'DRIVER_NOT_AVAILABLE' => l10n.driverNotAvailable,
  'TRIP_NOT_READY_FOR_ASSIGNMENT' => l10n.tripNotReadyForAssignment,
  _ => localizedStatus(l10n, option.status),
};

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.error = false,
    super.key,
  });
  final IconData icon;
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final color = error
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _RouteFacts extends StatelessWidget {
  const _RouteFacts({required this.route, required this.stale});
  final TripRoutePlan route;
  final bool stale;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.routeSummary,
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.straighten, size: 18),
          label: Text('${(route.distanceMeters / 1000).toStringAsFixed(1)} km'),
        ),
        Chip(
          avatar: const Icon(Icons.schedule, size: 18),
          label: Text(
            '${Duration(seconds: route.estimatedDurationSeconds).inMinutes} min',
          ),
        ),
        Chip(
          avatar: const Icon(Icons.route, size: 18),
          label: Text(route.providerName),
        ),
        if (stale) Chip(label: Text(context.l10n.routeStale)),
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
