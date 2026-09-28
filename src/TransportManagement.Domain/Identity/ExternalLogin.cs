using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class ExternalLogin : Entity
{
    private ExternalLogin() { }

    public ExternalLogin(Guid id, Guid accountId, string provider,
        string providerSubject, string emailSnapshot, DateTimeOffset now)
        : base(id, now)
    {
        AccountId = accountId;
        Provider = Normalize(provider);
        ProviderSubject = providerSubject.Trim();
        EmailSnapshot = emailSnapshot.Trim().ToLowerInvariant();
    }

    public Guid AccountId { get; private set; }
    public string Provider { get; private set; } = string.Empty;
    public string ProviderSubject { get; private set; } = string.Empty;
    public string EmailSnapshot { get; private set; } = string.Empty;

    private static string Normalize(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new DomainRuleException("External login provider is required.");
        return value.Trim().ToLowerInvariant();
    }
}
