using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Companies;

namespace TransportManagement.Application.Abstractions;

public interface IIdentityStore
{
    Task<IReadOnlyList<Guid>> ListActiveCompanyIdsAsync(CancellationToken cancellationToken);
    Task<User?> FindUserByEmailAsync(string email, CancellationToken cancellationToken);
    Task<User?> FindUserByIdAsync(Guid userId, CancellationToken cancellationToken);
    Task<Company?> FindCompanyByIdAsync(Guid companyId, CancellationToken cancellationToken);
    Task<RefreshToken?> FindActiveRefreshTokenAsync(string tokenHash, DateTimeOffset now, CancellationToken cancellationToken);
    Task AddRefreshTokenAsync(RefreshToken token, CancellationToken cancellationToken);
    Task RevokeAllUserTokensAsync(Guid userId, DateTimeOffset now, CancellationToken cancellationToken);
    void AddUserEvent(CompanyUserEvent userEvent);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
