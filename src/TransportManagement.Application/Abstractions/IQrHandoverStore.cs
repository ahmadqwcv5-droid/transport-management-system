using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface IQrHandoverStore
{
    Task<Truck?> FindTruckAsync(Guid truckId, CancellationToken cancellationToken);
    Task<Driver?> FindDriverAsync(Guid driverId, CancellationToken cancellationToken);
    Task<Driver?> FindDriverByAccountAsync(Guid accountId, CancellationToken cancellationToken);
    Task<TruckQrCredential?> FindActiveQrForTruckAsync(
        Guid truckId, CancellationToken cancellationToken);
    Task<TruckQrCredential?> FindActiveQrByHashAsync(
        string tokenHash, CancellationToken cancellationToken);
    Task<DriverTruckSession?> FindActiveSessionForDriverAsync(
        Guid driverId, CancellationToken cancellationToken);
    Task<DriverTruckSession?> FindActiveSessionForTruckAsync(
        Guid truckId, CancellationToken cancellationToken);
    Task<Trip?> FindCurrentTripForTruckAsync(
        Guid truckId, CancellationToken cancellationToken);
    Task<Trip?> FindTripAsync(Guid tripId, CancellationToken cancellationToken);
    Task<TripDriverParticipation?> FindActiveParticipationAsync(
        Guid tripId, CancellationToken cancellationToken);
    Task<TripHandoverRequest?> FindHandoverAsync(
        Guid requestId, CancellationToken cancellationToken);
    Task<TripHandoverRequest?> FindPendingHandoverAsync(
        Guid tripId, CancellationToken cancellationToken);
    Task<IReadOnlyList<TripHandoverRequest>> ListHandoversAsync(
        CancellationToken cancellationToken);
    Task<TruckPosition?> FindLatestPositionAsync(
        Guid truckId, CancellationToken cancellationToken);
    void AddQr(TruckQrCredential credential);
    void AddSession(DriverTruckSession session);
    void AddHandover(TripHandoverRequest request);
    void AddParticipation(TripDriverParticipation participation);
    void AddTripEvent(TripEvent tripEvent);
    void AddTruckEvent(TruckEvent truckEvent);
    void AddNotification(OperationNotification notification);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
