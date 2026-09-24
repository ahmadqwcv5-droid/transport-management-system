using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Clients;

public enum ClientSiteType { Factory, Warehouse, Pickup, Delivery, Office, Other }

public sealed class ClientSite : Entity, ITenantOwned
{
    private ClientSite() { }

    public ClientSite(Guid id, Guid companyId, Guid clientId, string name,
        ClientSiteType type, string? address, decimal latitude, decimal longitude,
        string? contactName, string? contactPhone, string? instructions,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        ClientId = clientId;
        Apply(name, type, address, latitude, longitude, contactName, contactPhone,
            instructions, now);
        IsActive = true;
    }

    public Guid CompanyId { get; private set; }
    public Guid ClientId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public ClientSiteType Type { get; private set; }
    public string? Address { get; private set; }
    public decimal Latitude { get; private set; }
    public decimal Longitude { get; private set; }
    public string? ContactName { get; private set; }
    public string? ContactPhone { get; private set; }
    public string? Instructions { get; private set; }
    public bool IsActive { get; private set; }

    public void Update(string name, ClientSiteType type, string? address,
        decimal latitude, decimal longitude, string? contactName,
        string? contactPhone, string? instructions, DateTimeOffset now) =>
        Apply(name, type, address, latitude, longitude, contactName, contactPhone,
            instructions, now);

    public void SetActive(bool value, DateTimeOffset now)
    {
        if (IsActive == value) return;
        IsActive = value;
        Touch(now);
    }

    private void Apply(string name, ClientSiteType type, string? address,
        decimal latitude, decimal longitude, string? contactName,
        string? contactPhone, string? instructions, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new DomainRuleException("Site name is required.");
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180)
            throw new DomainRuleException("Site coordinates are outside the valid range.", "INVALID_COORDINATES");
        Name = name.Trim();
        Type = type;
        Address = Normalize(address);
        Latitude = latitude;
        Longitude = longitude;
        ContactName = Normalize(contactName);
        ContactPhone = Normalize(contactPhone);
        Instructions = Normalize(instructions);
        Touch(now);
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
