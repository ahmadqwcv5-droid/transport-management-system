using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class Driver : Entity, ITenantOwned
{
    private Driver() { }

    public Driver(
        Guid id,
        Guid companyId,
        string fullName,
        string? phone,
        string licenseNumber,
        DateOnly? licenseExpiryDate,
        string? notes,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        Apply(fullName, phone, licenseNumber, licenseExpiryDate, notes, now);
        Status = DriverStatus.Available;
        IsActive = true;
    }

    public Guid CompanyId { get; private set; }
    public string FullName { get; private set; } = string.Empty;
    public string? Phone { get; private set; }
    public string LicenseNumber { get; private set; } = string.Empty;
    public DateOnly? LicenseExpiryDate { get; private set; }
    public DriverStatus Status { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive { get; private set; }

    public void Update(
        string fullName,
        string? phone,
        string licenseNumber,
        DateOnly? licenseExpiryDate,
        string? notes,
        DateTimeOffset now) => Apply(fullName, phone, licenseNumber, licenseExpiryDate, notes, now);

    public void ChangeStatus(DriverStatus status, DateTimeOffset now)
    {
        Status = status;
        Touch(now);
    }

    public void Deactivate(DateTimeOffset now)
    {
        if (Status == DriverStatus.OnTrip)
            throw new DomainRuleException("A driver on a trip cannot be deactivated.");
        IsActive = false;
        Touch(now);
    }

    private void Apply(
        string fullName,
        string? phone,
        string licenseNumber,
        DateOnly? licenseExpiryDate,
        string? notes,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(fullName))
            throw new DomainRuleException("Driver name is required.");
        if (string.IsNullOrWhiteSpace(licenseNumber))
            throw new DomainRuleException("License number is required.");
        FullName = fullName.Trim();
        Phone = Normalize(phone);
        LicenseNumber = licenseNumber.Trim().ToUpperInvariant();
        LicenseExpiryDate = licenseExpiryDate;
        Notes = Normalize(notes);
        Touch(now);
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
