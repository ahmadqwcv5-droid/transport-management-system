import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/maps/locale_aware_map_style.dart';
import '../../../design_system/app_design_tokens.dart';
import '../../../l10n/l10n_extensions.dart';
import '../domain/driver_trip_history_models.dart';

class DriverTripHistoryMap extends StatefulWidget {
  const DriverTripHistoryMap({required this.detail, super.key});

  static const styleUrl = String.fromEnvironment('MAP_STYLE_URL');
  final DriverTripHistoryDetail detail;

  @override
  State<DriverTripHistoryMap> createState() => _DriverTripHistoryMapState();
}

class _DriverTripHistoryMapState extends State<DriverTripHistoryMap> {
  MapLibreMapController? _controller;
  String? _style;
  String? _locale;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_locale == locale) return;
    _locale = locale;
    _resolveStyle(locale);
  }

  Future<void> _resolveStyle(String locale) async {
    if (DriverTripHistoryMap.styleUrl.isEmpty) return;
    try {
      final style = await LocaleAwareMapStyle.resolve(
        DriverTripHistoryMap.styleUrl,
        locale,
      );
      if (mounted && _locale == locale) setState(() => _style = style);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  List<LatLng> get _route {
    final geometry = widget.detail.routeGeometry;
    if (geometry == null || geometry.isEmpty) return const [];
    try {
      final decoded = jsonDecode(geometry) as Map<String, dynamic>;
      return (decoded['coordinates'] as List<dynamic>)
          .cast<List<dynamic>>()
          .map(
            (point) => LatLng(
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            ),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  List<LatLng> get _trail => widget.detail.trail
      .map((point) => LatLng(point.latitude, point.longitude))
      .toList();

  List<LatLng> get _stops => widget.detail.stops
      .where((stop) => stop.hasCoordinates)
      .map((stop) => LatLng(stop.latitude!, stop.longitude!))
      .toList();

  List<LatLng> get _allPoints => [..._route, ..._trail, ..._stops];

  @override
  Widget build(BuildContext context) {
    if (DriverTripHistoryMap.styleUrl.isEmpty ||
        _allPoints.isEmpty ||
        _failed) {
      return _Fallback(message: context.l10n.routeAndTrailUnavailable);
    }
    if (_style == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.tokens.radiusMedium),
      child: MapLibreMap(
        key: ValueKey(
          'driver-history-map-${widget.detail.summary.id}-$_locale',
        ),
        styleString: _style!,
        initialCameraPosition: CameraPosition(
          target: _allPoints.first,
          zoom: 11,
        ),
        annotationOrder: const [AnnotationType.line, AnnotationType.circle],
        onMapCreated: (controller) => _controller = controller,
        onStyleLoadedCallback: _draw,
      ),
    );
  }

  Future<void> _draw() async {
    final controller = _controller;
    if (controller == null) return;
    final routeColor = _hex(context.tokens.mapRoute);
    final trailColor = _hex(context.tokens.mapTrail);
    try {
      if (_route.length > 1) {
        await controller.addLine(
          LineOptions(
            geometry: _route,
            lineColor: routeColor,
            lineWidth: 5,
            lineOpacity: .65,
          ),
        );
      }
      if (_trail.length > 1) {
        await controller.addLine(
          LineOptions(geometry: _trail, lineColor: trailColor, lineWidth: 4),
        );
      }
      for (var index = 0; index < _stops.length; index++) {
        await controller.addCircle(
          CircleOptions(
            geometry: _stops[index],
            circleColor: index == 0 ? '#175CD3' : '#B42318',
            circleRadius: 8,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
      }
      if (_allPoints.length > 1) {
        final latitudes = _allPoints.map((point) => point.latitude);
        final longitudes = _allPoints.map((point) => point.longitude);
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                latitudes.reduce((a, b) => a < b ? a : b),
                longitudes.reduce((a, b) => a < b ? a : b),
              ),
              northeast: LatLng(
                latitudes.reduce((a, b) => a > b ? a : b),
                longitudes.reduce((a, b) => a > b ? a : b),
              ),
            ),
            left: 36,
            top: 36,
            right: 36,
            bottom: 36,
          ),
        );
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(context.tokens.radiusMedium),
    ),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(context.tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 42),
            SizedBox(height: context.tokens.space2),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
