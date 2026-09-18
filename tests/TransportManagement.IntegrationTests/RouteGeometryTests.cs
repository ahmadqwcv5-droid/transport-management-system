using Microsoft.Extensions.Configuration;
using System.Globalization;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Common;
using TransportManagement.Infrastructure.Tracking;

namespace TransportManagement.IntegrationTests;

public sealed class RouteGeometryTests
{
    private static readonly GeoCoordinate[] Route =
        [new(39.0m, 32.0m), new(39.1m, 32.0m), new(39.1m, 32.2m)];

    [Fact]
    public void GeoJsonNormalizesLongitudeLatitudeAndGeometryMathIsBounded()
    {
        var json = RouteGeometry.ToGeoJson(Route);
        var parsed = RouteGeometry.FromGeoJson(json);
        Assert.Equal(Route, parsed);
        var total = RouteGeometry.DistanceMeters(parsed);
        var halfway = RouteGeometry.Interpolate(parsed, total / 2);
        var projection = RouteGeometry.Project(parsed, halfway.Coordinate);
        Assert.InRange(projection.DistanceAlongRouteMeters / total * 100, 49.8m, 50.2m);
        Assert.InRange(projection.DistanceFromRouteMeters, 0, 1);
        Assert.InRange(halfway.Heading, 0, 360);
        Assert.Throws<DomainRuleException>(() => RouteGeometry.ValidateCoordinate(new(91, 0)));
    }

    [Fact]
    public void SimulatorReadsAreObservationalAndPauseResetArrivalAreDeterministic()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["Tracking:SimulatorSpeedKilometersPerHour"] = "60",
                ["Tracking:SimulatorStepDistanceMeters"] = "100000"
            }).Build();
        var provider = new SimulatedTrackingProvider(configuration);
        var companyId = Guid.NewGuid();
        var truckId = Guid.NewGuid();
        var target = new TrackingTarget(truckId, Guid.NewGuid(), "revision-a", Route, true);
        var start = DateTimeOffset.Parse("2026-09-17T00:00:00Z", CultureInfo.InvariantCulture);
        provider.Control(companyId, [target], new("start"), start);

        var afterTenA = provider.GetCurrent(companyId, [target], start.AddSeconds(10)).Single();
        var afterTenB = provider.GetCurrent(companyId, [target], start.AddSeconds(10)).Single();
        Assert.Equal(afterTenA.Latitude, afterTenB.Latitude);
        Assert.Equal(afterTenA.Longitude, afterTenB.Longitude);

        provider.Control(companyId, [target], new("pause"), start.AddSeconds(20));
        var pausedA = provider.GetCurrent(companyId, [target], start.AddSeconds(30)).Single();
        var pausedB = provider.GetCurrent(companyId, [target], start.AddHours(2)).Single();
        Assert.Equal(pausedA.Longitude, pausedB.Longitude);

        provider.Control(companyId, [target], new("step"), start.AddHours(2));
        var delivered = provider.GetCurrent(companyId, [target], start.AddHours(2)).Single();
        Assert.Equal(Route[^1].Latitude, delivered.Latitude);
        Assert.Equal(Route[^1].Longitude, delivered.Longitude);
        Assert.Equal(0, delivered.Speed);

        provider.Control(companyId, [target], new("reset"), start.AddHours(3));
        var reset = provider.GetCurrent(companyId, [target], start.AddHours(3)).Single();
        Assert.Equal(Route[0].Latitude, reset.Latitude);
        Assert.Equal(Route[0].Longitude, reset.Longitude);
    }

    [Fact]
    public void DifferentTrucksFollowDifferentRoutesAndNoRouteProducesNoSyntheticPoint()
    {
        var provider = new SimulatedTrackingProvider(new ConfigurationBuilder().Build());
        var company = Guid.NewGuid();
        var first = new TrackingTarget(Guid.NewGuid(), Guid.NewGuid(), "a", Route, true);
        var secondRoute = new[] { new GeoCoordinate(41, 28), new GeoCoordinate(41.2m, 29) };
        var second = new TrackingTarget(Guid.NewGuid(), Guid.NewGuid(), "b", secondRoute, true);
        var noRoute = new TrackingTarget(Guid.NewGuid(), null, null, [], false);
        var now = DateTimeOffset.UtcNow;
        provider.Control(company, [first, second, noRoute], new("step"), now);
        var samples = provider.GetCurrent(company, [first, second, noRoute], now);
        Assert.Equal(2, samples.Count);
        Assert.DoesNotContain(samples, x => x.TruckId == noRoute.TruckId);
        Assert.NotEqual(samples[0].Latitude, samples[1].Latitude);
    }
}
