import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../trips/domain/trip_models.dart';

final class LocationSelection {
  const LocationSelection({
    required this.latitude,
    required this.longitude,
    this.label,
  });
  final double latitude, longitude;
  final String? label;
}

bool validLocationCoordinate(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

Future<LocationSelection?> showLocationPickerDialog({
  required BuildContext context,
  required String title,
  required Future<List<LocationResult>> Function(String query) search,
  LocationSelection? initial,
}) => showDialog<LocationSelection>(
  context: context,
  builder: (_) =>
      _LocationPickerDialog(title: title, search: search, initial: initial),
);

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({
    required this.title,
    required this.search,
    this.initial,
  });
  final String title;
  final Future<List<LocationResult>> Function(String query) search;
  final LocationSelection? initial;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  static const _styleUrl = String.fromEnvironment('MAP_STYLE_URL');
  final _formKey = GlobalKey<FormState>();
  final _query = TextEditingController();
  late final TextEditingController _latitude = TextEditingController(
    text: widget.initial?.latitude.toStringAsFixed(6) ?? '',
  );
  late final TextEditingController _longitude = TextEditingController(
    text: widget.initial?.longitude.toStringAsFixed(6) ?? '',
  );
  MapLibreMapController? _map;
  Circle? _marker;
  bool _styleLoaded = false;
  List<LocationResult> _results = const [];
  bool _searching = false;
  String? _label;

  double? get _lat => double.tryParse(_latitude.text.trim());
  double? get _lon => double.tryParse(_longitude.text.trim());

  @override
  void dispose() {
    _query.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 3) return;
    setState(() => _searching = true);
    try {
      final values = await widget.search(_query.text.trim());
      if (mounted) setState(() => _results = values);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(double latitude, double longitude, {String? label}) {
    setState(() {
      _latitude.text = latitude.toStringAsFixed(6);
      _longitude.text = longitude.toStringAsFixed(6);
      _label = label;
      _results = const [];
    });
    unawaited(_syncMarker());
  }

  Future<void> _syncMarker() async {
    final controller = _map;
    final lat = _lat;
    final lon = _lon;
    if (controller == null ||
        !_styleLoaded ||
        !validLocationCoordinate(lat, lon)) {
      return;
    }
    final options = CircleOptions(
      geometry: LatLng(lat!, lon!),
      circleColor: '#F59E0B',
      circleRadius: 9,
      circleStrokeColor: '#7C2D12',
      circleStrokeWidth: 2,
    );
    if (_marker == null) {
      _marker = await controller.addCircle(options);
    } else {
      await controller.updateCircle(_marker!, options);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('location-picker-dialog'),
    title: Text(widget.title),
    content: SizedBox(
      width: 760,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('location-search-query'),
                      controller: _query,
                      decoration: InputDecoration(
                        labelText: context.l10n.searchLocation,
                      ),
                      onFieldSubmitted: (_) => _search(),
                    ),
                  ),
                  IconButton(
                    key: const Key('location-search'),
                    tooltip: context.l10n.searchLocation,
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
              if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView(
                    shrinkWrap: true,
                    children: _results
                        .map(
                          (result) => ListTile(
                            title: Text(result.displayName),
                            subtitle: Text(
                              result.address ?? result.providerName,
                            ),
                            onTap: () => _select(
                              result.latitude,
                              result.longitude,
                              label: result.displayName,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: _styleUrl.isEmpty
                    ? Center(child: Text(context.l10n.mapNotConfigured))
                    : MapLibreMap(
                        key: const Key('location-picker-map'),
                        styleString: _styleUrl,
                        initialCameraPosition: CameraPosition(
                          target: widget.initial == null
                              ? const LatLng(39, 35)
                              : LatLng(
                                  widget.initial!.latitude,
                                  widget.initial!.longitude,
                                ),
                          zoom: widget.initial == null ? 4 : 11,
                        ),
                        onMapCreated: (controller) => _map = controller,
                        onStyleLoadedCallback: () {
                          _styleLoaded = true;
                          unawaited(_syncMarker());
                        },
                        onMapClick: (_, point) =>
                            _select(point.latitude, point.longitude),
                        compassEnabled: false,
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _coordinate(
                      key: const Key('location-latitude'),
                      controller: _latitude,
                      label: context.l10n.latitude,
                      minimum: -90,
                      maximum: 90,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _coordinate(
                      key: const Key('location-longitude'),
                      controller: _longitude,
                      label: context.l10n.longitude,
                      minimum: -180,
                      maximum: 180,
                    ),
                  ),
                ],
              ),
              if (validLocationCoordinate(_lat, _lon)) ...[
                const SizedBox(height: 8),
                Text(
                  _label ??
                      '${_lat!.toStringAsFixed(6)}, ${_lon!.toStringAsFixed(6)}',
                  key: const Key('location-selection-preview'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('confirm-location'),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            LocationSelection(latitude: _lat!, longitude: _lon!, label: _label),
          );
        },
        child: Text(context.l10n.confirmLocation),
      ),
    ],
  );

  Widget _coordinate({
    required Key key,
    required TextEditingController controller,
    required String label,
    required double minimum,
    required double maximum,
  }) => TextFormField(
    key: key,
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
    onChanged: (_) {
      setState(() => _label = null);
      unawaited(_syncMarker());
    },
    validator: (value) {
      final number = double.tryParse(value ?? '');
      return number == null || number < minimum || number > maximum
          ? context.l10n.invalidCoordinate
          : null;
    },
  );
}
