using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Tracking;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint422MapReliabilityTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task OperationalAreaIsOwnerOnlyValidatedAndTenantIsolated()
    {
        using var ownerA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var ownerB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var driverEmail = $"map-driver-{Guid.NewGuid():N}@example.test";
        await AddUserAsync(driverEmail, AppRoles.Driver);
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(factory, driverEmail);

        var forbidden = await driver.PutAsJsonAsync(
            "/api/companies/me/map-preference",
            ValidArea("TR", "Türkiye"),
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);

        var invalid = await ownerA.PutAsJsonAsync(
            "/api/companies/me/map-preference",
            new
            {
                countryCode = "TUR",
                label = "Broken",
                south = 50,
                west = 30,
                north = 40,
                east = 20
            },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        var problem = await invalid.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken);
        Assert.StartsWith("INVALID_MAP_", problem.GetProperty("errorCode").GetString());

        var saved = await (await ownerA.PutAsJsonAsync(
            "/api/companies/me/map-preference",
            ValidArea("TR", "Türkiye"),
            TestContext.Current.CancellationToken)).RequiredJsonAsync();
        Assert.Equal("TR", saved.GetProperty("countryCode").GetString());
        Assert.Equal(35m, saved.GetProperty("south").GetDecimal());

        var otherTenant = await ownerB.GetAsync(
            "/api/companies/me/map-preference",
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.NoContent, otherTenant.StatusCode);
        var dashboard = await ownerA.GetJsonAsync<JsonElement>("/api/dashboard");
        Assert.Equal("Türkiye",
            dashboard.GetProperty("operationalArea").GetProperty("label").GetString());

        Assert.Equal(HttpStatusCode.NoContent, (await ownerA.DeleteAsync(
            "/api/companies/me/map-preference",
            TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await ownerA.GetAsync(
            "/api/companies/me/map-preference",
            TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task CurrentProjectionIsMonotonicIdempotentAndTenantSafe()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var truckId = (await (await owner.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"CHRON-{Guid.NewGuid():N}"[..20]
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var run = Guid.NewGuid();
        var recordedAt = DateTimeOffset.UtcNow;
        var newest = Position(ApiFactory.CompanyAId, truckId, run, recordedAt, 41, 29);
        var older = Position(ApiFactory.CompanyAId, truckId, run,
            recordedAt.AddMinutes(-1), 40, 28);
        var duplicate = Position(ApiFactory.CompanyAId, truckId, run, recordedAt, 41, 29);
        var equalConflict = Position(ApiFactory.CompanyAId, truckId, run, recordedAt, 42, 30);
        var nextRun = Position(ApiFactory.CompanyAId, truckId, Guid.NewGuid(),
            recordedAt.AddSeconds(1), 43, 31);

        using var scope = factory.Services.CreateScope();
        var companyContext = scope.ServiceProvider.GetRequiredService<ICompanyExecutionContext>();
        using var company = companyContext.Enter(ApiFactory.CompanyAId);
        var store = scope.ServiceProvider.GetRequiredService<ITrackingStore>();
        Assert.Equal(PositionIngestionOutcome.AcceptedCurrent,
            await store.IngestAsync(newest, recordedAt, TestContext.Current.CancellationToken));
        Assert.Equal(PositionIngestionOutcome.StoredOlderHistory,
            await store.IngestAsync(older, recordedAt, TestContext.Current.CancellationToken));
        Assert.Equal(PositionIngestionOutcome.DuplicateIgnored,
            await store.IngestAsync(duplicate, recordedAt, TestContext.Current.CancellationToken));
        Assert.Equal(PositionIngestionOutcome.StoredEqualConflict,
            await store.IngestAsync(equalConflict, recordedAt, TestContext.Current.CancellationToken));

        var current = await store.LatestPositionAsync(
            truckId, TestContext.Current.CancellationToken);
        Assert.Equal(newest.Id, current!.Id);
        var history = await store.HistoryAsync(
            truckId, 20, TestContext.Current.CancellationToken);
        Assert.Equal(3, history.Count);

        Assert.Equal(PositionIngestionOutcome.AcceptedCurrent,
            await store.IngestAsync(nextRun, recordedAt.AddSeconds(1),
                TestContext.Current.CancellationToken));
        current = await store.LatestPositionAsync(truckId, TestContext.Current.CancellationToken);
        Assert.Equal(nextRun.Id, current!.Id);
        Assert.Equal(nextRun.TrackingRunId, current.TrackingRunId);

        var foreign = Position(ApiFactory.CompanyBId, truckId, Guid.NewGuid(),
            recordedAt.AddSeconds(2), 44, 32);
        await Assert.ThrowsAsync<InvalidOperationException>(() => store.IngestAsync(
            foreign, recordedAt.AddSeconds(2), TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task DriverSeesUniqueDefaultTruckWithoutTripAndAmbiguityIsExplicit()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var email = $"idle-{suffix}@example.test";
        var userId = await AddUserAsync(email, AppRoles.Driver);
        var driverId = (await (await owner.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Idle Driver {suffix}",
            licenseNumber = $"IDLE-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.OK, (await owner.PutAsJsonAsync(
            $"/api/drivers/{driverId}/user-link", new { userId },
            TestContext.Current.CancellationToken)).StatusCode);
        var firstTruckId = (await (await owner.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"IDLE-A-{suffix}",
            fleetCode = $"IA-{suffix}",
            defaultDriverId = driverId
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        await (await owner.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "set-position",
            truckId = firstTruckId,
            latitude = 39.92m,
            longitude = 32.85m
        })).RequiredJsonAsync();

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(factory, email);
        var idle = await driver.GetJsonAsync<JsonElement>("/api/driver/my-trip/workspace");
        Assert.Equal("VEHICLE_ASSIGNED_IDLE", idle.GetProperty("state").GetString());
        Assert.Equal(firstTruckId, idle.GetProperty("truck").GetProperty("id").GetGuid());
        Assert.Equal(JsonValueKind.Null, idle.GetProperty("currentTrip").ValueKind);
        Assert.Equal(39.92m,
            idle.GetProperty("currentPosition").GetProperty("latitude").GetDecimal());

        await (await owner.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"IDLE-B-{suffix}",
            fleetCode = $"IB-{suffix}",
            defaultDriverId = driverId
        })).RequiredJsonAsync();
        var ambiguous = await driver.GetJsonAsync<JsonElement>("/api/driver/my-trip/workspace");
        Assert.Equal("VEHICLE_ASSIGNMENT_AMBIGUOUS",
            ambiguous.GetProperty("state").GetString());
        Assert.Equal(JsonValueKind.Null, ambiguous.GetProperty("truck").ValueKind);
    }

    private static object ValidArea(string countryCode, string label) => new
    {
        countryCode,
        label,
        south = 35,
        west = 25,
        north = 43,
        east = 45,
        centerLatitude = 39,
        centerLongitude = 35,
        preferredZoom = 5
    };

    private static TruckPosition Position(Guid companyId, Guid truckId,
        Guid runId, DateTimeOffset recordedAt, decimal latitude, decimal longitude) =>
        new(Guid.NewGuid(), companyId, truckId, latitude, longitude, 40, 5, true,
            recordedAt, "Sprint422Test", null, null, runId,
            MovementPhase.CurrentLocation);

    private async Task<Guid> AddUserAsync(string email, string role)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        var user = new User(Guid.NewGuid(), ApiFactory.CompanyAId, email,
            "Sprint 4.2.2 User", hasher.Hash(ApiFactory.Password), role,
            DateTimeOffset.UtcNow);
        db.Users.Add(user);
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        return user.Id;
    }
}
