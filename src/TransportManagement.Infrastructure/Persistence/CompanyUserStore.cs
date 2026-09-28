using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class CompanyUserStore(AppDbContext dbContext) : ICompanyUserStore
{
    public async Task<IReadOnlyList<User>> ListUsersAsync(string? role, bool? isActive,
        CancellationToken cancellationToken)
    {
        var memberships = dbContext.CompanyMemberships.AsNoTracking().AsQueryable();
        if (isActive.HasValue)
            memberships = memberships.Where(x =>
                (x.Status == MembershipStatus.Active) == isActive.Value);
        if (!string.IsNullOrWhiteSpace(role))
            memberships = memberships.Where(x => dbContext.CompanyMembershipRoles
                .Any(membershipRole => membershipRole.MembershipId == x.Id
                    && membershipRole.Role == role));
        var accountIds = memberships.Select(x => x.AccountId);
        return await dbContext.Users.AsNoTracking().Where(x => accountIds.Contains(x.Id))
            .OrderBy(x => x.DisplayName).ThenBy(x => x.Email)
            .ToListAsync(cancellationToken);
    }

    public Task<CompanyMembership?> GetMembershipAsync(Guid accountId,
        CancellationToken cancellationToken) => dbContext.CompanyMemberships
        .SingleOrDefaultAsync(x => x.AccountId == accountId, cancellationToken);

    public async Task<IReadOnlyList<string>> GetRolesAsync(Guid accountId,
        CancellationToken cancellationToken) => await dbContext.CompanyMemberships
        .Where(x => x.AccountId == accountId)
        .Join(dbContext.CompanyMembershipRoles, membership => membership.Id,
            role => role.MembershipId, (_, role) => role.Role)
        .OrderBy(x => x).ToListAsync(cancellationToken);

    public Task<User?> GetUserAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Users.SingleOrDefaultAsync(x => x.Id == id
            && dbContext.CompanyMemberships.Any(membership =>
                membership.AccountId == x.Id), cancellationToken);

    public Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Drivers.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public Task<Driver?> GetDriverByUserAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.Drivers.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);

    public Task<bool> UserLinkedAsync(Guid userId, Guid? excludingDriverId,
        CancellationToken cancellationToken) => dbContext.Drivers.AnyAsync(x =>
            x.UserId == userId && (!excludingDriverId.HasValue || x.Id != excludingDriverId),
            cancellationToken);

    public void AddEvent(CompanyUserEvent userEvent) => dbContext.CompanyUserEvents.Add(userEvent);

    public async Task RevokeTokensAsync(Guid userId, DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var tokens = await dbContext.RefreshTokens
            .Where(x => x.AccountId == userId && x.CompanyId == dbContext.CurrentCompanyId && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var token in tokens) token.Revoke(now);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken) =>
        dbContext.SaveChangesAsync(cancellationToken);
}
