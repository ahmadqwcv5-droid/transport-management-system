using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Companies;

public sealed class Company : Entity
{
    private Company() { }

    public Company(Guid id, string name, string slug, DateTimeOffset now) : base(id, now)
    {
        Name = name;
        Slug = slug;
        IsActive = true;
    }

    public string Name { get; private set; } = string.Empty;
    public string Slug { get; private set; } = string.Empty;
    public bool IsActive { get; private set; }
    public string? ConnectionCodeHash { get; private set; }
    public string? ConnectionCodeHint { get; private set; }
    public int ConnectionCodeVersion { get; private set; }

    public void RotateConnectionCode(string hash, string hint, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(hash) || string.IsNullOrWhiteSpace(hint))
            throw new DomainRuleException("A valid company connection code is required.",
                "COMPANY_CODE_INVALID");
        ConnectionCodeHash = hash;
        ConnectionCodeHint = hint;
        ConnectionCodeVersion++;
        Touch(now);
    }
}
