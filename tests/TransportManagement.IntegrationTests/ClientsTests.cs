using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class ClientsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task CreateUpdateListAndTenantIsolationWork()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var name = $"Factory {Guid.NewGuid():N}";

        var create = await companyA.PostJsonAsync("/api/clients", new
        {
            name,
            contactPerson = "Alex",
            email = "alex@example.test"
        });
        Assert.Equal(HttpStatusCode.Created, create.StatusCode);
        var created = await create.RequiredJsonAsync();
        var id = created.GetProperty("id").GetGuid();

        var update = await companyA.PutJsonAsync($"/api/clients/{id}", new
        {
            name = $"{name} Updated",
            contactPerson = "Sam",
            email = "sam@example.test"
        });
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        var updated = await update.RequiredJsonAsync();
        Assert.EndsWith("Updated", updated.GetProperty("name").GetString(), StringComparison.Ordinal);

        var list = await companyA.GetJsonAsync<JsonElement[]>("/api/clients?isActive=true");
        Assert.Contains(list!, item => item.GetProperty("id").GetGuid() == id);

        var tampered = await companyB.GetResponseAsync($"/api/clients/{id}");
        Assert.Equal(HttpStatusCode.NotFound, tampered.StatusCode);

        var deactivate = await companyA.PostEmptyAsync($"/api/clients/{id}/deactivate");
        Assert.Equal(HttpStatusCode.NoContent, deactivate.StatusCode);
    }
}
