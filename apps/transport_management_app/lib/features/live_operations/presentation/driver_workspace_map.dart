import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../dashboard/presentation/circular_marker_image.dart';
import '../../dashboard/presentation/maplibre_fleet_adapter.dart';
import '../domain/live_operations_models.dart';

typedef DriverPhotoLoader = Future<Uint8List> Function(String url);

class DriverWorkspaceMap extends StatefulWidget {
  const DriverWorkspaceMap({
    required this.workspace,
    required this.styleUrl,
    required this.photoLoader,
    super.key,
  });
  final DriverWorkspace workspace;
  final String styleUrl;
  final DriverPhotoLoader photoLoader;

  @override
  State<DriverWorkspaceMap> createState() => _DriverWorkspaceMapState();
}

class _DriverWorkspaceMapState extends State<DriverWorkspaceMap> {
  final _processor = const CircularMarkerImageProcessor();
  MapLibreMapController? _controller;
  Symbol? _truck;
  Line? _route;
  Line? _approach;
  final List<Circle> _stops = [];
  final Set<String> _images = {};
  bool _styleLoaded = false;
  bool _failed = false;

  @override
  void didUpdateWidget(covariant DriverWorkspaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) unawaited(_syncSafely());
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.workspace.currentPosition;
    final next = widget.workspace.nextStop;
    if (_failed ||
        widget.styleUrl.isEmpty ||
        (position == null && next == null)) {
      return DecoratedBox(
        key: const Key('driver-map-unavailable'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Icon(Icons.map_outlined, size: 52)),
      );
    }
    final target = position == null
        ? LatLng(next!.latitude!, next.longitude!)
        : LatLng(position.latitude, position.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Listener(
        key: const Key('driver-map-input-listener'),
        behavior: HitTestBehavior.translucent,
        child: MapLibreMap(
          key: const Key('driver-workspace-map'),
          styleString: widget.styleUrl,
          initialCameraPosition: CameraPosition(target: target, zoom: 13.5),
          annotationOrder: const [
            AnnotationType.line,
            AnnotationType.circle,
            AnnotationType.symbol,
          ],
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: () async {
            try {
              _styleLoaded = true;
              final controller = _controller;
              if (controller == null) return;
              final fallback = await rootBundle.load(truckMarkerAsset);
              await controller.addImage(
                truckMarkerImageName,
                fallback.buffer.asUint8List(
                  fallback.offsetInBytes,
                  fallback.lengthInBytes,
                ),
              );
              await _sync();
            } on Object {
              _markFailed();
            }
          },
        ),
      ),
    );
  }

  Future<void> _syncSafely() async {
    try {
      await _sync();
    } on Object {
      _markFailed();
    }
  }

  void _markFailed() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !mounted) return;
    final position = widget.workspace.currentPosition;
    final truck = widget.workspace.truck;
    if (position != null && truck != null) {
      var imageName = truckMarkerImageName;
      final photoUrl = truck.photoThumbnailUrl;
      final photoVersion = truck.photoVersion;
      if (photoUrl != null && photoVersion != null) {
        final candidate = 'driver-truck-marker-v2:${truck.id}:$photoVersion';
        try {
          if (_images.add(candidate)) {
            final source = await widget.photoLoader(photoUrl);
            await controller.addImage(
              candidate,
              await _processor.process(source),
            );
          }
          imageName = candidate;
        } on Object {
          _images.remove(candidate);
        }
      }
      final options = SymbolOptions(
        geometry: LatLng(position.latitude, position.longitude),
        iconImage: imageName,
        iconSize: imageName == truckMarkerImageName ? 0.7 : 0.78,
        iconRotate: imageName == truckMarkerImageName ? position.heading : 0,
        iconAnchor: 'center',
      );
      if (_truck == null) {
        _truck = await controller.addSymbol(options);
      } else {
        await controller.updateSymbol(_truck!, options);
      }
    }

    final status = widget.workspace.currentTrip?.status;
    final cargo = status == 'EnRouteToPickup' || status == 'AtPickup'
        ? const <LatLng>[]
        : widget.workspace.activeRoute?.coordinates
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList() ??
              const [];
    final approach = status == 'EnRouteToPickup'
        ? widget.workspace.approachRoute?.route.coordinates
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList() ??
              const []
        : const <LatLng>[];
    _route = await _syncLine(_route, cargo, '#175CD3');
    _approach = await _syncLine(_approach, approach, '#D97706');

    if (_stops.isEmpty) {
      for (final stop in widget.workspace.currentTrip?.stops ?? const []) {
        if (!stop.hasCoordinates) continue;
        _stops.add(
          await controller.addCircle(
            CircleOptions(
              geometry: LatLng(stop.latitude!, stop.longitude!),
              circleRadius: stop.type == 'Pickup' ? 8 : 9,
              circleColor: stop.type == 'Pickup' ? '#16A34A' : '#DC2626',
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2,
            ),
          ),
        );
      }
    }
  }

  Future<Line?> _syncLine(Line? line, List<LatLng> points, String color) async {
    final controller = _controller!;
    if (points.length < 2) {
      if (line != null) await controller.removeLine(line);
      return null;
    }
    if (line == null) {
      return controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: color,
          lineWidth: 5,
          lineOpacity: 0.9,
        ),
      );
    }
    await controller.updateLine(line, LineOptions(geometry: points));
    return line;
  }
}
