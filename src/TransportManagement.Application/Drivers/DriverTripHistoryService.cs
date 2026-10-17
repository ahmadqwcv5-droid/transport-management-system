using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Drivers;

public sealed class DriverTripHistoryService(
    IDriverIdentityStore identities,
    IDriverTripHistoryStore history,
    ICurrentUser currentUser)
{
    private static readonly string[] Categories =
        ["current", "upcoming", "completed", "cancelled"];

    public async Task<DriverTripHistoryPage> QueryAsync(
        DriverTripHistoryQuery query, CancellationToken cancellationToken)
    {
        Validate(query);
        var driver = await RequiredDriverAsync(cancellationToken);
        var (items, total) = await history.QueryAsync(
            driver.Id, query, cancellationToken);
        return new(items.Select(Map).ToArray(), total, query.Page, query.PageSize,
            (int)Math.Ceiling(total / (double)query.PageSize));
    }

    public async Task<DriverTripHistoryDetail> DetailAsync(
        Guid tripId, CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        var record = await history.DetailAsync(
            driver.Id, tripId, cancellationToken)
            ?? throw new NotFoundException(
                "The trip is not available in this Driver history.",
                "DRIVER_TRIP_NOT_FOUND");
        var trip = record.Trip;
        var first = record.Participations[0];
        var last = record.Participations[^1];
        var summary = Map(new DriverTripHistoryListRecord(
            trip.Id, trip.TripNumber, trip.Status, trip.PlannedStartAt,
            trip.ActualStartAt, trip.ArrivedPickupAt, trip.ArrivedDeliveryAt,
            trip.CompletedAt, trip.CancelledAt, record.TruckPlate,
            record.ClientName, trip.Origin, trip.Destination,
            trip.RoutePlan?.DistanceMeters,
            trip.RoutePlan?.EstimatedDurationSeconds,
            first.StartedAt, last.EndedAt, first.Source));

        var authorizedTrail = Array.Empty<DriverTripHistoryPosition>();
        var wasDownsampled = false;
        if (trip.TruckId.HasValue)
        {
            var candidates = await history.TrailCandidatesAsync(
                trip.Id, trip.TruckId.Value, 2000, cancellationToken);
            var authorized = candidates.Where(position =>
                    record.Participations.Any(interval =>
                        position.RecordedAt >= interval.StartedAt &&
                        (!interval.EndedAt.HasValue ||
                         position.RecordedAt <= interval.EndedAt.Value)))
                .ToArray();
            wasDownsampled = authorized.Length > 500;
            var bounded = Downsample(authorized, 500);
            authorizedTrail = bounded.Select(position =>
                new DriverTripHistoryPosition(position.Latitude,
                    position.Longitude, position.Speed, position.Heading,
                    position.RecordedAt, position.IsOnline)).ToArray();
        }

        return new(summary, trip.CargoDescription, trip.CancellationReason,
            trip.Stops.OrderBy(stop => stop.Sequence).Select(stop =>
                new DriverTripHistoryStop(stop.Sequence, stop.Type.ToString(),
                    stop.Name, stop.Address, stop.Latitude, stop.Longitude,
                    stop.PlannedArrivalAt)).ToArray(),
            trip.RoutePlan?.Geometry,
            trip.RoutePlan?.GeometryFormat,
            trip.RoutePlan?.DistanceMeters,
            trip.RoutePlan?.EstimatedDurationSeconds,
            record.Events.Select(item => new DriverTripHistoryEvent(
                item.EventType, item.OccurredAt, item.Source)).ToArray(),
            record.Participations.Select(item =>
                new DriverTripParticipationResponse(item.StartedAt,
                    item.EndedAt, item.Source, item.StartedPhase.ToString(),
                    item.EndedPhase?.ToString())).ToArray(),
            authorizedTrail, wasDownsampled);
    }

    private async Task<Domain.Fleet.Driver> RequiredDriverAsync(
        CancellationToken cancellationToken) =>
        await identities.GetDriverByUserAsync(
            currentUser.UserId, cancellationToken)
        ?? throw new NotFoundException(
            "The signed-in account is not linked to a Driver in this workspace.",
            "DRIVER_LINK_REQUIRED");

    private static void Validate(DriverTripHistoryQuery query)
    {
        if (query.Page < 1 || query.PageSize is < 1 or > 50)
            throw new DomainRuleException(
                "Page must be positive and page size must be between 1 and 50.",
                "INVALID_PAGINATION");
        if (!Categories.Contains(query.Category.Trim().ToLowerInvariant()))
            throw new DomainRuleException(
                "Driver trip category is not supported.",
                "INVALID_DRIVER_TRIP_CATEGORY");
        if (query.From.HasValue && query.To.HasValue && query.From > query.To)
            throw new DomainRuleException(
                "The history date range is invalid.", "INVALID_DATE_RANGE");
    }

    private static DriverTripHistorySummary Map(
        DriverTripHistoryListRecord item) => new(
        item.Id, item.TripNumber, item.Status.ToString(), Category(item.Status),
        item.PlannedStartAt, item.ActualStartAt, item.ArrivedPickupAt,
        item.ArrivedDeliveryAt, item.CompletedAt, item.CancelledAt,
        item.TruckPlate, item.ClientName, item.Origin, item.Destination,
        item.PlannedDistanceMeters, item.PlannedDurationSeconds,
        item.ParticipationStartedAt, item.ParticipationEndedAt,
        item.ParticipationSource);

    private static string Category(TripStatus status) => status switch
    {
        TripStatus.Assigned => "upcoming",
        TripStatus.Completed => "completed",
        TripStatus.Cancelled => "cancelled",
        _ => "current"
    };

    private static IReadOnlyList<Domain.Tracking.TruckPosition> Downsample(
        Domain.Tracking.TruckPosition[] positions, int maximum)
    {
        if (positions.Length <= maximum) return positions;
        var stride = (int)Math.Ceiling(positions.Length / (double)maximum);
        var result = positions.Where((_, index) => index % stride == 0).ToList();
        if (result[^1].Id != positions[^1].Id) result.Add(positions[^1]);
        return result;
    }
}
