import 'package:flutter/material.dart';

import 'planner/trip_planner_controller.dart';

/// Stable route entry point. Workflow state and step composition live under
/// [planner] so this screen remains a navigation-only shell.
class TripPlannerScreen extends StatelessWidget {
  const TripPlannerScreen({this.tripId, super.key});

  final String? tripId;

  @override
  Widget build(BuildContext context) => TripPlannerWorkflow(tripId: tripId);
}
