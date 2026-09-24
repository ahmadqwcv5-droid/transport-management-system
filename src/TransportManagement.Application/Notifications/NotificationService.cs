using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Notifications;

public sealed class NotificationService(INotificationStore store,
    IDriverIdentityStore identities, ICurrentUser currentUser, IClock clock)
{
    public async Task<NotificationPageResponse> ListAsync(int page, int pageSize,
        CancellationToken cancellationToken)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var driverId = await VisibleDriverIdAsync(cancellationToken);
        var (items, total) = await store.ListAsync(driverId, page, pageSize, cancellationToken);
        return new(items.Select(Map).ToArray(), total, page, pageSize,
            (int)Math.Ceiling(total / (double)pageSize));
    }

    public async Task<UnreadNotificationCountResponse> UnreadAsync(
        CancellationToken cancellationToken) => new(await store.UnreadCountAsync(
            await VisibleDriverIdAsync(cancellationToken), cancellationToken));

    public async Task MarkReadAsync(Guid id, CancellationToken cancellationToken)
    {
        var notification = await store.GetAsync(id,
            await VisibleDriverIdAsync(cancellationToken), cancellationToken)
            ?? throw new NotFoundException("Notification was not found.", "NOTIFICATION_NOT_FOUND");
        notification.MarkRead(currentUser.UserId, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task MarkAllReadAsync(CancellationToken cancellationToken)
    {
        var visible = await store.UnreadAsync(await VisibleDriverIdAsync(cancellationToken),
            100, cancellationToken);
        foreach (var notification in visible)
            notification.MarkRead(currentUser.UserId, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task<Guid?> VisibleDriverIdAsync(CancellationToken cancellationToken)
    {
        if (currentUser.Role != AppRoles.Driver) return null;
        var driver = await identities.GetDriverByUserAsync(currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException("The signed-in user is not linked to a driver.",
                "DRIVER_LINK_REQUIRED");
        return driver.Id;
    }

    private static NotificationResponse Map(Domain.Trips.OperationNotification x) =>
        new(x.Id, x.Type, x.Severity, x.TripId, x.TruckId, x.DriverId,
            x.DataJson, x.CreatedAt, x.ReadAt);
}
