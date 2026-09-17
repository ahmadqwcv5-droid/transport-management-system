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
        IsActive = true;
    }

    public Guid CompanyId { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string DisplayName { get; private set; } = string.Empty;
    public string PasswordHash { get; private set; } = string.Empty;
    public string Role { get; private set; } = string.Empty;
    public bool IsActive { get; private set; }
}
