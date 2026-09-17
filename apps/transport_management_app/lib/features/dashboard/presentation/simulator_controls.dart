import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';

class SimulatorControls extends ConsumerStatefulWidget {
  const SimulatorControls({required this.positions, super.key});

  static const enabled = bool.fromEnvironment(
    'ENABLE_SIMULATOR_CONTROLS',
    defaultValue: false,
  );

  final List<TrackedTruck> positions;

  @override
  ConsumerState<SimulatorControls> createState() => _SimulatorControlsState();
}

class _SimulatorControlsState extends ConsumerState<SimulatorControls> {
  String? _truckId;
  double _speedMultiplier = 1;

  @override
  Widget build(BuildContext context) => Card(
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
                    if (value != null) setState(() => _speedMultiplier = value);
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
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  key: const Key('sim-truck-selector'),
                  initialValue:
                      _truckId ?? widget.positions.firstOrNull?.truckId,
                  decoration: InputDecoration(
                    labelText: context.l10n.selectTruck,
                  ),
                  items: widget.positions
                      .map(
                        (position) => DropdownMenuItem(
                          value: position.truckId,
                          child: Text(position.plateNumber),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _truckId = value),
                ),
              ),
              OutlinedButton(
                key: const Key('sim-online'),
                onPressed: widget.positions.isEmpty
                    ? null
                    : () => _control(
                        'online',
                        truckId:
                            _truckId ?? widget.positions.firstOrNull?.truckId,
                      ),
                child: Text(context.l10n.setOnline),
              ),
              OutlinedButton(
                key: const Key('sim-offline'),
                onPressed: widget.positions.isEmpty
                    ? null
                    : () => _control(
                        'offline',
                        truckId:
                            _truckId ?? widget.positions.firstOrNull?.truckId,
                      ),
                child: Text(context.l10n.setOffline),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _control(
    String action, {
    String? truckId,
    double? speedMultiplier,
  }) async {
    final ok = await ref
        .read(dashboardControllerProvider.notifier)
        .control(action, truckId: truckId, speedMultiplier: speedMultiplier);
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
}
