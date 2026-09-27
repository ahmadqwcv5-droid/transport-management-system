import 'dart:math' as math;

final class VehicleVisualState {
  const VehicleVisualState({
    required this.latitude,
    required this.longitude,
    required this.heading,
  });
  final double latitude, longitude, heading;
}

/// Pure, fake-time-friendly latest-wins interpolation policy.
final class VehicleMotionInterpolator {
  VehicleMotionInterpolator({
    this.minimumDuration = const Duration(milliseconds: 250),
    this.maximumDuration = const Duration(milliseconds: 1800),
    this.snapDistanceMeters = 100000,
  });

  final Duration minimumDuration, maximumDuration;
  final double snapDistanceMeters;
  VehicleVisualState? _from, _to;
  DateTime? _startedAt;
  Duration _duration = Duration.zero;
  int _revision = 0;
  int get revision => _revision;

  VehicleVisualState retarget({
    required VehicleVisualState target,
    required DateTime now,
    Duration? sampleGap,
    bool animate = true,
  }) {
    final current = sample(now) ?? target;
    _revision++;
    _from = current;
    _to = target;
    _startedAt = now;
    final distance = _distanceMeters(current, target);
    if (!animate || distance >= snapDistanceMeters || distance < 0.5) {
      _duration = Duration.zero;
      _from = target;
      return target;
    }
    final gap = sampleGap ?? const Duration(seconds: 2);
    _duration = Duration(
      milliseconds: gap.inMilliseconds.clamp(
        minimumDuration.inMilliseconds,
        maximumDuration.inMilliseconds,
      ),
    );
    return current;
  }

  VehicleVisualState? sample(DateTime now) {
    final from = _from;
    final to = _to;
    final started = _startedAt;
    if (from == null || to == null || started == null) return to;
    if (_duration == Duration.zero) return to;
    final fraction =
        now.difference(started).inMicroseconds / _duration.inMicroseconds;
    if (fraction >= 1) return to;
    final t = fraction.clamp(0.0, 1.0);
    final delta = ((to.heading - from.heading + 540) % 360) - 180;
    return VehicleVisualState(
      latitude: from.latitude + (to.latitude - from.latitude) * t,
      longitude: from.longitude + (to.longitude - from.longitude) * t,
      heading: (from.heading + delta * t + 360) % 360,
    );
  }

  static double _distanceMeters(VehicleVisualState a, VehicleVisualState b) {
    const radius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
