using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class IdentityStore(AppDbContext dbContext) : IIdentityStore
{
    public async Task<IReadOnlyList<Guid>> ListActiveCompanyIdsAsync(
        CancellationToken cancellationToken) => await dbContext.Companies
        .IgnoreQueryFilters().Where(x => x.IsActive).Select(x => x.Id)
        .OrderBy(x => x).ToListAsync(cancellationToken);

    public Task<User?> FindUserByEmailAsync(string email, CancellationToken cancellationToken) =>
        dbContext.Users.IgnoreQueryFilters().SingleOrDefaultAsync(x => x.Email == email, cancellationToken);

    public Task<User?> FindUserByIdAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

    public async Task<IReadOnlyList<CompanyMembership>> ListMembershipsAsync(
        Guid accountId, bool activeOnly, CancellationToken cancellationToken)
    {
        var query = dbContext.CompanyMemberships.IgnoreQueryFilters()
            .Where(x => x.AccountId == accountId);
        if (activeOnly) query = query.Where(x => x.Status == MembershipStatus.Active);
        return await query.OrderBy(x => x.CompanyId).ToListAsync(cancellationToken);
    }

    public Task<CompanyMembership?> FindMembershipAsync(Guid membershipId,
        Guid accountId, CancellationToken cancellationToken) =>
        dbContext.CompanyMemberships.IgnoreQueryFilters().SingleOrDefaultAsync(
            x => x.Id == membershipId && x.AccountId == accountId, cancellationToken);

    public async Task<IReadOnlyList<string>> ListMembershipRolesAsync(Guid membershipId,
        CancellationToken cancellationToken) => await dbContext.CompanyMembershipRoles
        .IgnoreQueryFilters().Where(x => x.MembershipId == membershipId)
        .Select(x => x.Role).OrderBy(x => x).ToListAsync(cancellationToken);

    public Task<Company?> FindCompanyByIdAsync(Guid companyId, CancellationToken cancellationToken) =>
        dbContext.Companies.IgnoreQueryFilters()
            .SingleOrDefaultAsync(x => x.Id == companyId, cancellationToken);

    public Task<Driver?> FindDriverAsync(Guid accountId, Guid companyId,
        CancellationToken cancellationToken) => dbContext.Drivers.IgnoreQueryFilters()
        .SingleOrDefaultAsync(x => x.CompanyId == companyId && x.UserId == accountId,
            cancellationToken);

    public Task<ExternalLogin?> FindExternalLoginAsync(string provider,
        string providerSubject, CancellationToken cancellationToken) =>
        dbContext.ExternalLogins.SingleOrDefaultAsync(x => x.Provider == provider
            && x.ProviderSubject == providerSubject, cancellationToken);

    public async Task<IReadOnlyList<ExternalLogin>> ListExternalLoginsAsync(
        Guid accountId, CancellationToken cancellationToken) =>
        await dbContext.ExternalLogins.Where(x => x.AccountId == accountId)
            .OrderBy(x => x.Provider).ToListAsync(cancellationToken);

    public Task<RefreshToken?> FindActiveRefreshTokenAsync(
        string tokenHash, DateTimeOffset now, CancellationToken cancellationToken) =>
        dbContext.RefreshTokens.IgnoreQueryFilters()
            .SingleOrDefaultAsync(x => x.TokenHash == tokenHash && x.RevokedAt == null && x.ExpiresAt > now, cancellationToken);

    public async Task AddRefreshTokenAsync(RefreshToken token, CancellationToken cancellationToken) =>
        await dbContext.RefreshTokens.AddAsync(token, cancellationToken);

    public async Task RevokeAllUserTokensAsync(Guid accountId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var tokens = await dbContext.RefreshTokens.Where(x => x.AccountId == accountId && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var token in tokens) token.Revoke(now);
    }

    public async Task RevokeMembershipTokensAsync(Guid membershipId,
        DateTimeOffset now, CancellationToken cancellationToken)
    {
        var tokens = await dbContext.RefreshTokens.Where(x =>
            x.MembershipId == membershipId && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var token in tokens) token.Revoke(now);
    }

    public void AddUser(User account) => dbContext.Users.Add(account);
    public void AddMembership(CompanyMembership membership) =>
        dbContext.CompanyMemberships.Add(membership);
    public void AddMembershipRoles(IEnumerable<CompanyMembershipRole> roles) =>
        dbContext.CompanyMembershipRoles.AddRange(roles);
    public void AddExternalLogin(ExternalLogin login) => dbContext.ExternalLogins.Add(login);
    public void RemoveExternalLogin(ExternalLogin login) => dbContext.ExternalLogins.Remove(login);
    public void AddIdentityAudit(IdentityAuditEvent auditEvent) =>
        dbContext.IdentityAuditEvents.Add(auditEvent);
    public void AddUserEvent(CompanyUserEvent userEvent) => dbContext.CompanyUserEvents.Add(userEvent);

    public void AddNotification(OperationNotification notification) =>
        dbContext.OperationNotifications.Add(notification);

    public async Task SaveChangesAsync(CancellationToken cancellationToken) =>
        await dbContext.SaveChangesAsync(cancellationToken);
}
