import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../design_system/app_design_tokens.dart';
import '../../../design_system/components/app_page_header.dart';
import '../../../design_system/components/app_state_panel.dart';
import '../../../design_system/components/app_status_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../domain/driver_trip_history_models.dart';
import 'driver_trip_history_controller.dart';
import 'driver_trip_history_map.dart';

class DriverTripHistoryDetailScreen extends ConsumerWidget {
  const DriverTripHistoryDetailScreen({required this.tripId, super.key});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverTripHistoryDetailProvider(tripId));
    return state.when(
      loading: () => AppStatePanel(
        kind: AppStateKind.loading,
        title: context.l10n.loading,
      ),
      error: (_, _) => AppStatePanel(
        kind: AppStateKind.error,
        title: context.l10n.genericError,
        actionLabel: context.l10n.retry,
        onAction: () => ref.invalidate(driverTripHistoryDetailProvider(tripId)),
      ),
      data: (detail) => _Detail(detail: detail),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});
  final DriverTripHistoryDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    return ListView(
      key: const Key('driver-trip-history-detail'),
      padding: EdgeInsets.all(context.tokens.space4),
      children: [
        AppPageHeader(
          title: summary.tripNumber,
          subtitle: context.l10n.tripDetails,
          leading: const BackButton(),
          actions: [
            AppStatusBadge(
              label: localizedStatus(context.l10n, summary.status),
              tone: _tone(summary.status),
              icon: Icons.route_outlined,
            ),
          ],
        ),
        SizedBox(height: context.tokens.space4),
        _Overview(detail: detail),
        SizedBox(height: context.tokens.space4),
        Text(
          context.l10n.tripRouteAndTrail,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: context.tokens.space2),
        SizedBox(height: 420, child: DriverTripHistoryMap(detail: detail)),
        if (detail.trailWasDownsampled) ...[
          SizedBox(height: context.tokens.space2),
          Text(
            context.l10n.trailDownsampled,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.textMuted),
          ),
        ],
        SizedBox(height: context.tokens.space5),
        Text(
          context.l10n.pickupAndDelivery,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: context.tokens.space2),
        if (detail.stops.isEmpty)
          AppStatePanel(
            compact: true,
            kind: AppStateKind.empty,
            title: context.l10n.routeAndTrailUnavailable,
          )
        else
          ...detail.stops.map((stop) => _StopTile(stop: stop)),
        SizedBox(height: context.tokens.space5),
        Text(
          context.l10n.tripParticipation,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: context.tokens.space2),
        ...detail.participations.map(
          (item) => _TimelineTile(
            icon: Icons.badge_outlined,
            title: localizedStatus(context.l10n, item.startedPhase),
            subtitle: _interval(context, item.startedAt, item.endedAt),
          ),
        ),
        SizedBox(height: context.tokens.space5),
        Text(
          context.l10n.timeline,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: context.tokens.space2),
        if (detail.timeline.isEmpty)
          AppStatePanel(
            compact: true,
            kind: AppStateKind.empty,
            title: context.l10n.timeline,
          )
        else
          ...detail.timeline.map(
            (event) => _TimelineTile(
              icon: Icons.circle_outlined,
              title: _eventLabel(context.l10n, event.type),
              subtitle: _date(context, event.occurredAt),
            ),
          ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.detail});
  final DriverTripHistoryDetail detail;
  @override
  Widget build(BuildContext context) {
    final item = detail.summary;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.tokens.space4),
        child: Wrap(
          spacing: context.tokens.space5,
          runSpacing: context.tokens.space4,
          children: [
            _Fact(
              label: context.l10n.pickup,
              value: item.pickup ?? context.l10n.routeAndTrailUnavailable,
            ),
            _Fact(
              label: context.l10n.delivery,
              value: item.delivery ?? context.l10n.routeAndTrailUnavailable,
            ),
            if (item.truckPlate != null)
              _Fact(label: context.l10n.truck, value: item.truckPlate!),
            if (item.clientName != null)
              _Fact(label: context.l10n.client, value: item.clientName!),
            _Fact(
              label: context.l10n.cargoDescription,
              value: detail.cargoDescription,
            ),
            if (item.plannedDistanceMeters != null)
              _Fact(
                label: context.l10n.plannedDistance,
                value: context.l10n.kilometersValue(
                  (item.plannedDistanceMeters! / 1000).toStringAsFixed(1),
                ),
              ),
            if (item.plannedDurationSeconds != null)
              _Fact(
                label: context.l10n.plannedDuration,
                value: context.l10n.minutesValue(
                  (item.plannedDurationSeconds! / 60).round(),
                ),
              ),
            if (detail.cancellationReason != null)
              _Fact(
                label: context.l10n.cancellationReason,
                value: detail.cancellationReason!,
              ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: context.tokens.textMuted),
        ),
        SizedBox(height: context.tokens.space1),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop});
  final DriverTripHistoryStop stop;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          stop.type == 'Pickup'
              ? Icons.upload_outlined
              : Icons.download_outlined,
        ),
      ),
      title: Text(stop.name),
      subtitle: stop.address == null ? null : Text(stop.address!),
      trailing: Text(
        stop.type == 'Pickup' ? context.l10n.pickup : context.l10n.delivery,
      ),
    ),
  );
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    contentPadding: EdgeInsetsDirectional.symmetric(
      horizontal: context.tokens.space2,
    ),
  );
}

String _date(BuildContext context, DateTime value) => DateFormat.yMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).add_jm().format(value.toLocal());

String _interval(BuildContext context, DateTime start, DateTime? end) =>
    '${_date(context, start)} — ${end == null ? '…' : _date(context, end)}';

String _eventLabel(AppLocalizations l10n, String value) => switch (value) {
  'TripCreated' => l10n.eventTripCreated,
  'TripDraftUpdated' => l10n.eventDraftUpdated,
  'TripStopsUpdated' => l10n.eventStopsUpdated,
  'TripRouteCalculated' => l10n.eventRouteCalculated,
  'TripAssigned' => l10n.eventAssigned,
  'TripReassigned' => l10n.eventReassigned,
  'TripUnassigned' => l10n.eventUnassigned,
  'TripDispatchedToPickup' => l10n.eventDispatchedToPickup,
  'TripArrivedAtPickup' => l10n.eventArrivedAtPickup,
  'TripStarted' => l10n.eventTripStarted,
  'TripMarkedInTransit' => l10n.eventMarkedInTransit,
  'TripDelivered' => l10n.eventDelivered,
  'TripCompleted' => l10n.eventCompleted,
  'TripCancelled' => l10n.eventCancelled,
  _ => l10n.notificationUnknownType(value),
};

AppStatusTone _tone(String status) => switch (status) {
  'Completed' => AppStatusTone.success,
  'Cancelled' => AppStatusTone.danger,
  'Assigned' => AppStatusTone.information,
  _ => AppStatusTone.warning,
};
