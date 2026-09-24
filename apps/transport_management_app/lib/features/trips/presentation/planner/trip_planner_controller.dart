import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../l10n/l10n_extensions.dart';
import '../../../locations/presentation/location_picker_dialog.dart';
import '../../../clients/domain/client_models.dart';
import '../../domain/trip_models.dart';
import '../../../operations/domain/operations_data.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/operations_view.dart';
import '../../../operations/presentation/mutation_refresh_coordinator.dart';
import '../../../../shared/widgets/truck_avatar.dart';
import 'steps/trip_assignment_step.dart';
import 'steps/trip_details_step.dart';
import 'steps/trip_review_step.dart';
import 'steps/trip_route_step.dart';
import 'trip_planner_state.dart';

part 'steps/trip_planner_steps.dart';
part 'widgets/trip_planner_widgets.dart';
part 'widgets/trip_route_preview.dart';
part 'widgets/trip_stop_editor.dart';

class TripPlannerWorkflow extends ConsumerStatefulWidget {
  const TripPlannerWorkflow({this.tripId, super.key});
  final String? tripId;

  @override
  ConsumerState<TripPlannerWorkflow> createState() => TripPlannerController();
}

class TripPlannerController extends ConsumerState<TripPlannerWorkflow> {
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
  bool _driverExplicitlySelected = false;
  String? _persistedStopsSignature;
  String? _persistedRouteSignature;
  List<ClientSite> _clientSites = const [];

  TripPlannerState get plannerState => TripPlannerState(
    currentStep: _step,
    maximumReachableStep: _maxReachableStep,
    isSaving: _saving,
    isRouting: _routing,
    isAssigning: _assigning,
    skipAssignment: _skipAssignment,
    persistedTrip: _persistedTrip,
    assignmentOptions: _options,
  );
  Object? _error;
  _StopFields? _activeMapStop;

  void _mutate(VoidCallback mutation) => setState(mutation);

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
    if (_clientId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadClientSites(_clientId!));
      });
    }
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
      _driverExplicitlySelected = trip.driverId != null;
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

  Future<void> _loadClientSites(String clientId) async {
    try {
      final details = await ref.read(clientDetailsProvider(clientId).future);
      if (!mounted || _clientId != clientId) return;
      setState(
        () => _clientSites = details.sites
            .where((site) => site.isActive)
            .toList(),
      );
    } catch (_) {
      if (mounted && _clientId == clientId) {
        setState(() => _clientSites = const []);
      }
    }
  }

  void _selectClient(String? value) {
    _mutate(() {
      _clientId = value;
      _clientSites = const [];
    });
    if (value != null) unawaited(_loadClientSites(value));
  }

  Future<void> _saveAsSite(_StopFields fields) async {
    final clientId = _clientId;
    final point = fields.point;
    if (clientId == null || point == null || fields.name.text.trim().isEmpty) {
      return;
    }
    var type = 'Other';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.savedSite),
          content: DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: context.l10n.siteType),
            items:
                const [
                      'Factory',
                      'Warehouse',
                      'Pickup',
                      'Delivery',
                      'Office',
                      'Other',
                    ]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(localizedStatus(context.l10n, value)),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => type = value!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(operationsRepositoryProvider).saveClientSite(clientId, {
      'name': fields.name.text.trim(),
      'type': type,
      'address': blankToNull(fields.address.text),
      'latitude': point.latitude,
      'longitude': point.longitude,
    });
    ref.invalidate(clientDetailsProvider(clientId));
    await _loadClientSites(clientId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.siteSaved)));
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
        await ref
            .read(mutationRefreshCoordinatorProvider)
            .refresh(clientId: saved.clientId, truckId: saved.truckId);
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

  void _selectTruck(String? value) {
    _mutate(() {
      _truckId = value;
      if (_driverExplicitlySelected || value == null || _options == null) {
        return;
      }
      final truck = _options!.trucks
          .where((item) => item.id == value)
          .firstOrNull;
      final suggested = truck?.defaultDriverId;
      if (suggested != null &&
          _options!.drivers.any(
            (driver) => driver.id == suggested && driver.isEligible,
          )) {
        _driverId = suggested;
      }
    });
  }

  void _selectDriver(String? value) => _mutate(() {
    _driverId = value;
    _driverExplicitlySelected = value != null;
  });

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
      await ref
          .read(mutationRefreshCoordinatorProvider)
          .refresh(clientId: saved.clientId, truckId: saved.truckId);
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
}
