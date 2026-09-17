using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class TenantIsolationTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task CompanyAUserCannotReadCompanyBByModifiedId()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        using var client = factory.CreateClient();
        var login = await client.PostAsJsonAsync("/api/auth/login", new
        {
            email = "owner-a@example.test",
            password = ApiFactory.Password
        }, cancellationToken);
        var body = await login.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", body.GetProperty("accessToken").GetString());

        var ownCompany = await client.GetAsync($"/api/companies/{ApiFactory.CompanyAId}", cancellationToken);
        var foreignCompany = await client.GetAsync($"/api/companies/{ApiFactory.CompanyBId}", cancellationToken);

        Assert.Equal(HttpStatusCode.OK, ownCompany.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreignCompany.StatusCode);
    }
}
