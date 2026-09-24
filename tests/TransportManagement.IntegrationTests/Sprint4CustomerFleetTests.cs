using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint4CustomerFleetTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task ClientProfileContactsSitesLifecycleAndTenantDetailsAreOperational()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var created = await (await companyA.PostJsonAsync("/api/clients", new
        {
            name = $"Atlas {Guid.NewGuid():N}", legalName = "Atlas Logistics LLC",
            phone = "+90 555 000 0000", email = "ops@atlas.test", address = "Istanbul"
        })).RequiredJsonAsync();
        var id = created.GetProperty("id").GetGuid();
        Assert.Equal("Active", created.GetProperty("lifecycleStatus").GetString());

        var first = await (await companyA.PostJsonAsync($"/api/clients/{id}/contacts", new
        {
            name = "Primary One", isPrimary = true, email = "one@atlas.test"
        })).RequiredJsonAsync();
        var second = await (await companyA.PostJsonAsync($"/api/clients/{id}/contacts", new
        {
            name = "Primary Two", isPrimary = true, phone = "+90 555 100 0000"
        })).RequiredJsonAsync();
        Assert.NotEqual(first.GetProperty("id").GetGuid(), second.GetProperty("id").GetGuid());

        var site = await (await companyA.PostJsonAsync($"/api/clients/{id}/sites", new
        {
            name = "Main Warehouse", type = "Warehouse", address = "Kadikoy",
            latitude = 40.991m, longitude = 29.027m
        })).RequiredJsonAsync();
        Assert.True(site.GetProperty("isActive").GetBoolean());

        var details = await companyA.GetJsonAsync<JsonElement>($"/api/clients/{id}/details");
        Assert.Equal(2, details.GetProperty("contacts").GetArrayLength());
        Assert.Single(details.GetProperty("contacts").EnumerateArray(),
            x => x.GetProperty("isPrimary").GetBoolean());
        Assert.Equal(1, details.GetProperty("client").GetProperty("activeSiteCount").GetInt32());
        Assert.Contains(details.GetProperty("events").EnumerateArray(),
            x => x.GetProperty("eventCode").GetString() == "ClientSiteAdded");

        var foreign = await companyB.GetResponseAsync($"/api/clients/{id}/details");
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);

        var suspended = await companyA.PutJsonAsync($"/api/clients/{id}/lifecycle", new { status = "Suspended" });
        Assert.Equal(HttpStatusCode.OK, suspended.StatusCode);
        var trip = await companyA.PostJsonAsync("/api/trips", new
        {
            clientId = id, cargoDescription = "Blocked while suspended",
            plannedStartAt = DateTimeOffset.UtcNow.AddDays(1), price = 10
        });
        Assert.Equal(HttpStatusCode.Conflict, trip.StatusCode);

        var restored = await (await companyA.PutJsonAsync($"/api/clients/{id}/lifecycle",
            new { status = "Active" })).RequiredJsonAsync();
        Assert.Equal("Active", restored.GetProperty("lifecycleStatus").GetString());
    }

    [Fact]
    public async Task ClientSiteValidationAndArchiveKeepSnapshotDataIndependent()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = (await (await client.PostJsonAsync("/api/clients", new
        { name = $"Sites {Guid.NewGuid():N}" })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var invalid = await client.PostJsonAsync($"/api/clients/{clientId}/sites", new
        { name = "Invalid", type = "Other", latitude = 91, longitude = 20 });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        var site = await (await client.PostJsonAsync($"/api/clients/{clientId}/sites", new
        { name = "Pickup", type = "Pickup", address = "Original", latitude = 41.01, longitude = 29.01 }))
            .RequiredJsonAsync();
        var siteId = site.GetProperty("id").GetGuid();
        var trip = await (await client.PostJsonAsync("/api/trips", new
        {
            clientId, cargoDescription = "Snapshot", plannedStartAt = DateTimeOffset.UtcNow.AddDays(1), price = 1,
            stops = new[]
            {
                new { sequence = 0, type = "Pickup", name = "Pickup", address = "Original", latitude = 41.01, longitude = 29.01 },
                new { sequence = 1, type = "Delivery", name = "Delivery", address = "Target", latitude = 41.02, longitude = 29.02 }
            }
        })).RequiredJsonAsync();
        await (await client.PutJsonAsync($"/api/clients/{clientId}/sites/{siteId}", new
        { name = "Pickup changed", type = "Pickup", address = "Changed", latitude = 40.5, longitude = 28.5 }))
            .RequiredJsonAsync();
        var loaded = await client.GetJsonAsync<JsonElement>($"/api/trips/{trip.GetProperty("id").GetGuid()}");
        Assert.Equal("Original", loaded.GetProperty("stops")[0].GetProperty("address").GetString());

        var archived = await (await client.PostAsync($"/api/clients/{clientId}/sites/{siteId}/archive", null,
            TestContext.Current.CancellationToken))
            .RequiredJsonAsync();
        Assert.False(archived.GetProperty("isActive").GetBoolean());
        var activeSites = await client.GetJsonAsync<JsonElement[]>($"/api/clients/{clientId}/sites?isActive=true");
        Assert.DoesNotContain(activeSites!, x => x.GetProperty("id").GetGuid() == siteId);
    }

    [Fact]
    public async Task ExtendedTruckProfileUniquenessDefaultDriverAndOdometerRulesWork()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var driverId = (await (await companyA.PostJsonAsync("/api/drivers", new
        { fullName = "Default Driver", licenseNumber = $"S4-{suffix}" })).RequiredJsonAsync())
            .GetProperty("id").GetGuid();
        var truck = await (await companyA.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"S4-{suffix}", fleetCode = $"F-{suffix}", vin = $"VIN{suffix}",
            make = "Volvo", model = "FH", year = 2025, type = "TractorTrailer",
            payloadCapacity = 22.5, payloadUnit = "Tonnes", fuelType = "Diesel",
            odometerKilometers = 120000, defaultDriverId = driverId
        })).RequiredJsonAsync();
        var truckId = truck.GetProperty("id").GetGuid();
        Assert.Equal("Available", truck.GetProperty("baseStatus").GetString());
        Assert.Equal(driverId, truck.GetProperty("defaultDriverId").GetGuid());

        var duplicateVin = await companyA.PostJsonAsync("/api/trucks", new
        { plateNumber = $"OTHER-{suffix}", vin = $"vin{suffix}" });
        Assert.Equal(HttpStatusCode.Conflict, duplicateVin.StatusCode);
        var sameOtherTenant = await companyB.PostJsonAsync("/api/trucks", new
        { plateNumber = $"B-{suffix}", vin = $"vin{suffix}", fleetCode = $"f-{suffix}" });
        Assert.Equal(HttpStatusCode.Created, sameOtherTenant.StatusCode);

        var decreased = await companyA.PutJsonAsync($"/api/trucks/{truckId}", new
        { plateNumber = $"S4-{suffix}", odometerKilometers = 119999 });
        Assert.Equal(HttpStatusCode.Conflict, decreased.StatusCode);
        var corrected = await companyA.PutJsonAsync($"/api/trucks/{truckId}/odometer-correction",
            new { kilometers = 119999, reason = "Instrument replacement" });
        Assert.Equal(HttpStatusCode.OK, corrected.StatusCode);

        var details = await companyA.GetJsonAsync<JsonElement>($"/api/trucks/{truckId}/details");
        Assert.Equal("Default Driver", details.GetProperty("truck").GetProperty("defaultDriverName").GetString());
        Assert.Contains(details.GetProperty("events").EnumerateArray(),
            x => x.GetProperty("eventCode").GetString() == "TruckOdometerCorrected");
        Assert.Equal(HttpStatusCode.NotFound,
            (await companyB.GetResponseAsync($"/api/trucks/{truckId}/details")).StatusCode);
    }

    [Fact]
    public async Task ArchiveAndHardDeleteRulesProtectHistory()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var unused = await (await client.PostJsonAsync("/api/clients", new
        { name = $"Disposable {Guid.NewGuid():N}" })).RequiredJsonAsync();
        var unusedId = unused.GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.Conflict,
            (await client.DeleteAsync($"/api/clients/{unusedId}", TestContext.Current.CancellationToken)).StatusCode);
        await client.PutJsonAsync($"/api/clients/{unusedId}/lifecycle", new { status = "Archived" });
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.DeleteAsync($"/api/clients/{unusedId}", TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.GetResponseAsync($"/api/clients/{unusedId}")).StatusCode);
    }
}
