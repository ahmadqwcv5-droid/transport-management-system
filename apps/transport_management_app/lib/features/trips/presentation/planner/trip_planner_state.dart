import '../../domain/trip_models.dart';

/// Immutable cross-step snapshot exposed by planner orchestration.
final class TripPlannerState {
  const TripPlannerState({
    required this.currentStep,
    required this.maximumReachableStep,
    required this.isSaving,
    required this.isRouting,
    required this.isAssigning,
    required this.skipAssignment,
    this.persistedTrip,
    this.assignmentOptions,
  });

  final int currentStep, maximumReachableStep;
  final bool isSaving, isRouting, isAssigning, skipAssignment;
  final Trip? persistedTrip;
  final AssignmentOptions? assignmentOptions;

  TripPlannerState copyWith({
    int? currentStep,
    int? maximumReachableStep,
    bool? isSaving,
    bool? isRouting,
    bool? isAssigning,
    bool? skipAssignment,
    Trip? persistedTrip,
    AssignmentOptions? assignmentOptions,
  }) => TripPlannerState(
    currentStep: currentStep ?? this.currentStep,
    maximumReachableStep: maximumReachableStep ?? this.maximumReachableStep,
    isSaving: isSaving ?? this.isSaving,
    isRouting: isRouting ?? this.isRouting,
    isAssigning: isAssigning ?? this.isAssigning,
    skipAssignment: skipAssignment ?? this.skipAssignment,
    persistedTrip: persistedTrip ?? this.persistedTrip,
    assignmentOptions: assignmentOptions ?? this.assignmentOptions,
  );
}
