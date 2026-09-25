using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class Trip : Entity, ITenantOwned
{
    private readonly List<TripStop> _stops = [];
    private readonly List<TripRepositioningPlan> _repositioningPlans = [];
    private readonly List<TripEvent> _events = [];
    private Trip() { }

    public Trip(
        Guid id,
        Guid companyId,
        string tripNumber,
        Guid clientId,
        string cargoDescription,
        DateTimeOffset? plannedStartAt,
        decimal? price,
        string? notes,
        DateTimeOffset now) : base(id, now)
    {
        if (string.IsNullOrWhiteSpace(tripNumber))
            throw new DomainRuleException("Trip number is required.");
        CompanyId = companyId;
        TripNumber = tripNumber;
        ClientId = clientId;
        ApplyDraft(cargoDescription, plannedStartAt, price, notes, now);
        Status = TripStatus.Draft;
        Version = 1;
    }

    public Guid CompanyId { get; private set; }
    public string TripNumber { get; private set; } = string.Empty;
    public Guid ClientId { get; private set; }
    public Guid? TruckId { get; private set; }
    public Guid? DriverId { get; private set; }
    public string? Origin { get; private set; }
    public string? Destination { get; private set; }
    public string CargoDescription { get; private set; } = string.Empty;
    public DateTimeOffset? PlannedStartAt { get; private set; }
    public DateTimeOffset? ActualStartAt { get; private set; }
    public DateTimeOffset? ArrivedPickupAt { get; private set; }
    public DateTimeOffset? ArrivedDeliveryAt { get; private set; }
    public DateTimeOffset? DeliveredAt { get; private set; }
    public DateTimeOffset? CompletedAt { get; private set; }
    public decimal? Price { get; private set; }
    public string? Notes { get; private set; }
    public TripStatus Status { get; private set; }
    public string? CancellationReason { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }
    public Guid? CancelledByUserId { get; private set; }
    public DateTimeOffset? ArchivedAt { get; private set; }
    public Guid? ArchivedByUserId { get; private set; }
    public bool IsArchived => ArchivedAt.HasValue;
    public long Version { get; private set; }
    public IReadOnlyCollection<TripStop> Stops => _stops;
    public IReadOnlyCollection<TripRepositioningPlan> RepositioningPlans => _repositioningPlans;
    public IReadOnlyCollection<TripEvent> Events => _events;
    public TripRoutePlan? RoutePlan { get; private set; }
    public bool IsRouteAware => RoutePlan is not null && _stops.Count >= 2;

    public bool ReservesResources => Status is TripStatus.Assigned or TripStatus.EnRouteToPickup
        or TripStatus.AtPickup or TripStatus.Started
        or TripStatus.InTransit or TripStatus.AtDelivery or TripStatus.Delivered;

    public TripRepositioningPlan? CurrentRepositioningPlan => _repositioningPlans
        .Where(x => x.Status is RepositioningPlanStatus.Proposed or RepositioningPlanStatus.Active)
        .OrderByDescending(x => x.CalculatedAt)
        .FirstOrDefault();

    public bool UpdateDraft(
        Guid clientId,
        string cargoDescription,
        DateTimeOffset? plannedStartAt,
        decimal? price,
        string? notes,
        long expectedVersion,
        DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Draft);
        EnsureVersion(expectedVersion);
        var clientChanged = ClientId != clientId;
        ClientId = clientId;
        return ApplyDraft(cargoDescription, plannedStartAt, price, notes, now)
            || ApplyClientChange(clientChanged, now);
    }

    public void Assign(Guid truckId, Guid driverId, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Draft);
        TruckId = truckId;
        DriverId = driverId;
        Status = TripStatus.Assigned;
        Changed(now);
    }

    public void Reassign(Guid truckId, Guid driverId, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        foreach (var plan in _repositioningPlans) plan.Expire(now);
        TruckId = truckId;
        DriverId = driverId;
        Changed(now);
    }

    public void Unassign(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        foreach (var plan in _repositioningPlans) plan.Expire(now);
        TruckId = null;
        DriverId = null;
        Status = TripStatus.Draft;
        Changed(now);
    }

    public (bool StopsChanged, bool RouteInvalidated) ReplaceStops(
        IReadOnlyCollection<TripStop> stops,
        long expectedVersion,
        DateTimeOffset now,
        bool invalidateRoute = true)
    {
        EnsureStatus(TripStatus.Draft);
        EnsureVersion(expectedVersion);
        ValidateStops(stops, requireCoordinates: false);
        var ordered = stops.OrderBy(x => x.Sequence).ToArray();
        var stopsChanged = false;
        if (_stops.Count == ordered.Length
            && _stops.OrderBy(x => x.Sequence).Select(x => (x.Sequence, x.Type))
                .SequenceEqual(ordered.Select(x => (x.Sequence, x.Type))))
        {
            var existing = _stops.OrderBy(x => x.Sequence).ToArray();
            for (var index = 0; index < existing.Length; index++)
                stopsChanged |= existing[index].UpdateFrom(ordered[index], now);
        }
        else
        {
            _stops.Clear();
            _stops.AddRange(ordered);
            stopsChanged = true;
        }
        var routeInvalidated = stopsChanged && invalidateRoute && RoutePlan is not null;
        if (routeInvalidated) RoutePlan = null;
        if (!stopsChanged) return (false, false);
        Origin = _stops.OrderBy(x => x.Sequence).FirstOrDefault()?.Name;
        Destination = _stops.OrderBy(x => x.Sequence).LastOrDefault()?.Name;
        Changed(now);
        return (true, routeInvalidated);
    }

    public void ReplaceRoute(
        IReadOnlyCollection<TripStop> stops,
        TripRoutePlan routePlan,
        DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Draft);
        ValidateStops(stops, requireCoordinates: true);
        var ordered = stops.OrderBy(x => x.Sequence).ToArray();
        if (routePlan.CompanyId != CompanyId || routePlan.TripId != Id)
            throw new DomainRuleException("Route data does not belong to this trip.", "INVALID_TRIP_ROUTE");

        var pickup = ordered[0];
        var delivery = ordered[^1];
        var latitudeDelta = Math.Abs(pickup.Latitude!.Value - delivery.Latitude!.Value);
        var longitudeDelta = Math.Abs(pickup.Longitude!.Value - delivery.Longitude!.Value);
        if (latitudeDelta < 0.00001m && longitudeDelta < 0.00001m)
            throw new DomainRuleException("Pickup and delivery must be different locations.", "IDENTICAL_TRIP_STOPS");

        RoutePlan = routePlan;
        Origin = pickup.Name;
        Destination = delivery.Name;
        Changed(now);
    }

    public void AddRepositioningPlan(TripRepositioningPlan plan, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        if (plan.CompanyId != CompanyId || plan.TripId != Id || plan.TruckId != TruckId)
            throw new DomainRuleException("Repositioning plan does not belong to this assignment.", "INVALID_TRIP_ROUTE");
        foreach (var existing in _repositioningPlans) existing.Expire(now);
        _repositioningPlans.Add(plan);
        Changed(now);
    }

    public void DispatchToPickup(TripRepositioningPlan plan, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        if (!_repositioningPlans.Contains(plan))
            throw new DomainRuleException("Repositioning route is required.", "REPOSITIONING_ROUTE_REQUIRED");
        plan.Activate(now);
        Status = TripStatus.EnRouteToPickup;
        Changed(now);
    }

    public void DispatchForPickupConfirmation(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        Status = TripStatus.EnRouteToPickup;
        Changed(now);
    }

    public void MarkAtPickup(DateTimeOffset now)
    {
        if (Status == TripStatus.AtPickup) return;
        if (Status != TripStatus.EnRouteToPickup)
            throw new DomainRuleException("Arrival requires a dispatched trip.", "INVALID_TRIP_TRANSITION");
        CurrentRepositioningPlan?.Complete(now);
        ArrivedPickupAt = now;
        Status = TripStatus.AtPickup;
        Changed(now);
    }

    public void Start(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.AtPickup);
        ActualStartAt = now;
        Status = TripStatus.Started;
        Changed(now);
    }

    public void MarkInTransit(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Started);
        Status = TripStatus.InTransit;
        Changed(now);
    }

    public void ConfirmLoaded(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.AtPickup);
        ActualStartAt = now;
        Status = TripStatus.InTransit;
        Changed(now);
    }

    public void MarkAtDelivery(DateTimeOffset now)
    {
        if (Status == TripStatus.AtDelivery) return;
        EnsureStatus(TripStatus.InTransit);
        ArrivedDeliveryAt = now;
        Status = TripStatus.AtDelivery;
        Changed(now);
    }

    public void ConfirmDelivery(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.AtDelivery);
        DeliveredAt = now;
        CompletedAt = now;
        Status = TripStatus.Completed;
        Changed(now);
    }

    public void Deliver(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.InTransit);
        DeliveredAt = now;
        Status = TripStatus.Delivered;
        Changed(now);
    }

    public void Complete(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Delivered);
        CompletedAt = now;
        Status = TripStatus.Completed;
        Changed(now);
    }

    public void Cancel(string reason, Guid actorUserId, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length > 500)
            throw new DomainRuleException("A cancellation reason is required and must not exceed 500 characters.", "TRIP_CANCEL_REASON_REQUIRED");
        if (Status is TripStatus.AtDelivery or TripStatus.Delivered or TripStatus.Completed or TripStatus.Cancelled)
            throw new DomainRuleException($"A {Status} trip cannot be cancelled.", "INVALID_TRIP_TRANSITION");
        foreach (var plan in _repositioningPlans) plan.Expire(now);
        Status = TripStatus.Cancelled;
        CancellationReason = reason.Trim();
        CancelledAt = now;
        CancelledByUserId = actorUserId;
        Changed(now);
    }

    public void Archive(Guid actorUserId, DateTimeOffset now)
    {
        if (Status is not (TripStatus.Completed or TripStatus.Cancelled) || IsArchived)
            throw new DomainRuleException("Only an unarchived completed or cancelled trip may be archived.", "TRIP_ARCHIVE_NOT_ALLOWED");
        ArchivedAt = now;
        ArchivedByUserId = actorUserId;
        Changed(now);
    }

    public void Unarchive(DateTimeOffset now)
    {
        if (!IsArchived || Status is not (TripStatus.Completed or TripStatus.Cancelled))
            throw new DomainRuleException("This trip cannot be unarchived.", "TRIP_ARCHIVE_NOT_ALLOWED");
        ArchivedAt = null;
        ArchivedByUserId = null;
        Changed(now);
    }

    private bool ApplyDraft(
        string cargoDescription,
        DateTimeOffset? plannedStartAt,
        decimal? price,
        string? notes,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(cargoDescription))
            throw new DomainRuleException("Cargo description is required.");
        if (price < 0)
            throw new DomainRuleException("Trip price cannot be negative.");
        var normalizedCargo = cargoDescription.Trim();
        decimal? normalizedPrice = price.HasValue
            ? decimal.Round(price.Value, 2, MidpointRounding.AwayFromZero)
            : null;
        var normalizedNotes = string.IsNullOrWhiteSpace(notes) ? null : notes.Trim();
        if (CargoDescription == normalizedCargo && PlannedStartAt == plannedStartAt
            && Price == normalizedPrice && Notes == normalizedNotes)
            return false;
        CargoDescription = normalizedCargo;
        PlannedStartAt = plannedStartAt;
        Price = normalizedPrice;
        Notes = normalizedNotes;
        Changed(now);
        return true;
    }

    private bool ApplyClientChange(bool changed, DateTimeOffset now)
    {
        if (!changed) return false;
        Changed(now);
        return true;
    }

    private void ValidateStops(IReadOnlyCollection<TripStop> stops, bool requireCoordinates)
    {
        if (stops.Count != 2)
            throw new DomainRuleException("Pickup and delivery stops are required.", "INVALID_TRIP_STOPS");
        var ordered = stops.OrderBy(x => x.Sequence).ToArray();
        if (ordered[0].Sequence != 0 || ordered[0].Type != TripStopType.Pickup
            || ordered[^1].Type != TripStopType.Delivery
            || ordered.Select(x => x.Sequence).Distinct().Count() != ordered.Length
            || ordered.Any(x => x.CompanyId != CompanyId || x.TripId != Id)
            || requireCoordinates && ordered.Any(x => !x.HasCoordinates))
            throw new DomainRuleException("Stops are invalid for this trip.", "INVALID_TRIP_STOPS");
    }

    private void EnsureVersion(long expectedVersion)
    {
        if (expectedVersion != Version)
            throw new DomainRuleException("The trip was changed by another user.", "TRIP_CONCURRENCY_CONFLICT");
    }

    private void Changed(DateTimeOffset now)
    {
        Version++;
        Touch(now);
    }

    private void EnsureStatus(TripStatus expected)
    {
        if (Status != expected)
            throw new DomainRuleException($"Trip transition requires status {expected}; current status is {Status}.", "INVALID_TRIP_TRANSITION");
    }
}
