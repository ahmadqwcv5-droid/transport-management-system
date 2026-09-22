import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../dashboard/presentation/simulator_controls.dart';
import '../../locations/presentation/location_picker_dialog.dart';
import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
import '../../../l10n/l10n_extensions.dart';

final tripDetailsProvider = FutureProvider.autoDispose.family<Trip, String>(
  (ref, id) => ref.watch(operationsRepositoryProvider).getTrip(id),
);

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({required this.tripId, super.key});
  final String tripId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(tripDetailsProvider(tripId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is ApiException
                    ? localizedApiError(context, error)
                    : context.l10n.genericError,
              ),
              TextButton(
                onPressed: () => ref.invalidate(tripDetailsProvider(tripId)),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
        data: (trip) => _TripDetailsContent(trip: trip),
      );
}

class _TripDetailsContent extends ConsumerWidget {
  const _TripDetailsContent({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationsView(
    builder: (context, ref, data) {
      final client = data.clients
          .where((item) => item.id == trip.clientId)
          .firstOrNull;
      final truck = data.trucks
          .where((item) => item.id == trip.truckId)
          .firstOrNull;
      final driver = data.drivers
          .where((item) => item.id == trip.driverId)
          .firstOrNull;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: context.l10n.backToTrips,
                onPressed: () => context.go('/trips'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${trip.tripNumber} · ${trip.origin == null || trip.destination == null ? context.l10n.incompleteDraft : '${trip.origin} → ${trip.destination}'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Chip(label: Text(localizedStatus(context.l10n, trip.status))),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  _Fact(
                    context.l10n.client,
                    client?.name ?? context.l10n.unknown,
                  ),
                  _Fact(context.l10n.cargo, trip.cargoDescription),
                  _Fact(
                    context.l10n.truck,
                    truck?.plateNumber ?? context.l10n.notAssigned,
                  ),
                  _Fact(
                    context.l10n.driver,
                    driver?.fullName ?? context.l10n.notAssigned,
                  ),
                  _Fact(context.l10n.planned, trip.plannedStartAt ?? context.l10n.notAssigned),
                  _Fact(context.l10n.price, trip.price?.toStringAsFixed(2) ?? context.l10n.notAssigned),
                  if (trip.actualStartAt != null)
                    _Fact(context.l10n.started, trip.actualStartAt!),
                  if (trip.arrivedPickupAt != null)
                    _Fact(context.l10n.atPickup, trip.arrivedPickupAt!),
                  if (trip.deliveredAt != null)
                    _Fact(context.l10n.delivered, trip.deliveredAt!),
                  if (trip.completedAt != null)
                    _Fact(context.l10n.completed, trip.completedAt!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: trip.routePlan == null
                  ? Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(context.l10n.legacyTripRouteWarning),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 32,
                      runSpacing: 16,
                      children: [
                        _Fact(
                          context.l10n.routeDistance,
                          '${(trip.routePlan!.distanceMeters / 1000).toStringAsFixed(1)} km',
                        ),
                        _Fact(
                          context.l10n.routeDuration,
                          '${Duration(seconds: trip.routePlan!.estimatedDurationSeconds).inMinutes} min',
                        ),
                        _Fact(
                          context.l10n.routeProvider,
                          trip.routePlan!.providerName,
                        ),
                        for (final stop in trip.stops)
                          _Fact(
                            localizedStatus(context.l10n, stop.type),
                            stop.name,
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (trip.repositioningPlan != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: [
                    _Fact(
                      context.l10n.approachDistance,
                      '${(trip.repositioningPlan!.route.distanceMeters / 1000).toStringAsFixed(1)} km',
                    ),
                    _Fact(
                      context.l10n.approachDuration,
                      '${Duration(seconds: trip.repositioningPlan!.route.estimatedDurationSeconds).inMinutes} min',
                    ),
                    _Fact(
                      context.l10n.status,
                      localizedStatus(
                        context.l10n,
                        trip.repositioningPlan!.status,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.timeline,
                    style: Theme.of(context).textTheme.titleMedium),
                FutureBuilder<List<TripEvent>>(
                  future: ref.read(operationsRepositoryProvider).timeline(trip.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Text(context.l10n.loading);
                    return Column(children: snapshot.data!.map((event) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text(localizedTripEvent(context.l10n, event.eventType)),
                      subtitle: Text(
                        '${event.actorDisplayName} · ${DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).add_jm().format(DateTime.parse(event.occurredAt).toLocal())}',
                      ),
                    )).toList());
                  },
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (canManageOperations(ref))
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (trip.status == 'Draft')
                  OutlinedButton.icon(
                    onPressed: () => context.go('/trips/${trip.id}/edit'),
                    icon: const Icon(Icons.edit),
                    label: Text(context.l10n.editDraft),
                  ),
                for (final action in trip.allowedActions.where(
                  (value) => value != 'dispatch-to-pickup',
                ))
                  FilledButton(
                    key: Key('trip-action-$action'),
                    style: const {'delete', 'cancel'}.contains(action)
                        ? FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          )
                        : null,
                    onPressed: () => action == 'assign' || action == 'reassign'
                        ? _assign(context, ref, data, trip,
                            reassign: action == 'reassign')
                        : action == 'preview-repositioning'
                        ? _previewAndDispatch(
                            context,
                            ref,
                            trip,
                            truckId: truck?.id,
                            plateNumber: truck?.plateNumber,
                          )
                        : _act(context, ref, trip, action),
                    child: Text(_label(context, action)),
                  ),
              ],
            ),
        ],
      );
    },
  );
  static String _label(BuildContext context, String value) => switch (value) {
    'assign' => context.l10n.assign,
    'start' => context.l10n.start,
    'preview-repositioning' => context.l10n.previewApproach,
    'arrive-pickup' => context.l10n.confirmPickupArrival,
    'mark-in-transit' => context.l10n.markInTransit,
    'deliver' => context.l10n.deliver,
    'complete' => context.l10n.complete,
    'cancel' => context.l10n.cancel,
    'delete' => context.l10n.delete,
    'reassign' => context.l10n.reassign,
    'unassign' => context.l10n.unassign,
    'archive' => context.l10n.archive,
    'unarchive' => context.l10n.unarchive,
    'duplicate' => context.l10n.duplicateAsDraft,
    _ => value,
  };
  static Future<void> _previewAndDispatch(
    BuildContext context,
    WidgetRef ref,
    Trip trip, {
    String? truckId,
    String? plateNumber,
  }) async {
    RepositioningPreview? preview;
    try {
      preview = await ref
          .read(operationsRepositoryProvider)
          .previewRepositioning(trip.id);
      await ref.read(operationsControllerProvider.notifier).reload();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      if (SimulatorControls.enabled &&
          truckId != null &&
          plateNumber != null &&
          const {
            'TRUCK_POSITION_REQUIRED',
            'TRUCK_POSITION_STALE',
            'TRUCK_OFFLINE',
          }.contains(error.code)) {
        await _recoverLocation(context, ref, truckId, plateNumber, error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedApiError(context, error))),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final resolvedPreview = preview;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.dispatchToPickup),
        content: Text(
          resolvedPreview.alreadyAtPickup
              ? context.l10n.alreadyAtPickup
              : '${context.l10n.approachDistance}: '
                    '${(resolvedPreview.plan!.route.distanceMeters / 1000).toStringAsFixed(1)} km\n'
                    '${context.l10n.approachDuration}: '
                    '${Duration(seconds: resolvedPreview.plan!.route.estimatedDurationSeconds).inMinutes} min',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-dispatch-to-pickup'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.dispatchToPickup),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final dispatched = await ref
        .read(operationsControllerProvider.notifier)
        .mutate(
          (repo) => repo.dispatchToPickup(trip.id, resolvedPreview.plan?.id),
        );
    if (context.mounted) {
      showResult(
        context,
        dispatched,
        successMessage: context.l10n.dispatchStarted,
      );
      if (dispatched) ref.invalidate(tripDetailsProvider(trip.id));
    }
  }

  static Future<void> _recoverLocation(
    BuildContext context,
    WidgetRef ref,
    String truckId,
    String plateNumber,
    ApiException error,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('truck-location-recovery'),
        title: Text(context.l10n.fixTruckLocation),
        content: Text(localizedApiError(context, error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          if (error.code == 'TRUCK_POSITION_STALE')
            OutlinedButton(
              key: const Key('recover-refresh-location'),
              onPressed: () => Navigator.pop(dialogContext, 'refresh'),
              child: Text(context.l10n.refreshLocation),
            ),
          if (error.code == 'TRUCK_OFFLINE')
            OutlinedButton(
              key: const Key('recover-set-online'),
              onPressed: () => Navigator.pop(dialogContext, 'online'),
              child: Text(context.l10n.setOnline),
            ),
          FilledButton(
            key: const Key('recover-set-location'),
            onPressed: () => Navigator.pop(dialogContext, 'set'),
            child: Text(context.l10n.setSimulatedLocation),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    final dashboard = ref.read(dashboardRepositoryProvider);
    if (action == 'set') {
      final selected = await showLocationPickerDialog(
        context: context,
        title: context.l10n.locationForTruck(plateNumber),
        search: (query) =>
            ref.read(operationsRepositoryProvider).searchLocations(query),
      );
      if (selected == null) return;
      await dashboard.simulator(
        'set-position',
        truckId: truckId,
        latitude: selected.latitude,
        longitude: selected.longitude,
      );
    } else {
      await dashboard.simulator(
        action == 'refresh' ? 'refresh-position' : 'online',
        truckId: truckId,
      );
    }
    await ref.read(operationsControllerProvider.notifier).reload();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.locationCorrectedRetry)),
      );
    }
  }

  static Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    String action,
  ) async {
    String? reason;
    if (action == 'cancel') {
      final controller = TextEditingController();
      reason = await showDialog<String>(context: context, builder: (dialogContext) =>
        AlertDialog(title: Text(context.l10n.cancelTrip), content: TextField(
          key: const Key('cancel-reason'), controller: controller, maxLength: 500,
          decoration: InputDecoration(labelText: context.l10n.cancellationReason)),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel)), FilledButton(
            key: const Key('confirm-cancel-trip'),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.l10n.confirm))]));
      controller.dispose();
      if (reason == null || reason.isEmpty) return;
    } else if (const {'delete', 'unassign', 'archive', 'unarchive', 'duplicate'}.contains(action)) {
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_label(context, action)),
          content: Text(action == 'delete'
              ? context.l10n.deleteDraftWarning(trip.tripNumber)
              : context.l10n.confirmTripAction(trip.tripNumber)),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel)), FilledButton(
            key: Key('confirm-$action'), onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.confirm))]));
      if (confirmed != true) return;
    }
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate((repo) => switch (action) {
          'cancel' => repo.cancelTrip(trip.id, reason!),
          'delete' => repo.deleteDraft(trip.id),
          'unassign' => repo.unassignTrip(trip.id),
          'archive' => repo.archiveTrip(trip.id, archive: true),
          'unarchive' => repo.archiveTrip(trip.id, archive: false),
          'duplicate' => repo.duplicateTrip(trip.id),
          _ => repo.tripAction(trip.id, action),
        });
    if (context.mounted) {
      showResult(context, ok, successMessage: context.l10n.tripStatusUpdated);
      if (ok && action == 'delete') context.go('/trips');
      if (ok && action != 'delete') ref.invalidate(tripDetailsProvider(trip.id));
    }
  }

  static Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    OperationsData data,
    Trip trip,
    {bool reassign = false}
  ) async {
    final assignment = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AssignmentDialog(data),
    );
    if (assignment == null || !context.mounted) return;
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate(
          (repo) => reassign
              ? repo.reassignTrip(trip.id, assignment[0], assignment[1])
              : repo.assignTrip(trip.id, assignment[0], assignment[1]),
        );
    if (context.mounted) {
      showResult(context, ok, successMessage: context.l10n.resourcesAssigned);
      if (ok) ref.invalidate(tripDetailsProvider(trip.id));
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog(this.data);
  final OperationsData data;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late String? truckId = widget.data.trucks
      .where((item) => item.isActive && item.status == 'Available')
      .firstOrNull
      ?.id;
  late String? driverId = widget.data.drivers
      .where((item) => item.isActive && item.status == 'Available')
      .firstOrNull
      ?.id;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.assignResources),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('assign-truck'),
            initialValue: truckId,
            decoration: InputDecoration(labelText: context.l10n.truck),
            items: widget.data.trucks
                .where((item) => item.isActive && item.status == 'Available')
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.plateNumber),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => truckId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('assign-driver'),
            initialValue: driverId,
            decoration: InputDecoration(labelText: context.l10n.driver),
            items: widget.data.drivers
                .where((item) => item.isActive && item.status == 'Available')
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.fullName),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => driverId = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('confirm-assignment'),
        onPressed: truckId == null || driverId == null
            ? null
            : () => Navigator.pop(context, [truckId!, driverId!]),
        child: Text(context.l10n.assign),
      ),
    ],
  );
}
