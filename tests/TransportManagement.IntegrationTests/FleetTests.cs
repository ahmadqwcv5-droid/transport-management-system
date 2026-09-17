using System.Net;
using System.Net.Http.Json;

namespace TransportManagement.IntegrationTests;

public sealed class FleetTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task TruckPlateUniquenessIsTenantScopedAndTruckIsIsolated()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var plate = $"A-{Guid.NewGuid():N}"[..12];

        var first = await companyA.PostJsonAsync("/api/trucks", new { plateNumber = plate, make = "Volvo", year = 2024 });
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        var truckId = (await first.RequiredJsonAsync()).GetProperty("id").GetGuid();

        var duplicate = await companyA.PostJsonAsync("/api/trucks", new { plateNumber = plate });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);

        var otherTenant = await companyB.PostJsonAsync("/api/trucks", new { plateNumber = plate });
        Assert.Equal(HttpStatusCode.Created, otherTenant.StatusCode);

        var tampered = await companyB.GetResponseAsync($"/api/trucks/{truckId}");
        Assert.Equal(HttpStatusCode.NotFound, tampered.StatusCode);
    }

    [Fact]
    public async Task DriverLicenseUniquenessIsTenantScopedAndDriverIsIsolated()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var license = $"LIC-{Guid.NewGuid():N}"[..16];

        var first = await companyA.PostJsonAsync("/api/drivers", new { fullName = "Driver A", licenseNumber = license });
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        var driverId = (await first.RequiredJsonAsync()).GetProperty("id").GetGuid();

        var duplicate = await companyA.PostJsonAsync("/api/drivers", new { fullName = "Duplicate", licenseNumber = license });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);

        var otherTenant = await companyB.PostJsonAsync("/api/drivers", new { fullName = "Driver B", licenseNumber = license });
        Assert.Equal(HttpStatusCode.Created, otherTenant.StatusCode);

        var tampered = await companyB.GetResponseAsync($"/api/drivers/{driverId}");
        Assert.Equal(HttpStatusCode.NotFound, tampered.StatusCode);
    }
}
