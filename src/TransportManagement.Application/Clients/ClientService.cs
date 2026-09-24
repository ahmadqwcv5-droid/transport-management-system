using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Clients;

public sealed class ClientService(IClientStore store, IFleetStore fleetStore,
    ICurrentUser currentUser, IClock clock)
{
    public async Task<ClientResponse> CreateAsync(ClientRequest request, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        var client = new Client(Guid.NewGuid(), currentUser.CompanyId, request.Name,
            request.LegalName, request.ContactPerson, request.Phone, request.Email,
            request.Address, request.Notes, now);
        store.AddClient(client);
        Event(client, "ClientCreated", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(client);
    }

    public async Task<ClientResponse> UpdateAsync(Guid id, ClientRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(id, cancellationToken);
        var changed = client.Name != request.Name.Trim()
            || client.LegalName != Normalize(request.LegalName)
            || client.ContactPerson != Normalize(request.ContactPerson)
            || client.Phone != Normalize(request.Phone)
            || client.Email != Normalize(request.Email)?.ToLowerInvariant()
            || client.Address != Normalize(request.Address)
            || client.Notes != Normalize(request.Notes);
        if (!changed) return Map(client);
        var now = clock.UtcNow;
        client.Update(request.Name, request.LegalName, request.ContactPerson,
            request.Phone, request.Email, request.Address, request.Notes, now);
        Event(client, "ClientProfileUpdated", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(client);
    }

    public async Task<ClientResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        Map(await RequiredAsync(id, cancellationToken));

    public async Task<IReadOnlyList<ClientResponse>> ListAsync(bool? isActive,
        string? search, ClientLifecycleStatus? lifecycle, CancellationToken cancellationToken)
    {
        var clients = await store.ListClientsAsync(isActive, search, lifecycle, cancellationToken);
        var result = new List<ClientResponse>(clients.Count);
        foreach (var client in clients)
        {
            var sites = await store.ListClientSitesAsync(client.Id, true, null, cancellationToken);
            var trips = await store.ListClientTripsAsync(client.Id, 100, cancellationToken);
            result.Add(Map(client, sites.Count, trips.Count(IsActiveTrip)));
        }
        return result;
    }

    public async Task<ClientDetailsResponse> DetailsAsync(Guid id, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(id, cancellationToken);
        var contacts = await store.ListClientContactsAsync(id, cancellationToken);
        var sites = await store.ListClientSitesAsync(id, null, null, cancellationToken);
        var trips = await store.ListClientTripsAsync(id, 50, cancellationToken);
        var events = await store.ListClientEventsAsync(id, 50, cancellationToken);
        var tripSummaries = new List<ResourceTripSummaryResponse>(trips.Count);
        foreach (var trip in trips)
            tripSummaries.Add(await MapTripAsync(trip, cancellationToken));
        return new(Map(client, sites.Count(x => x.IsActive), trips.Count(IsActiveTrip)),
            contacts.Select(Map).ToArray(), sites.Select(Map).ToArray(),
            tripSummaries, events.Select(Map).ToArray(),
            trips.Count(x => x.Status is TripStatus.Draft or TripStatus.Assigned),
            trips.Count(IsActiveTrip), trips.Count(x => x.Status == TripStatus.Completed),
            trips.Count(x => x.Status == TripStatus.Cancelled));
    }

    public async Task<ClientResponse> ChangeLifecycleAsync(Guid id,
        ClientLifecycleRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(id, cancellationToken);
        if (client.LifecycleStatus == request.Status) return Map(client);
        var now = clock.UtcNow;
        client.ChangeLifecycle(request.Status, now);
        Event(client, request.Status switch
        {
            ClientLifecycleStatus.Active => "ClientReactivated",
            ClientLifecycleStatus.Suspended => "ClientSuspended",
            _ => "ClientArchived"
        }, null, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(client);
    }

    public async Task DeactivateAsync(Guid id, CancellationToken cancellationToken) =>
        _ = await ChangeLifecycleAsync(id,
            new(ClientLifecycleStatus.Archived), cancellationToken);

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(id, cancellationToken);
        if (client.LifecycleStatus != ClientLifecycleStatus.Archived)
            throw new ConflictException("Archive the client before deletion.", "CLIENT_ARCHIVE_REQUIRED");
        if (await store.ClientHasTripsAsync(id, cancellationToken))
            throw new ConflictException("A client with trip history cannot be deleted.", "CLIENT_HAS_HISTORY");
        store.RemoveClient(client);
        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task<ClientContactResponse> AddContactAsync(Guid clientId,
        ClientContactRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(clientId, cancellationToken);
        var now = clock.UtcNow;
        var existing = await store.ListClientContactsAsync(clientId, cancellationToken);
        if (request.IsPrimary) foreach (var oldContact in existing) oldContact.SetPrimary(false, now);
        var contact = new ClientContact(Guid.NewGuid(), currentUser.CompanyId,
            clientId, request.Name, request.JobTitle, request.Phone, request.WhatsApp,
            request.Email, request.IsPrimary || existing.Count == 0, request.Notes, now);
        store.AddClientContact(contact);
        Event(client, "ClientContactAdded", new { contactId = contact.Id }, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(contact);
    }

    public async Task<ClientContactResponse> UpdateContactAsync(Guid clientId,
        Guid contactId, ClientContactRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(clientId, cancellationToken);
        var contact = await store.GetClientContactAsync(clientId, contactId, cancellationToken)
            ?? throw new NotFoundException("Client contact was not found.");
        var now = clock.UtcNow;
        if (request.IsPrimary)
        {
            var contacts = await store.ListClientContactsAsync(clientId, cancellationToken);
            foreach (var other in contacts.Where(x => x.Id != contactId)) other.SetPrimary(false, now);
        }
        contact.Update(request.Name, request.JobTitle, request.Phone, request.WhatsApp,
            request.Email, request.IsPrimary, request.Notes, now);
        Event(client, request.IsPrimary ? "ClientPrimaryContactChanged" : "ClientContactUpdated",
            new { contactId }, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(contact);
    }

    public async Task DeleteContactAsync(Guid clientId, Guid contactId, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(clientId, cancellationToken);
        var contact = await store.GetClientContactAsync(clientId, contactId, cancellationToken)
            ?? throw new NotFoundException("Client contact was not found.");
        store.RemoveClientContact(contact);
        Event(client, "ClientContactRemoved", new { contactId }, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ClientSiteResponse>> SitesAsync(Guid clientId,
        bool? isActive, string? search, CancellationToken cancellationToken)
    {
        _ = await RequiredAsync(clientId, cancellationToken);
        return (await store.ListClientSitesAsync(clientId, isActive, search, cancellationToken))
            .Select(Map).ToArray();
    }

    public async Task<ClientSiteResponse> AddSiteAsync(Guid clientId,
        ClientSiteRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(clientId, cancellationToken);
        var now = clock.UtcNow;
        var site = new ClientSite(Guid.NewGuid(), currentUser.CompanyId, clientId,
            request.Name, request.Type, request.Address, request.Latitude,
            request.Longitude, request.ContactName, request.ContactPhone,
            request.Instructions, now);
        store.AddClientSite(site);
        Event(client, "ClientSiteAdded", new { siteId = site.Id }, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(site);
    }

    public async Task<ClientSiteResponse> UpdateSiteAsync(Guid clientId, Guid siteId,
        ClientSiteRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(clientId, cancellationToken);
        var site = await store.GetClientSiteAsync(clientId, siteId, cancellationToken)
            ?? throw new NotFoundException("Client site was not found.");
        var now = clock.UtcNow;
        site.Update(request.Name, request.Type, request.Address, request.Latitude,
            request.Longitude, request.ContactName, request.ContactPhone,
            request.Instructions, now);
        Event(client, "ClientSiteUpdated", new { siteId }, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(site);
    }

    public async Task<ClientSiteResponse> SetSiteActiveAsync(Guid clientId,
        Guid siteId, bool active, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(clientId, cancellationToken);
        var site = await store.GetClientSiteAsync(clientId, siteId, cancellationToken)
            ?? throw new NotFoundException("Client site was not found.");
        var now = clock.UtcNow;
        site.SetActive(active, now);
        Event(client, active ? "ClientSiteRestored" : "ClientSiteArchived",
            new { siteId }, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(site);
    }

    private async Task<Client> RequiredAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetClientAsync(id, cancellationToken)
        ?? throw new NotFoundException("Client was not found.");

    private void Event(Client client, string code, object? metadata, DateTimeOffset now) =>
        store.AddClientEvent(new(Guid.NewGuid(), client.CompanyId, client.Id,
            currentUser.UserId, code, metadata is null ? null : JsonSerializer.Serialize(metadata), now));

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static bool IsActiveTrip(Trip trip) => trip.Status is TripStatus.EnRouteToPickup
        or TripStatus.AtPickup or TripStatus.Started or TripStatus.InTransit or TripStatus.Delivered;
    private static ClientResponse Map(Client client, int sites = 0, int trips = 0) => new(
        client.Id, client.Name, client.ContactPerson, client.Phone, client.Email,
        client.Address, client.Notes, client.IsActive, client.CreatedAt, client.UpdatedAt,
        client.LegalName, client.LifecycleStatus, sites, trips);
    private static ClientContactResponse Map(ClientContact x) => new(x.Id, x.ClientId,
        x.Name, x.JobTitle, x.Phone, x.WhatsApp, x.Email, x.IsPrimary, x.Notes,
        x.CreatedAt, x.UpdatedAt);
    private static ClientSiteResponse Map(ClientSite x) => new(x.Id, x.ClientId,
        x.Name, x.Type, x.Address, x.Latitude, x.Longitude, x.ContactName,
        x.ContactPhone, x.Instructions, x.IsActive, x.CreatedAt, x.UpdatedAt);
    private static OperationsEventResponse Map(ClientEvent x) =>
        new(x.Id, x.EventCode, x.Metadata, x.CreatedAt);
    private async Task<ResourceTripSummaryResponse> MapTripAsync(Trip x,
        CancellationToken cancellationToken)
    {
        var truck = x.TruckId is Guid truckId
            ? await fleetStore.GetTruckAsync(truckId, cancellationToken) : null;
        var driver = x.DriverId is Guid driverId
            ? await fleetStore.GetDriverAsync(driverId, cancellationToken) : null;
        return new(x.Id, x.TripNumber, x.Origin, x.Destination,
            x.PlannedStartAt ?? x.CreatedAt, x.Status.ToString(), x.TruckId,
            truck?.PlateNumber, x.DriverId, driver?.FullName);
    }
}
