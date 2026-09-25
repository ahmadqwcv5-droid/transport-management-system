using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Infrastructure.Persistence;

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

    [Fact]
    public async Task PasswordChangeValidatesRevokesRefreshAndRequiresFreshLogin()
    {
        var email = $"password-{Guid.NewGuid():N}@example.test";
        const string oldPassword = "OldPassword!123";
        const string newPassword = "NewPassword!456";
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
            db.Users.Add(new User(Guid.NewGuid(), ApiFactory.CompanyAId, email,
                "Password Test", hasher.Hash(oldPassword), AppRoles.Driver,
                DateTimeOffset.UtcNow));
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }
        using var client = factory.CreateClient();
        var login = await (await client.PostJsonAsync("/api/auth/login",
            new { email, password = oldPassword })).RequiredJsonAsync();
        var refreshToken = login.GetProperty("refreshToken").GetString();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", login.GetProperty("accessToken").GetString());

        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutJsonAsync(
            "/api/auth/me/password", new { currentPassword = "wrong-password",
                newPassword, confirmPassword = newPassword })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await client.PutJsonAsync(
            "/api/auth/me/password", new { currentPassword = oldPassword,
                newPassword, confirmPassword = newPassword })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostJsonAsync(
            "/api/auth/refresh", new { refreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostJsonAsync(
            "/api/auth/login", new { email, password = oldPassword })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PostJsonAsync(
            "/api/auth/login", new { email, password = newPassword })).StatusCode);

        using var verification = factory.Services.CreateScope();
        var db2 = verification.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.True(await db2.CompanyUserEvents.IgnoreQueryFilters().AnyAsync(
            x => x.EventCode == "PasswordChanged" && x.CompanyId == ApiFactory.CompanyAId,
            TestContext.Current.CancellationToken));
    }
}
