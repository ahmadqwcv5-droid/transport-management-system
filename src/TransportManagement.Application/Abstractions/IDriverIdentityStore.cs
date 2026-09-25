using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface IDriverIdentityStore
{
    Task<Driver?> GetDriverByUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<User?> GetUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<Trip?> GetCurrentTripAsync(Guid driverId, CancellationToken cancellationToken);
    Task<Trip?> GetTripAsync(Guid tripId, CancellationToken cancellationToken);
    Task<DriverTruckSession?> GetActiveSessionAsync(Guid driverId, CancellationToken cancellationToken);
    Task<IReadOnlyList<DriverTruckSession>> GetConflictingSessionsAsync(
        Guid driverId, Guid truckId, CancellationToken cancellationToken);
    void AddSession(DriverTruckSession session);
    Task<bool> UserLinkedAsync(Guid userId, Guid? excludingDriverId, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
