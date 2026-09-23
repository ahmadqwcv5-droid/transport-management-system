part of '../trip_planner_controller.dart';

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
            child: TripPlannerController._styleUrl.isEmpty
                ? _RouteSchematic(
                    route: widget.route,
                    pickup: widget.pickup,
                    delivery: widget.delivery,
                  )
                : Stack(
                    children: [
                      MapLibreMap(
                        key: const Key('trip-planner-map'),
                        styleString: TripPlannerController._styleUrl,
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
