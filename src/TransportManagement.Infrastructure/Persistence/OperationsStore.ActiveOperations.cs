using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Dashboard;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed partial class OperationsStore
{
    public async Task<(IReadOnlyList<ActiveOperationSource> Items, int TotalCount)> QueryAsync(
        ActiveOperationsQuery request, int candidateLimit,
        CancellationToken cancellationToken)
    {
        IQueryable<Trip> source = dbContext.Trips.AsNoTracking()
            .Where(x => !x.ArchivedAt.HasValue && ReservedStatuses.Contains(x.Status));
        if (request.ClientId.HasValue) source = source.Where(x => x.ClientId == request.ClientId);
        if (request.TruckId.HasValue) source = source.Where(x => x.TruckId == request.TruckId);
        if (request.DriverId.HasValue) source = source.Where(x => x.DriverId == request.DriverId);
        source = ApplyPhase(source, request.Phase);
        source = ApplySearch(source, request.Search);

        var total = await source.CountAsync(cancellationToken);
        var cores = await source.OrderByDescending(x => x.UpdatedAt).ThenBy(x => x.Id)
            .Take(Math.Clamp(candidateLimit, 1, 500))
            .Select(x => new ActiveCore(
                x.Id, x.TripNumber, x.ClientId, x.TruckId, x.DriverId,
                x.Status, x.UpdatedAt,
                dbContext.TripStops.Where(s => s.TripId == x.Id)
                    .OrderBy(s => s.Sequence).Select(s => s.Name).FirstOrDefault(),
                dbContext.TripStops.Where(s => s.TripId == x.Id)
                    .OrderByDescending(s => s.Sequence).Select(s => s.Name).FirstOrDefault(),
                dbContext.TripRoutePlans.Where(r => r.TripId == x.Id)
                    .Select(r => r.Geometry).FirstOrDefault(),
                dbContext.TripRoutePlans.Where(r => r.TripId == x.Id)
                    .Select(r => (decimal?)r.DistanceMeters).FirstOrDefault(),
                dbContext.TripRepositioningPlans
                    .Where(r => r.TripId == x.Id &&
                        (r.Status == RepositioningPlanStatus.Proposed ||
                         r.Status == RepositioningPlanStatus.Active))
                    .OrderByDescending(r => r.CalculatedAt)
                    .Select(r => r.Geometry).FirstOrDefault(),
                dbContext.TripRepositioningPlans
                    .Where(r => r.TripId == x.Id &&
                        (r.Status == RepositioningPlanStatus.Proposed ||
                         r.Status == RepositioningPlanStatus.Active))
                    .OrderByDescending(r => r.CalculatedAt)
                    .Select(r => (decimal?)r.DistanceMeters).FirstOrDefault()))
            .ToListAsync(cancellationToken);
        if (cores.Count == 0) return ([], total);

        var clientIds = cores.Select(x => x.ClientId).Distinct().ToArray();
        var truckIds = cores.Where(x => x.TruckId.HasValue)
            .Select(x => x.TruckId!.Value).Distinct().ToArray();
        var driverIds = cores.Where(x => x.DriverId.HasValue)
            .Select(x => x.DriverId!.Value).Distinct().ToArray();
        var clients = await dbContext.Clients.AsNoTracking()
            .Where(x => clientIds.Contains(x.Id))
            .Select(x => new { x.Id, x.Name })
            .ToDictionaryAsync(x => x.Id, cancellationToken);
        var trucks = await dbContext.Trucks.AsNoTracking()
            .Where(x => truckIds.Contains(x.Id))
            .Select(x => new { x.Id, x.PlateNumber, x.FleetCode })
            .ToDictionaryAsync(x => x.Id, cancellationToken);
        var drivers = await dbContext.Drivers.AsNoTracking()
            .Where(x => driverIds.Contains(x.Id))
            .Select(x => new { x.Id, x.FullName })
            .ToDictionaryAsync(x => x.Id, cancellationToken);
        var photos = await dbContext.TruckPhotos.AsNoTracking()
            .Where(x => truckIds.Contains(x.TruckId))
            .Select(x => new { x.TruckId, x.Version })
            .ToDictionaryAsync(x => x.TruckId, cancellationToken);
        var latestTimes = dbContext.TruckPositions
            .Where(x => truckIds.Contains(x.TruckId))
            .GroupBy(x => x.TruckId)
            .Select(group => new
            {
                TruckId = group.Key,
                RecordedAt = group.Max(x => x.RecordedAt)
            });
        var positions = await dbContext.TruckPositions.AsNoTracking()
            .Where(x => truckIds.Contains(x.TruckId))
            .Join(latestTimes,
                position => new { position.TruckId, position.RecordedAt },
                latest => new { latest.TruckId, latest.RecordedAt },
                (position, _) => position)
            .Select(x => new PositionProjection(x.TruckId, x.TripId,
                x.Latitude, x.Longitude, x.Speed, x.IsOnline, x.RecordedAt))
            .ToDictionaryAsync(x => x.TruckId, cancellationToken);

        return (cores.Select(x =>
        {
            var truck = x.TruckId.HasValue ? trucks.GetValueOrDefault(x.TruckId.Value) : null;
            var driver = x.DriverId.HasValue ? drivers.GetValueOrDefault(x.DriverId.Value) : null;
            var photo = x.TruckId.HasValue ? photos.GetValueOrDefault(x.TruckId.Value) : null;
            var position = x.TruckId.HasValue ? positions.GetValueOrDefault(x.TruckId.Value) : null;
            return new ActiveOperationSource(x.TripId, x.TripNumber, x.ClientId,
                clients.GetValueOrDefault(x.ClientId)?.Name ?? string.Empty,
                x.TruckId, truck?.PlateNumber, truck?.FleetCode, photo?.Version,
                x.DriverId, driver?.FullName, x.Status, x.UpdatedAt,
                x.PickupName, x.DeliveryName, x.CargoGeometry, x.CargoDistance,
                x.ApproachGeometry, x.ApproachDistance, position?.TripId,
                position?.Latitude, position?.Longitude, position?.Speed,
                position?.IsOnline, position?.RecordedAt);
        }).ToArray(), total);
    }

    private static IQueryable<Trip> ApplyPhase(IQueryable<Trip> source, string? phase) =>
        string.IsNullOrWhiteSpace(phase) ? source : phase.Trim().ToLowerInvariant() switch
        {
            "awaitingdeparture" => source.Where(x => x.Status == TripStatus.Assigned),
            "topickup" => source.Where(x => x.Status == TripStatus.EnRouteToPickup),
            "awaitingloading" => source.Where(x => x.Status == TripStatus.AtPickup),
            "todelivery" => source.Where(x => x.Status == TripStatus.Started || x.Status == TripStatus.InTransit),
            "awaitingdeliveryconfirmation" => source.Where(x => x.Status == TripStatus.AtDelivery),
            "awaitingcompletion" => source.Where(x => x.Status == TripStatus.Delivered),
            _ => source.Where(_ => false)
        };

    private IQueryable<Trip> ApplySearch(IQueryable<Trip> source, string? search)
    {
        if (string.IsNullOrWhiteSpace(search)) return source;
        var term = search.Trim();
        if (!dbContext.Database.IsRelational())
            return source.Where(x => x.TripNumber.Contains(term)
                || dbContext.Clients.Any(c => c.Id == x.ClientId && c.Name.Contains(term))
                || x.TruckId.HasValue && dbContext.Trucks.Any(t => t.Id == x.TruckId
                    && (t.PlateNumber.Contains(term) || t.FleetCode != null && t.FleetCode.Contains(term)))
                || x.DriverId.HasValue && dbContext.Drivers.Any(d => d.Id == x.DriverId
                    && d.FullName.Contains(term))
                || dbContext.TripStops.Any(s => s.TripId == x.Id && s.Name.Contains(term)));
        var pattern = $"%{term}%";
        return source.Where(x => EF.Functions.ILike(x.TripNumber, pattern)
            || dbContext.Clients.Any(c => c.Id == x.ClientId && EF.Functions.ILike(c.Name, pattern))
            || x.TruckId.HasValue && dbContext.Trucks.Any(t => t.Id == x.TruckId
                && (EF.Functions.ILike(t.PlateNumber, pattern)
                    || t.FleetCode != null && EF.Functions.ILike(t.FleetCode, pattern)))
            || x.DriverId.HasValue && dbContext.Drivers.Any(d => d.Id == x.DriverId
                && EF.Functions.ILike(d.FullName, pattern))
            || dbContext.TripStops.Any(s => s.TripId == x.Id && EF.Functions.ILike(s.Name, pattern)));
    }

    private sealed record ActiveCore(Guid TripId, string TripNumber, Guid ClientId,
        Guid? TruckId, Guid? DriverId, TripStatus Status, DateTimeOffset UpdatedAt,
        string? PickupName, string? DeliveryName, string? CargoGeometry,
        decimal? CargoDistance, string? ApproachGeometry, decimal? ApproachDistance);

    private sealed record PositionProjection(Guid TruckId, Guid? TripId,
        decimal Latitude, decimal Longitude, decimal Speed, bool IsOnline,
        DateTimeOffset RecordedAt);
}
