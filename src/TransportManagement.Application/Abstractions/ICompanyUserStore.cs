using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Abstractions;

public interface ICompanyUserStore
{
    Task<IReadOnlyList<User>> ListUsersAsync(string? role, bool? isActive,
        CancellationToken cancellationToken);
    Task<CompanyMembership?> GetMembershipAsync(Guid accountId,
        CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> GetRolesAsync(Guid accountId,
        CancellationToken cancellationToken);
    Task<IReadOnlyList<CompanyMembershipRole>> GetRoleEntitiesAsync(Guid membershipId,
        CancellationToken cancellationToken);
    Task<int> CountActiveOwnersAsync(CancellationToken cancellationToken);
    Task<User?> GetUserAsync(Guid id, CancellationToken cancellationToken);
    Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken);
    Task<Driver?> GetDriverByUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<bool> UserLinkedAsync(Guid userId, Guid? excludingDriverId,
        CancellationToken cancellationToken);
    Task<bool> HasActiveTripAsync(Guid driverId, CancellationToken cancellationToken);
    Task<bool> HasActiveSessionAsync(Guid driverId, CancellationToken cancellationToken);
    Task<bool> HasPendingHandoverAsync(Guid driverId, CancellationToken cancellationToken);
    void AddRoles(IEnumerable<CompanyMembershipRole> roles);
    void RemoveRoles(IEnumerable<CompanyMembershipRole> roles);
    void AddEvent(CompanyUserEvent userEvent);
    Task RevokeTokensAsync(Guid userId, DateTimeOffset now, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
