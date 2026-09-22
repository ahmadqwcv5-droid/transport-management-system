using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint34TripOperationsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task MinimalDraftIsRouteIndependentNumberedAndResumable()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = await CreateClientAsync(client, "Minimal");
        var response = await client.PostJsonAsync("/api/trips", new
        {
            clientId,
            cargoDescription = "Resume-safe cargo"
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var draft = await response.RequiredJsonAsync();
        Assert.Matches(@"^TRP-\d{4}-\d{6}$", draft.GetProperty("tripNumber").GetString()!);
        Assert.Equal(JsonValueKind.Null, draft.GetProperty("plannedStartAt").ValueKind);
        Assert.Equal(JsonValueKind.Null, draft.GetProperty("routePlan").ValueKind);
        Assert.False(draft.GetProperty("readiness").GetProperty("canAssign").GetBoolean());
        var resumed = await client.GetJsonAsync<JsonElement>($"/api/trips/{draft.GetProperty("id").GetGuid()}");
        Assert.Equal(draft.GetProperty("tripNumber").GetString(), resumed.GetProperty("tripNumber").GetString());
    }

    [Fact]
    public async Task FirstStopsCanBeSavedImmediatelyAfterCreatingMinimalDraft()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = await CreateClientAsync(client, "Immediate stops");
        var created = await (await client.PostJsonAsync("/api/trips", new
        {
            clientId,
            cargoDescription = "First stop persistence"
        })).RequiredJsonAsync();

        var update = await client.PutAsJsonAsync(
            $"/api/trips/{created.GetProperty("id").GetGuid()}/stops",
            new
            {
                expectedVersion = created.GetProperty("version").GetInt64(),
                stops = new[]
                {
                    new { sequence = 0, type = "Pickup", name = "Factory", address = "Ankara", latitude = 39.9334m, longitude = 32.8597m },
                    new { sequence = 1, type = "Delivery", name = "Warehouse", address = "Istanbul", latitude = 41.0082m, longitude = 28.9784m }
                }
            }, TestContext.Current.CancellationToken);

        Assert.True(update.IsSuccessStatusCode,
            await update.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
        var saved = await update.RequiredJsonAsync();
        Assert.Equal(2, saved.GetProperty("stops").GetArrayLength());
        Assert.Equal(created.GetProperty("version").GetInt64() + 1,
            saved.GetProperty("version").GetInt64());
    }

    [Fact]
    public async Task StopsPersistAndProviderFailureDoesNotEraseDraft()
    {
        await using var failingFactory = new ApiFactory(useFailingRoutingProvider: true);
        await failingFactory.InitializeAsync();
        try
        {
            using var client = await OperationsTestClient.AuthenticatedClientAsync(failingFactory, "owner-a@example.test");
            var clientId = await CreateClientAsync(client, "Route failure");
            var created = await (await client.PostJsonAsync("/api/trips",
                RouteTestData.TripPayload(clientId, deliveryLatitude: 39.5m))).RequiredJsonAsync();
            var route = await client.PostJsonAsync(
                $"/api/trips/{created.GetProperty("id").GetGuid()}/calculate-route",
                new { routeProfile = "Driving" });
            Assert.Equal(HttpStatusCode.ServiceUnavailable, route.StatusCode);
            var persisted = await client.GetJsonAsync<JsonElement>(
                $"/api/trips/{created.GetProperty("id").GetGuid()}");
            Assert.Equal(2, persisted.GetProperty("stops").GetArrayLength());
            Assert.Equal(JsonValueKind.Null, persisted.GetProperty("routePlan").ValueKind);
        }
        finally { await failingFactory.DisposeAsync(); }
    }

    [Fact]
    public async Task PaginationSearchAndTenantTotalsAreScoped()
    {
        var marker = $"Paged-{Guid.NewGuid():N}";
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var clientA = await CreateClientAsync(companyA, marker);
        var clientB = await CreateClientAsync(companyB, marker);
        for (var index = 0; index < 3; index++)
            await (await companyA.PostJsonAsync("/api/trips", new { clientId = clientA, cargoDescription = $"A-{index}" })).RequiredJsonAsync();
        await (await companyB.PostJsonAsync("/api/trips", new { clientId = clientB, cargoDescription = "B" })).RequiredJsonAsync();

        var first = await companyA.GetJsonAsync<JsonElement>(
            $"/api/trips?search={marker}&page=1&pageSize=2&operationalGroup=planned");
        Assert.Equal(3, first.GetProperty("totalCount").GetInt32());
        Assert.Equal(2, first.GetProperty("items").GetArrayLength());
        var second = await companyA.GetJsonAsync<JsonElement>(
            $"/api/trips?search={marker}&page=2&pageSize=2&operationalGroup=planned");
        Assert.Single(second.GetProperty("items").EnumerateArray());
        var foreign = await companyB.GetJsonAsync<JsonElement>($"/api/trips?search={marker}&pageSize=100");
        Assert.Equal(1, foreign.GetProperty("totalCount").GetInt32());
    }

    [Fact]
    public async Task ConcurrentNumbersAreUniqueAndIncompleteDraftCannotBeAssigned()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = await CreateClientAsync(client, "Concurrent numbers");
        var responses = await Task.WhenAll(Enumerable.Range(0, 12).Select(index =>
            client.PostJsonAsync("/api/trips", new
            {
                clientId,
                cargoDescription = $"Concurrent cargo {index}"
            })));
        Assert.All(responses, response => Assert.Equal(HttpStatusCode.Created, response.StatusCode));
        var numbers = new List<string>();
        JsonElement? firstDraft = null;
        foreach (var response in responses)
        {
            var body = await response.RequiredJsonAsync();
            firstDraft ??= body;
            numbers.Add(body.GetProperty("tripNumber").GetString()!);
        }
        Assert.Equal(numbers.Count, numbers.Distinct(StringComparer.OrdinalIgnoreCase).Count());

        var draft = firstDraft!.Value;
        var assignment = await client.PostJsonAsync(
            $"/api/trips/{draft.GetProperty("id").GetGuid()}/assign",
            new { truckId = Guid.NewGuid(), driverId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.Conflict, assignment.StatusCode);
        Assert.Equal("TRIP_NOT_READY_FOR_ASSIGNMENT",
            (await assignment.Content.ReadFromJsonAsync<JsonElement>(
                TestContext.Current.CancellationToken)).GetProperty("errorCode").GetString());
    }

    [Fact]
    public async Task ChangingStopsInvalidatesTheAuthoritativeRoute()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = await CreateClientAsync(client, "Route invalidation");
        var ready = await RouteTestData.CreateReadyTripAsync(client, clientId);
        Assert.True(ready.GetProperty("readiness").GetProperty("canAssign").GetBoolean());
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var persistedVersion = await db.Trips.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.Id == ready.GetProperty("id").GetGuid())
                .Select(x => x.Version).SingleAsync(TestContext.Current.CancellationToken);
            Assert.Equal(ready.GetProperty("version").GetInt64(), persistedVersion);
        }

        var update = await client.PutAsJsonAsync(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}/stops",
            new
            {
                expectedVersion = ready.GetProperty("version").GetInt64(),
                stops = new[]
                {
                    new { sequence = 0, type = "Pickup", name = "Moved pickup", address = "Ankara", latitude = 39.9300m, longitude = 32.8541m },
                    new { sequence = 1, type = "Delivery", name = "Warehouse", address = "Delivery", latitude = 40.9208m, longitude = 31.8541m }
                }
            }, TestContext.Current.CancellationToken);
        Assert.True(update.IsSuccessStatusCode,
            await update.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
        var changed = await update.RequiredJsonAsync();
        Assert.Equal(JsonValueKind.Null, changed.GetProperty("routePlan").ValueKind);
        Assert.False(changed.GetProperty("readiness").GetProperty("canAssign").GetBoolean());
        Assert.Contains("CURRENT_ROUTE_REQUIRED",
            changed.GetProperty("readiness").GetProperty("missingRequirements")
                .EnumerateArray().Select(item => item.GetString()));
        var timeline = await client.GetJsonAsync<JsonElement>(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}/timeline");
        Assert.Single(timeline.GetProperty("items").EnumerateArray(),
            item => item.GetProperty("eventType").GetString() == "RouteInvalidated");
    }

    [Fact]
    public async Task IdenticalStopResubmissionPreservesRouteAndAssignmentReadiness()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = await CreateClientAsync(client, "Idempotent route");
        var ready = await RouteTestData.CreateReadyTripAsync(client, clientId);
        var routeId = ready.GetProperty("routePlan").GetProperty("id").GetGuid();
        var stops = ready.GetProperty("stops").EnumerateArray().Select(stop => new
        {
            sequence = stop.GetProperty("sequence").GetInt32(),
            type = stop.GetProperty("type").GetString(),
            name = stop.GetProperty("name").GetString(),
            address = stop.GetProperty("address").GetString(),
            latitude = stop.GetProperty("latitude").GetDecimal(),
            longitude = stop.GetProperty("longitude").GetDecimal()
        }).ToArray();

        var resubmitted = await (await client.PutAsJsonAsync(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}/stops",
            new
            {
                expectedVersion = ready.GetProperty("version").GetInt64(),
                stops
            }, TestContext.Current.CancellationToken)).RequiredJsonAsync();

        Assert.Equal(routeId,
            resubmitted.GetProperty("routePlan").GetProperty("id").GetGuid());
        Assert.True(resubmitted.GetProperty("readiness").GetProperty("canAssign").GetBoolean());
        Assert.Equal(ready.GetProperty("version").GetInt64(),
            resubmitted.GetProperty("version").GetInt64());

        var detailsOnly = await (await client.PutAsJsonAsync(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}", new
            {
                clientId,
                cargoDescription = "Updated cargo label",
                plannedStartAt = DateTimeOffset.UtcNow.AddDays(2),
                price = 1400m,
                notes = "Non-route edit",
                expectedVersion = resubmitted.GetProperty("version").GetInt64()
            }, TestContext.Current.CancellationToken)).RequiredJsonAsync();
        Assert.Equal(routeId,
            detailsOnly.GetProperty("routePlan").GetProperty("id").GetGuid());

        var renamedStops = stops.Select(stop => new
        {
            stop.sequence,
            stop.type,
            name = $"Renamed {stop.name}",
            address = $"Updated {stop.address}",
            stop.latitude,
            stop.longitude
        }).ToArray();
        var displayOnly = await (await client.PutAsJsonAsync(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}/stops",
            new
            {
                expectedVersion = detailsOnly.GetProperty("version").GetInt64(),
                stops = renamedStops
            }, TestContext.Current.CancellationToken)).RequiredJsonAsync();
        Assert.Equal(routeId,
            displayOnly.GetProperty("routePlan").GetProperty("id").GetGuid());
        var timeline = await client.GetJsonAsync<JsonElement>(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}/timeline");
        Assert.DoesNotContain(timeline.GetProperty("items").EnumerateArray(),
            item => item.GetProperty("eventType").GetString() == "RouteInvalidated");

        var suffix = Guid.NewGuid().ToString("N")[..10];
        var truckId = (await (await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"IDM-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var driverId = (await (await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"Idempotent Driver {suffix}",
            licenseNumber = $"IDM-{suffix}"
        })).RequiredJsonAsync()).GetProperty("id").GetGuid();
        var assigned = await client.PostJsonAsync(
            $"/api/trips/{ready.GetProperty("id").GetGuid()}/assign",
            new { truckId, driverId });
        Assert.Equal(HttpStatusCode.OK, assigned.StatusCode);
    }

    [Fact]
    public async Task TimelineAndLifecycleMutationsAreTenantIsolated()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var clientId = await CreateClientAsync(companyA, "Tenant audit");
        var draft = await (await companyA.PostJsonAsync("/api/trips",
            new { clientId, cargoDescription = "Private draft" })).RequiredJsonAsync();
        var id = draft.GetProperty("id").GetGuid();

        Assert.Equal(HttpStatusCode.NotFound,
            (await companyB.GetAsync($"/api/trips/{id}/timeline",
                TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await companyB.PostEmptyAsync($"/api/trips/{id}/duplicate")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await companyB.DeleteAsync($"/api/trips/{id}/draft",
                TestContext.Current.CancellationToken)).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await companyA.GetAsync($"/api/trips/{id}",
                TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task AssignmentOptionsExplainEligibilityAndRemainTenantScoped()
    {
        using var companyA = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        using var companyB = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-b@example.test");
        var clientId = await CreateClientAsync(companyA, "Options");
        var target = await RouteTestData.CreateReadyTripAsync(companyA, clientId);
        var reservedTrip = await RouteTestData.CreateReadyTripAsync(companyA, clientId);
        var availableTruck = await CreateTruckAsync(companyA, "OPT-A");
        var maintenanceTruck = await CreateTruckAsync(companyA, "OPT-M");
        var reservedTruck = await CreateTruckAsync(companyA, "OPT-R");
        var availableDriver = await CreateDriverAsync(companyA, "Available");
        var unavailableDriver = await CreateDriverAsync(companyA, "Unavailable");
        var reservedDriver = await CreateDriverAsync(companyA, "Reserved");
        var foreignTruck = await CreateTruckAsync(companyB, "FOREIGN");
        var foreignDriver = await CreateDriverAsync(companyB, "Foreign");
        await companyA.PutAsJsonAsync($"/api/trucks/{maintenanceTruck}/status",
            new { status = "Maintenance" }, TestContext.Current.CancellationToken);
        await companyA.PutAsJsonAsync($"/api/drivers/{unavailableDriver}/status",
            new { status = "Unavailable" }, TestContext.Current.CancellationToken);
        await (await companyA.PostJsonAsync(
            $"/api/trips/{reservedTrip.GetProperty("id").GetGuid()}/assign",
            new { truckId = reservedTruck, driverId = reservedDriver })).RequiredJsonAsync();

        var options = await companyA.GetJsonAsync<JsonElement>(
            $"/api/trips/{target.GetProperty("id").GetGuid()}/assignment-options");
        Assert.True(options.GetProperty("canAssign").GetBoolean());
        var trucks = options.GetProperty("trucks").EnumerateArray().ToArray();
        var drivers = options.GetProperty("drivers").EnumerateArray().ToArray();
        Assert.True(trucks.Single(x => x.GetProperty("id").GetGuid() == availableTruck)
            .GetProperty("isEligible").GetBoolean());
        Assert.Equal("TRUCK_MAINTENANCE", trucks.Single(x =>
            x.GetProperty("id").GetGuid() == maintenanceTruck).GetProperty("reasonCode").GetString());
        var reservedTruckOption = trucks.Single(x => x.GetProperty("id").GetGuid() == reservedTruck);
        Assert.Equal("TRUCK_ALREADY_ASSIGNED", reservedTruckOption.GetProperty("reasonCode").GetString());
        Assert.Equal(reservedTrip.GetProperty("tripNumber").GetString(),
            reservedTruckOption.GetProperty("conflictingTripNumber").GetString());
        Assert.True(drivers.Single(x => x.GetProperty("id").GetGuid() == availableDriver)
            .GetProperty("isEligible").GetBoolean());
        Assert.Equal("DRIVER_NOT_AVAILABLE", drivers.Single(x =>
            x.GetProperty("id").GetGuid() == unavailableDriver).GetProperty("reasonCode").GetString());
        Assert.Equal("DRIVER_ALREADY_ASSIGNED", drivers.Single(x =>
            x.GetProperty("id").GetGuid() == reservedDriver).GetProperty("reasonCode").GetString());
        Assert.DoesNotContain(trucks, x => x.GetProperty("id").GetGuid() == foreignTruck);
        Assert.DoesNotContain(drivers, x => x.GetProperty("id").GetGuid() == foreignDriver);
        Assert.Equal(HttpStatusCode.NotFound,
            (await companyB.GetAsync(
                $"/api/trips/{target.GetProperty("id").GetGuid()}/assignment-options",
                TestContext.Current.CancellationToken)).StatusCode);
    }

    [Fact]
    public async Task DeleteDuplicateCancelAndTimelineUseAuditedSemantics()
    {
        using var client = await OperationsTestClient.AuthenticatedClientAsync(factory, "owner-a@example.test");
        var clientId = await CreateClientAsync(client, "Lifecycle");
        var source = await RouteTestData.CreateReadyTripAsync(client, clientId);
        var sourceId = source.GetProperty("id").GetGuid();
        var duplicate = await (await client.PostEmptyAsync($"/api/trips/{sourceId}/duplicate")).RequiredJsonAsync();
        Assert.NotEqual(source.GetProperty("tripNumber").GetString(), duplicate.GetProperty("tripNumber").GetString());
        Assert.Equal(JsonValueKind.Null, duplicate.GetProperty("routePlan").ValueKind);
        Assert.Null(duplicate.GetProperty("truckId").GetString());
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.DeleteAsync($"/api/trips/{duplicate.GetProperty("id").GetGuid()}/draft",
                TestContext.Current.CancellationToken)).StatusCode);

        var missingReason = await client.PostJsonAsync($"/api/trips/{sourceId}/cancel", new { reason = "" });
        Assert.Equal(HttpStatusCode.BadRequest, missingReason.StatusCode);
        Assert.Equal("TRIP_CANCEL_REASON_REQUIRED",
            (await missingReason.Content.ReadFromJsonAsync<JsonElement>(
                TestContext.Current.CancellationToken)).GetProperty("errorCode").GetString());
        var cancelled = await (await client.PostJsonAsync($"/api/trips/{sourceId}/cancel",
            new { reason = "Customer changed the schedule" })).RequiredJsonAsync();
        Assert.Equal("Cancelled", cancelled.GetProperty("status").GetString());
        var archived = await (await client.PostEmptyAsync($"/api/trips/{sourceId}/archive")).RequiredJsonAsync();
        Assert.True(archived.GetProperty("isArchived").GetBoolean());
        await (await client.PostEmptyAsync($"/api/trips/{sourceId}/unarchive")).RequiredJsonAsync();
        var timeline = await client.GetJsonAsync<JsonElement>($"/api/trips/{sourceId}/timeline");
        var eventTypes = timeline.GetProperty("items").EnumerateArray()
            .Select(x => x.GetProperty("eventType").GetString()).ToArray();
        Assert.Contains("TripCreated", eventTypes);
        Assert.Contains("Cancelled", eventTypes);
        Assert.Contains("Archived", eventTypes);
        Assert.All(timeline.GetProperty("items").EnumerateArray().Where(x => x.GetProperty("source").GetString() == "User"),
            item => Assert.NotEqual(JsonValueKind.Null, item.GetProperty("actorUserId").ValueKind));
    }

    private static async Task<Guid> CreateClientAsync(HttpClient client, string prefix)
    {
        var response = await client.PostJsonAsync("/api/clients", new
        {
            name = $"{prefix}-{Guid.NewGuid():N}"
        });
        return (await response.RequiredJsonAsync()).GetProperty("id").GetGuid();
    }

    private static async Task<Guid> CreateTruckAsync(HttpClient client, string prefix)
    {
        var response = await client.PostJsonAsync("/api/trucks", new
        {
            plateNumber = $"{prefix}-{Guid.NewGuid():N}"[..Math.Min(18, prefix.Length + 11)]
        });
        return (await response.RequiredJsonAsync()).GetProperty("id").GetGuid();
    }

    private static async Task<Guid> CreateDriverAsync(HttpClient client, string prefix)
    {
        var suffix = Guid.NewGuid().ToString("N")[..10];
        var response = await client.PostJsonAsync("/api/drivers", new
        {
            fullName = $"{prefix} Driver {suffix}",
            licenseNumber = $"{prefix}-{suffix}"
        });
        return (await response.RequiredJsonAsync()).GetProperty("id").GetGuid();
    }
}
