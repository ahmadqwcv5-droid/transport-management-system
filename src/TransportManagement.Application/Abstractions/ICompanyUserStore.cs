using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Abstractions;

public interface ICompanyUserStore
{
    Task<IReadOnlyList<User>> ListUsersAsync(string? role, bool? isActive,
        CancellationToken cancellationToken);
    Task<User?> GetUserAsync(Guid id, CancellationToken cancellationToken);
    Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken);
    Task<Driver?> GetDriverByUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<bool> UserLinkedAsync(Guid userId, Guid? excludingDriverId,
        CancellationToken cancellationToken);
    void AddUser(User user);
    void AddEvent(CompanyUserEvent userEvent);
    Task RevokeTokensAsync(Guid userId, DateTimeOffset now, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
