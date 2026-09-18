using System.Net;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Trips;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class RoutePlanningTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task SearchPreviewCreateAndReadUseApplicationOwnedRouteContracts()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var search = await client.GetJsonAsync<JsonElement[]>("/api/locations/search?query=Ankara");
        Assert.NotNull(search);
        Assert.Single(search);
        Assert.Equal("DeterministicTest", search[0].GetProperty("providerName").GetString());

        var clientId = await CreateClientAsync(client);
        var payload = RouteTestData.TripPayload(clientId);
        var preview = await (await client.PostJsonAsync("/api/routes/preview", new
        {
            routeProfile = "Driving",
            stops = payload.GetType().GetProperty("stops")!.GetValue(payload)
        })).RequiredJsonAsync();
        Assert.True(preview.GetProperty("coordinates").GetArrayLength() > 2);
        Assert.True(preview.GetProperty("distanceMeters").GetDecimal() > 0);

        var created = await (await client.PostJsonAsync("/api/trips", payload)).RequiredJsonAsync();
        Assert.Equal(2, created.GetProperty("stops").GetArrayLength());
        Assert.False(created.GetProperty("requiresLocationSelection").GetBoolean());
        Assert.Equal("geojson-linestring", created.GetProperty("routePlan").GetProperty("geometryFormat").GetString());
    }

    [Fact]
    public async Task RouteIsImmutableAfterAssignmentAndTenantCannotReadRouteOrTrail()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var clientId = await CreateClientAsync(companyA);
        var truckId = (await (await companyA.PostJsonAsync("/api/trucks", new { plateNumber = $"R-{Guid.NewGuid():N}"[..20] })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await companyA.PostJsonAsync("/api/drivers", new
        {
            fullName = "Route Driver",
            licenseNumber = $"RL-{Guid.NewGuid():N}"[..20]
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var trip = await (await companyA.PostJsonAsync("/api/trips", RouteTestData.TripPayload(clientId))).RequiredJsonAsync();
        var tripId = trip.GetProperty("id").GetGuid();
        await companyA.PostJsonAsync($"/api/trips/{tripId}/assign", new { truckId, driverId });

        Assert.Equal(HttpStatusCode.BadRequest,
            (await companyA.PutJsonAsync($"/api/trips/{tripId}", RouteTestData.TripPayload(clientId))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await companyB.GetResponseAsync($"/api/trips/{tripId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await companyB.GetResponseAsync($"/api/trips/{tripId}/route-progress")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await companyB.GetResponseAsync($"/api/tracking/trucks/{truckId}/history")).StatusCode);
    }

    [Fact]
    public async Task LegacyLabelOnlyTripRemainsReadableWithoutInventedCoordinates()
    {
        var now = DateTimeOffset.UtcNow;
        var clientId = Guid.NewGuid();
        var tripId = Guid.NewGuid();
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Clients.Add(new Client(clientId, ApiFactory.CompanyAId, "Legacy Client",
                null, null, null, null, null, now));
            db.Trips.Add(new Trip(tripId, ApiFactory.CompanyAId, clientId,
                "Old depot label", "Old customer label", "Legacy cargo", now.AddDays(1), 10, null, now));
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var response = await client.GetJsonAsync<JsonElement>($"/api/trips/{tripId}");
        Assert.Equal("Old depot label", response.GetProperty("origin").GetString());
        Assert.Equal("Old customer label", response.GetProperty("destination").GetString());
        Assert.True(response.GetProperty("requiresLocationSelection").GetBoolean());
        Assert.Empty(response.GetProperty("stops").EnumerateArray());
        Assert.Equal(JsonValueKind.Null, response.GetProperty("routePlan").ValueKind);
    }

    private static async Task<Guid> CreateClientAsync(HttpClient client) =>
        (await (await client.PostJsonAsync("/api/clients", new { name = $"Route Client {Guid.NewGuid():N}" })).RequiredJsonAsync())
        .GetProperty("id").GetGuid();
}
