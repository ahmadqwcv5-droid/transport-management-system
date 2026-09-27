using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint421ReliabilityTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task ActiveOperationsQueryIsTenantScopedSearchableAndStable()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];

        var aSecond = await CreateAssignedAsync(companyA, suffix, "Z");
        var aFirst = await CreateAssignedAsync(companyA, suffix, "A");
        var bOnly = await CreateAssignedAsync(companyB, suffix, "B");

        var aPage = await companyA.GetJsonAsync<JsonElement>(
            $"/api/dashboard/active-trips?search={suffix}&phase=awaitingdeparture&limit=10");
        Assert.Equal(2, aPage.GetProperty("totalCount").GetInt32());
        var aNumbers = aPage.GetProperty("items").EnumerateArray()
            .Select(x => x.GetProperty("tripNumber").GetString()!)
            .ToArray();
        Assert.Equal(new[] { aFirst, aSecond }.OrderBy(x => x), aNumbers);
        Assert.All(aPage.GetProperty("items").EnumerateArray(), item =>
            Assert.DoesNotContain("Scoped-" + suffix + "-B",
                item.GetProperty("clientName").GetString()));

        var bPage = await companyB.GetJsonAsync<JsonElement>(
            $"/api/dashboard/active-trips?search={suffix}&phase=awaitingdeparture&limit=10");
        Assert.Equal(1, bPage.GetProperty("totalCount").GetInt32());
        Assert.Equal(bOnly, bPage.GetProperty("items")[0]
            .GetProperty("tripNumber").GetString());
        Assert.Equal("Scoped-" + suffix + "-B", bPage.GetProperty("items")[0]
            .GetProperty("clientName").GetString());
    }

    private static async Task<string> CreateAssignedAsync(
        HttpClient client, string suffix, string marker)
    {
        var clientId = (await (await client.PostJsonAsync("/api/clients",
            new { name = $"Scoped-{suffix}-{marker}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var truckId = (await (await client.PostJsonAsync("/api/trucks",
            new { plateNumber = $"Q-{suffix}-{marker}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Query Driver {suffix} {marker}",
            licenseNumber = $"Q-{suffix}-{marker}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var trip = await RouteTestData.CreateReadyTripAsync(client, clientId,
            39.9208m, 32.8541m, 39.9215m, 32.8550m);
        await (await client.PostJsonAsync(
            $"/api/trips/{trip.GetProperty("id").GetGuid()}/assign",
            new { truckId, driverId })).RequiredJsonAsync();
        return trip.GetProperty("tripNumber").GetString()!;
    }
}
