using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface IIdentityStore
{
    Task<IReadOnlyList<Guid>> ListActiveCompanyIdsAsync(CancellationToken cancellationToken);
    Task<User?> FindUserByEmailAsync(string email, CancellationToken cancellationToken);
    Task<User?> FindUserByIdAsync(Guid userId, CancellationToken cancellationToken);
    Task<IReadOnlyList<CompanyMembership>> ListMembershipsAsync(Guid accountId,
        bool activeOnly, CancellationToken cancellationToken);
    Task<CompanyMembership?> FindMembershipAsync(Guid membershipId, Guid accountId,
        CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> ListMembershipRolesAsync(Guid membershipId,
        CancellationToken cancellationToken);
    Task<Company?> FindCompanyByIdAsync(Guid companyId, CancellationToken cancellationToken);
    Task<Driver?> FindDriverAsync(Guid accountId, Guid companyId,
        CancellationToken cancellationToken);
    Task<ExternalLogin?> FindExternalLoginAsync(string provider, string providerSubject,
        CancellationToken cancellationToken);
    Task<IReadOnlyList<ExternalLogin>> ListExternalLoginsAsync(Guid accountId,
        CancellationToken cancellationToken);
    Task<RefreshToken?> FindActiveRefreshTokenAsync(string tokenHash, DateTimeOffset now, CancellationToken cancellationToken);
    Task AddRefreshTokenAsync(RefreshToken token, CancellationToken cancellationToken);
    Task RevokeAllUserTokensAsync(Guid accountId, DateTimeOffset now, CancellationToken cancellationToken);
    Task RevokeMembershipTokensAsync(Guid membershipId, DateTimeOffset now,
        CancellationToken cancellationToken);
    void AddUser(User account);
    void AddMembership(CompanyMembership membership);
    void AddMembershipRoles(IEnumerable<CompanyMembershipRole> roles);
    void AddExternalLogin(ExternalLogin login);
    void RemoveExternalLogin(ExternalLogin login);
    void AddIdentityAudit(IdentityAuditEvent auditEvent);
    void AddUserEvent(CompanyUserEvent userEvent);
    void AddNotification(OperationNotification notification);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
