using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Trips;

public sealed class ResourceEventWriter(
    IClientStore clientStore,
    IFleetStore fleetStore,
    ICurrentUser currentUser,
    IClock clock)
{
    public void Client(Guid clientId, string code, object? metadata = null)
    {
        var now = clock.UtcNow;
        clientStore.AddClientEvent(new ClientEvent(Guid.NewGuid(),
            currentUser.CompanyId, clientId, currentUser.UserId, code,
            Serialize(metadata), now));
    }

    public void Truck(Guid truckId, string code, object? metadata = null,
        string source = "User")
    {
        var now = clock.UtcNow;
        fleetStore.AddTruckEvent(new TruckEvent(Guid.NewGuid(),
            currentUser.CompanyId, truckId,
            source == "System" ? null : currentUser.UserId, code,
            Serialize(metadata), now));
    }

    private static string? Serialize(object? value) =>
        value is null ? null : JsonSerializer.Serialize(value);
}
