using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint411DriverOnboardingTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task OwnerCreatesAndLinksDriverAccountEntirelyThroughApi()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var driverId = (await (await owner.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Onboarded Driver {suffix}",
            licenseNumber = $"ONB-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

        var created = await owner.PostJsonAsync("/api/company-users/drivers", new
        {
            email = $"onboarded-{suffix}@example.test",
            displayName = $"Onboarded Driver {suffix}",
            driverId
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var body = await created.RequiredJsonAsync();
        var password = body.GetProperty("temporaryPassword").GetString();
        var user = body.GetProperty("user");
        Assert.Equal(driverId, user.GetProperty("driverId").GetGuid());
        Assert.Equal("Driver", user.GetProperty("role").GetString());
        Assert.False(string.IsNullOrWhiteSpace(password));

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, $"onboarded-{suffix}@example.test", password!);
        var workspace = await driver.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        Assert.Equal("NO_ACTIVE_TRIP", workspace.GetProperty("state").GetString());

        var duplicate = await owner.PostJsonAsync("/api/company-users/drivers", new
        {
            email = $"onboarded-{suffix}@example.test",
            displayName = "Duplicate"
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
        Assert.Contains("USER_EMAIL_ALREADY_EXISTS",
            await duplicate.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task CompanyUsersAreOwnerOnlyAndTenantScoped()
    {
        using var ownerA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var ownerB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var created = await (await ownerA.PostJsonAsync("/api/company-users/drivers", new
        {
            email = $"isolated-{suffix}@example.test",
            displayName = "Isolated Driver"
        })).RequiredJsonAsync();
        var userId = created.GetProperty("user").GetProperty("id").GetGuid();
        var password = created.GetProperty("temporaryPassword").GetString()!;

        Assert.Equal(HttpStatusCode.NotFound,
            (await ownerB.GetAsync($"/api/company-users/{userId}",
                TestContext.Current.CancellationToken)).StatusCode);
        var companyBUsers = await ownerB.GetJsonAsync<JsonElement[]>("/api/company-users") ?? [];
        Assert.DoesNotContain(companyBUsers, x => x.GetProperty("id").GetGuid() == userId);

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, $"isolated-{suffix}@example.test", password);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await driver.GetAsync("/api/company-users",
                TestContext.Current.CancellationToken)).StatusCode);
        var unlinked = await driver.GetJsonAsync<JsonElement>("/api/driver/my-trip/workspace");
        Assert.Equal("ACCOUNT_NOT_LINKED", unlinked.GetProperty("state").GetString());
    }

    [Fact]
    public async Task LinkingIsOneToOneAndReplacementLeavesOnlyOneLink()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var firstDriver = await CreateDriverAsync(owner, $"ONE-A-{suffix}");
        var secondDriver = await CreateDriverAsync(owner, $"ONE-B-{suffix}");
        var firstUser = await CreateUserAsync(owner, $"one-a-{suffix}@example.test");
        var secondUser = await CreateUserAsync(owner, $"one-b-{suffix}@example.test");

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
        var users = await owner.GetJsonAsync<JsonElement[]>("/api/company-users?role=Driver") ?? [];
        Assert.Null(users.Single(x => x.GetProperty("id").GetGuid() == firstUser)
            .GetProperty("driverId").GetString());
        Assert.Equal(firstDriver, users.Single(x => x.GetProperty("id").GetGuid() == secondUser)
            .GetProperty("driverId").GetGuid());
    }

    [Fact]
    public async Task PasswordResetRevokesRefreshAndSoundPreferenceIsPerUser()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var createdResponse = await owner.PostJsonAsync("/api/company-users/drivers", new
        {
            email = $"security-{suffix}@example.test",
            displayName = "Security Driver"
        });
        var created = await createdResponse.RequiredJsonAsync();
        var userId = created.GetProperty("user").GetProperty("id").GetGuid();
        var password = created.GetProperty("temporaryPassword").GetString()!;

        using var raw = factory.CreateClient();
        var login = await raw.PostAsJsonAsync("/api/auth/login", new
        {
            email = $"security-{suffix}@example.test",
            password
        }, TestContext.Current.CancellationToken);
        var tokens = await login.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken);
        var access = tokens.GetProperty("accessToken").GetString()!;
        var refresh = tokens.GetProperty("refreshToken").GetString()!;
        raw.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", access);
        var preference = await raw.PutAsJsonAsync("/api/auth/me/notification-sounds",
            new { enabled = false }, TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.OK, preference.StatusCode);
        Assert.False((await preference.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken)).GetProperty("notificationSoundsEnabled").GetBoolean());

        Assert.Equal(HttpStatusCode.OK, (await owner.PostAsync(
            $"/api/company-users/{userId}/reset-temporary-password", null,
            TestContext.Current.CancellationToken)).StatusCode);
        var rejectedRefresh = await raw.PostAsJsonAsync("/api/auth/refresh",
            new { refreshToken = refresh }, TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Unauthorized, rejectedRefresh.StatusCode);

        var ownerMe = await owner.GetJsonAsync<JsonElement>("/api/auth/me");
        Assert.True(ownerMe.GetProperty("notificationSoundsEnabled").GetBoolean());
    }

    private static async Task<Guid> CreateDriverAsync(HttpClient owner, string suffix) =>
        (await (await owner.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Driver {suffix}", licenseNumber = suffix
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

    private static async Task<Guid> CreateUserAsync(HttpClient owner, string email) =>
        (await (await owner.PostJsonAsync("/api/company-users/drivers", new
        {
            email, displayName = email
        })).RequiredJsonAsync()).GetProperty("user").GetProperty("id").GetGuid();
}
