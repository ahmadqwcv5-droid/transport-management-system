using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Clients;

public sealed class Client : Entity, ITenantOwned
{
    private Client() { }

    public Client(
        Guid id,
        Guid companyId,
        string name,
        string? contactPerson,
        string? phone,
        string? email,
        string? address,
        string? notes,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        Apply(name, contactPerson, phone, email, address, notes, now);
        IsActive = true;
    }

    public Guid CompanyId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? ContactPerson { get; private set; }
    public string? Phone { get; private set; }
    public string? Email { get; private set; }
    public string? Address { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive { get; private set; }

    public void Update(
        string name,
        string? contactPerson,
        string? phone,
        string? email,
        string? address,
        string? notes,
        DateTimeOffset now) => Apply(name, contactPerson, phone, email, address, notes, now);

    public void Deactivate(DateTimeOffset now)
    {
        IsActive = false;
        Touch(now);
    }

    private void Apply(
        string name,
        string? contactPerson,
        string? phone,
        string? email,
        string? address,
        string? notes,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new DomainRuleException("Client name is required.");
        Name = name.Trim();
        ContactPerson = Normalize(contactPerson);
        Phone = Normalize(phone);
        Email = Normalize(email)?.ToLowerInvariant();
        Address = Normalize(address);
        Notes = Normalize(notes);
        Touch(now);
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
