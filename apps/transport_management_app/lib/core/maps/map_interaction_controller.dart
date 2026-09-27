enum FleetInteractionMode {
  fleetOverview,
  followVehicle,
  freeExplore,
  routeOverview,
}

/// Platform-neutral camera state shared by Owner and Driver maps.
final class MapInteractionController {
  MapInteractionController({
    FleetInteractionMode initialMode = FleetInteractionMode.fleetOverview,
  }) : _mode = initialMode;

  FleetInteractionMode _mode;
  FleetInteractionMode get mode => _mode;
  bool get followsVehicle => _mode == FleetInteractionMode.followVehicle;

  void fleetOverview() => _mode = FleetInteractionMode.fleetOverview;
  void followVehicle() => _mode = FleetInteractionMode.followVehicle;
  void routeOverview() => _mode = FleetInteractionMode.routeOverview;

  /// Wheel/pinch zoom is orthogonal to the current semantic camera mode.
  void userZoom() {}

  /// A deliberate pan/rotate/pitch gives control to the user.
  void userPan() => _mode = FleetInteractionMode.freeExplore;
}
