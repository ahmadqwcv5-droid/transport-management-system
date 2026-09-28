using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint411DriverOnboardingTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task OwnerInvitesAndLinksDriverWhoChoosesTheirOwnPassword()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var email = $"onboarded-{suffix}@example.test";
        var driverId = await CreateDriverAsync(owner, $"ONB-{suffix}");

        var accepted = await InviteAndAcceptAsync(owner, email, driverId);
        Assert.True(accepted.GetProperty("accountCreated").GetBoolean());
        Assert.Equal(driverId, (await owner.GetJsonAsync<JsonElement[]>(
            "/api/company-users") ?? []).Single(x =>
                x.GetProperty("id").GetGuid() ==
                accepted.GetProperty("accountId").GetGuid())
            .GetProperty("driverId").GetGuid());

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, email, ApiFactory.Password);
        var workspace = await driver.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        Assert.Equal("NO_VEHICLE_ASSIGNED", workspace.GetProperty("state").GetString());

        var invitations = await owner.GetJsonAsync<JsonElement[]>(
            "/api/membership-invitations") ?? [];
        Assert.Equal("Accepted", invitations.Single(x =>
            x.GetProperty("email").GetString() == email)
            .GetProperty("status").GetString());
    }

    [Fact]
    public async Task AcceptedCompanyMembershipIsOwnerOnlyAndTenantScoped()
    {
        using var ownerA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var ownerB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var email = $"isolated-{suffix}@example.test";
        var accepted = await InviteAndAcceptAsync(ownerA, email);
        var userId = accepted.GetProperty("accountId").GetGuid();

        Assert.Equal(HttpStatusCode.NotFound,
            (await ownerB.GetAsync($"/api/company-users/{userId}",
                TestContext.Current.CancellationToken)).StatusCode);
        var companyBUsers = await ownerB.GetJsonAsync<JsonElement[]>(
            "/api/company-users") ?? [];
        Assert.DoesNotContain(companyBUsers,
            x => x.GetProperty("id").GetGuid() == userId);

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, email);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await driver.GetAsync("/api/company-users",
                TestContext.Current.CancellationToken)).StatusCode);
        var unlinked = await driver.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        Assert.Equal("ACCOUNT_NOT_LINKED", unlinked.GetProperty("state").GetString());
    }

    [Fact]
    public async Task DriverLinksRemainOneToOneAndExplicit()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var firstDriver = await CreateDriverAsync(owner, $"ONE-A-{suffix}");
        var secondDriver = await CreateDriverAsync(owner, $"ONE-B-{suffix}");
        var firstUser = (await InviteAndAcceptAsync(
            owner, $"one-a-{suffix}@example.test")).GetProperty("accountId").GetGuid();
        var secondUser = (await InviteAndAcceptAsync(
            owner, $"one-b-{suffix}@example.test")).GetProperty("accountId").GetGuid();

        Assert.Equal(HttpStatusCode.OK, (await owner.PutAsJsonAsync(
            $"/api/company-users/{firstUser}/driver-link", new { driverId = firstDriver },
            TestContext.Current.CancellationToken)).StatusCode);
        var duplicateUser = await owner.PutAsJsonAsync(
            $"/api/company-users/{firstUser}/driver-link", new { driverId = secondDriver },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Conflict, duplicateUser.StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await owner.PutAsJsonAsync(
            $"/api/company-users/{secondUser}/driver-link", new { driverId = firstDriver },
            TestContext.Current.CancellationToken)).StatusCode);
        var users = await owner.GetJsonAsync<JsonElement[]>(
            "/api/company-users?role=Driver") ?? [];
        Assert.Null(users.Single(x => x.GetProperty("id").GetGuid() == firstUser)
            .GetProperty("driverId").GetString());
        Assert.Equal(firstDriver,
            users.Single(x => x.GetProperty("id").GetGuid() == secondUser)
                .GetProperty("driverId").GetGuid());
    }

    [Fact]
    public async Task SelfOwnedPasswordChangeRevokesRefreshAndPreferenceIsPerAccount()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var email = $"security-{suffix}@example.test";
        await InviteAndAcceptAsync(owner, email);

        using var raw = factory.CreateClient();
        var login = await raw.PostAsJsonAsync("/api/auth/login", new
        {
            email,
            password = ApiFactory.Password
        }, TestContext.Current.CancellationToken);
        var tokens = await login.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken);
        var access = tokens.GetProperty("accessToken").GetString()!;
        var refresh = tokens.GetProperty("refreshToken").GetString()!;
        raw.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", access);

        var preference = await raw.PutAsJsonAsync(
            "/api/auth/me/notification-sounds", new { enabled = false },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.OK, preference.StatusCode);
        Assert.False((await preference.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken))
            .GetProperty("notificationSoundsEnabled").GetBoolean());

        var changed = await raw.PutAsJsonAsync("/api/auth/me/password", new
        {
            currentPassword = ApiFactory.Password,
            newPassword = "ReplacementPassword!123",
            confirmPassword = "ReplacementPassword!123"
        }, TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.NoContent, changed.StatusCode);
        var rejectedRefresh = await raw.PostAsJsonAsync("/api/auth/refresh",
            new { refreshToken = refresh }, TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Unauthorized, rejectedRefresh.StatusCode);

        var ownerMe = await owner.GetJsonAsync<JsonElement>("/api/auth/me");
        Assert.True(ownerMe.GetProperty("notificationSoundsEnabled").GetBoolean());
    }

    private static async Task<Guid> CreateDriverAsync(
        HttpClient owner, string suffix) =>
        (await (await owner.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Driver {suffix}", licenseNumber = suffix
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

    private async Task<JsonElement> InviteAndAcceptAsync(
        HttpClient owner, string email, Guid? driverId = null)
    {
        var invitation = await (await owner.PostJsonAsync(
            "/api/company-users/drivers", new
            {
                email,
                displayName = email,
                driverId
            })).RequiredJsonAsync();
        var path = invitation.GetProperty("acceptancePath").GetString()!;
        var token = Uri.UnescapeDataString(path[(path.IndexOf("token=", StringComparison.Ordinal) + 6)..]);
        using var anonymous = factory.CreateClient();
        return await (await anonymous.PostAsJsonAsync("/api/invitations/accept", new
        {
            token,
            email,
            displayName = email,
            password = ApiFactory.Password
        }, TestContext.Current.CancellationToken)).RequiredJsonAsync();
    }
}
