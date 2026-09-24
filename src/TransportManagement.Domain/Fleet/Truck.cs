using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class Truck : Entity, ITenantOwned
{
    private Truck() { }

    public Truck(
        Guid id,
        Guid companyId,
        string plateNumber,
        string? make,
        string? model,
        int? year,
        string? notes,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        Apply(plateNumber, make, model, year, notes, now);
        Status = TruckStatus.Available;
    }

    public Guid CompanyId { get; private set; }
    public string PlateNumber { get; private set; } = string.Empty;
    public string? FleetCode { get; private set; }
    public string? Vin { get; private set; }
    public string? Make { get; private set; }
    public string? Model { get; private set; }
    public int? Year { get; private set; }
    public TruckType? Type { get; private set; }
    public decimal? PayloadCapacity { get; private set; }
    public PayloadUnit PayloadUnit { get; private set; } = PayloadUnit.Kilograms;
    public TruckFuelType? FuelType { get; private set; }
    public decimal? OdometerKilometers { get; private set; }
    public Guid? DefaultDriverId { get; private set; }
    public TruckStatus Status { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive => Status != TruckStatus.Archived;

    public void Update(string plateNumber, string? make, string? model, int? year, string? notes, DateTimeOffset now) =>
        Apply(plateNumber, make, model, year, notes, now);

    public void ChangeStatus(TruckStatus status, DateTimeOffset now)
    {
        if (status == TruckStatus.OnTrip)
            throw new DomainRuleException("OnTrip is derived from the active trip and cannot be stored.", "DERIVED_TRUCK_STATUS");
        Status = status;
        Touch(now);
    }

    public void Deactivate(DateTimeOffset now)
    {
        Status = TruckStatus.Archived;
        Touch(now);
    }

    public void Restore(DateTimeOffset now) => ChangeStatus(TruckStatus.Available, now);

    public void UpdateProfile(string plateNumber, string? fleetCode, string? vin,
        string? make, string? model, int? year, TruckType? type,
        decimal? payloadCapacity, PayloadUnit payloadUnit, TruckFuelType? fuelType,
        decimal? odometerKilometers, Guid? defaultDriverId, string? notes,
        DateTimeOffset now)
    {
        Apply(plateNumber, make, model, year, notes, now);
        if (payloadCapacity < 0) throw new DomainRuleException("Payload capacity cannot be negative.");
        if (odometerKilometers < 0) throw new DomainRuleException("Odometer cannot be negative.");
        FleetCode = Normalize(fleetCode)?.ToUpperInvariant();
        Vin = Normalize(vin)?.ToUpperInvariant();
        Type = type;
        PayloadCapacity = payloadCapacity;
        PayloadUnit = payloadUnit;
        FuelType = fuelType;
        OdometerKilometers = odometerKilometers;
        DefaultDriverId = defaultDriverId;
    }

    public void CorrectOdometer(decimal kilometers, string reason, DateTimeOffset now)
    {
        if (kilometers < 0) throw new DomainRuleException("Odometer cannot be negative.");
        if (string.IsNullOrWhiteSpace(reason))
            throw new DomainRuleException("An odometer correction reason is required.", "ODOMETER_REASON_REQUIRED");
        OdometerKilometers = kilometers;
        Touch(now);
    }

    private void Apply(string plateNumber, string? make, string? model, int? year, string? notes, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(plateNumber))
            throw new DomainRuleException("Plate number is required.");
        if (year is < 1900 || year > 2100)
            throw new DomainRuleException("Truck year must be between 1900 and 2100.");
        PlateNumber = plateNumber.Trim().ToUpperInvariant();
        Make = Normalize(make);
        Model = Normalize(model);
        Year = year;
        Notes = Normalize(notes);
        Touch(now);
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
