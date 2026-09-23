using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed class TripQueryService(
    ITripQueryStore queryStore,
    TripEntityResolver resolver)
{
    public async Task<TripResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        TripResponseMapper.Map(await resolver.TripAsync(id, cancellationToken));

    public async Task<TripPageResponse> QueryAsync(
        TripListQuery query, CancellationToken cancellationToken)
    {
        if (query.Page < 1 || query.PageSize is < 1 or > 100)
            throw new DomainRuleException("Page must be positive and page size must be between 1 and 100.", "INVALID_PAGINATION");
        if (!new[] { "plannedstart", "tripnumber", "created", "status" }.Contains(query.Sort.ToLowerInvariant())
            || !new[] { "asc", "desc" }.Contains(query.Direction.ToLowerInvariant()))
            throw new DomainRuleException("Sort is not supported.", "INVALID_SORT");
        if (!string.IsNullOrWhiteSpace(query.OperationalGroup)
            && !new[] { "active", "planned", "completed", "cancelled", "archived" }
                .Contains(query.OperationalGroup.ToLowerInvariant()))
            throw new DomainRuleException("Operational group is not supported.", "INVALID_TRIP_FILTER");
        var (items, total) = await queryStore.QueryTripsAsync(query, cancellationToken);
        return new(items.Select(TripResponseMapper.Map).ToArray(), total, query.Page, query.PageSize,
            (int)Math.Ceiling(total / (double)query.PageSize));
    }

    public async Task<IReadOnlyList<TripResponse>> ListAsync(
        TripStatus? status, Guid? clientId, Guid? truckId, Guid? driverId,
        DateTimeOffset? plannedFrom, DateTimeOffset? plannedTo,
        CancellationToken cancellationToken) =>
        (await queryStore.ListTripsAsync(status, clientId, truckId, driverId,
            plannedFrom, plannedTo, cancellationToken))
        .Select(TripResponseMapper.Map).ToArray();

    public async Task<TripTimelineResponse> TimelineAsync(
        Guid id, int page, int pageSize, CancellationToken cancellationToken)
    {
        _ = await resolver.TripAsync(id, cancellationToken);
        if (page < 1 || pageSize is < 1 or > 100)
            throw new DomainRuleException("Timeline pagination is invalid.", "INVALID_PAGINATION");
        var (events, total) = await queryStore.ListTripEventsAsync(id, page, pageSize, cancellationToken);
        var items = new List<TripEventResponse>(events.Count);
        foreach (var item in events)
        {
            var actor = item.ActorUserId.HasValue
                ? await queryStore.UserDisplayNameAsync(item.ActorUserId.Value, cancellationToken)
                : null;
            items.Add(new(item.Id, item.EventType, item.OccurredAt, item.ActorUserId,
                actor ?? "System", item.Source, item.Metadata));
        }
        return new(items, total, page, pageSize, (int)Math.Ceiling(total / (double)pageSize));
    }
}
