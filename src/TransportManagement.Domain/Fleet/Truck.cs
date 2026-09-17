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
        IsActive = true;
    }

    public Guid CompanyId { get; private set; }
    public string PlateNumber { get; private set; } = string.Empty;
    public string? Make { get; private set; }
    public string? Model { get; private set; }
    public int? Year { get; private set; }
    public TruckStatus Status { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive { get; private set; }

    public void Update(string plateNumber, string? make, string? model, int? year, string? notes, DateTimeOffset now) =>
        Apply(plateNumber, make, model, year, notes, now);

    public void ChangeStatus(TruckStatus status, DateTimeOffset now)
    {
        Status = status;
        Touch(now);
    }

    public void Deactivate(DateTimeOffset now)
    {
        if (Status == TruckStatus.OnTrip)
            throw new DomainRuleException("A truck on a trip cannot be deactivated.");
        IsActive = false;
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
