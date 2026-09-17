using TransportManagement.Domain.Tracking;

namespace TransportManagement.Application.Abstractions;

public interface ITrackingStore
{
    Task<IReadOnlyList<TruckPosition>> LatestPositionsAsync(CancellationToken cancellationToken);
    Task<TruckPosition?> LatestPositionAsync(Guid truckId, CancellationToken cancellationToken);
    Task<IReadOnlyList<TruckPosition>> HistoryAsync(Guid truckId, int limit, CancellationToken cancellationToken);
    void AddPositions(IEnumerable<TruckPosition> positions);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
