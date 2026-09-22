import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../locations/presentation/location_picker_dialog.dart';
import '../../operations/presentation/operations_controller.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';

class SimulatorControls extends ConsumerStatefulWidget {
  const SimulatorControls({required this.trucks, super.key});

  static const enabled = bool.fromEnvironment(
    'ENABLE_SIMULATOR_CONTROLS',
    defaultValue: false,
  );

  final List<SimulatorTruck> trucks;

  @override
  ConsumerState<SimulatorControls> createState() => _SimulatorControlsState();
}

class _SimulatorControlsState extends ConsumerState<SimulatorControls> {
  String? _truckId;
  double _speedMultiplier = 1;

  SimulatorTruck? get _selected {
    if (widget.trucks.isEmpty) return null;
    return widget.trucks
            .where((truck) => truck.truckId == _truckId)
            .firstOrNull ??
        widget.trucks.first;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Card(
      key: const Key('simulator-controls'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.simulator,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in [
                  ('start', context.l10n.start),
                  ('pause', context.l10n.pause),
                  ('resume', context.l10n.resume),
                  ('stop', context.l10n.stop),
                  ('reset', context.l10n.reset),
                  ('step', context.l10n.step),
                ])
                  OutlinedButton(
                    key: Key('sim-${action.$1}'),
                    onPressed: () => _control(action.$1),
                    child: Text(action.$2),
                  ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<double>(
                    key: const Key('sim-speed-selector'),
                    initialValue: _speedMultiplier,
                    decoration: InputDecoration(
                      labelText: context.l10n.simulationSpeed,
                    ),
                    items: const [0.5, 1.0, 2.0, 5.0, 10.0]
                        .map(
                          (speed) => DropdownMenuItem(
                            value: speed,
                            child: Text('$speed×'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _speedMultiplier = value);
                      }
                    },
                  ),
                ),
                FilledButton.tonal(
                  key: const Key('sim-speed'),
                  onPressed: () =>
                      _control('speed', speedMultiplier: _speedMultiplier),
                  child: Text(context.l10n.applySpeed),
                ),
              ],
            ),
            const Divider(height: 24),
            if (widget.trucks.isEmpty)
              Text(context.l10n.noActiveTrucks)
            else ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      key: const Key('sim-truck-selector'),
                      initialValue: selected!.truckId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.selectTruck,
                      ),
                      items: widget.trucks
                          .map(
                            (truck) => DropdownMenuItem(
                              value: truck.truckId,
                              child: Text(
                                '${truck.plateNumber} · ${_stateLabel(context, truck.locationState)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _truckId = value),
                    ),
                  ),
                  Chip(
                    key: Key('sim-state-${selected.locationState}'),
                    avatar: Icon(_stateIcon(selected.locationState), size: 18),
                    label: Text(_stateLabel(context, selected.locationState)),
                  ),
                  if (selected.recordedAt != null)
                    Text(
                      context.l10n.locationAgeSeconds(
                        selected.positionAgeSeconds ?? 0,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_helper(context, selected)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('sim-set-location'),
                    onPressed: () => _pickLocation(selected),
                    icon: const Icon(Icons.add_location_alt),
                    label: Text(
                      selected.hasLocation
                          ? context.l10n.moveSimulatedTruck
                          : context.l10n.setSimulatedLocation,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('sim-refresh-location'),
                    onPressed:
                        selected.hasLocation &&
                            selected.locationState != 'Offline'
                        ? () => _control(
                            'refresh-position',
                            truckId: selected.truckId,
                          )
                        : null,
                    icon: const Icon(Icons.gps_fixed),
                    label: Text(context.l10n.refreshLocation),
                  ),
                  OutlinedButton(
                    key: const Key('sim-online'),
                    onPressed:
                        selected.hasLocation &&
                            selected.locationState == 'Offline'
                        ? () => _control('online', truckId: selected.truckId)
                        : null,
                    child: Text(context.l10n.setOnline),
                  ),
                  OutlinedButton(
                    key: const Key('sim-offline'),
                    onPressed:
                        selected.hasLocation &&
                            selected.locationState != 'Offline'
                        ? () => _control('offline', truckId: selected.truckId)
                        : null,
                    child: Text(context.l10n.setOffline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocation(SimulatorTruck truck) async {
    final selection = await showLocationPickerDialog(
      context: context,
      title: context.l10n.locationForTruck(truck.plateNumber),
      initial: truck.hasLocation
          ? LocationSelection(
              latitude: truck.latitude!,
              longitude: truck.longitude!,
            )
          : null,
      search: (query) =>
          ref.read(operationsRepositoryProvider).searchLocations(query),
    );
    if (selection == null) return;
    await _control(
      'set-position',
      truckId: truck.truckId,
      latitude: selection.latitude,
      longitude: selection.longitude,
    );
  }

  Future<void> _control(
    String action, {
    String? truckId,
    double? speedMultiplier,
    double? latitude,
    double? longitude,
  }) async {
    final ok = await ref
        .read(dashboardControllerProvider.notifier)
        .control(
          action,
          truckId: truckId,
          speedMultiplier: speedMultiplier,
          latitude: latitude,
          longitude: longitude,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.l10n.simulatorCommandSucceeded
              : context.l10n.genericError,
        ),
      ),
    );
  }

  static String _stateLabel(BuildContext context, String state) =>
      switch (state) {
        'NoLocation' => context.l10n.noLocation,
        'Current' => context.l10n.currentLocation,
        'Stale' => context.l10n.staleLocation,
        'Offline' => context.l10n.offline,
        _ => state,
      };

  static IconData _stateIcon(String state) => switch (state) {
    'Current' => Icons.gps_fixed,
    'Stale' => Icons.history,
    'Offline' => Icons.gps_off,
    _ => Icons.location_disabled,
  };

  static String _helper(BuildContext context, SimulatorTruck truck) =>
      switch (truck.locationState) {
        'NoLocation' => context.l10n.noLocationHelp,
        'Stale' => context.l10n.staleLocationHelp,
        'Offline' => context.l10n.offlineLocationHelp,
        _ => context.l10n.currentLocationHelp,
      };
}
