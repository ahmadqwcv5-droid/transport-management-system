using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class AuthTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task LoginRefreshMeAndLogoutFlowSucceeds()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        using var client = factory.CreateClient();
        var login = await client.PostAsJsonAsync("/api/auth/login", new
        {
            email = "owner-a@example.test",
            password = ApiFactory.Password
        }, cancellationToken);
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var loginBody = await login.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        var accessToken = loginBody.GetProperty("accessToken").GetString();
        var refreshToken = loginBody.GetProperty("refreshToken").GetString();
        Assert.False(string.IsNullOrWhiteSpace(accessToken));
        Assert.False(string.IsNullOrWhiteSpace(refreshToken));

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        var me = await client.GetAsync("/api/auth/me", cancellationToken);
        Assert.Equal(HttpStatusCode.OK, me.StatusCode);

        var refresh = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken }, cancellationToken);
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
        var refreshBody = await refresh.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        var rotatedRefreshToken = refreshBody.GetProperty("refreshToken").GetString();
        Assert.NotEqual(refreshToken, rotatedRefreshToken);

        var reuse = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken }, cancellationToken);
        Assert.Equal(HttpStatusCode.Unauthorized, reuse.StatusCode);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", refreshBody.GetProperty("accessToken").GetString());
        var logout = await client.PostAsJsonAsync(
            "/api/auth/logout", new { refreshToken = rotatedRefreshToken }, cancellationToken);
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
    }

    [Fact]
    public async Task InvalidPasswordReturnsProblemDetailsWithoutToken()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/login", new
        {
            email = "owner-a@example.test",
            password = "wrong-password"
        }, cancellationToken);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }
}
