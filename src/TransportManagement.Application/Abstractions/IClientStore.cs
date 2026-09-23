using TransportManagement.Domain.Clients;

namespace TransportManagement.Application.Abstractions;

public interface IClientStore
{
    Task<Client?> GetClientAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Client>> ListClientsAsync(
        bool? isActive, string? search, CancellationToken cancellationToken);
    void AddClient(Client client);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
