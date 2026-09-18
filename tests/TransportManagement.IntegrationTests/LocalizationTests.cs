using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class LocalizationTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task PreferredLocalePersistsAndInvalidLocaleIsRejected()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var updated = await (await client.PutJsonAsync("/api/auth/me/preferences", new { preferredLocale = "ar" })).RequiredJsonAsync();
        Assert.Equal("ar", updated.GetProperty("preferredLocale").GetString());
        var current = await client.GetJsonAsync<JsonElement>("/api/auth/me");
        Assert.Equal("ar", current.GetProperty("preferredLocale").GetString());

        var invalid = await client.PutJsonAsync("/api/auth/me/preferences", new { preferredLocale = "fr" });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
    }

    [Fact]
    public async Task DomainProblemContainsStableErrorCode()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var response = await client.PostJsonAsync(
            "/api/trips", RouteTestData.TripPayload(Guid.NewGuid()));
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        Assert.Equal("CLIENT_NOT_FOUND", problem.GetProperty("errorCode").GetString());
    }
}
