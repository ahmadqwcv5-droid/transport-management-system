using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Tracking;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class DriverDepartureTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task FarDriverDepartureGeneratesRouteSessionAndSingleIdempotentEvent()
    {
        var setup = await CreateAssignmentAsync(factory);
        await AddPositionAsync(factory, setup.TruckId, 39.8800m, 32.8000m, true,
            DateTimeOffset.UtcNow);
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, setup.DriverEmail);

        var workspace = await driver.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        var action = Assert.Single(workspace.GetProperty("actions").EnumerateArray());
        Assert.Equal("DEPART_TO_PICKUP", action.GetProperty("code").GetString());
        Assert.True(action.GetProperty("enabled").GetBoolean());
        Assert.Equal(JsonValueKind.Null, action.GetProperty("blockingReason").ValueKind);
        Assert.Equal(JsonValueKind.Null,
            workspace.GetProperty("approachRoute").ValueKind);

        var departed = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup")).RequiredJsonAsync();
        Assert.Equal("EnRouteToPickup", departed.GetProperty("status").GetString());
        var planId = departed.GetProperty("repositioningPlan").GetProperty("id").GetGuid();
        Assert.Equal("Active", departed.GetProperty("repositioningPlan")
            .GetProperty("status").GetString());

        var repeated = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup")).RequiredJsonAsync();
        Assert.Equal(planId, repeated.GetProperty("repositioningPlan").GetProperty("id").GetGuid());

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.TripRepositioningPlans.IgnoreQueryFilters()
            .CountAsync(x => x.TripId == setup.TripId,
                TestContext.Current.CancellationToken));
        Assert.Equal(1, await db.DriverTruckSessions.IgnoreQueryFilters()
            .CountAsync(x => x.DriverId == setup.DriverId && x.EndedAt == null,
                TestContext.Current.CancellationToken));
        Assert.Equal(1, await db.TripEvents.IgnoreQueryFilters()
            .CountAsync(x => x.TripId == setup.TripId
                && x.EventType == "DriverDepartedToPickup",
                TestContext.Current.CancellationToken));
        Assert.False(await db.TripEvents.IgnoreQueryFilters().AnyAsync(
            x => x.TripId == setup.TripId && x.Source == "ManagerOverride",
            TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task DriverDepartureReusesValidManagerPreview()
    {
        var setup = await CreateAssignmentAsync(factory);
        await AddPositionAsync(factory, setup.TruckId, 39.8800m, 32.8000m, true,
            DateTimeOffset.UtcNow);
        using var manager = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var preview = await (await manager.PostEmptyAsync(
            $"/api/trips/{setup.TripId}/repositioning/preview")).RequiredJsonAsync();
        var proposedId = preview.GetProperty("plan").GetProperty("id").GetGuid();
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, setup.DriverEmail);

        var departed = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup")).RequiredJsonAsync();

        Assert.Equal(proposedId,
            departed.GetProperty("repositioningPlan").GetProperty("id").GetGuid());
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.TripRepositioningPlans.IgnoreQueryFilters()
            .CountAsync(x => x.TripId == setup.TripId,
                TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task DriverDepartureReplacesPreviewAfterTruckMovesBeyondTolerance()
    {
        var setup = await CreateAssignmentAsync(factory);
        await AddPositionAsync(factory, setup.TruckId, 39.8800m, 32.8000m, true,
            DateTimeOffset.UtcNow);
        using var manager = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var preview = await (await manager.PostEmptyAsync(
            $"/api/trips/{setup.TripId}/repositioning/preview")).RequiredJsonAsync();
        var stalePlanId = preview.GetProperty("plan").GetProperty("id").GetGuid();
        await AddPositionAsync(factory, setup.TruckId, 39.8900m, 32.8100m, true,
            DateTimeOffset.UtcNow.AddMilliseconds(1));
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, setup.DriverEmail);

        var departed = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup")).RequiredJsonAsync();
        var activePlanId = departed.GetProperty("repositioningPlan")
            .GetProperty("id").GetGuid();

        Assert.NotEqual(stalePlanId, activePlanId);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var plans = await db.TripRepositioningPlans.IgnoreQueryFilters()
            .Where(x => x.TripId == setup.TripId).ToListAsync(
                TestContext.Current.CancellationToken);
        Assert.Equal(2, plans.Count);
        Assert.Equal("Expired", plans.Single(x => x.Id == stalePlanId).Status.ToString());
        Assert.Equal("Active", plans.Single(x => x.Id == activePlanId).Status.ToString());
    }

    [Fact]
    public async Task DriverReadinessAndDepartureReturnExactTelemetryBlockers()
    {
        var missing = await CreateAssignmentAsync(factory);
        await AssertBlockedAsync(factory, missing, "TRUCK_POSITION_REQUIRED");

        var offline = await CreateAssignmentAsync(factory);
        await AddPositionAsync(factory, offline.TruckId, 39.88m, 32.80m, false,
            DateTimeOffset.UtcNow);
        await AssertBlockedAsync(factory, offline, "TRUCK_OFFLINE");

        var stale = await CreateAssignmentAsync(factory);
        await AddPositionAsync(factory, stale.TruckId, 39.88m, 32.80m, true,
            DateTimeOffset.UtcNow.AddMinutes(-10));
        await AssertBlockedAsync(factory, stale, "TRUCK_POSITION_STALE");
    }

    [Fact]
    public async Task RoutingFailureLeavesAssignmentWithoutPlanOrSession()
    {
        await using var failing = new ApiFactory(useFailingRoutingProvider: true);
        await failing.InitializeAsync();
        var setup = await CreateAssignmentAsync(failing);
        await AddPositionAsync(failing, setup.TruckId, 39.88m, 32.80m, true,
            DateTimeOffset.UtcNow);
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            failing, setup.DriverEmail);

        var response = await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup");
        await AssertProblemAsync(response, HttpStatusCode.ServiceUnavailable,
            "ROUTE_CALCULATION_FAILED");

        using var scope = failing.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var trip = await db.Trips.IgnoreQueryFilters().SingleAsync(
            x => x.Id == setup.TripId, TestContext.Current.CancellationToken);
        Assert.Equal("Assigned", trip.Status.ToString());
        Assert.False(await db.TripRepositioningPlans.IgnoreQueryFilters()
            .AnyAsync(x => x.TripId == setup.TripId,
                TestContext.Current.CancellationToken));
        Assert.False(await db.DriverTruckSessions.IgnoreQueryFilters()
            .AnyAsync(x => x.DriverId == setup.DriverId,
                TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task DriverAtPickupDepartsWithoutInventingApproachGeometry()
    {
        var setup = await CreateAssignmentAsync(factory);
        await AddPositionAsync(factory, setup.TruckId, 39.9208m, 32.8541m, true,
            DateTimeOffset.UtcNow);
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, setup.DriverEmail);

        var departed = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup")).RequiredJsonAsync();

        Assert.Equal("EnRouteToPickup", departed.GetProperty("status").GetString());
        Assert.Equal(JsonValueKind.Null,
            departed.GetProperty("repositioningPlan").ValueKind);
    }

    private static async Task AssertBlockedAsync(
        ApiFactory target, Setup setup, string code)
    {
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            target, setup.DriverEmail);
        var workspace = await driver.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        var action = Assert.Single(workspace.GetProperty("actions").EnumerateArray());
        Assert.False(action.GetProperty("enabled").GetBoolean());
        Assert.Equal(code, action.GetProperty("blockingReason").GetString());
        await AssertProblemAsync(await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup"), HttpStatusCode.Conflict, code);
    }

    private static async Task<Setup> CreateAssignmentAsync(ApiFactory target)
    {
        using var manager = await OperationsTestClient.AuthenticatedClientAsync(
            target, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var email = $"departure-{suffix}@example.test";
        Guid userId;
        using (var scope = target.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
            var user = new User(Guid.NewGuid(), ApiFactory.CompanyAId, email,
                "Departure Driver", hasher.Hash(ApiFactory.Password), AppRoles.Driver,
                DateTimeOffset.UtcNow);
            db.Users.Add(user);
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
            userId = user.Id;
        }
        var clientId = (await (await manager.PostJsonAsync("/api/clients",
            new { name = $"Departure {suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var truckId = (await (await manager.PostJsonAsync("/api/trucks",
            new { plateNumber = $"DEP-{suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var driverId = (await (await manager.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Departure Driver {suffix}",
            licenseNumber = $"DEP-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        await (await manager.PutAsJsonAsync($"/api/drivers/{driverId}/user-link",
            new { userId }, TestContext.Current.CancellationToken)).RequiredJsonAsync();
        var tripId = (await RouteTestData.CreateReadyTripAsync(manager, clientId))
            .GetProperty("id").GetGuid();
        await (await manager.PostJsonAsync($"/api/trips/{tripId}/assign",
            new { truckId, driverId })).RequiredJsonAsync();
        return new(tripId, truckId, driverId, email);
    }

    private static async Task AddPositionAsync(
        ApiFactory target, Guid truckId, decimal latitude, decimal longitude,
        bool online, DateTimeOffset recordedAt)
    {
        using var scope = target.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.TruckPositions.Add(new TruckPosition(
            Guid.NewGuid(), ApiFactory.CompanyAId, truckId, latitude, longitude,
            0, 0, online, recordedAt, "Test", null, null, Guid.NewGuid(),
            MovementPhase.CurrentLocation, null));
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);
    }

    private static async Task AssertProblemAsync(
        HttpResponseMessage response, HttpStatusCode status, string code)
    {
        Assert.Equal(status, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken);
        Assert.Equal(code, problem.GetProperty("errorCode").GetString());
    }

    private sealed record Setup(
        Guid TripId, Guid TruckId, Guid DriverId, string DriverEmail);
}
