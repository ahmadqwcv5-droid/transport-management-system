using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class RefreshToken : Entity, ITenantOwned
{
    private RefreshToken() { }

    public RefreshToken(Guid id, Guid companyId, Guid userId, string tokenHash, DateTimeOffset expiresAt, DateTimeOffset now)
        : base(id, now)
    {
        CompanyId = companyId;
        UserId = userId;
        TokenHash = tokenHash;
        ExpiresAt = expiresAt;
    }

    public Guid CompanyId { get; private set; }
    public Guid UserId { get; private set; }
    public string TokenHash { get; private set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; private set; }
    public DateTimeOffset? RevokedAt { get; private set; }
    public Guid? ReplacedByTokenId { get; private set; }
    public bool IsActive(DateTimeOffset now) => RevokedAt is null && ExpiresAt > now;

    public void Revoke(DateTimeOffset now, Guid? replacedByTokenId = null)
    {
        RevokedAt = now;
        ReplacedByTokenId = replacedByTokenId;
        UpdatedAt = now;
    }
}
