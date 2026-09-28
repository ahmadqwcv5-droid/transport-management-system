using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class CompanyMembershipRole : ITenantOwned
{
    private CompanyMembershipRole() { }

    public CompanyMembershipRole(Guid companyId, Guid membershipId, string role)
    {
        if (!AppRoles.All.Contains(role))
            throw new DomainRuleException("The membership role is invalid.",
                "USER_ROLE_INVALID");
        CompanyId = companyId;
        MembershipId = membershipId;
        Role = role;
    }

    public Guid CompanyId { get; private set; }
    public Guid MembershipId { get; private set; }
    public string Role { get; private set; } = string.Empty;
}
