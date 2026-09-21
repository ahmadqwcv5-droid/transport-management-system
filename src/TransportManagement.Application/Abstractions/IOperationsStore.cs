using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface IOperationsStore
{
    Task<Client?> GetClientAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Client>> ListClientsAsync(bool? isActive, string? search, CancellationToken cancellationToken);
    void AddClient(Client client);

    Task<Truck?> GetTruckAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Truck>> ListTrucksAsync(TruckStatus? status, bool? isActive, string? search, CancellationToken cancellationToken);
    Task<bool> PlateExistsAsync(string plateNumber, Guid? excludingId, CancellationToken cancellationToken);
    Task<bool> TruckReservedAsync(Guid truckId, Guid? excludingTripId, CancellationToken cancellationToken);
    void AddTruck(Truck truck);

    Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Driver>> ListDriversAsync(DriverStatus? status, bool? isActive, string? search, CancellationToken cancellationToken);
    Task<bool> LicenseExistsAsync(string licenseNumber, Guid? excludingId, CancellationToken cancellationToken);
    Task<bool> DriverReservedAsync(Guid driverId, Guid? excludingTripId, CancellationToken cancellationToken);
    void AddDriver(Driver driver);

    Task<Trip?> GetTripAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Trip>> ListTripsAsync(
        TripStatus? status,
        Guid? clientId,
        Guid? truckId,
        Guid? driverId,
        DateTimeOffset? plannedFrom,
        DateTimeOffset? plannedTo,
        CancellationToken cancellationToken);
    void AddTrip(Trip trip);
    void AddRepositioningPlan(TripRepositioningPlan plan);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}
