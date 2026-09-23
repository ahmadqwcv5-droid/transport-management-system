part of '../trip_planner_controller.dart';

extension TripPlannerSteps on TripPlannerController {
  Widget _form(OperationsData data) => Card(
    child: Stepper(
      currentStep: _step,
      onStepTapped: (value) {
        if (value <= _maxReachableStep) _mutate(() => _step = value);
      },
      onStepContinue: _step < 3 ? _continue : null,
      onStepCancel: _step > 0 ? () => _mutate(() => _step--) : null,
      controlsBuilder: (context, details) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_step < 3)
              FilledButton(
                key: Key('trip-step-${_step + 1}-next'),
                onPressed: _saving || _routing ? null : details.onStepContinue,
                child: Text(context.l10n.next),
              ),
            if (_step > 0)
              TextButton(
                onPressed: details.onStepCancel,
                child: Text(context.l10n.back),
              ),
          ],
        ),
      ),
      steps: [
        Step(
          title: Text(context.l10n.tripDetailsStep),
          isActive: _step == 0,
          state: _stepState(0),
          content: TripDetailsStep(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('trip-client'),
                  initialValue: _clientId,
                  decoration: InputDecoration(labelText: context.l10n.client),
                  items: data.clients
                      .where((x) => x.isActive)
                      .map(
                        (x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)),
                      )
                      .toList(),
                  onChanged: (value) => _mutate(() => _clientId = value),
                  validator: (value) =>
                      value == null ? context.l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('trip-cargo'),
                  controller: _cargo,
                  decoration: InputDecoration(labelText: context.l10n.cargo),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.l10n.required
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('trip-planned-picker'),
                  controller: _planned,
                  readOnly: true,
                  onTap: _pickPlanned,
                  decoration: InputDecoration(
                    labelText: context.l10n.plannedStart,
                    suffixIcon: const Icon(Icons.event),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('trip-price'),
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: context.l10n.price),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final number = num.tryParse(value);
                    return number == null || number < 0
                        ? context.l10n.invalidNumber
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('trip-notes'),
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: context.l10n.notes),
                ),
              ],
            ),
          ),
        ),
        Step(
          title: Text(context.l10n.locationsAndRouteStep),
          isActive: _step == 1,
          state: _stepState(1),
          content: TripRouteStep(
            child: Column(
              children: [
                _StopEditor(
                  key: const Key('pickup-editor'),
                  title: context.l10n.pickup,
                  fieldKey: 'pickup',
                  fields: _pickup,
                  onSearch: () => _search(_pickup),
                  onSelectMap: () => _mutate(() => _activeMapStop = _pickup),
                  selectingOnMap: identical(_activeMapStop, _pickup),
                  onChanged: _onStopsChanged,
                ),
                const SizedBox(height: 14),
                _StopEditor(
                  key: const Key('delivery-editor'),
                  title: context.l10n.delivery,
                  fieldKey: 'delivery',
                  fields: _delivery,
                  onSearch: () => _search(_delivery),
                  onSelectMap: () => _mutate(() => _activeMapStop = _delivery),
                  selectingOnMap: identical(_activeMapStop, _delivery),
                  onChanged: _onStopsChanged,
                ),
                const SizedBox(height: 16),
                if (_routeStale)
                  _Notice(
                    key: const Key('route-stale-warning'),
                    icon: Icons.warning_amber,
                    text: context.l10n.routeStale,
                    error: true,
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    key: const Key('calculate-route'),
                    onPressed: _routing ? null : _calculate,
                    icon: _routing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.route),
                    label: Text(
                      _routing
                          ? context.l10n.calculatingRoute
                          : _route == null || _routeStale
                          ? context.l10n.calculateRoute
                          : context.l10n.recalculateRoute,
                    ),
                  ),
                ),
                if (_route != null) ...[
                  const SizedBox(height: 12),
                  _RouteFacts(route: _route!, stale: _routeStale),
                ],
              ],
            ),
          ),
        ),
        Step(
          title: Text(context.l10n.truckAndDriverStep),
          isActive: _step == 2,
          state: _stepState(2),
          content: TripAssignmentStep(child: _assignmentStep()),
        ),
        Step(
          title: Text(context.l10n.reviewAndConfirmStep),
          isActive: _step == 3,
          state: _stepState(3),
          content: TripReviewStep(child: _reviewStep(data)),
        ),
      ],
    ),
  );

  StepState _stepState(int index) {
    if (index == _step && _error != null) return StepState.error;
    if (index < _step || index < _maxReachableStep) return StepState.complete;
    if (index > _maxReachableStep) return StepState.disabled;
    return StepState.indexed;
  }

  Widget _assignmentStep() {
    final options = _options;
    if (_loadingOptions) return const LinearProgressIndicator();
    if (options == null) {
      return OutlinedButton.icon(
        key: const Key('refresh-assignment-options'),
        onPressed: _persistedTrip == null
            ? null
            : () => _loadAssignmentOptions(_persistedTrip!.id),
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.refreshAvailability),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('skip-assignment'),
          value: _skipAssignment,
          title: Text(context.l10n.skipForNow),
          subtitle: Text(context.l10n.keepAsUnassignedDraft),
          onChanged: (value) => _mutate(() => _skipAssignment = value),
        ),
        if (!_skipAssignment) ...[
          _assignmentDropdown(
            key: const Key('assignment-truck'),
            label: context.l10n.truck,
            value: _truckId,
            options: options.trucks,
            onChanged: (value) => _mutate(() => _truckId = value),
          ),
          const SizedBox(height: 12),
          _assignmentDropdown(
            key: const Key('assignment-driver'),
            label: context.l10n.driver,
            value: _driverId,
            options: options.drivers,
            onChanged: (value) => _mutate(() => _driverId = value),
          ),
        ],
        if (!options.canAssign)
          _Notice(
            icon: Icons.info_outline,
            text: context.l10n.tripNotReadyForAssignment,
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const Key('refresh-assignment-options'),
            onPressed: () => _loadAssignmentOptions(options.tripId),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.refreshAvailability),
          ),
        ),
      ],
    );
  }

  Widget _assignmentDropdown({
    required Key key,
    required String label,
    required String? value,
    required List<AssignmentResourceOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    final eligible = options.where((item) => item.isEligible).toList();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (eligible.isEmpty)
          _Notice(
            icon: Icons.block,
            text: label == context.l10n.truck
                ? context.l10n.noEligibleTruck
                : context.l10n.noEligibleDriver,
            error: true,
          )
        else
          DropdownButtonFormField<String>(
            initialValue: eligible.any((item) => item.id == value)
                ? value
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: eligible
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(
                      item.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        for (final item in options.where((item) => !item.isEligible))
          ListTile(
            dense: true,
            enabled: false,
            leading: const Icon(Icons.block, size: 18),
            title: Text(item.displayName),
            subtitle: Text(localizedAssignmentReason(context.l10n, item)),
          ),
      ],
    );
  }

  Widget _reviewStep(OperationsData data) {
    final trip = _persistedTrip;
    final client = data.clients
        .where((item) => item.id == _clientId)
        .firstOrNull;
    final truck = _options?.trucks
        .where((item) => item.id == _truckId)
        .firstOrNull;
    final driver = _options?.drivers
        .where((item) => item.id == _driverId)
        .firstOrNull;
    return Column(
      key: const Key('trip-review-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewRow(
          context.l10n.tripNumber,
          trip?.tripNumber ?? context.l10n.allocatedAfterSave,
        ),
        _ReviewRow(
          context.l10n.client,
          client?.name ?? context.l10n.notAvailable,
        ),
        _ReviewRow(context.l10n.cargo, _cargo.text.trim()),
        _ReviewRow(
          context.l10n.plannedStart,
          _planned.text.isEmpty ? context.l10n.notAvailable : _planned.text,
        ),
        _ReviewRow(
          context.l10n.price,
          _price.text.isEmpty ? context.l10n.notAvailable : _price.text,
        ),
        _ReviewRow(context.l10n.pickup, _pickup.name.text.trim()),
        _ReviewRow(context.l10n.delivery, _delivery.name.text.trim()),
        _ReviewRow(
          context.l10n.distance,
          _route == null
              ? context.l10n.notAvailable
              : '${(_route!.distanceMeters / 1000).toStringAsFixed(1)} km',
        ),
        _ReviewRow(
          context.l10n.estimatedDuration,
          _route == null
              ? context.l10n.notAvailable
              : '${Duration(seconds: _route!.estimatedDurationSeconds).inMinutes} min',
        ),
        _ReviewRow(
          context.l10n.truck,
          _skipAssignment
              ? context.l10n.notAssigned
              : truck?.displayName ?? context.l10n.notAssigned,
        ),
        _ReviewRow(
          context.l10n.driver,
          _skipAssignment
              ? context.l10n.notAssigned
              : driver?.displayName ?? context.l10n.notAssigned,
        ),
        _ReviewRow(
          context.l10n.readiness,
          trip?.readiness.canAssign == true
              ? context.l10n.ready
              : context.l10n.draftIncomplete,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              key: const Key('edit-trip-details'),
              onPressed: () => _mutate(() => _step = 0),
              child: Text(context.l10n.editTripDetails),
            ),
            TextButton(
              key: const Key('edit-route'),
              onPressed: () => _mutate(() => _step = 1),
              child: Text(context.l10n.editLocationsAndRoute),
            ),
            TextButton(
              key: const Key('edit-assignment'),
              onPressed: () => _mutate(() => _step = 2),
              child: Text(context.l10n.editAssignment),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('finish-save-draft'),
              onPressed: _assigning || _saving
                  ? null
                  : () => _finish(assign: false),
              icon: const Icon(Icons.save),
              label: Text(context.l10n.saveDraft),
            ),
            if (!_skipAssignment)
              FilledButton.icon(
                key: const Key('finish-assign-trip'),
                onPressed:
                    _assigning ||
                        _saving ||
                        _truckId == null ||
                        _driverId == null
                    ? null
                    : () => _finish(assign: true),
                icon: const Icon(Icons.check_circle),
                label: Text(
                  trip == null
                      ? context.l10n.createAndAssignTrip
                      : context.l10n.assignTrip,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
