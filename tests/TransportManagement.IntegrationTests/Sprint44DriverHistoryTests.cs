using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint44DriverHistoryTests(ApiFactory factory)
    : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task HistoryIsDriverScopedDeterministicAndIntervalBounded()
    {
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var driverAId = await CreateDriverAsync(owner, $"H44-A-{suffix}");
        var driverBId = await CreateDriverAsync(owner, $"H44-B-{suffix}");
        var emailA = $"h44-a-{suffix}@example.test";
        var emailB = $"h44-b-{suffix}@example.test";
        await InviteAndAcceptAsync(owner, emailA, driverAId);
        await InviteAndAcceptAsync(owner, emailB, driverBId);
        var clientId = (await (await owner.PostJsonAsync("/api/clients", new
        {
            name = $"History client {suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var truckId = (await (await owner.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"H44-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();

        var now = DateTimeOffset.UtcNow.AddDays(-10);
        var historyIds = new List<Guid>();
        Guid handoverTripId;
        Guid crossTenantTripId;
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (var index = 0; index < 105; index++)
            {
                var trip = new Trip(Guid.NewGuid(), ApiFactory.CompanyAId,
                    $"H44-{suffix}-{index:000}", clientId, "Authorized cargo",
                    now.AddHours(index), null, "Internal note", now);
                trip.Assign(truckId, driverAId, now);
                db.Trips.Add(trip);
                db.TripDriverParticipations.Add(new TripDriverParticipation(
                    Guid.NewGuid(), ApiFactory.CompanyAId, trip.Id, driverAId,
                    now, "Assignment", TripStatus.Assigned, null, null, null, now));
                historyIds.Add(trip.Id);
            }

            var handoverTrip = new Trip(Guid.NewGuid(), ApiFactory.CompanyAId,
                $"H44-{suffix}-HANDOVER", clientId, "Handover cargo", now,
                null, "Must not be returned", now);
            handoverTrip.Assign(truckId, driverBId, now);
            db.Trips.Add(handoverTrip);
            var first = new TripDriverParticipation(Guid.NewGuid(),
                ApiFactory.CompanyAId, handoverTrip.Id, driverAId, now,
                "Assignment", TripStatus.Assigned, null, null, null, now);
            first.End(now.AddMinutes(10), TripStatus.Assigned, null, null);
            var second = new TripDriverParticipation(Guid.NewGuid(),
                ApiFactory.CompanyAId, handoverTrip.Id, driverBId,
                now.AddMinutes(10), "ApprovedHandover", TripStatus.Assigned,
                null, null, null, now.AddMinutes(10));
            db.TripDriverParticipations.AddRange(first, second);
            var crossTenantTrip = new Trip(Guid.NewGuid(), ApiFactory.CompanyBId,
                $"H44-{suffix}-FOREIGN", clientId, "Foreign cargo", now,
                null, null, now);
            db.Trips.Add(crossTenantTrip);
            db.TripDriverParticipations.Add(new TripDriverParticipation(
                Guid.NewGuid(), ApiFactory.CompanyBId, crossTenantTrip.Id,
                driverAId, now, "Assignment", TripStatus.Assigned,
                null, null, null, now));
            var runId = Guid.NewGuid();
            db.TruckPositions.AddRange(
                new TruckPosition(Guid.NewGuid(), ApiFactory.CompanyAId,
                    truckId, 39.9m, 32.8m, 30, 90, true,
                    now.AddMinutes(5), "Test", handoverTrip.Id, null, runId),
                new TruckPosition(Guid.NewGuid(), ApiFactory.CompanyAId,
                    truckId, 40.0m, 32.9m, 30, 90, true,
                    now.AddMinutes(15), "Test", handoverTrip.Id, null, runId));
            await db.SaveChangesAsync(TestContext.Current.CancellationToken);
            handoverTripId = handoverTrip.Id;
            crossTenantTripId = crossTenantTrip.Id;
        }

        using var driverA = await OperationsTestClient.AuthenticatedClientAsync(
            factory, emailA);
        var firstPage = await driverA.GetJsonAsync<JsonElement>(
            "/api/driver/trips?category=upcoming&page=1&pageSize=50");
        Assert.Equal(106, firstPage.GetProperty("totalCount").GetInt32());
        Assert.Equal(50, firstPage.GetProperty("items").GetArrayLength());
        var thirdPage = await driverA.GetJsonAsync<JsonElement>(
            "/api/driver/trips?category=upcoming&page=3&pageSize=50");
        Assert.Equal(6, thirdPage.GetProperty("items").GetArrayLength());

        var firstDetail = await driverA.GetJsonAsync<JsonElement>(
            $"/api/driver/trips/{handoverTripId}");
        Assert.Single(firstDetail.GetProperty("trail").EnumerateArray());
        Assert.Single(firstDetail.GetProperty("participations").EnumerateArray());
        Assert.False(firstDetail.TryGetProperty("price", out _));
        Assert.False(firstDetail.TryGetProperty("notes", out _));

        using var driverB = await OperationsTestClient.AuthenticatedClientAsync(
            factory, emailB);
        var secondDetail = await driverB.GetJsonAsync<JsonElement>(
            $"/api/driver/trips/{handoverTripId}");
        Assert.Single(secondDetail.GetProperty("trail").EnumerateArray());
        Assert.NotEqual(
            firstDetail.GetProperty("trail")[0].GetProperty("recordedAt").GetDateTimeOffset(),
            secondDetail.GetProperty("trail")[0].GetProperty("recordedAt").GetDateTimeOffset());

        var anotherDriversTrip = await driverB.GetResponseAsync(
            $"/api/driver/trips/{historyIds[0]}");
        Assert.Equal(HttpStatusCode.NotFound, anotherDriversTrip.StatusCode);
        var invalidPage = await driverA.GetResponseAsync(
            "/api/driver/trips?category=upcoming&page=0&pageSize=20");
        Assert.Equal(HttpStatusCode.BadRequest, invalidPage.StatusCode);
        var crossTenant = await driverA.GetResponseAsync(
            $"/api/driver/trips/{crossTenantTripId}");
        Assert.Equal(HttpStatusCode.NotFound, crossTenant.StatusCode);
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

    private static string Token(string path) => Uri.UnescapeDataString(
        path[(path.IndexOf("token=", StringComparison.Ordinal) + 6)..]);
}
