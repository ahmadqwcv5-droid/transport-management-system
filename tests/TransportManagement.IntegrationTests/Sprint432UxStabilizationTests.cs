using System.Net;
using System.Text.Json;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint432UxStabilizationTests(ApiFactory factory)
    : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task InvitationCreatedAccountUsesDeliberateArabicLocale()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var email = $"locale-{Guid.NewGuid():N}@example.test";
        var invitation = await (await owner.PostJsonAsync(
            "/api/membership-invitations", new
            {
                email,
                roles = new[] { AppRoles.Employee },
                expiresInDays = 3
            })).RequiredJsonAsync();
        var url = invitation.GetProperty("acceptancePath").GetString()!;
        var token = Uri.UnescapeDataString(
            url[(url.IndexOf("token=", StringComparison.Ordinal) + 6)..]);

        using var anonymous = factory.CreateClient();
        var accepted = await anonymous.PostJsonAsync("/api/invitations/accept",
            new
            {
                token,
                email,
                displayName = "Arabic Invitee",
                password = ApiFactory.Password,
                preferredLocale = "ar"
            });
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);

        using var account = await OperationsTestClient.AuthenticatedClientAsync(
            factory, email);
        var me = await account.GetJsonAsync<JsonElement>("/api/auth/me");
        Assert.Equal("ar", me.GetProperty("preferredLocale").GetString());
    }

    [Fact]
    public async Task NotificationApiExposesStableEventKeysAndKnownTypesOnly()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var email = $"notify-{Guid.NewGuid():N}@example.test";
        await owner.PostJsonAsync("/api/membership-invitations", new
        {
            email,
            roles = new[] { AppRoles.Employee },
            expiresInDays = 3
        });

        var page = await owner.GetJsonAsync<JsonElement>(
            "/api/notifications?page=1&pageSize=100");
        foreach (var item in page.GetProperty("items").EnumerateArray())
        {
            Assert.Contains(item.GetProperty("type").GetString()!,
                OperationNotificationTypes.All);
            Assert.False(string.IsNullOrWhiteSpace(
                item.GetProperty("eventKey").GetString()));
            var data = item.TryGetProperty("dataJson", out var json)
                ? json.GetString() ?? string.Empty : string.Empty;
            Assert.DoesNotContain("password", data,
                StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("token", data,
                StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("qrPayload", data,
                StringComparison.OrdinalIgnoreCase);
        }
    }

    [Fact]
    public async Task RepeatedMembershipTransitionsUseDistinctEventKeys()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var email = $"membership-cycle-{Guid.NewGuid():N}@example.test";
        var invitation = await (await owner.PostJsonAsync(
            "/api/membership-invitations", new
            {
                email,
                roles = new[] { AppRoles.Employee },
                expiresInDays = 3
            })).RequiredJsonAsync();
        var url = invitation.GetProperty("acceptancePath").GetString()!;
        var token = Uri.UnescapeDataString(
            url[(url.IndexOf("token=", StringComparison.Ordinal) + 6)..]);

        using var anonymous = factory.CreateClient();
        var accepted = await (await anonymous.PostJsonAsync(
            "/api/invitations/accept", new
            {
                token,
                email,
                displayName = "Membership Cycle",
                password = ApiFactory.Password,
                preferredLocale = "en"
            })).RequiredJsonAsync();
        var membershipId = accepted.GetProperty("membershipId").GetGuid();

        Assert.Equal(HttpStatusCode.OK, (await owner.PutJsonAsync(
            $"/api/memberships/{membershipId}/status",
            new { status = "Suspended" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await owner.PutJsonAsync(
            $"/api/memberships/{membershipId}/status",
            new { status = "Active" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await owner.PutJsonAsync(
            $"/api/memberships/{membershipId}/status",
            new { status = "Suspended" })).StatusCode);

        var page = await owner.GetJsonAsync<JsonElement>(
            "/api/notifications?page=1&pageSize=100");
        var keys = page.GetProperty("items").EnumerateArray()
            .Where(item => item.GetProperty("type").GetString()
                == "MembershipSuspended")
            .Select(item => item.GetProperty("eventKey").GetString())
            .Where(key => key is not null
                && key.Contains(membershipId.ToString(), StringComparison.Ordinal))
            .ToArray();
        Assert.Equal(2, keys.Length);
        Assert.Equal(2, keys.Distinct(StringComparer.Ordinal).Count());
    }
}
