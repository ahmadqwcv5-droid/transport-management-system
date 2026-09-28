using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Domain.Identity;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint431IdentityStabilizationTests(ApiFactory factory)
    : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task InvitationUrlIsCompleteAndGoogleMismatchDoesNotConsumeInvitation()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var email = $"invite-google-{Guid.NewGuid():N}@example.test";
        var invitation = await (await owner.PostJsonAsync(
            "/api/membership-invitations", new
            {
                email,
                roles = new[] { AppRoles.Employee },
                expiresInDays = 3
            })).RequiredJsonAsync();
        var url = invitation.GetProperty("acceptancePath").GetString()!;
        Assert.StartsWith("http://localhost:3000/#/accept-invitation?token=", url);
        var token = Token(url);

        using var wrong = await GoogleClientAsync(
            $"wrong-{Guid.NewGuid():N}@example.test", $"wrong-{Guid.NewGuid():N}");
        var mismatch = await wrong.PostJsonAsync("/api/invitations/accept",
            new { token });
        Assert.Equal(HttpStatusCode.BadRequest, mismatch.StatusCode);
        Assert.Contains("INVITATION_EMAIL_MISMATCH",
            await mismatch.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        using var invited = await GoogleClientAsync(email, $"subject-{Guid.NewGuid():N}");
        Assert.Equal(HttpStatusCode.OK,
            (await invited.PostJsonAsync("/api/invitations/accept", new { token })).StatusCode);
        var workspaces = await invited.GetJsonAsync<JsonElement[]>(
            "/api/auth/workspaces") ?? [];
        Assert.Contains(workspaces,
            x => x.GetProperty("companyId").GetGuid() == ApiFactory.CompanyAId);

        var replay = await invited.PostJsonAsync("/api/invitations/accept",
            new { token });
        Assert.Equal(HttpStatusCode.BadRequest, replay.StatusCode);
        Assert.Contains("INVITATION_ALREADY_USED",
            await replay.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task OwnerRoleManagementRejectsEscalationAndInvalidatesStaleAccess()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var operationsEmail = $"operations-{Guid.NewGuid():N}@example.test";
        var operationsId = await InviteAndAcceptAsync(
            owner, operationsEmail, [AppRoles.Operations]);
        using var operations = await OperationsTestClient.AuthenticatedClientAsync(
            factory, operationsEmail);

        var ownerInvite = await operations.PostJsonAsync(
            "/api/membership-invitations", new
            {
                email = $"owner-escalation-{Guid.NewGuid():N}@example.test",
                roles = new[] { AppRoles.Owner }
            });
        Assert.Equal(HttpStatusCode.Forbidden, ownerInvite.StatusCode);
        Assert.Contains("OWNER_ROLE_REQUIRES_OWNER",
            await ownerInvite.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        var roleEscalation = await operations.PutAsJsonAsync(
            $"/api/company-users/{operationsId}/roles",
            new { roles = new[] { AppRoles.Owner } },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Forbidden, roleEscalation.StatusCode);

        var ownerMe = await owner.GetJsonAsync<JsonElement>("/api/auth/me");
        var selfRemoval = await owner.PutAsJsonAsync(
            $"/api/company-users/{ownerMe.GetProperty("id").GetGuid()}/roles",
            new { roles = new[] { AppRoles.Operations } },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Conflict, selfRemoval.StatusCode);
        Assert.Contains("MEMBERSHIP_SELF_OWNER_REMOVAL_FORBIDDEN",
            await selfRemoval.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        var targetEmail = $"role-target-{Guid.NewGuid():N}@example.test";
        var targetId = await InviteAndAcceptAsync(
            owner, targetEmail, [AppRoles.Employee]);
        using var stale = await OperationsTestClient.AuthenticatedClientAsync(
            factory, targetEmail);
        var updated = await owner.PutAsJsonAsync(
            $"/api/company-users/{targetId}/roles",
            new { roles = new[] { AppRoles.Operations, AppRoles.Employee } },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await stale.GetAsync("/api/company-users",
                TestContext.Current.CancellationToken)).StatusCode);

        using var refreshed = await OperationsTestClient.AuthenticatedClientAsync(
            factory, targetEmail);
        Assert.Equal(HttpStatusCode.OK,
            (await refreshed.GetAsync("/api/company-users",
                TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task DriverLinkCannotBeStolenAndActiveSessionBlocksUnlinkAndRoleRemoval()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var driverId = await CreateDriverAsync(owner, $"LINK-{suffix}");
        var otherDriverId = await CreateDriverAsync(owner, $"LINK2-{suffix}");
        var firstEmail = $"link-first-{suffix}@example.test";
        var secondEmail = $"link-second-{suffix}@example.test";
        var firstId = await InviteAndAcceptAsync(owner, firstEmail, [AppRoles.Driver]);
        var secondId = await InviteAndAcceptAsync(owner, secondEmail, [AppRoles.Driver]);

        Assert.Equal(HttpStatusCode.OK, (await owner.PutAsJsonAsync(
            $"/api/company-users/{firstId}/driver-link",
            new { driverId }, TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await owner.PutAsJsonAsync(
            $"/api/company-users/{firstId}/driver-link",
            new { driverId }, TestContext.Current.CancellationToken)).StatusCode);
        var stolen = await owner.PutAsJsonAsync(
            $"/api/company-users/{secondId}/driver-link",
            new { driverId }, TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Conflict, stolen.StatusCode);
        Assert.Contains("DRIVER_ACCOUNT_ALREADY_LINKED",
            await stolen.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        Assert.Equal(HttpStatusCode.OK, (await owner.PutAsJsonAsync(
            $"/api/company-users/{secondId}/driver-link",
            new { driverId = otherDriverId },
            TestContext.Current.CancellationToken)).StatusCode);
        var truck = await (await owner.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"LINK-{suffix}",
            defaultDriverId = driverId
        })).RequiredJsonAsync();
        var truckId = truck.GetProperty("id").GetGuid();
        var qr = await (await owner.PostEmptyAsync(
            $"/api/trucks/{truckId}/qr/regenerate")).RequiredJsonAsync();

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, firstEmail);
        var confirmed = await driver.PostJsonAsync("/api/driver/truck-qr/confirm",
            new { code = qr.GetProperty("qrPayload").GetString() });
        Assert.Equal(HttpStatusCode.OK, confirmed.StatusCode);

        var unlink = await owner.DeleteAsync(
            $"/api/company-users/{firstId}/driver-link",
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Conflict, unlink.StatusCode);
        Assert.Contains("DRIVER_UNLINK_ACTIVE_SESSION",
            await unlink.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        var removeRole = await owner.PutAsJsonAsync(
            $"/api/company-users/{firstId}/roles",
            new { roles = new[] { AppRoles.Employee } },
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.Conflict, removeRole.StatusCode);
        Assert.Contains("DRIVER_ROLE_LINKED",
            await removeRole.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task QrStatusNeverReturnsSecretAndFullPayloadResolves()
    {
        using var ownerA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var ownerB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var driverId = await CreateDriverAsync(ownerA, $"QR31-{suffix}");
        var email = $"qr31-{suffix}@example.test";
        await InviteAndAcceptAsync(ownerA, email, [AppRoles.Driver], driverId);
        var truckId = (await (await ownerA.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"QR31-{suffix}",
            defaultDriverId = driverId
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

        var empty = await ownerA.GetJsonAsync<JsonElement>(
            $"/api/trucks/{truckId}/qr");
        Assert.False(empty.GetProperty("hasActiveCredential").GetBoolean());
        Assert.False(empty.TryGetProperty("code", out _));
        Assert.False(empty.TryGetProperty("qrPayload", out _));

        var generated = await (await ownerA.PostEmptyAsync(
            $"/api/trucks/{truckId}/qr/regenerate")).RequiredJsonAsync();
        var status = await ownerA.GetJsonAsync<JsonElement>(
            $"/api/trucks/{truckId}/qr");
        Assert.True(status.GetProperty("hasActiveCredential").GetBoolean());
        Assert.False(status.TryGetProperty("code", out _));
        Assert.False(status.TryGetProperty("qrPayload", out _));

        using var driver = await OperationsTestClient.AuthenticatedClientAsync(
            factory, email);
        Assert.Equal(HttpStatusCode.OK, (await driver.PostJsonAsync(
            "/api/driver/truck-qr/preview",
            new { code = generated.GetProperty("qrPayload").GetString() })).StatusCode);
        await ownerA.PostEmptyAsync($"/api/trucks/{truckId}/qr/regenerate");

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.TruckQrCredentials.IgnoreQueryFilters().CountAsync(
            x => x.TruckId == truckId && x.RevokedAt == null,
            TestContext.Current.CancellationToken));
        Assert.Equal(HttpStatusCode.NotFound,
            (await ownerB.GetAsync($"/api/trucks/{truckId}/qr",
                TestContext.Current.CancellationToken)).StatusCode);
    }

    private async Task<HttpClient> GoogleClientAsync(string email, string subject)
    {
        var client = factory.CreateClient();
        var response = await (await client.PostJsonAsync(
            "/api/auth/external/sign-in", new
            {
                provider = "google",
                idToken = $"verified|{subject}|{email}|true"
            })).RequiredJsonAsync();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", response.GetProperty("accessToken").GetString());
        return client;
    }

    private static async Task<Guid> CreateDriverAsync(
        HttpClient owner, string suffix) =>
        (await (await owner.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Driver {suffix}",
            licenseNumber = suffix
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

    private async Task<Guid> InviteAndAcceptAsync(
        HttpClient owner, string email, string[] roles, Guid? driverId = null)
    {
        var invitation = await (await owner.PostJsonAsync(
            "/api/membership-invitations", new
            {
                email,
                roles,
                driverId,
                expiresInDays = 3
            })).RequiredJsonAsync();
        using var anonymous = factory.CreateClient();
        var accepted = await (await anonymous.PostJsonAsync(
            "/api/invitations/accept", new
            {
                token = Token(invitation.GetProperty("acceptancePath").GetString()!),
                email,
                displayName = email,
                password = ApiFactory.Password
            })).RequiredJsonAsync();
        return accepted.GetProperty("accountId").GetGuid();
    }

    private static string Token(string url) =>
        Uri.UnescapeDataString(
            url[(url.IndexOf("token=", StringComparison.Ordinal) + 6)..]);
}
