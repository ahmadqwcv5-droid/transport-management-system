using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Infrastructure.Persistence;
using TransportManagement.Application.Tracking;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint41LiveFleetWorkflowTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task GeofencesDriverConfirmationsAndNotificationsCompleteTripExactlyOnce()
    {
        using var manager = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        Assert.Equal(TimeSpan.Zero,
            factory.Services.GetRequiredService<GeofencePolicy>().MinimumDwell);
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var driverUserId = await AddDriverUserAsync($"driver-{suffix}@example.test");
        var clientId = (await (await manager.PostJsonAsync("/api/clients",
            new { name = $"Live {suffix}" })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var truckId = (await (await manager.PostJsonAsync("/api/trucks",
            new { plateNumber = $"LIVE-{suffix}" })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await manager.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Live Driver {suffix}", licenseNumber = $"LIVE-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var linked = await manager.PutAsJsonAsync($"/api/drivers/{driverId}/user-link",
            new { userId = driverUserId }, TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.OK, linked.StatusCode);

        var trip = await RouteTestData.CreateReadyTripAsync(manager, clientId,
            39.9208m, 32.8541m, 39.9215m, 32.8550m);
        var tripId = trip.GetProperty("id").GetGuid();
        await (await manager.PostJsonAsync($"/api/trips/{tripId}/assign",
            new { truckId, driverId })).RequiredJsonAsync();
        await (await manager.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "seed-position", truckId, latitude = 39.9208m, longitude = 32.8541m
        })).RequiredJsonAsync();
        using var driver = await OperationsTestClient.AuthenticatedClientAsync(factory,
            $"driver-{suffix}@example.test");
        var dispatch = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/depart-to-pickup")).RequiredJsonAsync();
        Assert.Equal("EnRouteToPickup", dispatch.GetProperty("status").GetString());

        await manager.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        Assert.Equal("EnRouteToPickup", (await manager.GetJsonAsync<JsonElement>(
            $"/api/trips/{tripId}")).GetProperty("status").GetString());
        await ResetAndPollAsync(manager);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var observation = await db.TripGeofenceObservations.IgnoreQueryFilters()
                .SingleAsync(x => x.TripId == tripId, TestContext.Current.CancellationToken);
            Assert.True(observation.ConsecutiveSamples >= 2,
                $"Observed {observation.ConsecutiveSamples} samples; last={observation.LastSampleAt:o}");
            Assert.NotNull(observation.ConfirmedAt);
        }
        Assert.Equal("AtPickup", (await manager.GetJsonAsync<JsonElement>(
            $"/api/trips/{tripId}")).GetProperty("status").GetString());
        Assert.Equal(1, await NotificationCountAsync(manager, tripId, "TruckArrivedAtPickup"));

        Assert.Equal(HttpStatusCode.Forbidden,
            (await driver.GetAsync("/api/trips", TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await driver.GetAsync("/api/tracking/positions", TestContext.Current.CancellationToken)).StatusCode);
        var mine = await driver.GetJsonAsync<JsonElement>("/api/driver/my-trip");
        Assert.Equal(tripId, mine.GetProperty("trip").GetProperty("id").GetGuid());
        var workspace = await driver.GetJsonAsync<JsonElement>("/api/driver/my-trip/workspace");
        Assert.Equal("ACTIVE_TRIP_READY", workspace.GetProperty("state").GetString());
        Assert.Equal(tripId, workspace.GetProperty("currentTrip").GetProperty("id").GetGuid());
        Assert.Equal(truckId, workspace.GetProperty("truck").GetProperty("id").GetGuid());
        Assert.Equal("Pickup", workspace.GetProperty("nextStop").GetProperty("type").GetString());
        var inTransit = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/confirm-loaded")).RequiredJsonAsync();
        Assert.Equal("InTransit", inTransit.GetProperty("status").GetString());

        await (await manager.PostJsonAsync("/api/tracking/simulator/control",
            new { action = "step" })).RequiredJsonAsync();
        await manager.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await ResetAndPollAsync(manager);
        Assert.Equal("AtDelivery", (await manager.GetJsonAsync<JsonElement>(
            $"/api/trips/{tripId}")).GetProperty("status").GetString());
        Assert.Equal(1, await NotificationCountAsync(manager, tripId, "TruckArrivedAtDelivery"));

        var completed = await (await driver.PostEmptyAsync(
            "/api/driver/my-trip/confirm-delivery")).RequiredJsonAsync();
        Assert.Equal("Completed", completed.GetProperty("status").GetString());
        Assert.Equal("Available", (await manager.GetJsonAsync<JsonElement>(
            $"/api/drivers/{driverId}")).GetProperty("status").GetString());
        Assert.Equal("Available", (await manager.GetJsonAsync<JsonElement>(
            $"/api/trucks/{truckId}")).GetProperty("status").GetString());
        Assert.Equal(1, await NotificationCountAsync(manager, tripId, "DriverConfirmedDeparture"));
        Assert.Equal(1, await NotificationCountAsync(manager, tripId, "DriverConfirmedDelivery"));

        var postTrip = await driver.GetJsonAsync<JsonElement>("/api/driver/my-trip/workspace");
        Assert.Equal("POST_TRIP_VEHICLE", postTrip.GetProperty("state").GetString());
        Assert.Equal(truckId, postTrip.GetProperty("truck").GetProperty("id").GetGuid());
        Assert.Equal(tripId, postTrip.GetProperty("vehicleSession").GetProperty("lastTripId").GetGuid());
        Assert.Equal(HttpStatusCode.NoContent, (await driver.PostEmptyAsync(
            "/api/driver/my-trip/end-vehicle-session")).StatusCode);
        Assert.Equal("NO_ACTIVE_TRIP", (await driver.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace")).GetProperty("state").GetString());

        await ResetAndPollAsync(manager);
        Assert.Equal(1, await NotificationCountAsync(manager, tripId, "TruckArrivedAtDelivery"));
    }

    [Fact]
    public async Task TruckPhotoUploadValidatesContentAndIsTenantScoped()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var truckId = (await (await companyA.PostJsonAsync("/api/trucks",
            new { plateNumber = $"PHOTO-{Guid.NewGuid():N}"[..20] })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();

        using var invalid = new MultipartFormDataContent();
        invalid.Add(new ByteArrayContent(Encoding.UTF8.GetBytes("not an image")),
            "file", "fake.png");
        var rejected = await companyA.PostAsync($"/api/trucks/{truckId}/photo", invalid,
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.BadRequest, rejected.StatusCode);

        using var valid = new MultipartFormDataContent();
        var bytes = Convert.FromBase64String(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");
        var content = new ByteArrayContent(bytes);
        content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        valid.Add(content, "file", "truck.png");
        var uploaded = await (await companyA.PostAsync($"/api/trucks/{truckId}/photo",
            valid, TestContext.Current.CancellationToken)).RequiredJsonAsync();
        var version = uploaded.GetProperty("version").GetString();
        Assert.False(string.IsNullOrWhiteSpace(version));

        var thumbnail = await companyA.GetAsync($"/api/trucks/{truckId}/photo/thumbnail",
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.OK, thumbnail.StatusCode);
        Assert.Equal("image/webp", thumbnail.Content.Headers.ContentType?.MediaType);
        Assert.Equal($"\"{version}\"", thumbnail.Headers.ETag?.Tag);
        Assert.Equal(HttpStatusCode.NotFound, (await companyB.GetAsync(
            $"/api/trucks/{truckId}/photo/thumbnail",
            TestContext.Current.CancellationToken)).StatusCode);

        var removed = await companyA.DeleteAsync($"/api/trucks/{truckId}/photo",
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await companyA.GetAsync(
            $"/api/trucks/{truckId}/photo/thumbnail",
            TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task ManagerOverridesRequireReasonsAndPreserveAuditSource()
    {
        using var manager = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var clientId = (await (await manager.PostJsonAsync("/api/clients",
            new { name = $"Override {suffix}" })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var truckId = (await (await manager.PostJsonAsync("/api/trucks",
            new { plateNumber = $"OVR-{suffix}" })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await manager.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Override Driver {suffix}", licenseNumber = $"OVR-L-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var trip = await RouteTestData.CreateReadyTripAsync(manager, clientId,
            39.9208m, 32.8541m, 39.9215m, 32.8550m);
        var tripId = trip.GetProperty("id").GetGuid();
        await (await manager.PostJsonAsync($"/api/trips/{tripId}/assign",
            new { truckId, driverId })).RequiredJsonAsync();
        await (await manager.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "seed-position", truckId, latitude = 39.9208m, longitude = 32.8541m
        })).RequiredJsonAsync();
        await (await manager.PostJsonAsync($"/api/trips/{tripId}/dispatch-to-pickup",
            new { reason = "Test manager override" })).RequiredJsonAsync();
        await manager.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await ResetAndPollAsync(manager);

        var missingReason = await manager.PostJsonAsync(
            $"/api/trips/{tripId}/override/confirm-loaded", new { reason = "" });
        Assert.Equal(HttpStatusCode.BadRequest, missingReason.StatusCode);
        var inTransit = await (await manager.PostJsonAsync(
            $"/api/trips/{tripId}/override/confirm-loaded",
            new { reason = "Driver device unavailable at pickup." })).RequiredJsonAsync();
        Assert.Equal("InTransit", inTransit.GetProperty("status").GetString());

        await (await manager.PostJsonAsync("/api/tracking/simulator/control",
            new { action = "step" })).RequiredJsonAsync();
        await manager.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await ResetAndPollAsync(manager);
        var completed = await (await manager.PostJsonAsync(
            $"/api/trips/{tripId}/override/confirm-delivery",
            new { reason = "Signed paperwork verified by operations." })).RequiredJsonAsync();
        Assert.Equal("Completed", completed.GetProperty("status").GetString());

        var timeline = await manager.GetJsonAsync<JsonElement>(
            $"/api/trips/{tripId}/timeline?pageSize=100");
        var overrideEvents = timeline.GetProperty("items").EnumerateArray()
            .Where(item => item.GetProperty("source").GetString() == "ManagerOverride")
            .ToArray();
        Assert.Equal(3, overrideEvents.Length);
        Assert.All(overrideEvents, item => Assert.NotNull(item.GetProperty("actorUserId").GetString()));
    }

    private async Task<Guid> AddDriverUserAsync(string email)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        var user = new User(Guid.NewGuid(), ApiFactory.CompanyAId, email,
            "Test Driver", hasher.Hash(ApiFactory.Password), AppRoles.Driver,
            DateTimeOffset.UtcNow);
        db.Users.Add(user);
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        return user.Id;
    }

    private static async Task ResetAndPollAsync(HttpClient client)
    {
        await (await client.PostJsonAsync("/api/tracking/simulator/control",
            new { action = "reset" })).RequiredJsonAsync();
        await Task.Delay(25, TestContext.Current.CancellationToken);
        await (await client.PostJsonAsync("/api/tracking/simulator/control",
            new { action = "reset" })).RequiredJsonAsync();
    }

    private static async Task<int> NotificationCountAsync(
        HttpClient client, Guid tripId, string type)
    {
        var page = await client.GetJsonAsync<JsonElement>("/api/notifications?pageSize=100");
        return page.GetProperty("items").EnumerateArray()
            .Count(x => x.GetProperty("tripId").GetGuid() == tripId
                && x.GetProperty("type").GetString() == type);
    }
}
