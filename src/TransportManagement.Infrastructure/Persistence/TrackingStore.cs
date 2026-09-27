using Microsoft.EntityFrameworkCore;
using System.Data;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class TrackingStore(AppDbContext dbContext) : ITrackingStore
{
    public async Task<IReadOnlyList<TruckPosition>> LatestPositionsAsync(CancellationToken cancellationToken)
    {
        var projected = await dbContext.TruckCurrentPositions.AsNoTracking()
            .Join(dbContext.TruckPositions.AsNoTracking(), current => current.PositionId,
                position => position.Id, (_, position) => position)
            .ToListAsync(cancellationToken);
        var projectedTruckIds = projected.Select(x => x.TruckId).ToHashSet();
        var legacy = await dbContext.TruckPositions.AsNoTracking()
            .Where(x => !projectedTruckIds.Contains(x.TruckId))
            .ToListAsync(cancellationToken);
        return projected.Concat(legacy.GroupBy(x => x.TruckId)
            .Select(group => group.OrderByDescending(x => x.RecordedAt)
                .ThenByDescending(x => x.Id).First())).ToArray();
    }

    public async Task<TruckPosition?> LatestPositionAsync(
        Guid truckId, CancellationToken cancellationToken)
    {
        var projected = await dbContext.TruckCurrentPositions.AsNoTracking()
            .Where(x => x.TruckId == truckId)
            .Join(dbContext.TruckPositions.AsNoTracking(), current => current.PositionId,
                position => position.Id, (_, position) => position)
            .SingleOrDefaultAsync(cancellationToken);
        return projected ?? await dbContext.TruckPositions.AsNoTracking()
            .Where(x => x.TruckId == truckId).OrderByDescending(x => x.RecordedAt)
            .ThenByDescending(x => x.Id).FirstOrDefaultAsync(cancellationToken);
    }

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

    public async Task<PositionIngestionOutcome> IngestAsync(
        TruckPosition position, DateTimeOffset projectedAt,
        CancellationToken cancellationToken)
    {
        if (position.CompanyId != dbContext.CurrentCompanyId)
            throw new InvalidOperationException("Cannot ingest another tenant's position.");
        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable, cancellationToken) : null;
        var current = await dbContext.TruckCurrentPositions
            .SingleOrDefaultAsync(x => x.TruckId == position.TruckId, cancellationToken);
        TruckPosition? previous = null;
        if (current is not null)
            previous = await dbContext.TruckPositions.AsNoTracking()
                .SingleAsync(x => x.Id == current.PositionId, cancellationToken);

        if (previous is not null && SamePacket(previous, position))
        {
            if (transaction is not null) await transaction.CommitAsync(cancellationToken);
            return PositionIngestionOutcome.DuplicateIgnored;
        }

        dbContext.TruckPositions.Add(position);
        PositionIngestionOutcome outcome;
        if (previous is null || position.RecordedAt > previous.RecordedAt)
        {
            if (current is null)
                dbContext.TruckCurrentPositions.Add(new TruckCurrentPosition(
                    position.CompanyId, position, projectedAt));
            else
                current.Advance(position, projectedAt);
            outcome = PositionIngestionOutcome.AcceptedCurrent;
        }
        else
            outcome = position.RecordedAt < previous.RecordedAt
                ? PositionIngestionOutcome.StoredOlderHistory
                : PositionIngestionOutcome.StoredEqualConflict;

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
        return outcome;
    }

    private static bool SamePacket(TruckPosition left, TruckPosition right) =>
        left.TruckId == right.TruckId
        && left.TrackingRunId == right.TrackingRunId
        && left.RecordedAt == right.RecordedAt
        && left.Latitude == right.Latitude && left.Longitude == right.Longitude
        && left.Speed == right.Speed && left.Heading == right.Heading
        && left.IsOnline == right.IsOnline
        && left.TripId == right.TripId && left.RoutePlanId == right.RoutePlanId
        && left.RepositioningPlanId == right.RepositioningPlanId
        && left.MovementPhase == right.MovementPhase
        && string.Equals(left.Source, right.Source, StringComparison.Ordinal);

    public async Task SaveChangesAsync(CancellationToken cancellationToken) => await dbContext.SaveChangesAsync(cancellationToken);
}
