using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

/// Global personal account. Company access lives in CompanyMembership.
public sealed class User : Entity
{
    private User() { }

    public User(Guid id, string email, string displayName, string? passwordHash,
        DateTimeOffset now)
        : base(id, now)
    {
        Email = email.Trim().ToLowerInvariant();
        DisplayName = displayName.Trim();
        PasswordHash = passwordHash;
        PreferredLocale = "en";
        IsActive = true;
    }

    public string Email { get; private set; } = string.Empty;
    public string DisplayName { get; private set; } = string.Empty;
    public string? PasswordHash { get; private set; }
    public string PreferredLocale { get; private set; } = "en";
    public bool NotificationSoundsEnabled { get; private set; } = true;
    public bool IsActive { get; private set; }

    public void ChangePreferredLocale(string locale, DateTimeOffset now)
    {
        if (locale is not ("en" or "ar"))
            throw new DomainRuleException("Only English and Arabic locales are supported.", "UNSUPPORTED_LOCALE");
        PreferredLocale = locale;
        Touch(now);
    }

    public void ChangeNotificationSounds(bool enabled, DateTimeOffset now)
    {
        NotificationSoundsEnabled = enabled;
        Touch(now);
    }

    public void Deactivate(DateTimeOffset now)
    {
        IsActive = false;
        Touch(now);
    }

    public void Reactivate(DateTimeOffset now)
    {
        IsActive = true;
        Touch(now);
    }

    public void ResetPassword(string passwordHash, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(passwordHash))
            throw new DomainRuleException("A password hash is required.", "PASSWORD_HASH_REQUIRED");
        PasswordHash = passwordHash;
        Touch(now);
    }
}
