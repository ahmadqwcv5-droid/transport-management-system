using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class Trip : Entity, ITenantOwned
{
    private readonly List<TripStop> _stops = [];
    private readonly List<TripRepositioningPlan> _repositioningPlans = [];
    private Trip() { }

    public Trip(
        Guid id,
        Guid companyId,
        Guid clientId,
        string origin,
        string destination,
        string cargoDescription,
        DateTimeOffset plannedStartAt,
        decimal price,
        string? notes,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        ClientId = clientId;
        ApplyDraft(origin, destination, cargoDescription, plannedStartAt, price, notes, now);
        Status = TripStatus.Draft;
    }

    public Guid CompanyId { get; private set; }
    public Guid ClientId { get; private set; }
    public Guid? TruckId { get; private set; }
    public Guid? DriverId { get; private set; }
    public string Origin { get; private set; } = string.Empty;
    public string Destination { get; private set; } = string.Empty;
    public string CargoDescription { get; private set; } = string.Empty;
    public DateTimeOffset PlannedStartAt { get; private set; }
    public DateTimeOffset? ActualStartAt { get; private set; }
    public DateTimeOffset? ArrivedPickupAt { get; private set; }
    public DateTimeOffset? DeliveredAt { get; private set; }
    public DateTimeOffset? CompletedAt { get; private set; }
    public decimal Price { get; private set; }
    public string? Notes { get; private set; }
    public TripStatus Status { get; private set; }
    public IReadOnlyCollection<TripStop> Stops => _stops;
    public IReadOnlyCollection<TripRepositioningPlan> RepositioningPlans => _repositioningPlans;
    public TripRoutePlan? RoutePlan { get; private set; }
    public bool IsRouteAware => RoutePlan is not null && _stops.Count >= 2;

    public bool ReservesResources => Status is TripStatus.Assigned or TripStatus.EnRouteToPickup
        or TripStatus.AtPickup or TripStatus.Started
        or TripStatus.InTransit or TripStatus.Delivered;

    public TripRepositioningPlan? CurrentRepositioningPlan => _repositioningPlans
        .Where(x => x.Status is RepositioningPlanStatus.Proposed or RepositioningPlanStatus.Active)
        .OrderByDescending(x => x.CalculatedAt)
        .FirstOrDefault();

    public void UpdateDraft(
        Guid clientId,
        string origin,
        string destination,
        string cargoDescription,
        DateTimeOffset plannedStartAt,
        decimal price,
        string? notes,
        DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Draft);
        ClientId = clientId;
        ApplyDraft(origin, destination, cargoDescription, plannedStartAt, price, notes, now);
    }

    public void Assign(Guid truckId, Guid driverId, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Draft);
        TruckId = truckId;
        DriverId = driverId;
        Status = TripStatus.Assigned;
        Touch(now);
    }

    public void ReplaceRoute(
        IReadOnlyCollection<TripStop> stops,
        TripRoutePlan routePlan,
        DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Draft);
        if (stops.Count < 2)
            throw new DomainRuleException("A route requires pickup and delivery stops.", "INVALID_TRIP_STOPS");
        var ordered = stops.OrderBy(x => x.Sequence).ToArray();
        if (ordered[0].Sequence != 0 || ordered[0].Type != TripStopType.Pickup
            || ordered[^1].Type != TripStopType.Delivery
            || ordered.Select(x => x.Sequence).Distinct().Count() != ordered.Length)
            throw new DomainRuleException("Stops must start with pickup, end with delivery, and have unique ordering.", "INVALID_TRIP_STOPS");
        if (ordered.Any(x => x.CompanyId != CompanyId || x.TripId != Id || !x.HasCoordinates)
            || routePlan.CompanyId != CompanyId || routePlan.TripId != Id)
            throw new DomainRuleException("Route data does not belong to this trip.", "INVALID_TRIP_ROUTE");

        var pickup = ordered[0];
        var delivery = ordered[^1];
        var latitudeDelta = Math.Abs(pickup.Latitude!.Value - delivery.Latitude!.Value);
        var longitudeDelta = Math.Abs(pickup.Longitude!.Value - delivery.Longitude!.Value);
        if (latitudeDelta < 0.00001m && longitudeDelta < 0.00001m)
            throw new DomainRuleException("Pickup and delivery must be different locations.", "IDENTICAL_TRIP_STOPS");

        _stops.Clear();
        _stops.AddRange(ordered);
        RoutePlan = routePlan;
        Origin = pickup.Name;
        Destination = delivery.Name;
        Touch(now);
    }

    public void AddRepositioningPlan(TripRepositioningPlan plan, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        if (plan.CompanyId != CompanyId || plan.TripId != Id || plan.TruckId != TruckId)
            throw new DomainRuleException("Repositioning plan does not belong to this assignment.", "INVALID_TRIP_ROUTE");
        foreach (var existing in _repositioningPlans) existing.Expire(now);
        _repositioningPlans.Add(plan);
        Touch(now);
    }

    public void DispatchToPickup(TripRepositioningPlan plan, DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
        if (!_repositioningPlans.Contains(plan))
            throw new DomainRuleException("Repositioning route is required.", "REPOSITIONING_ROUTE_REQUIRED");
        plan.Activate(now);
        Status = TripStatus.EnRouteToPickup;
        Touch(now);
    }

    public void MarkAtPickup(DateTimeOffset now)
    {
        if (Status == TripStatus.AtPickup) return;
        if (Status is not (TripStatus.Assigned or TripStatus.EnRouteToPickup))
            throw new DomainRuleException("Arrival requires an assigned or dispatched trip.", "INVALID_TRIP_TRANSITION");
        if (Status == TripStatus.EnRouteToPickup)
            CurrentRepositioningPlan?.Complete(now);
        ArrivedPickupAt = now;
        Status = TripStatus.AtPickup;
        Touch(now);
    }

    public void Start(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.AtPickup);
        ActualStartAt = now;
        Status = TripStatus.Started;
        Touch(now);
    }

    public void MarkInTransit(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Started);
        Status = TripStatus.InTransit;
        Touch(now);
    }

    public void Deliver(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.InTransit);
        DeliveredAt = now;
        Status = TripStatus.Delivered;
        Touch(now);
    }

    public void Complete(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Delivered);
        CompletedAt = now;
        Status = TripStatus.Completed;
        Touch(now);
    }

    public void Cancel(DateTimeOffset now)
    {
        if (Status is TripStatus.Delivered or TripStatus.Completed or TripStatus.Cancelled)
            throw new DomainRuleException($"A {Status} trip cannot be cancelled.", "INVALID_TRIP_TRANSITION");
        Status = TripStatus.Cancelled;
        Touch(now);
    }

    private void ApplyDraft(
        string origin,
        string destination,
        string cargoDescription,
        DateTimeOffset plannedStartAt,
        decimal price,
        string? notes,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(origin) || string.IsNullOrWhiteSpace(destination))
            throw new DomainRuleException("Trip origin and destination are required.");
        if (string.IsNullOrWhiteSpace(cargoDescription))
            throw new DomainRuleException("Cargo description is required.");
        if (price < 0)
            throw new DomainRuleException("Trip price cannot be negative.");
        Origin = origin.Trim();
        Destination = destination.Trim();
        CargoDescription = cargoDescription.Trim();
        PlannedStartAt = plannedStartAt;
        Price = decimal.Round(price, 2, MidpointRounding.AwayFromZero);
        Notes = string.IsNullOrWhiteSpace(notes) ? null : notes.Trim();
        Touch(now);
    }

    private void EnsureStatus(TripStatus expected)
    {
        if (Status != expected)
            throw new DomainRuleException($"Trip transition requires status {expected}; current status is {Status}.", "INVALID_TRIP_TRANSITION");
    }
}
