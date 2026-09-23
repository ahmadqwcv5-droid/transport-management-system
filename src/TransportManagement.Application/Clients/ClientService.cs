using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Clients;

namespace TransportManagement.Application.Clients;

public sealed class ClientService(IClientStore store, ICurrentUser currentUser, IClock clock)
{
    public async Task<ClientResponse> CreateAsync(ClientRequest request, CancellationToken cancellationToken)
    {
        var client = new Client(
            Guid.NewGuid(), currentUser.CompanyId, request.Name, request.ContactPerson,
            request.Phone, request.Email, request.Address, request.Notes, clock.UtcNow);
        store.AddClient(client);
        await store.SaveChangesAsync(cancellationToken);
        return Map(client);
    }

    public async Task<ClientResponse> UpdateAsync(Guid id, ClientRequest request, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(id, cancellationToken);
        client.Update(request.Name, request.ContactPerson, request.Phone, request.Email, request.Address, request.Notes, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(client);
    }

    public async Task<ClientResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        Map(await RequiredAsync(id, cancellationToken));

    public async Task<IReadOnlyList<ClientResponse>> ListAsync(bool? isActive, string? search, CancellationToken cancellationToken) =>
        (await store.ListClientsAsync(isActive, search, cancellationToken)).Select(Map).ToArray();

    public async Task DeactivateAsync(Guid id, CancellationToken cancellationToken)
    {
        var client = await RequiredAsync(id, cancellationToken);
        client.Deactivate(clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task<Client> RequiredAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetClientAsync(id, cancellationToken)
        ?? throw new NotFoundException("Client was not found.");

    private static ClientResponse Map(Client client) => new(
        client.Id, client.Name, client.ContactPerson, client.Phone, client.Email,
        client.Address, client.Notes, client.IsActive, client.CreatedAt, client.UpdatedAt);
}
