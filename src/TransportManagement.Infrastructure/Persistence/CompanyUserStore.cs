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
        var query = dbContext.Users.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(role)) query = query.Where(x => x.Role == role);
        if (isActive.HasValue) query = query.Where(x => x.IsActive == isActive.Value);
        return await query.OrderBy(x => x.DisplayName).ThenBy(x => x.Email)
            .ToListAsync(cancellationToken);
    }

    public Task<User?> GetUserAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Users.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Drivers.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public Task<Driver?> GetDriverByUserAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.Drivers.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);

    public Task<bool> UserLinkedAsync(Guid userId, Guid? excludingDriverId,
        CancellationToken cancellationToken) => dbContext.Drivers.AnyAsync(x =>
            x.UserId == userId && (!excludingDriverId.HasValue || x.Id != excludingDriverId),
            cancellationToken);

    public void AddUser(User user) => dbContext.Users.Add(user);
    public void AddEvent(CompanyUserEvent userEvent) => dbContext.CompanyUserEvents.Add(userEvent);

    public async Task RevokeTokensAsync(Guid userId, DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var tokens = await dbContext.RefreshTokens
            .Where(x => x.UserId == userId && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var token in tokens) token.Revoke(now);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken) =>
        dbContext.SaveChangesAsync(cancellationToken);
}
