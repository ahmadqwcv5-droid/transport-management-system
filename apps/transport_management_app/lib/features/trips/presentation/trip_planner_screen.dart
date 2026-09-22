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
  final _planned = TextEditingController();
  DateTime? _plannedAt;
  String? _clientId;
  TripRoutePlan? _route;
  bool _initialized = false;
  bool _routing = false;
  bool _saving = false;
  bool _loadingTrip = false;
  int _step = 0;
  Trip? _persistedTrip;
  Object? _error;
  _StopFields? _activeMapStop;

  @override
  void dispose() {
    _pickup.dispose();
    _delivery.dispose();
    _cargo.dispose();
    _price.dispose();
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
    }
  }

  List<TripStop>? _stops() {
    final pickup = _pickup.toStop(0, 'Pickup');
    final delivery = _delivery.toStop(1, 'Delivery');
    return pickup == null || delivery == null ? null : [pickup, delivery];
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
          _route = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _calculate(Trip? trip) async {
    final stops = _stops();
    if (stops == null) {
      setState(() => _error = StateError(context.l10n.invalidCoordinate));
      return;
    }
    setState(() {
      _routing = true;
      _error = null;
    });
    try {
      final saved = await _saveDraft(trip, stay: true);
      if (saved == null) return;
      final routed = await ref.read(operationsRepositoryProvider)
          .calculateTripRoute(saved.id);
      if (mounted) {
        setState(() {
          _persistedTrip = routed;
          _route = routed.routePlan;
          _step = 4;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<Trip?> _saveDraft(Trip? trip, {bool stay = false}) async {
    if (_clientId == null || _cargo.text.trim().isEmpty) {
      setState(() => _error = StateError(context.l10n.required));
      return null;
    }
    setState(() => _saving = true);
    try {
      var saved = await ref.read(operationsRepositoryProvider).saveTrip({
        'clientId': _clientId,
        'cargoDescription': _cargo.text.trim(),
        'plannedStartAt': _plannedAt?.toUtc().toIso8601String(),
        'price': _price.text.trim().isEmpty ? null : num.parse(_price.text),
        'notes': trip?.notes,
        if (trip != null) 'expectedVersion': trip.version,
      }, trip?.id);
      _persistedTrip = saved;
      final stops = _stops();
      if (stops != null) {
        await ref.read(operationsRepositoryProvider)
            .saveTripStops(saved.id, stops, saved.version);
        saved = await ref.read(operationsRepositoryProvider).getTrip(saved.id);
      }
      await ref.read(operationsControllerProvider.notifier).reload();
      await ref.read(tripsControllerProvider.notifier).refresh();
      if (!mounted) return saved;
      setState(() { _persistedTrip = saved; _saving = false; _error = null; });
      if (!stay) context.go('/trips/${saved.id}/edit');
      return saved;
    } catch (error) {
      if (mounted) setState(() { _saving = false; _error = error; });
      return null;
    }
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
      _route = null;
      _activeMapStop = null;
    });
  }

  Future<void> _pickPlanned() async {
    final initial = _plannedAt?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
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
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      final trip = _persistedTrip ?? data.trips
          .where((item) => item.id == widget.tripId)
          .firstOrNull;
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
                    OutlinedButton(
                      key: const Key('calculate-route'),
                      onPressed: _routing ? null : () => _calculate(trip),
                      child: Text(
                        _routing
                            ? context.l10n.calculatingRoute
                            : context.l10n.calculateRoute,
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('save-draft'),
                      onPressed: _saving ? null : () => _saveDraft(trip),
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
      onStepTapped: (value) => setState(() => _step = value),
      onStepContinue: _step < 5 ? () => setState(() => _step++) : null,
      onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
      controlsBuilder: (context, details) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(spacing: 8, children: [
          if (_step < 5) FilledButton(onPressed: details.onStepContinue,
            child: Text(context.l10n.next)),
          if (_step > 0) TextButton(onPressed: details.onStepCancel,
            child: Text(context.l10n.back)),
        ]),
      ),
      steps: [
        Step(title: Text(context.l10n.tripBasics), isActive: _step >= 0, content: Column(children: [
          DropdownButtonFormField<String>(
            key: const Key('trip-client'), initialValue: _clientId,
            decoration: InputDecoration(labelText: context.l10n.client),
            items: data.clients.where((x) => x.isActive).map((x) =>
              DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
            onChanged: (value) => _clientId = value,
          ),
          const SizedBox(height: 12),
          TextFormField(key: const Key('trip-cargo'), controller: _cargo,
            decoration: InputDecoration(labelText: context.l10n.cargo)),
        ])),
        Step(title: Text(context.l10n.pickupAndDelivery), isActive: _step >= 1, content: Column(children: [
          _StopEditor(key: const Key('pickup-editor'), title: context.l10n.pickup,
            fieldKey: 'pickup', fields: _pickup, onSearch: () => _search(_pickup),
            onSelectMap: () => setState(() => _activeMapStop = _pickup),
            selectingOnMap: identical(_activeMapStop, _pickup),
            onChanged: () => setState(() => _route = null)),
          const SizedBox(height: 14),
          _StopEditor(key: const Key('delivery-editor'), title: context.l10n.delivery,
            fieldKey: 'delivery', fields: _delivery, onSearch: () => _search(_delivery),
            onSelectMap: () => setState(() => _activeMapStop = _delivery),
            selectingOnMap: identical(_activeMapStop, _delivery),
            onChanged: () => setState(() => _route = null)),
        ])),
        Step(title: Text(context.l10n.scheduleAndCommercial), isActive: _step >= 2, content: Column(children: [
          TextFormField(key: const Key('trip-planned-picker'), controller: _planned,
            readOnly: true, onTap: _pickPlanned,
            decoration: InputDecoration(labelText: context.l10n.plannedStart,
              suffixIcon: const Icon(Icons.event))),
          const SizedBox(height: 12),
          TextFormField(key: const Key('trip-price'), controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.price)),
        ])),
        Step(title: Text(context.l10n.plannedRoute), isActive: _step >= 3,
          content: Text(_route == null ? context.l10n.routeNotCalculated
              : '${(_route!.distanceMeters / 1000).toStringAsFixed(1)} km · ${_route!.providerName}')),
        Step(title: Text(context.l10n.assignmentOptional), isActive: _step >= 4,
          content: Text(context.l10n.assignmentAfterDraft)),
        Step(title: Text(context.l10n.review), isActive: _step >= 5,
          content: Text(context.l10n.saveDraftReview)),
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
    if (controller == null) return;
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
                        onMapCreated: (controller) => _controller = controller,
                        onStyleLoadedCallback: () =>
                            _draw(fitRoute: widget.route != null),
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
