using TransportManagement.Application.Trips;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Abstractions;

public interface IFleetStore
{
    Task<Truck?> GetTruckAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Truck>> ListTrucksAsync(
        TruckStatus? status, bool? isActive, string? search, CancellationToken cancellationToken);
    Task<bool> PlateExistsAsync(string plateNumber, Guid? excludingId, CancellationToken cancellationToken);
    Task<bool> TruckReservedAsync(Guid truckId, Guid? excludingTripId, CancellationToken cancellationToken);
    Task<IReadOnlyList<ResourceReservation>> TruckReservationsAsync(
        Guid excludingTripId, CancellationToken cancellationToken);
    void AddTruck(Truck truck);

    Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Driver>> ListDriversAsync(
        DriverStatus? status, bool? isActive, string? search, CancellationToken cancellationToken);
    Task<bool> LicenseExistsAsync(string licenseNumber, Guid? excludingId, CancellationToken cancellationToken);
    Task<bool> DriverReservedAsync(Guid driverId, Guid? excludingTripId, CancellationToken cancellationToken);
    Task<IReadOnlyList<ResourceReservation>> DriverReservationsAsync(
        Guid excludingTripId, CancellationToken cancellationToken);
    void AddDriver(Driver driver);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
