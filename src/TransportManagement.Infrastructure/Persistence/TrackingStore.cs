using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class TrackingStore(AppDbContext dbContext) : ITrackingStore
{
    public async Task<IReadOnlyList<TruckPosition>> LatestPositionsAsync(CancellationToken cancellationToken)
    {
        var latestTimes = dbContext.TruckPositions
            .GroupBy(position => position.TruckId)
            .Select(group => new { TruckId = group.Key, RecordedAt = group.Max(x => x.RecordedAt) });
        return await dbContext.TruckPositions.AsNoTracking()
            .Join(latestTimes,
                position => new { position.TruckId, position.RecordedAt },
                latest => new { latest.TruckId, latest.RecordedAt },
                (position, _) => position)
            .ToListAsync(cancellationToken);
    }

    public Task<TruckPosition?> LatestPositionAsync(Guid truckId, CancellationToken cancellationToken) =>
        dbContext.TruckPositions.AsNoTracking().Where(x => x.TruckId == truckId)
            .OrderByDescending(x => x.RecordedAt).FirstOrDefaultAsync(cancellationToken);

    public Task<TruckPosition?> LatestTripPositionAsync(
        Guid tripId, Guid truckId, CancellationToken cancellationToken) =>
        dbContext.TruckPositions.AsNoTracking()
            .Where(x => x.TripId == tripId && x.TruckId == truckId
                && (x.MovementPhase == MovementPhase.Cargo || x.MovementPhase == null))
            .OrderByDescending(x => x.RecordedAt)
            .ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);

    public Task<TruckPosition?> LatestRepositioningPositionAsync(
        Guid tripId, Guid repositioningPlanId, Guid truckId,
        CancellationToken cancellationToken) =>
        dbContext.TruckPositions.AsNoTracking()
            .Where(x => x.TripId == tripId && x.RepositioningPlanId == repositioningPlanId
                && x.TruckId == truckId && x.MovementPhase == MovementPhase.Repositioning)
            .OrderByDescending(x => x.RecordedAt)
            .ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<IReadOnlyList<TruckPosition>> HistoryAsync(Guid truckId, int limit, CancellationToken cancellationToken) =>
        await dbContext.TruckPositions.AsNoTracking().Where(x => x.TruckId == truckId)
            .OrderByDescending(x => x.RecordedAt).Take(limit).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<TruckPosition>> TripHistoryAsync(
        Guid tripId, Guid truckId, int limit, CancellationToken cancellationToken)
    {
        var newest = await dbContext.TruckPositions.AsNoTracking()
            .Where(x => x.TripId == tripId && x.TruckId == truckId)
            .OrderByDescending(x => x.RecordedAt)
            .ThenByDescending(x => x.Id)
            .Take(limit)
            .ToListAsync(cancellationToken);
        newest.Reverse();
        return newest;
    }

    public Task<bool> HasTripHistoryAsync(Guid tripId, CancellationToken cancellationToken) =>
        dbContext.TruckPositions.AsNoTracking()
            .AnyAsync(x => x.TripId == tripId, cancellationToken);

    public void AddPositions(IEnumerable<TruckPosition> positions) => dbContext.TruckPositions.AddRange(positions);
    public async Task SaveChangesAsync(CancellationToken cancellationToken) => await dbContext.SaveChangesAsync(cancellationToken);
}
