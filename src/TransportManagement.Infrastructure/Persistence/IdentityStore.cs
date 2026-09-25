using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Companies;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class IdentityStore(AppDbContext dbContext, ICurrentUser currentUser) : IIdentityStore
{
    public Task<User?> FindUserByEmailAsync(string email, CancellationToken cancellationToken) =>
        dbContext.Users.IgnoreQueryFilters().SingleOrDefaultAsync(x => x.Email == email, cancellationToken);

    public Task<User?> FindUserByIdAsync(Guid userId, CancellationToken cancellationToken) =>
        currentUser.IsAuthenticated
            ? dbContext.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
            : dbContext.Users.IgnoreQueryFilters().SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

    public Task<Company?> FindCompanyByIdAsync(Guid companyId, CancellationToken cancellationToken) =>
        dbContext.Companies.IgnoreQueryFilters()
            .SingleOrDefaultAsync(x => x.Id == companyId, cancellationToken);

    public Task<RefreshToken?> FindActiveRefreshTokenAsync(
        string tokenHash, DateTimeOffset now, CancellationToken cancellationToken) =>
        dbContext.RefreshTokens.IgnoreQueryFilters()
            .SingleOrDefaultAsync(x => x.TokenHash == tokenHash && x.RevokedAt == null && x.ExpiresAt > now, cancellationToken);

    public async Task AddRefreshTokenAsync(RefreshToken token, CancellationToken cancellationToken) =>
        await dbContext.RefreshTokens.AddAsync(token, cancellationToken);

    public async Task RevokeAllUserTokensAsync(Guid userId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var tokens = await dbContext.RefreshTokens.Where(x => x.UserId == userId && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var token in tokens) token.Revoke(now);
    }

    public async Task SaveChangesAsync(CancellationToken cancellationToken) =>
        await dbContext.SaveChangesAsync(cancellationToken);
}
