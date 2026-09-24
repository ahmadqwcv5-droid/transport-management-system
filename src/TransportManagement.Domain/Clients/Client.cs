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
        DateTimeOffset now)
        : this(id, companyId, name, null, contactPerson, phone, email, address, notes, now)
    { }

    public Client(
        Guid id,
        Guid companyId,
        string name,
        string? legalName,
        string? contactPerson,
        string? phone,
        string? email,
        string? address,
        string? notes,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        Apply(name, legalName, contactPerson, phone, email, address, notes, now);
        LifecycleStatus = ClientLifecycleStatus.Active;
    }

    public Guid CompanyId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? LegalName { get; private set; }
    public string? ContactPerson { get; private set; }
    public string? Phone { get; private set; }
    public string? Email { get; private set; }
    public string? Address { get; private set; }
    public string? Notes { get; private set; }
    public ClientLifecycleStatus LifecycleStatus { get; private set; }
    public bool IsActive => LifecycleStatus == ClientLifecycleStatus.Active;

    public void Update(
        string name,
        string? legalName,
        string? contactPerson,
        string? phone,
        string? email,
        string? address,
        string? notes,
        DateTimeOffset now) => Apply(name, legalName, contactPerson, phone, email, address, notes, now);

    public void Update(string name, string? contactPerson, string? phone,
        string? email, string? address, string? notes, DateTimeOffset now) =>
        Apply(name, LegalName, contactPerson, phone, email, address, notes, now);

    public void Deactivate(DateTimeOffset now)
    {
        LifecycleStatus = ClientLifecycleStatus.Archived;
        Touch(now);
    }

    public void ChangeLifecycle(ClientLifecycleStatus status, DateTimeOffset now)
    {
        if (LifecycleStatus == status) return;
        LifecycleStatus = status;
        Touch(now);
    }

    private void Apply(
        string name,
        string? legalName,
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
        LegalName = Normalize(legalName);
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
