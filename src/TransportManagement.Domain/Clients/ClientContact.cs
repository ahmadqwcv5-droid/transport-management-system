using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Clients;

public sealed class ClientContact : Entity, ITenantOwned
{
    private ClientContact() { }

    public ClientContact(Guid id, Guid companyId, Guid clientId, string name,
        string? jobTitle, string? phone, string? whatsApp, string? email,
        bool isPrimary, string? notes, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        ClientId = clientId;
        Apply(name, jobTitle, phone, whatsApp, email, isPrimary, notes, now);
    }

    public Guid CompanyId { get; private set; }
    public Guid ClientId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? JobTitle { get; private set; }
    public string? Phone { get; private set; }
    public string? WhatsApp { get; private set; }
    public string? Email { get; private set; }
    public bool IsPrimary { get; private set; }
    public string? Notes { get; private set; }

    public void Update(string name, string? jobTitle, string? phone,
        string? whatsApp, string? email, bool isPrimary, string? notes,
        DateTimeOffset now) => Apply(name, jobTitle, phone, whatsApp, email,
            isPrimary, notes, now);

    public void SetPrimary(bool value, DateTimeOffset now)
    {
        if (IsPrimary == value) return;
        IsPrimary = value;
        Touch(now);
    }

    private void Apply(string name, string? jobTitle, string? phone,
        string? whatsApp, string? email, bool isPrimary, string? notes,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new DomainRuleException("Contact name is required.");
        Name = name.Trim();
        JobTitle = Normalize(jobTitle);
        Phone = Normalize(phone);
        WhatsApp = Normalize(whatsApp);
        Email = Normalize(email)?.ToLowerInvariant();
        IsPrimary = isPrimary;
        Notes = Normalize(notes);
        Touch(now);
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
