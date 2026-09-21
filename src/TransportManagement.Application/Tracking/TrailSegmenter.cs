using TransportManagement.Application.Routing;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.Application.Tracking;

public static class TrailSegmenter
{
    public static IReadOnlyList<IReadOnlyList<TruckPosition>> Segment(
        IEnumerable<TruckPosition> positions,
        TimeSpan gapThreshold,
        decimal jumpThresholdMeters)
    {
        var ordered = positions
            .Where(position => position.TripId.HasValue && position.TrackingRunId.HasValue)
            .OrderBy(position => position.RecordedAt)
            .ThenBy(position => position.Id)
            .ToArray();
        if (ordered.Length == 0) return [];

        var result = new List<IReadOnlyList<TruckPosition>>();
        var current = new List<TruckPosition> { ordered[0] };
        for (var index = 1; index < ordered.Length; index++)
        {
            var previous = ordered[index - 1];
            var next = ordered[index];
            if (IsBoundary(previous, next, gapThreshold, jumpThresholdMeters))
            {
                result.Add(current);
                current = [];
            }
            current.Add(next);
        }
        result.Add(current);
        return result;
    }

    private static bool IsBoundary(
        TruckPosition previous,
        TruckPosition next,
        TimeSpan gapThreshold,
        decimal jumpThresholdMeters)
    {
        if (previous.TrackingRunId != next.TrackingRunId
            || previous.RoutePlanId != next.RoutePlanId
            || next.RecordedAt - previous.RecordedAt > gapThreshold)
            return true;

        var distance = RouteGeometry.DistanceMeters([
            new(previous.Latitude, previous.Longitude),
            new(next.Latitude, next.Longitude)
        ]);
        return distance > jumpThresholdMeters;
    }
}
