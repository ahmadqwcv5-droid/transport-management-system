using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class TruckQrCredential : Entity, ITenantOwned
{
    private TruckQrCredential() { }

    public TruckQrCredential(Guid id, Guid companyId, Guid truckId,
        string tokenHash, string codeHint, Guid generatedByAccountId,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        TruckId = truckId;
        TokenHash = tokenHash;
        CodeHint = codeHint;
        GeneratedByAccountId = generatedByAccountId;
        GeneratedAt = now;
    }

    public Guid CompanyId { get; private set; }
    public Guid TruckId { get; private set; }
    public string TokenHash { get; private set; } = string.Empty;
    public string CodeHint { get; private set; } = string.Empty;
    public Guid GeneratedByAccountId { get; private set; }
    public DateTimeOffset GeneratedAt { get; private set; }
    public DateTimeOffset? RevokedAt { get; private set; }
    public Guid? RevokedByAccountId { get; private set; }
    public bool IsActive => RevokedAt is null;

    public void Revoke(Guid accountId, DateTimeOffset now)
    {
        if (!IsActive) return;
        RevokedAt = now;
        RevokedByAccountId = accountId;
        Touch(now);
    }
}
