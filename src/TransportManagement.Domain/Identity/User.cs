using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class User : Entity, ITenantOwned
{
    private User() { }

    public User(Guid id, Guid companyId, string email, string displayName, string passwordHash, string role, DateTimeOffset now)
        : base(id, now)
    {
        if (!AppRoles.All.Contains(role)) throw new ArgumentOutOfRangeException(nameof(role));
        CompanyId = companyId;
        Email = email.Trim().ToLowerInvariant();
        DisplayName = displayName.Trim();
        PasswordHash = passwordHash;
        Role = role;
        PreferredLocale = "en";
        IsActive = true;
    }

    public Guid CompanyId { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string DisplayName { get; private set; } = string.Empty;
    public string PasswordHash { get; private set; } = string.Empty;
    public string Role { get; private set; } = string.Empty;
    public string PreferredLocale { get; private set; } = "en";
    public bool IsActive { get; private set; }

    public void ChangePreferredLocale(string locale, DateTimeOffset now)
    {
        if (locale is not ("en" or "ar"))
            throw new DomainRuleException("Only English and Arabic locales are supported.", "UNSUPPORTED_LOCALE");
        PreferredLocale = locale;
        Touch(now);
    }
}
