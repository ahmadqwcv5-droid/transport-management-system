using System.Globalization;
using TransportManagement.Application.Tracking;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.IntegrationTests;

public sealed class TrailSegmenterTests
{
    private static readonly Guid CompanyId = Guid.NewGuid();
    private static readonly Guid TruckId = Guid.NewGuid();
    private static readonly Guid TripId = Guid.NewGuid();
    private static readonly Guid RouteId = Guid.NewGuid();
    private static readonly Guid RunId = Guid.NewGuid();
    private static readonly DateTimeOffset Start = DateTimeOffset.Parse(
        "2026-09-18T00:00:00Z", CultureInfo.InvariantCulture);

    [Fact]
    public void SessionAndRouteChangesCreateIndependentChronologicalSegments()
    {
        var otherRun = Guid.NewGuid();
        var otherRoute = Guid.NewGuid();
        var positions = new[]
        {
            Position(3, Start.AddSeconds(20), runId: otherRun, routeId: otherRoute),
            Position(1, Start),
            Position(2, Start.AddSeconds(10), runId: otherRun),
        };

        var segments = TrailSegmenter.Segment(
            positions, TimeSpan.FromMinutes(5), 5_000);

        Assert.Equal(3, segments.Count);
        Assert.Equal([1, 2, 3], segments.SelectMany(x => x).Select(x => (int)x.Latitude));
    }

    [Fact]
    public void TimeGapAndHaversineJumpCreateIndependentSegments()
    {
        var positions = new[]
        {
            Position(39, Start, longitude: 32),
            Position(39, Start.AddSeconds(10), longitude: 32.001m),
            Position(39, Start.AddMinutes(10), longitude: 32.002m),
            Position(39, Start.AddMinutes(10).AddSeconds(10), longitude: 33),
        };

        var segments = TrailSegmenter.Segment(
            positions, TimeSpan.FromMinutes(5), 5_000);

        Assert.Equal([2, 1, 1], segments.Select(x => x.Count));
    }

    [Fact]
    public void UnassignedPositionsAreExcluded()
    {
        var positions = new[]
        {
            Position(1, Start),
            Position(2, Start.AddSeconds(1), noTrip: true),
        };

        var segments = TrailSegmenter.Segment(
            positions, TimeSpan.FromMinutes(5), 5_000);

        Assert.Single(segments);
        Assert.Single(segments[0]);
        Assert.Equal(1, segments[0][0].Latitude);
    }

    private static TruckPosition Position(
        decimal latitude,
        DateTimeOffset recordedAt,
        decimal longitude = 32,
        Guid? tripId = default,
        Guid? routeId = default,
        Guid? runId = default,
        bool noTrip = false)
    {
        var effectiveTripId = tripId == default ? TripId : tripId;
        var effectiveRouteId = routeId == default ? RouteId : routeId;
        var effectiveRunId = runId == default ? RunId : runId;
        return new(
            Guid.NewGuid(), CompanyId, TruckId, latitude, longitude, 65, 0, true,
            recordedAt, "Test", noTrip ? null : effectiveTripId, effectiveRouteId,
            effectiveRunId ?? Guid.Empty);
    }
}
