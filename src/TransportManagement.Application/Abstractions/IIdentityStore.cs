using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Abstractions;

public interface IIdentityStore
{
    Task<User?> FindUserByEmailAsync(string email, CancellationToken cancellationToken);
    Task<User?> FindUserByIdAsync(Guid userId, CancellationToken cancellationToken);
    Task<RefreshToken?> FindActiveRefreshTokenAsync(string tokenHash, DateTimeOffset now, CancellationToken cancellationToken);
    Task AddRefreshTokenAsync(RefreshToken token, CancellationToken cancellationToken);
    Task RevokeAllUserTokensAsync(Guid userId, DateTimeOffset now, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
