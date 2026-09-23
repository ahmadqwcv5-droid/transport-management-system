part of 'fleet_map.dart';

class TrailLegend extends StatelessWidget {
  const TrailLegend({
    required this.showTrail,
    required this.onChanged,
    super.key,
  });
  final bool showTrail;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('fleet-trail-legend'),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 6, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LegendLine(color: Color(0xFF175CD3)),
          Text(context.l10n.cargoRoute),
          const SizedBox(width: 8),
          const _LegendLine(color: Color(0xFFD97706), dashed: true),
          Text(context.l10n.approachRoute),
          const SizedBox(width: 8),
          const _LegendLine(color: Color(0xFF047857)),
          Text(context.l10n.travelledTrail),
          const SizedBox(width: 4),
          Switch(
            key: const Key('fleet-trail-visibility'),
            value: showTrail,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, this.dashed = false});
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 4,
    child: Row(
      children: List.generate(
        dashed ? 3 : 1,
        (_) => Expanded(
          child: Container(
            margin: EdgeInsetsDirectional.only(end: dashed ? 2 : 0),
            color: color,
          ),
        ),
      ),
    ),
  );
}

class _SelectedTruckCard extends StatelessWidget {
  const _SelectedTruckCard({
    required this.position,
    required this.onClose,
    required this.onRecenter,
    required this.detail,
    required this.loading,
  });
  final TrackedTruck position;
  final FleetTripDetail? detail;
  final bool loading;
  final VoidCallback onClose;
  final VoidCallback onRecenter;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 6,
    child: SizedBox(
      width: 270,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    position.plateNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.close,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _CompactStatusChip(
                  label: localizedStatus(context.l10n, position.truckStatus),
                ),
                _CompactStatusChip(
                  label: position.isOnline
                      ? context.l10n.online
                      : context.l10n.offline,
                ),
                _CompactStatusChip(
                  label: !position.isOnline
                      ? context.l10n.offline
                      : position.speed > 0.5
                      ? context.l10n.moving
                      : context.l10n.stationary,
                ),
              ],
            ),
            Text(
              '${context.l10n.speed}: ${position.speed.toStringAsFixed(0)} km/h',
            ),
            Text(
              '${context.l10n.driver}: ${position.driverName ?? context.l10n.notAssigned}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${context.l10n.activeTrip}: ${position.currentTripId ?? context.l10n.notAssigned}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${context.l10n.lastUpdate}: ${_compactTimestamp(position.recordedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (loading) const LinearProgressIndicator(),
            if (detail != null) ...[
              const Divider(),
              Text(
                key: const Key('fleet-route-progress'),
                '${context.l10n.routeProgress}: ${detail!.displayedProgress.progressPercent?.toStringAsFixed(1) ?? '—'}%',
              ),
              Text(
                '${context.l10n.remainingDistance}: ${((detail!.displayedProgress.remainingDistanceMeters ?? 0) / 1000).toStringAsFixed(1)} km',
              ),
              Text(
                '${context.l10n.eta}: ${detail!.displayedProgress.estimatedArrivalAt ?? '—'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                detail!.displayedProgress.isOffRoute == true
                    ? context.l10n.offRoute
                    : context.l10n.onRoute,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const Key('fleet-map-recenter'),
                onPressed: onRecenter,
                icon: const Icon(Icons.center_focus_strong),
                label: Text(
                  detail == null
                      ? context.l10n.recenter
                      : context.l10n.fitRoute,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompactStatusChip extends StatelessWidget {
  const _CompactStatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

String _compactTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final utc = parsed.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

class _FleetPanel extends StatelessWidget {
  const _FleetPanel({
    required this.positions,
    required this.selectedTruckId,
    required this.onTruckSelected,
  });

  final List<TrackedTruck> positions;
  final String? selectedTruckId;
  final ValueChanged<TrackedTruck> onTruckSelected;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('map-annotations-ready'),
    elevation: 5,
    child: SizedBox(
      width: 220,
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
            child: Text(
              context.l10n.fleetList,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: positions.isEmpty
                ? Center(child: Text(context.l10n.noTrackedTrucks))
                : ListView.builder(
                    padding: const EdgeInsetsDirectional.only(bottom: 6),
                    itemCount: positions.length,
                    itemBuilder: (context, index) {
                      final position = positions[index];
                      final selected = position.truckId == selectedTruckId;
                      return Material(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Colors.transparent,
                        child: ListTile(
                          key: Key('real-map-truck-${position.truckId}'),
                          dense: true,
                          selected: selected,
                          leading: Icon(
                            Icons.local_shipping,
                            color: !position.isOnline
                                ? Colors.grey
                                : position.speed > 0.5
                                ? Colors.green
                                : Colors.blue,
                          ),
                          title: Text(position.plateNumber),
                          subtitle: Text(
                            !position.isOnline
                                ? context.l10n.offline
                                : position.speed > 0.5
                                ? context.l10n.moving
                                : context.l10n.stationary,
                          ),
                          onTap: () => onTruckSelected(position),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.actions,
    super.key,
  });

  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    ),
  );
}

class _FallbackMap extends StatelessWidget {
  const _FallbackMap({required this.positions, required this.onTruckSelected});

  final List<TrackedTruck> positions;
  final ValueChanged<TrackedTruck> onTruckSelected;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Container(
        key: const Key('offline-map-surface'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: positions.isEmpty
              ? Text(context.l10n.noTrackedTrucks)
              : const Icon(Icons.grid_view_rounded, size: 72),
        ),
      ),
      PositionedDirectional(
        start: 12,
        top: 12,
        child: Chip(
          key: const Key('map-status-fallback'),
          avatar: const Icon(Icons.info_outline),
          label: Text(context.l10n.fallbackMode),
        ),
      ),
      ...positions.asMap().entries.map(
        (entry) => PositionedDirectional(
          start: 28.0 + (entry.key * 83) % 520,
          top: 78.0 + (entry.key * 57) % 210,
          child: Tooltip(
            message: entry.value.plateNumber,
            child: InkWell(
              key: Key('fallback-truck-marker-${entry.value.truckId}'),
              onTap: () => onTruckSelected(entry.value),
              child: CircleAvatar(
                backgroundColor: entry.value.isOnline
                    ? Colors.green
                    : Colors.grey,
                child: const Icon(Icons.local_shipping, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
