using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class Trip : Entity, ITenantOwned
{
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
    public DateTimeOffset? DeliveredAt { get; private set; }
    public DateTimeOffset? CompletedAt { get; private set; }
    public decimal Price { get; private set; }
    public string? Notes { get; private set; }
    public TripStatus Status { get; private set; }

    public bool ReservesResources => Status is TripStatus.Assigned or TripStatus.Started
        or TripStatus.InTransit or TripStatus.Delivered;

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

    public void Start(DateTimeOffset now)
    {
        EnsureStatus(TripStatus.Assigned);
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
