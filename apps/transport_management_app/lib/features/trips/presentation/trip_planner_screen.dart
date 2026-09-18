import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';

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
  String? _clientId;
  TripRoutePlan? _route;
  bool _initialized = false;
  bool _routing = false;
  bool _saving = false;
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
    final trip = data.trips
        .where((item) => item.id == widget.tripId)
        .firstOrNull;
    _clientId =
        trip?.clientId ??
        data.clients.where((item) => item.isActive).firstOrNull?.id;
    _cargo.text = trip?.cargoDescription ?? '';
    _price.text = trip?.price.toString() ?? '0';
    _planned.text =
        trip?.plannedStartAt ??
        DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String();
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

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    final stops = _stops();
    if (stops == null) return;
    setState(() {
      _routing = true;
      _error = null;
    });
    try {
      final route = await ref
          .read(operationsRepositoryProvider)
          .previewRoute(stops);
      if (mounted) setState(() => _route = route);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _save(Trip? trip) async {
    if (!_formKey.currentState!.validate() || _route == null) return;
    final stops = _stops();
    if (stops == null) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate(
          (repo) => repo.saveTrip({
            'clientId': _clientId,
            'stops': stops.map((item) => item.toJson()).toList(),
            'routeProfile': 'Driving',
            'cargoDescription': _cargo.text.trim(),
            'plannedStartAt': DateTime.parse(
              _planned.text,
            ).toUtc().toIso8601String(),
            'price': num.parse(_price.text),
            'notes': trip?.notes,
          }, trip?.id),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.go('/trips');
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

  @override
  Widget build(BuildContext context) => OperationsView(
    builder: (context, ref, data) {
      _initialize(data);
      final trip = data.trips
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
                      onPressed: _routing ? null : _calculate,
                      child: Text(
                        _routing
                            ? context.l10n.calculatingRoute
                            : context.l10n.calculateRoute,
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('save-trip'),
                      onPressed: _route == null || _saving
                          ? null
                          : () => _save(trip),
                      icon: const Icon(Icons.save),
                      label: Text(
                        _saving ? context.l10n.loading : context.l10n.saveTrip,
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
                context.l10n.routeProviderUnavailable,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _form(OperationsData data) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: const Key('trip-client'),
            initialValue: _clientId,
            decoration: InputDecoration(labelText: context.l10n.client),
            items: data.clients
                .where((item) => item.isActive)
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => _clientId = value,
            validator: (value) => value == null ? context.l10n.required : null,
          ),
          const SizedBox(height: 14),
          _StopEditor(
            key: const Key('pickup-editor'),
            title: context.l10n.pickup,
            fieldKey: 'pickup',
            fields: _pickup,
            onSearch: () => _search(_pickup),
            onSelectMap: () => setState(() => _activeMapStop = _pickup),
            selectingOnMap: identical(_activeMapStop, _pickup),
            onChanged: () => setState(() => _route = null),
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
            onChanged: () => setState(() => _route = null),
          ),
          const SizedBox(height: 14),
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
            controller: _planned,
            decoration: InputDecoration(labelText: context.l10n.plannedStart),
            validator: (value) => DateTime.tryParse(value ?? '') == null
                ? context.l10n.validDate
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('trip-price'),
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.price),
            validator: (value) {
              final amount = num.tryParse(value ?? '');
              return amount == null || amount < 0
                  ? context.l10n.validPrice
                  : null;
            },
          ),
        ],
      ),
    ),
  );
}

class _StopFields {
  final name = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
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
    required this.onMapTap,
    required this.selecting,
  });
  final TripRoutePlan? route;
  final ValueChanged<LatLng> onMapTap;
  final bool selecting;
  @override
  State<_RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<_RoutePreview> {
  MapLibreMapController? _controller;
  @override
  void didUpdateWidget(covariant _RoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) unawaited(_draw());
  }

  Future<void> _draw() async {
    final controller = _controller;
    final route = widget.route;
    if (controller == null || route == null || route.coordinates.length < 2) {
      return;
    }
    await controller.clearLines();
    await controller.clearCircles();
    final points = route.coordinates
        .map((item) => LatLng(item.latitude, item.longitude))
        .toList();
    await controller.addLine(
      LineOptions(geometry: points, lineColor: '#175CD3', lineWidth: 5),
    );
    await controller.addCircles([
      CircleOptions(
        geometry: points.first,
        circleColor: '#16A34A',
        circleRadius: 8,
      ),
      CircleOptions(
        geometry: points.last,
        circleColor: '#DC2626',
        circleRadius: 8,
      ),
    ]);
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
                ? widget.route == null
                      ? Center(child: Text(context.l10n.calculateRouteHint))
                      : _RouteSchematic(route: widget.route!)
                : Stack(
                    children: [
                      MapLibreMap(
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
                        onStyleLoadedCallback: _draw,
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
  const _RouteSchematic({required this.route});
  final TripRoutePlan route;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trip_origin, color: Colors.green),
                Expanded(child: Divider(thickness: 4)),
                Icon(Icons.location_on, color: Colors.red),
              ],
            ),
            const SizedBox(height: 18),
            Text(context.l10n.mapNotConfigured, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
