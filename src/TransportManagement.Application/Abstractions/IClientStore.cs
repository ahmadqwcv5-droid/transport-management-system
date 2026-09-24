using TransportManagement.Domain.Clients;

namespace TransportManagement.Application.Abstractions;

public interface IClientStore
{
    Task<Client?> GetClientAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Client>> ListClientsAsync(
        bool? isActive, string? search, ClientLifecycleStatus? lifecycle,
        CancellationToken cancellationToken);
    Task<IReadOnlyList<ClientContact>> ListClientContactsAsync(Guid clientId, CancellationToken cancellationToken);
    Task<ClientContact?> GetClientContactAsync(Guid clientId, Guid contactId, CancellationToken cancellationToken);
    void AddClientContact(ClientContact contact);
    void RemoveClientContact(ClientContact contact);
    Task<IReadOnlyList<ClientSite>> ListClientSitesAsync(Guid clientId, bool? isActive, string? search, CancellationToken cancellationToken);
    Task<ClientSite?> GetClientSiteAsync(Guid clientId, Guid siteId, CancellationToken cancellationToken);
    void AddClientSite(ClientSite site);
    Task<IReadOnlyList<ClientEvent>> ListClientEventsAsync(Guid clientId, int limit, CancellationToken cancellationToken);
    void AddClientEvent(ClientEvent clientEvent);
    Task<IReadOnlyList<TransportManagement.Domain.Trips.Trip>> ListClientTripsAsync(Guid clientId, int limit, CancellationToken cancellationToken);
    Task<bool> ClientHasTripsAsync(Guid clientId, CancellationToken cancellationToken);
    void AddClient(Client client);
    void RemoveClient(Client client);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
