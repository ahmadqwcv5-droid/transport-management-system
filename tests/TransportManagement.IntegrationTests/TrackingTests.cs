using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Tracking;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class TrackingTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task SimulatorInventoryIncludesUnlocatedTruckAndSeedIsTenantSafe()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var plate = $"LOC-{Guid.NewGuid():N}"[..20];
        var truckId = (await (await companyA.PostJsonAsync(
            "/api/trucks", new { plateNumber = plate })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();

        var inventory = await companyA.GetJsonAsync<JsonElement[]>("/api/tracking/simulator/trucks");
        var unlocated = inventory!.Single(x => x.GetProperty("truckId").GetGuid() == truckId);
        Assert.Equal("NoLocation", unlocated.GetProperty("locationState").GetString());
        Assert.Equal(JsonValueKind.Null, unlocated.GetProperty("latitude").ValueKind);

        var foreignSeed = await companyB.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "set-position", truckId, latitude = 39.9m, longitude = 32.8m
        });
        Assert.Equal(HttpStatusCode.NotFound, foreignSeed.StatusCode);
        var invalid = await companyA.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "set-position", truckId, latitude = 91m, longitude = 32.8m
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        var invalidProblem = await invalid.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        Assert.Equal("INVALID_POSITION", invalidProblem.GetProperty("errorCode").GetString());

        await (await companyA.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "set-position", truckId, latitude = 39.9m, longitude = 32.8m
        })).RequiredJsonAsync();
        var current = await companyA.GetJsonAsync<JsonElement>(
            $"/api/tracking/trucks/{truckId}/position");
        Assert.Equal(39.9m, current.GetProperty("latitude").GetDecimal());
        Assert.Equal("CurrentLocation", current.GetProperty("movementPhase").GetString());
        Assert.Equal(JsonValueKind.Null, current.GetProperty("currentTripId").ValueKind);
        Assert.Equal(JsonValueKind.Null, current.GetProperty("repositioningPlanId").ValueKind);
    }

    [Fact]
    public async Task SimulatorLocationMutationIsRejectedWhenProviderIsDisabled()
    {
        await using var disabledFactory = new ApiFactory(
            useFailingRoutingProvider: false, simulatorEnabled: false);
        await disabledFactory.InitializeAsync();
        using var client = await OperationsTestClient.AuthenticatedClientAsync(
            disabledFactory, "owner-a@example.test");
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"DIS-{Guid.NewGuid():N}"[..20]
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

        var response = await client.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "set-position", truckId, latitude = 39m, longitude = 32m
        });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        Assert.Equal("SIMULATOR_DISABLED", problem.GetProperty("errorCode").GetString());
    }

    [Fact]
    public async Task StationarySimulatorHeartbeatRestoresFreshnessWithBoundedWrites()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var clientId = (await (await client.PostJsonAsync(
            "/api/clients", new { name = $"Heartbeat {suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var truckId = (await (await client.PostJsonAsync(
            "/api/trucks", new { plateNumber = $"HB-{suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Heartbeat Driver {suffix}", licenseNumber = $"HB-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var tripId = (await RouteTestData.CreateReadyTripAsync(client, clientId))
            .GetProperty("id").GetGuid();
        await (await client.PostJsonAsync(
            $"/api/trips/{tripId}/assign", new { truckId, driverId })).RequiredJsonAsync();

        var oldPosition = new TruckPosition(
            Guid.NewGuid(), ApiFactory.CompanyAId, truckId, 39.9m, 32.8m,
            0, 123, true, DateTimeOffset.UtcNow.AddMinutes(-10),
            "SimulatorSeed", null, null, Guid.NewGuid(), MovementPhase.CurrentLocation);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.TruckPositions.Add(oldPosition);
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        for (var index = 0; index < 10; index++)
            await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        using (var ingestionScope = factory.Services.CreateScope())
        {
            var companyContext = ingestionScope.ServiceProvider
                .GetRequiredService<ICompanyExecutionContext>();
            using var company = companyContext.Enter(ApiFactory.CompanyAId);
            await ingestionScope.ServiceProvider.GetRequiredService<TrackingIngestionService>()
                .TickAsync(TestContext.Current.CancellationToken);
        }

        var history = await client.GetJsonAsync<JsonElement[]>(
            $"/api/tracking/trucks/{truckId}/history?limit=200");
        Assert.Equal(2, history!.Length);
        var latest = history[0];
        Assert.Equal(oldPosition.Latitude, latest.GetProperty("latitude").GetDecimal());
        Assert.Equal(oldPosition.Longitude, latest.GetProperty("longitude").GetDecimal());
        Assert.Equal(oldPosition.Heading, latest.GetProperty("heading").GetDecimal());
        Assert.Equal("CurrentLocation", latest.GetProperty("movementPhase").GetString());

        var preview = await client.PostEmptyAsync($"/api/trips/{tripId}/repositioning/preview");
        Assert.True(preview.IsSuccessStatusCode,
            await preview.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        await (await client.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "refresh-position", truckId
        })).RequiredJsonAsync();
        var refreshed = await client.GetJsonAsync<JsonElement>(
            $"/api/tracking/trucks/{truckId}/position");
        Assert.Equal(oldPosition.Latitude, refreshed.GetProperty("latitude").GetDecimal());
        Assert.Equal(oldPosition.Longitude, refreshed.GetProperty("longitude").GetDecimal());
        using var verificationScope = factory.Services.CreateScope();
        var verificationDb = verificationScope.ServiceProvider.GetRequiredService<AppDbContext>();
        var refreshedRow = await verificationDb.TruckPositions.IgnoreQueryFilters()
            .Where(x => x.CompanyId == ApiFactory.CompanyAId && x.TruckId == truckId)
            .OrderByDescending(x => x.RecordedAt)
            .FirstAsync(TestContext.Current.CancellationToken);
        Assert.Null(refreshedRow.TripId);
        Assert.Null(refreshedRow.RoutePlanId);
        Assert.Null(refreshedRow.RepositioningPlanId);
        Assert.Equal(MovementPhase.CurrentLocation, refreshedRow.MovementPhase);
    }

    [Fact]
    public async Task AssigningDistantNextTripDoesNotTeleportCompletedTruckToPickup()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var clientId = (await (await client.PostJsonAsync("/api/clients", new
        {
            name = $"No teleport {suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"NT-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"No Teleport {suffix}",
            licenseNumber = $"NT-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

        var tripAId = (await RouteTestData.CreateReadyTripAsync(
            client, clientId, 39, 32, 40, 31)).GetProperty("id").GetGuid();
        await (await client.PostJsonAsync($"/api/trips/{tripAId}/assign", new { truckId, driverId })).RequiredJsonAsync();
        await (await client.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "seed-position", truckId, latitude = 39m, longitude = 32m
        })).RequiredJsonAsync();
        await (await client.PostJsonAsync($"/api/trips/{tripAId}/dispatch-to-pickup", new { reason = "Test manager override" })).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripAId}/arrive-pickup")).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripAId}/start")).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripAId}/mark-in-transit")).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripAId}/deliver")).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripAId}/complete")).RequiredJsonAsync();

        var finalPosition = new TruckPosition(
            Guid.NewGuid(), ApiFactory.CompanyAId, truckId, 40, 31, 0, 0, true,
            DateTimeOffset.UtcNow, "Test", tripAId, null, Guid.NewGuid(), MovementPhase.Cargo);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.TruckPositions.Add(finalPosition);
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        var tripBId = (await RouteTestData.CreateReadyTripAsync(
            client, clientId, 41, 28, 40.5m, 29)).GetProperty("id").GetGuid();
        await client.PostJsonAsync($"/api/trips/{tripBId}/assign", new { truckId, driverId });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");

        using var verificationScope = factory.Services.CreateScope();
        var verificationDb = verificationScope.ServiceProvider.GetRequiredService<AppDbContext>();
        var latest = await verificationDb.TruckPositions.IgnoreQueryFilters()
            .Where(x => x.CompanyId == ApiFactory.CompanyAId && x.TruckId == truckId)
            .OrderByDescending(x => x.RecordedAt)
            .FirstAsync(TestContext.Current.CancellationToken);
        Assert.Equal(finalPosition.Latitude, latest.Latitude);
        Assert.Equal(finalPosition.Longitude, latest.Longitude);
    }

    [Fact]
    public async Task SimulatorMovesPausesResumesResetsAndTracksOfflineState()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var truckId = await CreateStartedRouteTripAsync(client);

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "reset" });
        await (await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "start" })).RequiredJsonAsync();
        var first = (await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions"))!.Single(x => x.GetProperty("truckId").GetGuid() == truckId);
        var second = (await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions"))!.Single(x => x.GetProperty("truckId").GetGuid() == truckId);
        Assert.InRange(Math.Abs(first.GetProperty("longitude").GetDecimal() - second.GetProperty("longitude").GetDecimal()), 0, 0.00001m);

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "pause" });
        var paused1 = await client.GetJsonAsync<JsonElement>( $"/api/tracking/trucks/{truckId}/position");
        var paused2 = await client.GetJsonAsync<JsonElement>( $"/api/tracking/trucks/{truckId}/position");
        Assert.Equal(paused1.GetProperty("longitude").GetDecimal(), paused2.GetProperty("longitude").GetDecimal());
        var trips = await client.GetJsonAsync<JsonElement>("/api/trips?pageSize=100");
        var tripId = trips.GetProperty("items").EnumerateArray()
            .Single(x => x.GetProperty("truckId").GetGuid() == truckId).GetProperty("id").GetGuid();
        var progressBefore = await client.GetJsonAsync<JsonElement>($"/api/trips/{tripId}/route-progress");

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "step" });
        var resumed = await client.GetJsonAsync<JsonElement>($"/api/tracking/trucks/{truckId}/position");
        Assert.NotEqual(paused2.GetProperty("longitude").GetDecimal(), resumed.GetProperty("longitude").GetDecimal());
        var progressAfter = await client.GetJsonAsync<JsonElement>($"/api/trips/{tripId}/route-progress");
        Assert.True(progressAfter.GetProperty("progressPercent").GetDecimal() >
            progressBefore.GetProperty("progressPercent").GetDecimal());
        Assert.True(progressAfter.GetProperty("remainingDistanceMeters").GetDecimal() <
            progressBefore.GetProperty("remainingDistanceMeters").GetDecimal());

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "offline", truckId });
        var offline = await client.GetJsonAsync<JsonElement>($"/api/tracking/trucks/{truckId}/position");
        Assert.False(offline.GetProperty("isOnline").GetBoolean());
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "reset" });
        var reset = await client.GetJsonAsync<JsonElement>($"/api/tracking/trucks/{truckId}/position");
        Assert.True(reset.GetProperty("isOnline").GetBoolean());
    }

    [Fact]
    public async Task TrackingHistoryControlsAndDashboardAreTenantScoped()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var foreignTruck = await (await companyB.PostJsonAsync("/api/trucks", new { plateNumber = $"B-{Guid.NewGuid():N}"[..20] })).RequiredJsonAsync();
        var foreignTruckId = foreignTruck.GetProperty("id").GetGuid();
        await companyB.PostJsonAsync("/api/tracking/simulator/control", new { action = "start" });
        await companyB.GetJsonAsync<JsonElement[]>("/api/tracking/positions");

        Assert.Equal(HttpStatusCode.NotFound, (await companyA.GetResponseAsync($"/api/tracking/trucks/{foreignTruckId}/history")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await companyA.PostJsonAsync("/api/tracking/simulator/control", new { action = "offline", truckId = foreignTruckId })).StatusCode);
        var dashboard = await companyA.GetJsonAsync<JsonElement>("/api/dashboard");
        Assert.DoesNotContain(dashboard.GetProperty("positions").EnumerateArray(), x => x.GetProperty("truckId").GetGuid() == foreignTruckId);
    }

    [Fact]
    public async Task StationaryPollingIsDeduplicatedWhileMovementAndStateChangesPersist()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var truckId = await CreateStartedRouteTripAsync(client);

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "reset" });
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "start" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "pause" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        var pausedCount = await HistoryCountAsync(client, truckId);
        Assert.Equal(4, pausedCount);

        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        Assert.Equal(pausedCount, await HistoryCountAsync(client, truckId));

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "step" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        Assert.Equal(pausedCount + 1, await HistoryCountAsync(client, truckId));

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "offline", truckId });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        Assert.Equal(pausedCount + 2, await HistoryCountAsync(client, truckId));

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "online", truckId });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        Assert.Equal(pausedCount + 3, await HistoryCountAsync(client, truckId));
    }

    [Fact]
    public async Task ResetHistoryIsReturnedAsTripScopedIndependentSegments()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var truckId = await CreateStartedRouteTripAsync(client);
        var tripPage = await client.GetJsonAsync<JsonElement>("/api/trips?pageSize=100");
        var tripId = tripPage.GetProperty("items").EnumerateArray()
            .Single(x => x.GetProperty("truckId").GetGuid() == truckId)
            .GetProperty("id").GetGuid();

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "reset" });
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "step" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "reset" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");

        var history = await client.GetJsonAsync<JsonElement>($"/api/tracking/trips/{tripId}/history");
        var segments = history.GetProperty("segments").EnumerateArray().ToArray();
        Assert.Equal(3, segments.Length);
        Assert.All(segments, segment => Assert.NotEmpty(segment.GetProperty("points").EnumerateArray()));
        Assert.All(segments, segment => Assert.NotEqual(Guid.Empty, segment.GetProperty("trackingRunId").GetGuid()));
        Assert.All(segments, segment => Assert.Equal(JsonValueKind.String, segment.GetProperty("routePlanId").ValueKind));
    }

    [Fact]
    public async Task TripHistoryExcludesAnotherTripAndLegacyPositionsAndIsTenantScoped()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var truckId = await CreateStartedRouteTripAsync(companyA);
        var now = DateTimeOffset.UtcNow;
        Guid tripAId;
        Guid tripBId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var tripA = await db.Trips.IgnoreQueryFilters()
                .Include(x => x.RoutePlan)
                .SingleAsync(
                    x => x.CompanyId == ApiFactory.CompanyAId && x.TruckId == truckId,
                    TestContext.Current.CancellationToken);
            tripAId = tripA.Id;
            var tripB = new Trip(
                Guid.NewGuid(), ApiFactory.CompanyAId, "TRP-2026-900002", tripA.ClientId,
                "Previous cargo",
                now.AddDays(-1), 100, null, now.AddDays(-2));
            tripB.Assign(truckId, tripA.DriverId!.Value, now.AddDays(-2));
            tripBId = tripB.Id;
            db.Trips.Add(tripB);
            db.TruckPositions.AddRange(
                Position(truckId, tripAId, tripA.RoutePlan!.Id, 39, now.AddSeconds(1)),
                Position(truckId, tripBId, null, 40, now),
                Position(truckId, null, null, 41, now.AddSeconds(2)));
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        var tripAHistory = await companyA.GetJsonAsync<JsonElement>(
            $"/api/tracking/trips/{tripAId}/history");
        var tripAPoints = tripAHistory.GetProperty("segments").EnumerateArray()
            .SelectMany(segment => segment.GetProperty("points").EnumerateArray()).ToArray();
        Assert.Single(tripAPoints);
        Assert.Equal(39, tripAPoints[0].GetProperty("latitude").GetDecimal());

        var tripBHistory = await companyA.GetJsonAsync<JsonElement>(
            $"/api/tracking/trips/{tripBId}/history");
        var tripBPoints = tripBHistory.GetProperty("segments").EnumerateArray()
            .SelectMany(segment => segment.GetProperty("points").EnumerateArray()).ToArray();
        Assert.Single(tripBPoints);
        Assert.Equal(40, tripBPoints[0].GetProperty("latitude").GetDecimal());

        var forbidden = await companyB.GetResponseAsync($"/api/tracking/trips/{tripAId}/history");
        Assert.Equal(HttpStatusCode.NotFound, forbidden.StatusCode);
        var problem = await forbidden.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        Assert.Equal("TRIP_NOT_FOUND", problem.GetProperty("errorCode").GetString());
    }

    [Fact]
    public async Task UnassignedPositionRemainsAvailableAsCurrentFleetLocation()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"FREE-{Guid.NewGuid():N}"[..20]
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.TruckPositions.Add(Position(
                truckId, null, null, 38.5m, DateTimeOffset.UtcNow));
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        var current = await client.GetJsonAsync<JsonElement>(
            $"/api/tracking/trucks/{truckId}/position");
        Assert.Equal(38.5m, current.GetProperty("latitude").GetDecimal());
        Assert.Equal(JsonValueKind.Null, current.GetProperty("currentTripId").ValueKind);
    }

    private static async Task<int> HistoryCountAsync(HttpClient client, Guid truckId) =>
        (await client.GetJsonAsync<JsonElement[]>($"/api/tracking/trucks/{truckId}/history?limit=200"))!.Length;

    private static async Task<Guid> CreateStartedRouteTripAsync(HttpClient client)
    {
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var clientId = (await (await client.PostJsonAsync("/api/clients", new { name = $"Tracking {suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new { plateNumber = $"SIM-{suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Driver {suffix}", licenseNumber = $"SIM-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var tripId = (await RouteTestData.CreateReadyTripAsync(client, clientId))
            .GetProperty("id").GetGuid();
        await (await client.PostJsonAsync($"/api/trips/{tripId}/assign", new { truckId, driverId })).RequiredJsonAsync();
        await (await client.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "seed-position", truckId, latitude = 39.9208m, longitude = 32.8541m
        })).RequiredJsonAsync();
        await (await client.PostJsonAsync($"/api/trips/{tripId}/dispatch-to-pickup", new { reason = "Test manager override" })).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripId}/arrive-pickup")).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripId}/start")).RequiredJsonAsync();
        await (await client.PostEmptyAsync($"/api/trips/{tripId}/mark-in-transit")).RequiredJsonAsync();
        return truckId;
    }

    private static TruckPosition Position(
        Guid truckId, Guid? tripId, Guid? routePlanId,
        decimal latitude, DateTimeOffset recordedAt) =>
        new(
            Guid.NewGuid(), ApiFactory.CompanyAId, truckId, latitude, 32,
            65, 0, true, recordedAt, "Test", tripId, routePlanId, Guid.NewGuid());
}
