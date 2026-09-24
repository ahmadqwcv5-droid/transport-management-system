using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface INotificationStore
{
    Task<(IReadOnlyList<OperationNotification> Items, int TotalCount)> ListAsync(
        Guid? driverId, int page, int pageSize, CancellationToken cancellationToken);
    Task<int> UnreadCountAsync(Guid? driverId, CancellationToken cancellationToken);
    Task<OperationNotification?> GetAsync(Guid id, Guid? driverId, CancellationToken cancellationToken);
    Task<IReadOnlyList<OperationNotification>> UnreadAsync(Guid? driverId, int limit,
        CancellationToken cancellationToken);
    Task<bool> EventExistsAsync(string eventKey, CancellationToken cancellationToken);
    void Add(OperationNotification notification);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
