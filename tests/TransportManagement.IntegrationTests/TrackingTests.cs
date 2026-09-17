using System.Net;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class TrackingTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task SimulatorMovesPausesResumesResetsAndTracksOfflineState()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var truck = await (await client.PostJsonAsync("/api/trucks", new { plateNumber = $"SIM-{Guid.NewGuid():N}"[..20] })).RequiredJsonAsync();
        var truckId = truck.GetProperty("id").GetGuid();

        await (await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "start" })).RequiredJsonAsync();
        var first = (await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions"))!.Single(x => x.GetProperty("truckId").GetGuid() == truckId);
        var second = (await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions"))!.Single(x => x.GetProperty("truckId").GetGuid() == truckId);
        Assert.NotEqual(first.GetProperty("longitude").GetDecimal(), second.GetProperty("longitude").GetDecimal());

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "pause" });
        var paused1 = await client.GetJsonAsync<JsonElement>( $"/api/tracking/trucks/{truckId}/position");
        var paused2 = await client.GetJsonAsync<JsonElement>( $"/api/tracking/trucks/{truckId}/position");
        Assert.Equal(paused1.GetProperty("longitude").GetDecimal(), paused2.GetProperty("longitude").GetDecimal());

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "resume" });
        var resumed = await client.GetJsonAsync<JsonElement>($"/api/tracking/trucks/{truckId}/position");
        Assert.NotEqual(paused2.GetProperty("longitude").GetDecimal(), resumed.GetProperty("longitude").GetDecimal());

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
        var truck = await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"DEDUP-{Guid.NewGuid():N}"[..20]
        })).RequiredJsonAsync();
        var truckId = truck.GetProperty("id").GetGuid();

        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "reset" });
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "start" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        await client.PostJsonAsync("/api/tracking/simulator/control", new { action = "pause" });
        await client.GetJsonAsync<JsonElement[]>("/api/tracking/positions");
        var pausedCount = await HistoryCountAsync(client, truckId);
        Assert.Equal(2, pausedCount);

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

    private static async Task<int> HistoryCountAsync(HttpClient client, Guid truckId) =>
        (await client.GetJsonAsync<JsonElement[]>($"/api/tracking/trucks/{truckId}/history?limit=200"))!.Length;
}
