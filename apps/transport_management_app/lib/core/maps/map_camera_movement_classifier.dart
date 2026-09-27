enum MapCameraMovement { none, zoom, explore }

/// Platform-neutral camera state used to classify MapLibre camera callbacks.
final class MapCameraView {
  const MapCameraView({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.bearing,
    required this.tilt,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;
  final double tilt;
}

/// Distinguishes zooming from deliberate exploration when an embedded map
/// consumes pointer events before Flutter's outer gesture listener sees them.
final class MapCameraMovementClassifier {
  MapCameraView? _previous;

  MapCameraMovement observe(
    MapCameraView current, {
    required bool programmatic,
  }) {
    final previous = _previous;
    _previous = current;
    if (programmatic || previous == null) return MapCameraMovement.none;

    if ((current.zoom - previous.zoom).abs() > 0.0001) {
      return MapCameraMovement.zoom;
    }
    if ((current.latitude - previous.latitude).abs() > 0.00000001 ||
        (current.longitude - previous.longitude).abs() > 0.00000001 ||
        _angleDifference(current.bearing, previous.bearing) > 0.01 ||
        (current.tilt - previous.tilt).abs() > 0.01) {
      return MapCameraMovement.explore;
    }
    return MapCameraMovement.none;
  }

  void reset([MapCameraView? initial]) => _previous = initial;

  static double _angleDifference(double first, double second) {
    final raw = (first - second).abs() % 360;
    return raw > 180 ? 360 - raw : raw;
  }
}
