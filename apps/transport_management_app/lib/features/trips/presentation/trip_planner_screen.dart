import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../locations/presentation/location_picker_dialog.dart';
import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
import 'trips_controller.dart';

class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({this.tripId, super.key});
  final String? tripId;

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  static const _styleUrl = String.fromEnvironment('MAP_STYLE_URL');
  final _formKey = GlobalKey<FormState>();
  final _pickup = _StopFields();
  final _delivery = _StopFields();
  final _cargo = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _planned = TextEditingController();
  DateTime? _plannedAt;
  String? _clientId;
  TripRoutePlan? _route;
  bool _initialized = false;
  bool _routing = false;
  bool _saving = false;
  bool _loadingTrip = false;
  bool _loadingOptions = false;
  bool _assigning = false;
  bool _skipAssignment = true;
  bool _routeStale = false;
  int _step = 0;
  int _maxReachableStep = 0;
  Trip? _persistedTrip;
  AssignmentOptions? _options;
  String? _truckId;
  String? _driverId;
  String? _persistedStopsSignature;
  String? _persistedRouteSignature;
  Object? _error;
  _StopFields? _activeMapStop;

  @override
  void dispose() {
    _pickup.dispose();
    _delivery.dispose();
    _cargo.dispose();
    _price.dispose();
    _notes.dispose();
    _planned.dispose();
    super.dispose();
  }

  void _initialize(OperationsData data) {
    if (_initialized) return;
    _initialized = true;
    if (widget.tripId != null) {
      final cached = data.trips
          .where((item) => item.id == widget.tripId)
          .firstOrNull;
      if (cached != null) {
        _applyTrip(data, cached);
        return;
      }
      _loadingTrip = true;
      unawaited(_loadPersistedTrip(data));
      return;
    }
    _applyTrip(data, null);
  }

  Future<void> _loadPersistedTrip(OperationsData data) async {
    try {
      final trip = await ref
          .read(operationsRepositoryProvider)
          .getTrip(widget.tripId!);
      if (!mounted) return;
      setState(() {
        _applyTrip(data, trip);
        _loadingTrip = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingTrip = false;
      });
    }
  }

  void _applyTrip(OperationsData data, Trip? trip) {
    _persistedTrip = trip;
    _clientId =
        trip?.clientId ??
        data.clients.where((item) => item.isActive).firstOrNull?.id;
    _cargo.text = trip?.cargoDescription ?? '';
    _price.text = trip?.price.toString() ?? '0';
    _notes.text = trip?.notes ?? '';
    _plannedAt = DateTime.tryParse(
      trip?.plannedStartAt ??
          DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
    );
    _planned.text = _plannedAt == null
        ? ''
        : DateFormat.yMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).add_jm().format(_plannedAt!.toLocal());
    if (trip != null) {
      final stops = [...trip.stops]
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      _pickup.load(stops.where((item) => item.type == 'Pickup').firstOrNull);
      _delivery.load(
        stops.where((item) => item.type == 'Delivery').firstOrNull,
      );
      _route = trip.routePlan;
      _persistedStopsSignature = _stopsSignature(trip.stops);
      _persistedRouteSignature = trip.routePlan == null
          ? null
          : _routeSignature(trip.stops);
      _truckId = trip.truckId;
      _driverId = trip.driverId;
      _skipAssignment = trip.truckId == null || trip.driverId == null;
      if (trip.routePlan != null) {
        _step = 2;
        _maxReachableStep = 2;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadAssignmentOptions(trip.id));
        });
      } else if (trip.stops.length == 2) {
        _step = 1;
        _maxReachableStep = 1;
      }
    }
  }

  List<TripStop>? _stops() {
    final pickup = _pickup.toStop(0, 'Pickup');
    final delivery = _delivery.toStop(1, 'Delivery');
    return pickup == null || delivery == null ? null : [pickup, delivery];
  }

  String _stopsSignature(List<TripStop> stops) =>
      ([...stops]..sort((a, b) => a.sequence.compareTo(b.sequence)))
          .map(
            (stop) => [
              stop.sequence,
              stop.type.toLowerCase(),
              stop.name.trim(),
              (stop.address ?? '').trim(),
              stop.latitude?.toStringAsFixed(6) ?? '',
              stop.longitude?.toStringAsFixed(6) ?? '',
            ].join(':'),
          )
          .join('|');

  String _routeSignature(List<TripStop> stops) =>
      ([...stops]..sort((a, b) => a.sequence.compareTo(b.sequence)))
          .map(
            (stop) => [
              stop.sequence,
              stop.type.toLowerCase(),
              stop.latitude?.toStringAsFixed(6) ?? '',
              stop.longitude?.toStringAsFixed(6) ?? '',
            ].join(':'),
          )
          .join('|');

  bool get _hasCurrentRoute {
    final stops = _stops();
    return stops != null &&
        _route != null &&
        !_routeStale &&
        _persistedRouteSignature == _routeSignature(stops);
  }

  void _onStopsChanged() {
    final stops = _stops();
    setState(() {
      _routeStale =
          _route != null &&
          (stops == null || _persistedRouteSignature != _routeSignature(stops));
    });
  }

  Future<void> _search(_StopFields fields) async {
    if (fields.name.text.trim().length < 3) return;
    try {
      final results = await ref
          .read(operationsRepositoryProvider)
          .searchLocations(fields.name.text.trim());
      if (!mounted) return;
      final selected = await showDialog<LocationResult>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.searchResults),
          content: SizedBox(
            width: 520,
            child: results.isEmpty
                ? Text(context.l10n.noLocationResults)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final item = results[index];
                      return ListTile(
                        title: Text(item.displayName),
                        subtitle: Text(item.address ?? item.providerName),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
      );
      if (selected != null) {
        setState(() {
          fields.loadResult(selected);
        });
        _onStopsChanged();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _calculate() async {
    final stops = _stops();
    if (stops == null || stops.any((stop) => stop.name.trim().isEmpty)) {
      setState(() => _error = StateError(context.l10n.invalidCoordinate));
      return;
    }
    final pickup = stops.first;
    final delivery = stops.last;
    if (pickup.latitude == delivery.latitude &&
        pickup.longitude == delivery.longitude) {
      setState(() => _error = StateError(context.l10n.identicalStops));
      return;
    }
    setState(() {
      _routing = true;
      _error = null;
    });
    try {
      final saved = await _persistDraft();
      if (saved == null) return;
      final routed = await ref
          .read(operationsRepositoryProvider)
          .calculateTripRoute(saved.id);
      if (mounted) {
        setState(() {
          _persistedTrip = routed;
          _route = routed.routePlan;
          _persistedStopsSignature = _stopsSignature(routed.stops);
          _persistedRouteSignature = _routeSignature(routed.stops);
          _routeStale = false;
          _step = 2;
          _maxReachableStep = 2;
        });
        await _loadAssignmentOptions(routed.id);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<Trip?> _persistDraft({bool refreshLists = false}) async {
    final price = _price.text.trim().isEmpty
        ? null
        : num.tryParse(_price.text.trim());
    if (_clientId == null ||
        _cargo.text.trim().isEmpty ||
        (price != null && price < 0) ||
        (_price.text.trim().isNotEmpty && price == null)) {
      setState(
        () => _error = StateError(
          _price.text.trim().isNotEmpty && price == null
              ? context.l10n.invalidNumber
              : context.l10n.required,
        ),
      );
      return null;
    }
    setState(() => _saving = true);
    try {
      final existing = _persistedTrip;
      var saved = await ref.read(operationsRepositoryProvider).saveTrip({
        'clientId': _clientId,
        'cargoDescription': _cargo.text.trim(),
        'plannedStartAt': _plannedAt?.toUtc().toIso8601String(),
        'price': price,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        if (existing != null) 'expectedVersion': existing.version,
      }, existing?.id);
      _persistedTrip = saved;
      final stops = _stops();
      if (stops != null && _stopsSignature(stops) != _persistedStopsSignature) {
        saved = await ref
            .read(operationsRepositoryProvider)
            .saveTripStops(saved.id, stops, saved.version);
        _persistedTrip = saved;
      }
      _persistedStopsSignature = _stopsSignature(saved.stops);
      _route = saved.routePlan;
      _persistedRouteSignature = saved.routePlan == null
          ? null
          : _routeSignature(saved.stops);
      _routeStale = false;
      if (refreshLists) {
        await ref.read(operationsControllerProvider.notifier).reload();
        await ref.read(tripsControllerProvider.notifier).refresh();
      }
      if (!mounted) return saved;
      setState(() {
        _persistedTrip = saved;
        _saving = false;
        _error = null;
      });
      return saved;
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
      return null;
    }
  }

  Future<void> _loadAssignmentOptions(String tripId) async {
    if (_loadingOptions) return;
    setState(() {
      _loadingOptions = true;
      _error = null;
    });
    try {
      final options = await ref
          .read(operationsRepositoryProvider)
          .assignmentOptions(tripId);
      if (!mounted) return;
      setState(() {
        _options = options;
        _truckId =
            options.currentTruckId ??
            _eligibleSelection(options.trucks, _truckId);
        _driverId =
            options.currentDriverId ??
            _eligibleSelection(options.drivers, _driverId);
        _loadingOptions = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loadingOptions = false;
        });
      }
    }
  }

  String? _eligibleSelection(
    List<AssignmentResourceOption> options,
    String? current,
  ) {
    if (current != null &&
        options.any((item) => item.id == current && item.isEligible)) {
      return current;
    }
    return options.where((item) => item.isEligible).firstOrNull?.id;
  }

  Future<void> _continue() async {
    if (_saving || _routing || _assigning) return;
    if (_step == 0) {
      final price = _price.text.trim().isEmpty
          ? null
          : num.tryParse(_price.text.trim());
      if (_clientId == null ||
          _cargo.text.trim().isEmpty ||
          (price != null && price < 0) ||
          (_price.text.trim().isNotEmpty && price == null)) {
        _formKey.currentState?.validate();
        return;
      }
      if (await _persistDraft() == null || !mounted) return;
      setState(() {
        _step = 1;
        _maxReachableStep = 1;
      });
      return;
    }
    if (_step == 1) {
      if (!_hasCurrentRoute) {
        setState(
          () => _error = StateError(
            _routeStale ? context.l10n.routeStale : context.l10n.routeRequired,
          ),
        );
        return;
      }
      setState(() {
        _step = 2;
        _maxReachableStep = 2;
      });
      await _loadAssignmentOptions(_persistedTrip!.id);
      return;
    }
    if (_step == 2) {
      if (!_skipAssignment && (_truckId == null || _driverId == null)) {
        setState(
          () => _error = StateError(context.l10n.assignmentSelectionRequired),
        );
        return;
      }
      setState(() {
        _step = 3;
        _maxReachableStep = 3;
        _error = null;
      });
    }
  }

  Future<void> _finish({required bool assign}) async {
    setState(() {
      _assigning = assign;
      _error = null;
    });
    final saved = await _persistDraft();
    if (saved == null || !mounted) {
      if (mounted) setState(() => _assigning = false);
      return;
    }
    try {
      var result = saved;
      if (assign) {
        if (_truckId == null || _driverId == null) {
          throw StateError(context.l10n.assignmentSelectionRequired);
        }
        result = await ref
            .read(operationsRepositoryProvider)
            .assignTripAndGet(saved.id, _truckId!, _driverId!);
      }
      await ref.read(operationsControllerProvider.notifier).reload();
      await ref.read(tripsControllerProvider.notifier).refresh();
      if (!mounted) return;
      _persistedTrip = result;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assign
                ? context.l10n.tripCreatedAndAssigned
                : context.l10n.draftSaved,
          ),
        ),
      );
      context.go('/trips/${result.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _step = 2;
        _maxReachableStep = 2;
      });
      await _loadAssignmentOptions(saved.id);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _saveAndStay() async {
    final saved = await _persistDraft(refreshLists: true);
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.draftSaved)));
    if (widget.tripId == null) context.go('/trips/${saved.id}/edit');
  }

  void _selectMapPoint(LatLng point) {
    final fields = _activeMapStop;
    if (fields == null) return;
    setState(() {
      fields.latitude.text = point.latitude.toStringAsFixed(6);
      fields.longitude.text = point.longitude.toStringAsFixed(6);
      if (fields.name.text.trim().isEmpty) {
        fields.name.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      _activeMapStop = null;
    });
    _onStopsChanged();
  }

  Future<void> _pickPlanned() async {
    final initial =
        _plannedAt?.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _plannedAt = value.toUtc();
      _planned.text = DateFormat.yMd(
        Localizations.localeOf(context).toLanguageTag(),
      ).add_jm().format(value);
    });
  }

  @override
  Widget build(BuildContext context) => OperationsView(
    builder: (context, ref, data) {
      _initialize(data);
      if (_loadingTrip) {
        return const Center(child: CircularProgressIndicator());
      }
      final trip =
          _persistedTrip ??
          data.trips.where((item) => item.id == widget.tripId).firstOrNull;
      return Form(
        key: _formKey,
        child: ListView(
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
                    trip == null
                        ? context.l10n.planTrip
                        : context.l10n.editDraftTrip,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('save-draft'),
                      onPressed: _saving ? null : _saveAndStay,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _saving ? context.l10n.loading : context.l10n.saveDraft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final form = _form(data);
                final map = _RoutePreview(
                  route: _route,
                  pickup: _pickup.point,
                  delivery: _delivery.point,
                  onMapTap: _selectMapPoint,
                  selecting: _activeMapStop != null,
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [form, const SizedBox(height: 16), map],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: form),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: map),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error is ApiException
                    ? localizedApiError(context, _error! as ApiException)
                    : _error is StateError
                    ? (_error! as StateError).message.toString()
                    : context.l10n.genericError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _form(OperationsData data) => Card(
    child: Stepper(
      currentStep: _step,
      onStepTapped: (value) {
        if (value <= _maxReachableStep) setState(() => _step = value);
      },
      onStepContinue: _step < 3 ? _continue : null,
      onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
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
          content: Column(
            children: [
              DropdownButtonFormField<String>(
                key: const Key('trip-client'),
                initialValue: _clientId,
                decoration: InputDecoration(labelText: context.l10n.client),
                items: data.clients
                    .where((x) => x.isActive)
                    .map(
                      (x) => DropdownMenuItem(value: x.id, child: Text(x.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _clientId = value),
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
        Step(
          title: Text(context.l10n.locationsAndRouteStep),
          isActive: _step == 1,
          state: _stepState(1),
          content: Column(
            children: [
              _StopEditor(
                key: const Key('pickup-editor'),
                title: context.l10n.pickup,
                fieldKey: 'pickup',
                fields: _pickup,
                onSearch: () => _search(_pickup),
                onSelectMap: () => setState(() => _activeMapStop = _pickup),
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
                onSelectMap: () => setState(() => _activeMapStop = _delivery),
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
        Step(
          title: Text(context.l10n.truckAndDriverStep),
          isActive: _step == 2,
          state: _stepState(2),
          content: _assignmentStep(),
        ),
        Step(
          title: Text(context.l10n.reviewAndConfirmStep),
          isActive: _step == 3,
          state: _stepState(3),
          content: _reviewStep(data),
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
          onChanged: (value) => setState(() => _skipAssignment = value),
        ),
        if (!_skipAssignment) ...[
          _assignmentDropdown(
            key: const Key('assignment-truck'),
            label: context.l10n.truck,
            value: _truckId,
            options: options.trucks,
            onChanged: (value) => setState(() => _truckId = value),
          ),
          const SizedBox(height: 12),
          _assignmentDropdown(
            key: const Key('assignment-driver'),
            label: context.l10n.driver,
            value: _driverId,
            options: options.drivers,
            onChanged: (value) => setState(() => _driverId = value),
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
              onPressed: () => setState(() => _step = 0),
              child: Text(context.l10n.editTripDetails),
            ),
            TextButton(
              key: const Key('edit-route'),
              onPressed: () => setState(() => _step = 1),
              child: Text(context.l10n.editLocationsAndRoute),
            ),
            TextButton(
              key: const Key('edit-assignment'),
              onPressed: () => setState(() => _step = 2),
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

class _StopFields {
  final name = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  GeoPoint? get point {
    final lat = double.tryParse(latitude.text);
    final lon = double.tryParse(longitude.text);
    return validLocationCoordinate(lat, lon) ? GeoPoint(lat!, lon!) : null;
  }

  void load(TripStop? stop) {
    if (stop == null) return;
    name.text = stop.name;
    address.text = stop.address ?? '';
    latitude.text = stop.latitude?.toString() ?? '';
    longitude.text = stop.longitude?.toString() ?? '';
  }

  void loadResult(LocationResult result) {
    name.text = result.displayName;
    address.text = result.address ?? result.displayName;
    latitude.text = result.latitude.toStringAsFixed(6);
    longitude.text = result.longitude.toStringAsFixed(6);
  }

  TripStop? toStop(int sequence, String type) {
    final lat = double.tryParse(latitude.text);
    final lon = double.tryParse(longitude.text);
    if (lat == null || lon == null) return null;
    return TripStop(
      sequence: sequence,
      type: type,
      name: name.text.trim(),
      address: address.text.trim(),
      latitude: lat,
      longitude: lon,
    );
  }

  void dispose() {
    name.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
  }
}

class _StopEditor extends StatelessWidget {
  const _StopEditor({
    required this.title,
    required this.fieldKey,
    required this.fields,
    required this.onSearch,
    required this.onSelectMap,
    required this.selectingOnMap,
    required this.onChanged,
    super.key,
  });
  final String title;
  final String fieldKey;
  final _StopFields fields;
  final VoidCallback onSearch, onChanged;
  final VoidCallback onSelectMap;
  final bool selectingOnMap;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('trip-$fieldKey-name'),
                  controller: fields.name,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: context.l10n.locationName,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.l10n.required
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: context.l10n.searchLocation,
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: Key('trip-$fieldKey-select-map'),
              onPressed: onSelectMap,
              icon: Icon(
                selectingOnMap ? Icons.touch_app : Icons.add_location_alt,
              ),
              label: Text(
                selectingOnMap
                    ? context.l10n.tapMapToSelect
                    : context.l10n.selectOnMap,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: Key('trip-$fieldKey-address'),
            controller: fields.address,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(labelText: context.l10n.address),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _coordinate(
                  context,
                  fields.latitude,
                  Key('trip-$fieldKey-latitude'),
                  context.l10n.latitude,
                  -90,
                  90,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _coordinate(
                  context,
                  fields.longitude,
                  Key('trip-$fieldKey-longitude'),
                  context.l10n.longitude,
                  -180,
                  180,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _coordinate(
    BuildContext context,
    TextEditingController controller,
    Key fieldKey,
    String label,
    double min,
    double max,
  ) => TextFormField(
    key: fieldKey,
    controller: controller,
    onChanged: (_) => onChanged(),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final number = double.tryParse(value ?? '');
      return number == null || number < min || number > max
          ? context.l10n.invalidCoordinate
          : null;
    },
  );
}

class _RoutePreview extends StatefulWidget {
  const _RoutePreview({
    required this.route,
    required this.pickup,
    required this.delivery,
    required this.onMapTap,
    required this.selecting,
  });
  final TripRoutePlan? route;
  final GeoPoint? pickup, delivery;
  final ValueChanged<LatLng> onMapTap;
  final bool selecting;
  @override
  State<_RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<_RoutePreview> {
  MapLibreMapController? _controller;
  bool _styleReady = false;
  Line? _routeLine;
  Circle? _pickupCircle;
  Circle? _deliveryCircle;
  @override
  void didUpdateWidget(covariant _RoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(
      _draw(fitRoute: oldWidget.route != widget.route && widget.route != null),
    );
  }

  Future<void> _draw({bool fitRoute = false}) async {
    final controller = _controller;
    final route = widget.route;
    if (controller == null || !_styleReady) return;
    await _syncStop(
      widget.pickup,
      '#16A34A',
      _pickupCircle,
      (circle) => _pickupCircle = circle,
    );
    await _syncStop(
      widget.delivery,
      '#DC2626',
      _deliveryCircle,
      (circle) => _deliveryCircle = circle,
    );
    if (route == null || route.coordinates.length < 2) {
      if (_routeLine != null) {
        await controller.removeLine(_routeLine!);
        _routeLine = null;
      }
      return;
    }
    final points = route.coordinates
        .map((item) => LatLng(item.latitude, item.longitude))
        .toList();
    final lineOptions = LineOptions(
      geometry: points,
      lineColor: '#175CD3',
      lineWidth: 5,
    );
    if (_routeLine == null) {
      _routeLine = await controller.addLine(lineOptions);
    } else {
      await controller.updateLine(_routeLine!, lineOptions);
    }
    if (!fitRoute) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 40,
        top: 40,
        right: 40,
        bottom: 40,
      ),
    );
  }

  Future<void> _syncStop(
    GeoPoint? point,
    String color,
    Circle? current,
    void Function(Circle? value) assign,
  ) async {
    final controller = _controller!;
    if (point == null) {
      if (current != null) await controller.removeCircle(current);
      assign(null);
      return;
    }
    final options = CircleOptions(
      geometry: LatLng(point.latitude, point.longitude),
      circleColor: color,
      circleRadius: 9,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2,
    );
    if (current == null) {
      assign(await controller.addCircle(options));
    } else {
      await controller.updateCircle(current, options);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.routePreview,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.route != null)
                  Text(
                    '${(widget.route!.distanceMeters / 1000).toStringAsFixed(1)} km · ${Duration(seconds: widget.route!.estimatedDurationSeconds).inMinutes} min',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _TripPlannerScreenState._styleUrl.isEmpty
                ? _RouteSchematic(
                    route: widget.route,
                    pickup: widget.pickup,
                    delivery: widget.delivery,
                  )
                : Stack(
                    children: [
                      MapLibreMap(
                        key: const Key('trip-planner-map'),
                        styleString: _TripPlannerScreenState._styleUrl,
                        initialCameraPosition: CameraPosition(
                          target: widget.route == null
                              ? const LatLng(39.0, 35.0)
                              : LatLng(
                                  widget.route!.coordinates.first.latitude,
                                  widget.route!.coordinates.first.longitude,
                                ),
                          zoom: widget.route == null ? 4 : 7,
                        ),
                        onMapCreated: (controller) {
                          _controller = controller;
                          _styleReady = false;
                        },
                        onStyleLoadedCallback: () {
                          _styleReady = true;
                          unawaited(_draw(fitRoute: widget.route != null));
                        },
                        onMapClick: (_, point) => widget.onMapTap(point),
                        compassEnabled: false,
                        rotateGesturesEnabled: false,
                      ),
                      if (widget.selecting)
                        PositionedDirectional(
                          top: 12,
                          start: 12,
                          end: 12,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                context.l10n.tapMapToSelect,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _RouteSchematic extends StatelessWidget {
  const _RouteSchematic({this.route, this.pickup, this.delivery});
  final TripRoutePlan? route;
  final GeoPoint? pickup, delivery;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pickup != null)
                  const Icon(
                    Icons.trip_origin,
                    key: Key('planner-pickup-marker'),
                    color: Colors.green,
                  ),
                if (pickup != null && delivery != null)
                  const Expanded(child: Divider(thickness: 4)),
                if (delivery != null)
                  const Icon(
                    Icons.location_on,
                    key: Key('planner-delivery-marker'),
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              pickup == null && delivery == null
                  ? context.l10n.calculateRouteHint
                  : context.l10n.mapNotConfigured,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
