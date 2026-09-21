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
        var target = new TrackingTarget(truckId, Guid.NewGuid(), Guid.NewGuid(), "revision-a", Route, true);
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
        Assert.Equal(delivered.Latitude, reset.Latitude);
        Assert.Equal(delivered.Longitude, reset.Longitude);
        Assert.NotEqual(afterTenA.TrackingRunId, reset.TrackingRunId);
    }

    [Fact]
    public void DifferentTrucksFollowDifferentRoutesAndNoRouteProducesNoSyntheticPoint()
    {
        var provider = new SimulatedTrackingProvider(new ConfigurationBuilder().Build());
        var company = Guid.NewGuid();
        var first = new TrackingTarget(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "a", Route, true);
        var secondRoute = new[] { new GeoCoordinate(41, 28), new GeoCoordinate(41.2m, 29) };
        var second = new TrackingTarget(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "b", secondRoute, true);
        var noRoute = new TrackingTarget(Guid.NewGuid(), null, null, null, [], false);
        var now = DateTimeOffset.UtcNow;
        provider.Control(company, [first, second, noRoute], new("step"), now);
        var samples = provider.GetCurrent(company, [first, second, noRoute], now);
        Assert.Equal(2, samples.Count);
        Assert.DoesNotContain(samples, x => x.TruckId == noRoute.TruckId);
        Assert.NotEqual(samples[0].Latitude, samples[1].Latitude);
    }

    [Fact]
    public void SimulatorMultiplierAcceleratesProgressWithoutInflatingPhysicalSpeed()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["Tracking:SimulatorSpeedKilometersPerHour"] = "65"
            }).Build();
        var oneX = new SimulatedTrackingProvider(configuration);
        var tenX = new SimulatedTrackingProvider(configuration);
        var companyId = Guid.NewGuid();
        var target = new TrackingTarget(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "revision", Route, true);
        var start = DateTimeOffset.Parse("2026-09-18T00:00:00Z", CultureInfo.InvariantCulture);

        oneX.Control(companyId, [target], new("start"), start);
        tenX.Control(companyId, [target], new("speed", SpeedMultiplier: 10), start);
        tenX.Control(companyId, [target], new("start"), start);

        var normal = oneX.GetCurrent(companyId, [target], start.AddSeconds(30)).Single();
        var accelerated = tenX.GetCurrent(companyId, [target], start.AddSeconds(30)).Single();
        var normalProgress = RouteGeometry.Project(
            Route, new(normal.Latitude, normal.Longitude)).DistanceAlongRouteMeters;
        var acceleratedProgress = RouteGeometry.Project(
            Route, new(accelerated.Latitude, accelerated.Longitude)).DistanceAlongRouteMeters;

        Assert.Equal(65m, normal.Speed);
        Assert.Equal(normal.Speed, accelerated.Speed);
        Assert.True(acceleratedProgress > normalProgress * 8);
    }

    [Fact]
    public void NewSimulatorInstanceRestoresFromPersistedCoordinateWithoutRouteZeroJump()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["Tracking:SimulatorSpeedKilometersPerHour"] = "60"
            }).Build();
        var companyId = Guid.NewGuid();
        var truckId = Guid.NewGuid();
        var tripId = Guid.NewGuid();
        var routeId = Guid.NewGuid();
        var start = DateTimeOffset.Parse("2026-09-21T08:00:00Z", CultureInfo.InvariantCulture);
        var firstProvider = new SimulatedTrackingProvider(configuration);
        var initial = new TrackingTarget(truckId, tripId, routeId, "cargo:a", Route, true);
        firstProvider.Control(companyId, [initial], new("start"), start);
        var beforeRestart = firstProvider.GetCurrent(companyId, [initial], start.AddMinutes(5)).Single();

        var restoredTarget = initial with
        {
            RestorePosition = new(beforeRestart.Latitude, beforeRestart.Longitude),
            RestoreProjectionToleranceMeters = 100
        };
        var restartedProvider = new SimulatedTrackingProvider(configuration);
        var afterRestart = restartedProvider.GetCurrent(
            companyId, [restoredTarget], start.AddMinutes(5)).Single();

        Assert.InRange(Math.Abs(afterRestart.Latitude - beforeRestart.Latitude), 0, 0.00001m);
        Assert.InRange(Math.Abs(afterRestart.Longitude - beforeRestart.Longitude), 0, 0.00001m);
        Assert.NotEqual(Route[0].Latitude, afterRestart.Latitude);

        var unsafeTarget = initial with
        {
            RestorePosition = new(0, 0),
            RestoreProjectionToleranceMeters = 10
        };
        Assert.Empty(new SimulatedTrackingProvider(configuration).GetCurrent(
            companyId, [unsafeTarget], start.AddMinutes(5)));
    }
}
