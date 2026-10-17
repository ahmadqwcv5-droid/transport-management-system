using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Drivers;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class DriverTripHistoryStore(AppDbContext dbContext)
    : IDriverTripHistoryStore
{
    public async Task<(IReadOnlyList<DriverTripHistoryListRecord> Items,
        int TotalCount)> QueryAsync(Guid driverId, DriverTripHistoryQuery query,
        CancellationToken cancellationToken)
    {
        var source = dbContext.Trips.AsNoTracking().Where(trip =>
            dbContext.TripDriverParticipations.Any(participation =>
                participation.TripId == trip.Id &&
                participation.DriverId == driverId));

        source = query.Category.Trim().ToLowerInvariant() switch
        {
            "current" => source.Where(trip =>
                trip.Status == TripStatus.EnRouteToPickup ||
                trip.Status == TripStatus.AtPickup ||
                trip.Status == TripStatus.Started ||
                trip.Status == TripStatus.InTransit ||
                trip.Status == TripStatus.AtDelivery ||
                trip.Status == TripStatus.Delivered),
            "upcoming" => source.Where(trip => trip.Status == TripStatus.Assigned),
            "completed" => source.Where(trip => trip.Status == TripStatus.Completed),
            "cancelled" => source.Where(trip => trip.Status == TripStatus.Cancelled),
            _ => source.Where(_ => false)
        };

        if (query.From.HasValue)
            source = source.Where(trip =>
                (trip.PlannedStartAt ?? trip.CreatedAt) >= query.From.Value);
        if (query.To.HasValue)
            source = source.Where(trip =>
                (trip.PlannedStartAt ?? trip.CreatedAt) <= query.To.Value);

        var total = await source.CountAsync(cancellationToken);
        var items = await source
            .OrderByDescending(trip => trip.PlannedStartAt ?? trip.CreatedAt)
            .ThenByDescending(trip => trip.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .Select(trip => new DriverTripHistoryListRecord(
                trip.Id,
                trip.TripNumber,
                trip.Status,
                trip.PlannedStartAt,
                trip.ActualStartAt,
                trip.ArrivedPickupAt,
                trip.ArrivedDeliveryAt,
                trip.CompletedAt,
                trip.CancelledAt,
                trip.TruckId == null ? null : dbContext.Trucks
                    .Where(truck => truck.Id == trip.TruckId)
                    .Select(truck => truck.PlateNumber)
                    .SingleOrDefault(),
                dbContext.Clients.Where(client => client.Id == trip.ClientId)
                    .Select(client => client.Name).SingleOrDefault(),
                trip.Origin,
                trip.Destination,
                trip.RoutePlan == null ? null : trip.RoutePlan.DistanceMeters,
                trip.RoutePlan == null ? null : trip.RoutePlan.EstimatedDurationSeconds,
                dbContext.TripDriverParticipations
                    .Where(participation => participation.TripId == trip.Id &&
                        participation.DriverId == driverId)
                    .OrderBy(participation => participation.StartedAt)
                    .Select(participation => participation.StartedAt).First(),
                dbContext.TripDriverParticipations
                    .Where(participation => participation.TripId == trip.Id &&
                        participation.DriverId == driverId)
                    .OrderByDescending(participation => participation.StartedAt)
                    .Select(participation => participation.EndedAt).First(),
                dbContext.TripDriverParticipations
                    .Where(participation => participation.TripId == trip.Id &&
                        participation.DriverId == driverId)
                    .OrderBy(participation => participation.StartedAt)
                    .Select(participation => participation.Source).First()))
            .ToListAsync(cancellationToken);
        return (items, total);
    }

    public async Task<DriverTripHistoryDetailRecord?> DetailAsync(
        Guid driverId, Guid tripId, CancellationToken cancellationToken)
    {
        var authorized = await dbContext.TripDriverParticipations.AsNoTracking()
            .AnyAsync(participation => participation.TripId == tripId &&
                participation.DriverId == driverId, cancellationToken);
        if (!authorized) return null;

        var trip = await dbContext.Trips.AsNoTracking()
            .Include(item => item.Stops)
            .Include(item => item.RoutePlan)
            .SingleOrDefaultAsync(item => item.Id == tripId, cancellationToken);
        if (trip is null) return null;

        var participations = await dbContext.TripDriverParticipations.AsNoTracking()
            .Where(item => item.TripId == tripId && item.DriverId == driverId)
            .OrderBy(item => item.StartedAt)
            .ToListAsync(cancellationToken);
        var events = await dbContext.TripEvents.AsNoTracking()
            .Where(item => item.TripId == tripId)
            .OrderBy(item => item.OccurredAt)
            .ThenBy(item => item.Id)
            .ToListAsync(cancellationToken);
        var clientName = await dbContext.Clients.AsNoTracking()
            .Where(client => client.Id == trip.ClientId)
            .Select(client => client.Name)
            .SingleOrDefaultAsync(cancellationToken);
        var truckPlate = trip.TruckId is null ? null : await dbContext.Trucks
            .AsNoTracking().Where(truck => truck.Id == trip.TruckId)
            .Select(truck => truck.PlateNumber)
            .SingleOrDefaultAsync(cancellationToken);
        return new(trip, truckPlate, clientName, participations, events);
    }

    public async Task<IReadOnlyList<TruckPosition>> TrailCandidatesAsync(
        Guid tripId, Guid truckId, int limit,
        CancellationToken cancellationToken)
    {
        var newest = await dbContext.TruckPositions.AsNoTracking()
            .Where(position => position.TripId == tripId &&
                position.TruckId == truckId)
            .OrderByDescending(position => position.RecordedAt)
            .ThenByDescending(position => position.Id)
            .Take(limit)
            .ToListAsync(cancellationToken);
        newest.Reverse();
        return newest;
    }
}
