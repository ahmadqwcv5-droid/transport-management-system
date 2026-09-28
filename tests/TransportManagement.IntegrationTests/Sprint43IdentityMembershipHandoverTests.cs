using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint43IdentityMembershipHandoverTests(ApiFactory factory)
    : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task MultiMembershipLoginRequiresSelectionAndRevocationStopsStaleTokens()
    {
        Guid membershipB;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
            var now = DateTimeOffset.UtcNow;
            var account = new User(Guid.NewGuid(), "multi@example.test", "Multi Account",
                hasher.Hash(ApiFactory.Password), now);
            var membershipA = new CompanyMembership(Guid.NewGuid(), ApiFactory.CompanyAId,
                account.Id, MembershipStatus.Active, null, now);
            var second = new CompanyMembership(Guid.NewGuid(), ApiFactory.CompanyBId,
                account.Id, MembershipStatus.Active, null, now);
            membershipB = second.Id;
            db.Users.Add(account);
            db.CompanyMemberships.AddRange(membershipA, second);
            db.CompanyMembershipRoles.AddRange(
                new CompanyMembershipRole(ApiFactory.CompanyAId, membershipA.Id, AppRoles.Driver),
                new CompanyMembershipRole(ApiFactory.CompanyBId, second.Id, AppRoles.Owner));
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        using var client = factory.CreateClient();
        var login = await (await client.PostAsJsonAsync("/api/auth/login", new
        {
            email = "multi@example.test",
            password = ApiFactory.Password
        }, TestContext.Current.CancellationToken)).RequiredJsonAsync();
        Assert.Equal(JsonValueKind.Null, login.GetProperty("user")
            .GetProperty("companyId").ValueKind);
        Assert.True(login.GetProperty("user")
            .GetProperty("requiresWorkspaceSelection").GetBoolean());

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", login.GetProperty("accessToken").GetString());
        var workspaces = await client.GetJsonAsync<JsonElement[]>("/api/auth/workspaces") ?? [];
        Assert.Equal(2, workspaces.Length);

        var switched = await (await client.PostJsonAsync("/api/auth/switch-workspace", new
        {
            membershipId = membershipB,
            refreshToken = login.GetProperty("refreshToken").GetString()
        })).RequiredJsonAsync();
        Assert.Equal(ApiFactory.CompanyBId, switched.GetProperty("user")
            .GetProperty("companyId").GetGuid());
        var switchedAccess = switched.GetProperty("accessToken").GetString()!;
        var switchedRefresh = switched.GetProperty("refreshToken").GetString()!;
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", switchedAccess);
        Assert.Equal(HttpStatusCode.OK,
            (await client.GetAsync($"/api/companies/{ApiFactory.CompanyBId}",
                TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/companies/{ApiFactory.CompanyAId}",
                TestContext.Current.CancellationToken)).StatusCode);

        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var membership = await db.CompanyMemberships.IgnoreQueryFilters()
                .SingleAsync(x => x.Id == membershipB, TestContext.Current.CancellationToken);
            membership.Suspend(DateTimeOffset.UtcNow);
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
        }

        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.GetAsync($"/api/companies/{ApiFactory.CompanyBId}",
                TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh",
                new { refreshToken = switchedRefresh },
                TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task FakeGoogleProvesCreationConflictExplicitLinkAndLastMethodGuard()
    {
        using var client = factory.CreateClient();
        var providers = await client.GetJsonAsync<JsonElement[]>(
            "/api/auth/external/providers") ?? [];
        Assert.True(providers.Single().GetProperty("isConfigured").GetBoolean());

        var invalid = await client.PostJsonAsync("/api/auth/external/sign-in", new
        {
            provider = "google",
            idToken = "invalid"
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        Assert.Contains("EXTERNAL_TOKEN_INVALID",
            await invalid.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        var email = $"google-{Guid.NewGuid():N}@example.test";
        var created = await (await client.PostJsonAsync("/api/auth/external/sign-in", new
        {
            provider = "google",
            idToken = $"verified|subject-new|{email}|true"
        })).RequiredJsonAsync();
        Assert.False(created.GetProperty("user").GetProperty("hasLocalPassword").GetBoolean());
        Assert.Equal(JsonValueKind.Null,
            created.GetProperty("user").GetProperty("companyId").ValueKind);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", created.GetProperty("accessToken").GetString());
        var lastMethod = await client.DeleteAsync(
            "/api/auth/me/external-logins/google",
            TestContext.Current.CancellationToken);
        Assert.Equal(HttpStatusCode.BadRequest, lastMethod.StatusCode);
        Assert.Contains("LAST_SIGN_IN_METHOD",
            await lastMethod.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        var collision = await client.PostJsonAsync("/api/auth/external/sign-in", new
        {
            provider = "google",
            idToken = "verified|owner-other|owner-a@example.test|true"
        });
        Assert.Equal(HttpStatusCode.BadRequest, collision.StatusCode);
        Assert.Contains("EXTERNAL_ACCOUNT_LINK_REQUIRED",
            await collision.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var linked = await owner.PostJsonAsync("/api/auth/me/external-logins", new
        {
            provider = "google",
            idToken = "verified|owner-linked|owner-a@example.test|true"
        });
        Assert.Equal(HttpStatusCode.OK, linked.StatusCode);
        var methods = await linked.Content.ReadFromJsonAsync<JsonElement[]>(
            TestContext.Current.CancellationToken) ?? [];
        Assert.Contains(methods,
            x => x.GetProperty("provider").GetString() == "google");
        Assert.Equal(HttpStatusCode.OK,
            (await owner.DeleteAsync("/api/auth/me/external-logins/google",
                TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task InvitationSecretIsHashedAndAcceptanceIsSingleUseAndAudited()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var email = $"invite-{Guid.NewGuid():N}@example.test";
        var invitation = await (await owner.PostJsonAsync(
            "/api/membership-invitations", new
            {
                email,
                roles = new[] { AppRoles.Driver },
                expiresInDays = 3
            })).RequiredJsonAsync();
        var invitationId = invitation.GetProperty("id").GetGuid();
        var token = Token(invitation.GetProperty("acceptancePath").GetString()!);

        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await db.CompanyInvitations.IgnoreQueryFilters()
                .SingleAsync(x => x.Id == invitationId,
                    TestContext.Current.CancellationToken);
            Assert.NotEqual(token, stored.TokenHash);
            Assert.DoesNotContain(token, stored.TokenHash, StringComparison.Ordinal);
        }

        using var anonymous = factory.CreateClient();
        var mismatch = await anonymous.PostJsonAsync("/api/invitations/accept", new
        {
            token,
            email = "wrong@example.test",
            displayName = "Wrong",
            password = ApiFactory.Password
        });
        Assert.Equal(HttpStatusCode.BadRequest, mismatch.StatusCode);
        Assert.Contains("INVITATION_EMAIL_MISMATCH",
            await mismatch.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        var accepted = await anonymous.PostJsonAsync("/api/invitations/accept", new
        {
            token,
            email,
            displayName = "Invited Driver",
            password = ApiFactory.Password
        });
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        var replay = await anonymous.PostJsonAsync("/api/invitations/accept", new
        {
            token,
            email,
            displayName = "Invited Driver",
            password = ApiFactory.Password
        });
        Assert.Equal(HttpStatusCode.BadRequest, replay.StatusCode);
        Assert.Contains("INVITATION_ALREADY_USED",
            await replay.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));

        using var proofScope = factory.Services.CreateScope();
        var proofDb = proofScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.True(await proofDb.IdentityAuditEvents.IgnoreQueryFilters().AnyAsync(
            x => x.EventCode == "CompanyInvitationAccepted",
            TestContext.Current.CancellationToken));
        Assert.True(await proofDb.OperationNotifications.IgnoreQueryFilters().AnyAsync(
            x => x.Type == "CompanyInvitationAccepted",
            TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task ExactCompanyCodeHasNoDirectoryAndConnectionApprovalAddsWorkspace()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var code = await owner.GetJsonAsync<JsonElement>(
            "/api/company-connection-code");
        var rawCode = code.GetProperty("code").GetString()!;

        var email = $"join-{Guid.NewGuid():N}@example.test";
        using var applicant = await GoogleClientAsync(email, $"join-{Guid.NewGuid():N}");
        var wrong = await applicant.PostJsonAsync("/api/company-connections/resolve",
            new { code = "definitely-wrong" });
        Assert.Equal(HttpStatusCode.NotFound, wrong.StatusCode);
        var summary = await (await applicant.PostJsonAsync(
            "/api/company-connections/resolve", new { code = rawCode })).RequiredJsonAsync();
        Assert.Equal("Company A", summary.GetProperty("companyName").GetString());
        Assert.Equal(2, summary.EnumerateObject().Count());

        var request = await (await applicant.PostJsonAsync(
            "/api/company-connections", new { code = rawCode })).RequiredJsonAsync();
        var requestId = request.GetProperty("id").GetGuid();
        var duplicate = await applicant.PostJsonAsync(
            "/api/company-connections", new { code = rawCode });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
        var pending = await owner.GetJsonAsync<JsonElement[]>(
            "/api/company-connections/pending") ?? [];
        Assert.Contains(pending, x => x.GetProperty("id").GetGuid() == requestId);
        var driverId = await CreateDriverAsync(owner, $"JOIN-{Guid.NewGuid():N}"[..13]);
        Assert.Equal(HttpStatusCode.OK, (await owner.PostJsonAsync(
            $"/api/company-connections/{requestId}/approve",
            new { driverId = (Guid?)driverId, reason = "Verified in test" })).StatusCode);

        var workspaces = await applicant.GetJsonAsync<JsonElement[]>(
            "/api/auth/workspaces") ?? [];
        Assert.Contains(workspaces,
            x => x.GetProperty("companyId").GetGuid() == ApiFactory.CompanyAId);
    }

    [Fact]
    public async Task TruckQrRegenerationInvalidatesOldCodeAndCrossTenantLeaksNothing()
    {
        using var ownerA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        using var ownerB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-b@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var driverAId = await CreateDriverAsync(ownerA, $"QR-A-{suffix}");
        var driverBId = await CreateDriverAsync(ownerB, $"QR-B-{suffix}");
        var driverAEmail = $"qr-a-{suffix}@example.test";
        var driverBEmail = $"qr-b-{suffix}@example.test";
        await InviteAndAcceptAsync(ownerA, driverAEmail, driverAId);
        await InviteAndAcceptAsync(ownerB, driverBEmail, driverBId);
        var truck = await (await ownerA.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"QR-{suffix}",
            defaultDriverId = driverAId
        })).RequiredJsonAsync();
        var truckId = truck.GetProperty("id").GetGuid();

        var first = await (await ownerA.PostEmptyAsync(
            $"/api/trucks/{truckId}/qr/regenerate")).RequiredJsonAsync();
        var firstCode = first.GetProperty("code").GetString()!;
        using var driverA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, driverAEmail);
        Assert.Equal(HttpStatusCode.OK, (await driverA.PostJsonAsync(
            "/api/driver/truck-qr/preview", new { code = firstCode })).StatusCode);

        var second = await (await ownerA.PostEmptyAsync(
            $"/api/trucks/{truckId}/qr/regenerate")).RequiredJsonAsync();
        var secondCode = second.GetProperty("code").GetString()!;
        Assert.NotEqual(firstCode, secondCode);
        Assert.Equal(HttpStatusCode.NotFound, (await driverA.PostJsonAsync(
            "/api/driver/truck-qr/preview", new { code = firstCode })).StatusCode);
        var started = await (await driverA.PostJsonAsync(
            "/api/driver/truck-qr/confirm", new { code = secondCode })).RequiredJsonAsync();
        Assert.Equal("SessionStarted", started.GetProperty("state").GetString());
        var unchanged = await ownerA.GetJsonAsync<JsonElement>(
            $"/api/trucks/{truckId}");
        Assert.Equal(driverAId, unchanged.GetProperty("defaultDriverId").GetGuid());

        using var driverB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, driverBEmail);
        Assert.Equal(HttpStatusCode.NotFound, (await driverB.PostJsonAsync(
            "/api/driver/truck-qr/preview", new { code = secondCode })).StatusCode);
    }

    [Fact]
    public async Task ApprovedHandoverPreservesTripTruckRouteAndCreatesParticipationBoundary()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var driverAId = await CreateDriverAsync(owner, $"HAND-A-{suffix}");
        var driverBId = await CreateDriverAsync(owner, $"HAND-B-{suffix}");
        var emailA = $"hand-a-{suffix}@example.test";
        var emailB = $"hand-b-{suffix}@example.test";
        await InviteAndAcceptAsync(owner, emailA, driverAId);
        await InviteAndAcceptAsync(owner, emailB, driverBId);
        var truckId = (await (await owner.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"HAND-{suffix}",
            defaultDriverId = driverAId
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var clientId = (await (await owner.PostJsonAsync("/api/clients", new
        {
            name = $"Handover Client {suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var ready = await RouteTestData.CreateReadyTripAsync(owner, clientId);
        var tripId = ready.GetProperty("id").GetGuid();
        var assigned = await (await owner.PostJsonAsync(
            $"/api/trips/{tripId}/assign", new { truckId, driverId = driverAId }))
            .RequiredJsonAsync();
        var routeId = assigned.GetProperty("routePlan").GetProperty("id").GetGuid();
        var qr = await (await owner.PostEmptyAsync(
            $"/api/trucks/{truckId}/qr/regenerate")).RequiredJsonAsync();
        var code = qr.GetProperty("code").GetString()!;

        using var driverB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, emailB);
        var pending = await (await driverB.PostJsonAsync(
            "/api/driver/truck-qr/confirm", new
            {
                code,
                reason = "Substitute Driver"
            })).RequiredJsonAsync();
        Assert.Equal("HandoverPending", pending.GetProperty("state").GetString());
        var before = await owner.GetJsonAsync<JsonElement>($"/api/trips/{tripId}");
        Assert.Equal(driverAId, before.GetProperty("driverId").GetGuid());

        var requestId = pending.GetProperty("handoverRequestId").GetGuid();
        var approved = await owner.PostJsonAsync(
            $"/api/handovers/{requestId}/approve",
            new { reason = "Operations approved" });
        Assert.Equal(HttpStatusCode.OK, approved.StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await owner.PostJsonAsync(
            $"/api/handovers/{requestId}/approve",
            new { reason = "Idempotent replay" })).StatusCode);

        var after = await owner.GetJsonAsync<JsonElement>($"/api/trips/{tripId}");
        Assert.Equal(tripId, after.GetProperty("id").GetGuid());
        Assert.Equal(truckId, after.GetProperty("truckId").GetGuid());
        Assert.Equal(driverBId, after.GetProperty("driverId").GetGuid());
        Assert.Equal(routeId, after.GetProperty("routePlan").GetProperty("id").GetGuid());

        using var driverA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, emailA);
        var oldWorkspace = await driverA.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        Assert.NotEqual(tripId,
            oldWorkspace.TryGetProperty("currentTrip", out var oldTrip)
                && oldTrip.ValueKind != JsonValueKind.Null
                ? oldTrip.GetProperty("id").GetGuid()
                : Guid.Empty);
        var newWorkspace = await driverB.GetJsonAsync<JsonElement>(
            "/api/driver/my-trip/workspace");
        Assert.Equal(tripId,
            newWorkspace.GetProperty("currentTrip").GetProperty("id").GetGuid());

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var participation = await db.TripDriverParticipations.IgnoreQueryFilters()
            .Where(x => x.TripId == tripId).OrderBy(x => x.StartedAt)
            .ToListAsync(TestContext.Current.CancellationToken);
        Assert.Equal(2, participation.Count);
        Assert.Equal(driverAId, participation[0].DriverId);
        Assert.NotNull(participation[0].EndedAt);
        Assert.Equal(driverBId, participation[1].DriverId);
        Assert.Null(participation[1].EndedAt);
        Assert.Equal(participation[0].EndedAt, participation[1].StartedAt);
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

    private async Task InviteAndAcceptAsync(
        HttpClient owner, string email, Guid driverId)
    {
        var invitation = await (await owner.PostJsonAsync(
            "/api/company-users/drivers", new
            {
                email,
                displayName = email,
                driverId
            })).RequiredJsonAsync();
        using var anonymous = factory.CreateClient();
        var accepted = await anonymous.PostJsonAsync("/api/invitations/accept", new
        {
            token = Token(invitation.GetProperty("acceptancePath").GetString()!),
            email,
            displayName = email,
            password = ApiFactory.Password
        });
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
    }

    private static string Token(string path) =>
        Uri.UnescapeDataString(
            path[(path.IndexOf("token=", StringComparison.Ordinal) + 6)..]);
}
