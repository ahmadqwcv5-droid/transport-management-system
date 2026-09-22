using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Domain.Tracking;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class DispatchTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task PreviewDispatchArrivalAndCargoStartKeepRoutesAndProgressSeparate()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var resources = await CreateAssignedTripAsync(client);
        await AddPositionAsync(resources.TruckId, 39.9198m, 32.8541m, true, DateTimeOffset.UtcNow);

        var before = await client.GetJsonAsync<JsonElement>($"/api/trips/{resources.TripId}");
        var cargoRouteId = before.GetProperty("routePlan").GetProperty("id").GetGuid();
        var previewResponse = await client.PostEmptyAsync(
            $"/api/trips/{resources.TripId}/repositioning/preview");
        Assert.True(previewResponse.IsSuccessStatusCode,
            await previewResponse.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
        var preview = await previewResponse.RequiredJsonAsync();
        Assert.False(preview.GetProperty("alreadyAtPickup").GetBoolean());
        var plan = preview.GetProperty("plan");
        var planId = plan.GetProperty("id").GetGuid();
        Assert.NotEqual(cargoRouteId, planId);
        Assert.Equal("Proposed", plan.GetProperty("status").GetString());

        var dispatched = await (await client.PostJsonAsync(
            $"/api/trips/{resources.TripId}/dispatch-to-pickup",
            new { repositioningPlanId = planId })).RequiredJsonAsync();
        Assert.Equal("EnRouteToPickup", dispatched.GetProperty("status").GetString());
        Assert.Equal(cargoRouteId, dispatched.GetProperty("routePlan").GetProperty("id").GetGuid());
        Assert.Equal("Active", dispatched.GetProperty("repositioningPlan").GetProperty("status").GetString());

        var prematureStart = await client.PostEmptyAsync($"/api/trips/{resources.TripId}/start");
        await AssertProblemAsync(prematureStart, HttpStatusCode.Conflict, "TRUCK_NOT_AT_PICKUP");
        var progress = await client.GetJsonAsync<JsonElement>(
            $"/api/trips/{resources.TripId}/repositioning-progress");
        Assert.False(progress.GetProperty("cargoProgressStarted").GetBoolean());
        var cargoProgress = await client.GetJsonAsync<JsonElement>(
            $"/api/trips/{resources.TripId}/route-progress");
        Assert.Equal(JsonValueKind.Null, cargoProgress.GetProperty("progressPercent").ValueKind);
        Assert.Equal("Heading to pickup", cargoProgress.GetProperty("operationalPhase").GetString());

        await AddPositionAsync(resources.TruckId, 39.9208m, 32.8541m, true, DateTimeOffset.UtcNow.AddMilliseconds(1),
            resources.TripId, planId, MovementPhase.Repositioning);
        var arrived = await (await client.PostEmptyAsync(
            $"/api/trips/{resources.TripId}/arrive-pickup")).RequiredJsonAsync();
        Assert.Equal("AtPickup", arrived.GetProperty("status").GetString());
        Assert.Equal("Completed", arrived.GetProperty("repositioningPlan").GetProperty("status").GetString());
        Assert.Equal("OnTrip", (await client.GetJsonAsync<JsonElement>($"/api/trucks/{resources.TruckId}"))
            .GetProperty("status").GetString());
        Assert.Equal("OnTrip", (await client.GetJsonAsync<JsonElement>($"/api/drivers/{resources.DriverId}"))
            .GetProperty("status").GetString());

        var started = await (await client.PostEmptyAsync($"/api/trips/{resources.TripId}/start")).RequiredJsonAsync();
        Assert.Equal("Started", started.GetProperty("status").GetString());
        Assert.Equal(cargoRouteId, started.GetProperty("routePlan").GetProperty("id").GetGuid());
    }

    [Fact]
    public async Task DispatchRejectsMissingStaleOfflineAndMovedPositionsWithStableErrors()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");

        var missing = await CreateAssignedTripAsync(client);
        await AssertProblemAsync(
            await client.PostEmptyAsync($"/api/trips/{missing.TripId}/repositioning/preview"),
            HttpStatusCode.Conflict, "TRUCK_POSITION_REQUIRED");

        var stale = await CreateAssignedTripAsync(client);
        await AddPositionAsync(stale.TruckId, 39, 32, true, DateTimeOffset.UtcNow.AddMinutes(-10));
        await AssertProblemAsync(
            await client.PostEmptyAsync($"/api/trips/{stale.TripId}/repositioning/preview"),
            HttpStatusCode.Conflict, "TRUCK_POSITION_STALE");

        var offline = await CreateAssignedTripAsync(client);
        await AddPositionAsync(offline.TruckId, 39, 32, false, DateTimeOffset.UtcNow);
        await AssertProblemAsync(
            await client.PostEmptyAsync($"/api/trips/{offline.TripId}/repositioning/preview"),
            HttpStatusCode.Conflict, "TRUCK_OFFLINE");

        var moved = await CreateAssignedTripAsync(client);
        await AddPositionAsync(moved.TruckId, 39, 32, true, DateTimeOffset.UtcNow);
        var previewResponse = await client.PostEmptyAsync(
            $"/api/trips/{moved.TripId}/repositioning/preview");
        Assert.True(previewResponse.IsSuccessStatusCode,
            await previewResponse.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
        var preview = await previewResponse.RequiredJsonAsync();
        var planId = preview.GetProperty("plan").GetProperty("id").GetGuid();
        await AddPositionAsync(moved.TruckId, 39.01m, 32, true, DateTimeOffset.UtcNow.AddMilliseconds(1));
        await AssertProblemAsync(
            await client.PostJsonAsync($"/api/trips/{moved.TripId}/dispatch-to-pickup",
                new { repositioningPlanId = planId }),
            HttpStatusCode.Conflict, "REPOSITIONING_ROUTE_STALE");
    }

    [Fact]
    public async Task NearPickupDispatchIsDirectAndTenantBoundariesAreEnforced()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var resources = await CreateAssignedTripAsync(companyA);
        await AddPositionAsync(resources.TruckId, 39.9208m, 32.8541m, true, DateTimeOffset.UtcNow);

        var preview = await (await companyA.PostEmptyAsync(
            $"/api/trips/{resources.TripId}/repositioning/preview")).RequiredJsonAsync();
        Assert.True(preview.GetProperty("alreadyAtPickup").GetBoolean());
        Assert.Equal(JsonValueKind.Null, preview.GetProperty("plan").ValueKind);
        var dispatched = await (await companyA.PostJsonAsync(
            $"/api/trips/{resources.TripId}/dispatch-to-pickup", new { })).RequiredJsonAsync();
        Assert.Equal("AtPickup", dispatched.GetProperty("status").GetString());
        Assert.Contains("start", dispatched.GetProperty("allowedActions").EnumerateArray().Select(x => x.GetString()));

        var foreign = await companyB.PostEmptyAsync(
            $"/api/trips/{resources.TripId}/repositioning/preview");
        await AssertProblemAsync(foreign, HttpStatusCode.NotFound, "TRIP_NOT_FOUND");
    }

    [Fact]
    public async Task SimulatorTelemetryOwnsArrivalAndCancellationReleasesBusyResources()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var resources = await CreateAssignedTripAsync(client);
        await (await client.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "seed-position",
            truckId = resources.TruckId,
            latitude = 39.9198m,
            longitude = 32.8541m
        })).RequiredJsonAsync();
        var preview = await (await client.PostEmptyAsync(
            $"/api/trips/{resources.TripId}/repositioning/preview")).RequiredJsonAsync();
        var planId = preview.GetProperty("plan").GetProperty("id").GetGuid();
        await (await client.PostJsonAsync(
            $"/api/trips/{resources.TripId}/dispatch-to-pickup",
            new { repositioningPlanId = planId })).RequiredJsonAsync();

        await (await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "step" }))
            .RequiredJsonAsync();
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        var arrived = await client.GetJsonAsync<JsonElement>($"/api/trips/{resources.TripId}");
        Assert.Equal("AtPickup", arrived.GetProperty("status").GetString());
        var history = await client.GetJsonAsync<JsonElement>(
            $"/api/tracking/trips/{resources.TripId}/history");
        Assert.Contains(history.GetProperty("segments").EnumerateArray(), segment =>
            segment.GetProperty("movementPhase").GetString() == "Repositioning"
            && segment.GetProperty("repositioningPlanId").GetGuid() == planId);

        var cancelled = await (await client.PostJsonAsync(
            $"/api/trips/{resources.TripId}/cancel", new { reason = "Dispatch test cancellation" })).RequiredJsonAsync();
        Assert.Equal("Cancelled", cancelled.GetProperty("status").GetString());
        Assert.Equal("Available", (await client.GetJsonAsync<JsonElement>($"/api/trucks/{resources.TruckId}"))
            .GetProperty("status").GetString());
        Assert.Equal("Available", (await client.GetJsonAsync<JsonElement>($"/api/drivers/{resources.DriverId}"))
            .GetProperty("status").GetString());
    }

    [Fact]
    public async Task RoutingProviderFailureLeavesAssignmentAndPositionUnchanged()
    {
        await using var failingFactory = new ApiFactory(useFailingRoutingProvider: true);
        await failingFactory.InitializeAsync();
        using var client = await OperationsTestClient.AuthenticatedClientAsync(
            failingFactory, "owner-a@example.test");
        var resources = await CreateAssignedTripAsync(client);
        const decimal latitude = 39.9198m;
        const decimal longitude = 32.8541m;
        await AddPositionAsync(
            failingFactory, resources.TruckId, latitude, longitude, true, DateTimeOffset.UtcNow);

        await AssertProblemAsync(
            await client.PostEmptyAsync($"/api/trips/{resources.TripId}/repositioning/preview"),
            HttpStatusCode.ServiceUnavailable, "ROUTING_PROVIDER_FAILURE");

        var trip = await client.GetJsonAsync<JsonElement>($"/api/trips/{resources.TripId}");
        Assert.Equal("Assigned", trip.GetProperty("status").GetString());
        Assert.Equal(JsonValueKind.Null, trip.GetProperty("repositioningPlan").ValueKind);
        var position = await client.GetJsonAsync<JsonElement>(
            $"/api/tracking/trucks/{resources.TruckId}/position");
        Assert.Equal(latitude, position.GetProperty("latitude").GetDecimal());
        Assert.Equal(longitude, position.GetProperty("longitude").GetDecimal());
    }

    private static async Task<(Guid TripId, Guid TruckId, Guid DriverId)> CreateAssignedTripAsync(HttpClient client)
    {
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var clientId = (await (await client.PostJsonAsync("/api/clients", new
        {
            name = $"Dispatch {suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"DSP-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Dispatch Driver {suffix}", licenseNumber = $"DSP-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var tripId = (await RouteTestData.CreateReadyTripAsync(client, clientId))
            .GetProperty("id").GetGuid();
        await (await client.PostJsonAsync($"/api/trips/{tripId}/assign", new { truckId, driverId }))
            .RequiredJsonAsync();
        return (tripId, truckId, driverId);
    }

    private async Task AddPositionAsync(
        Guid truckId, decimal latitude, decimal longitude, bool isOnline,
        DateTimeOffset recordedAt, Guid? tripId = null, Guid? repositioningPlanId = null,
        MovementPhase phase = MovementPhase.CurrentLocation)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.TruckPositions.Add(new TruckPosition(
            Guid.NewGuid(), ApiFactory.CompanyAId, truckId, latitude, longitude,
            0, 0, isOnline, recordedAt, "Test", tripId, null, Guid.NewGuid(),
            phase, repositioningPlanId));
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);
    }

    private static async Task AddPositionAsync(
        ApiFactory targetFactory, Guid truckId, decimal latitude, decimal longitude,
        bool isOnline, DateTimeOffset recordedAt)
    {
        using var scope = targetFactory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.TruckPositions.Add(new TruckPosition(
            Guid.NewGuid(), ApiFactory.CompanyAId, truckId, latitude, longitude,
            0, 0, isOnline, recordedAt, "Test", null, null, Guid.NewGuid(),
            MovementPhase.CurrentLocation, null));
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);
    }

    private static async Task AssertProblemAsync(
        HttpResponseMessage response, HttpStatusCode status, string errorCode)
    {
        Assert.Equal(status, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        Assert.Equal(errorCode, problem.GetProperty("errorCode").GetString());
    }
}
