using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class TripsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task FullLifecycleSynchronizesTruckAndDriverStatuses()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var resources = await CreateResourcesAsync(client);
        var tripId = await CreateTripAsync(client, resources.ClientId);

        var draft = await client.GetJsonAsync<JsonElement>($"/api/trips/{tripId}");
        Assert.Equal("Draft", draft.GetProperty("status").GetString());

        await AssertTransitionAsync(client, $"/api/trips/{tripId}/assign", "Assigned", new
        {
            truckId = resources.TruckId,
            driverId = resources.DriverId
        });
        await (await client.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "seed-position",
            truckId = resources.TruckId,
            latitude = 39.9208m,
            longitude = 32.8541m
        })).RequiredJsonAsync();
        await AssertTransitionAsync(client, $"/api/trips/{tripId}/dispatch-to-pickup", "AtPickup", new { });
        await AssertTransitionAsync(client, $"/api/trips/{tripId}/start", "Started");
        Assert.Equal("OnTrip", (await client.GetJsonAsync<JsonElement>($"/api/trucks/{resources.TruckId}"))
            .GetProperty("status").GetString());
        Assert.Equal("OnTrip", (await client.GetJsonAsync<JsonElement>($"/api/drivers/{resources.DriverId}"))
            .GetProperty("status").GetString());

        await AssertTransitionAsync(client, $"/api/trips/{tripId}/mark-in-transit", "InTransit");
        await AssertTransitionAsync(client, $"/api/trips/{tripId}/deliver", "Delivered");
        await AssertTransitionAsync(client, $"/api/trips/{tripId}/complete", "Completed");

        Assert.Equal("Available", (await client.GetJsonAsync<JsonElement>($"/api/trucks/{resources.TruckId}"))
            .GetProperty("status").GetString());
        Assert.Equal("Available", (await client.GetJsonAsync<JsonElement>($"/api/drivers/{resources.DriverId}"))
            .GetProperty("status").GetString());
    }

    [Fact]
    public async Task InvalidTransitionAndDoubleAssignmentsAreRejectedAndCancellationReleasesReservation()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var first = await CreateResourcesAsync(client);
        var second = await CreateResourcesAsync(client, first.ClientId);
        var tripOne = await CreateTripAsync(client, first.ClientId);
        var tripTwo = await CreateTripAsync(client, first.ClientId);
        var tripThree = await CreateTripAsync(client, first.ClientId);

        var invalid = await client.PostEmptyAsync($"/api/trips/{tripOne}/complete");
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        await AssertTransitionAsync(client, $"/api/trips/{tripOne}/assign", "Assigned", new
        {
            truckId = first.TruckId,
            driverId = first.DriverId
        });

        var truckConflict = await client.PostJsonAsync($"/api/trips/{tripTwo}/assign", new
        {
            truckId = first.TruckId,
            driverId = second.DriverId
        });
        Assert.Equal(HttpStatusCode.Conflict, truckConflict.StatusCode);

        var driverConflict = await client.PostJsonAsync($"/api/trips/{tripThree}/assign", new
        {
            truckId = second.TruckId,
            driverId = first.DriverId
        });
        Assert.Equal(HttpStatusCode.Conflict, driverConflict.StatusCode);

        await AssertTransitionAsync(client, $"/api/trips/{tripOne}/cancel", "Cancelled");
        await AssertTransitionAsync(client, $"/api/trips/{tripTwo}/assign", "Assigned", new
        {
            truckId = first.TruckId,
            driverId = first.DriverId
        });
    }

    [Fact]
    public async Task CrossTenantAssignmentsAndTripIdTamperingAreRejected()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var resourcesA = await CreateResourcesAsync(companyA);
        var resourcesB = await CreateResourcesAsync(companyB);
        var tripId = await CreateTripAsync(companyA, resourcesA.ClientId);

        var foreignClient = await companyA.PostJsonAsync("/api/trips", RouteTestData.TripPayload(resourcesB.ClientId));
        Assert.Equal(HttpStatusCode.NotFound, foreignClient.StatusCode);

        var foreignTruck = await companyA.PostJsonAsync($"/api/trips/{tripId}/assign", new
        {
            truckId = resourcesB.TruckId,
            driverId = resourcesA.DriverId
        });
        Assert.Equal(HttpStatusCode.NotFound, foreignTruck.StatusCode);

        var foreignDriver = await companyA.PostJsonAsync($"/api/trips/{tripId}/assign", new
        {
            truckId = resourcesA.TruckId,
            driverId = resourcesB.DriverId
        });
        Assert.Equal(HttpStatusCode.NotFound, foreignDriver.StatusCode);

        var tampered = await companyB.GetResponseAsync($"/api/trips/{tripId}");
        Assert.Equal(HttpStatusCode.NotFound, tampered.StatusCode);
    }

    private static async Task<(Guid ClientId, Guid TruckId, Guid DriverId)> CreateResourcesAsync(
        HttpClient client,
        Guid? existingClientId = null)
    {
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var clientId = existingClientId ?? (await (await client.PostJsonAsync("/api/clients", new
        {
            name = $"Client {suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"TRK-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Driver {suffix}",
            licenseNumber = $"LIC-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        return (clientId, truckId, driverId);
    }

    private static async Task<Guid> CreateTripAsync(HttpClient client, Guid clientId)
    {
        var response = await client.PostJsonAsync("/api/trips", RouteTestData.TripPayload(clientId));
        Assert.True(response.StatusCode == HttpStatusCode.Created,
            await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
        return (await response.RequiredJsonAsync()).GetProperty("id").GetGuid();
    }

    private static async Task AssertTransitionAsync(HttpClient client, string path, string expectedStatus, object? body = null)
    {
        var response = body is null ? await client.PostEmptyAsync(path) : await client.PostJsonAsync(path, body);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var result = await response.RequiredJsonAsync();
        Assert.Equal(expectedStatus, result.GetProperty("status").GetString());
    }
}
