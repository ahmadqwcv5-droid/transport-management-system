final class TripPlannerValidation {
  const TripPlannerValidation._();

  static bool hasDistinctCoordinates(
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
  ) =>
      pickupLatitude != null &&
      pickupLongitude != null &&
      deliveryLatitude != null &&
      deliveryLongitude != null &&
      (pickupLatitude != deliveryLatitude ||
          pickupLongitude != deliveryLongitude);

  static bool canOpenStep(int target, int maximumReachableStep) =>
      target >= 0 && target <= maximumReachableStep;
}
