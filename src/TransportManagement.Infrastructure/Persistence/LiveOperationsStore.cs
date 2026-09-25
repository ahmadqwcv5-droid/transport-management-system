using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class LiveOperationsStore(AppDbContext dbContext) :
    IGeofenceStore, INotificationStore, IDriverIdentityStore
{
    private static readonly TripStatus[] CurrentStatuses =
        [TripStatus.Assigned, TripStatus.EnRouteToPickup, TripStatus.AtPickup,
         TripStatus.Started, TripStatus.InTransit, TripStatus.AtDelivery, TripStatus.Delivered];

    public Task<TripGeofenceObservation?> GetAsync(Guid tripId, GeofenceStage stage,
        string routeIdentity, CancellationToken cancellationToken) =>
        dbContext.TripGeofenceObservations.SingleOrDefaultAsync(x => x.TripId == tripId
            && x.Stage == stage && x.RouteIdentity == routeIdentity, cancellationToken);

    public void Add(TripGeofenceObservation observation) =>
        dbContext.TripGeofenceObservations.Add(observation);

    public async Task<(IReadOnlyList<OperationNotification> Items, int TotalCount)> ListAsync(
        Guid? driverId, int page, int pageSize, CancellationToken cancellationToken)
    {
        var query = Visible(driverId).AsNoTracking();
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return (items, total);
    }

    public Task<int> UnreadCountAsync(Guid? driverId, CancellationToken cancellationToken) =>
        Visible(driverId).CountAsync(x => x.ReadAt == null, cancellationToken);

    public Task<OperationNotification?> GetAsync(Guid id, Guid? driverId,
        CancellationToken cancellationToken) =>
        Visible(driverId).SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<IReadOnlyList<OperationNotification>> UnreadAsync(Guid? driverId,
        int limit, CancellationToken cancellationToken) => await Visible(driverId)
        .Where(x => x.ReadAt == null).OrderByDescending(x => x.CreatedAt)
        .Take(limit).ToListAsync(cancellationToken);

    public Task<bool> EventExistsAsync(string eventKey, CancellationToken cancellationToken) =>
        dbContext.OperationNotifications.AnyAsync(x => x.EventKey == eventKey, cancellationToken);

    public void Add(OperationNotification notification) =>
        dbContext.OperationNotifications.Add(notification);

    public Task<Driver?> GetDriverByUserAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.Drivers.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);

    public Task<User?> GetUserAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

    public Task<Trip?> GetCurrentTripAsync(Guid driverId, CancellationToken cancellationToken) =>
        dbContext.Trips.Include(x => x.Stops).Include(x => x.RoutePlan)
            .Include(x => x.RepositioningPlans).Where(x => x.DriverId == driverId
                && CurrentStatuses.Contains(x.Status)).OrderByDescending(x => x.UpdatedAt)
            .FirstOrDefaultAsync(cancellationToken);

    public Task<Trip?> GetTripAsync(Guid tripId, CancellationToken cancellationToken) =>
        dbContext.Trips.Include(x => x.Stops).Include(x => x.RoutePlan)
            .Include(x => x.RepositioningPlans).SingleOrDefaultAsync(x => x.Id == tripId, cancellationToken);

    public Task<DriverTruckSession?> GetActiveSessionAsync(Guid driverId,
        CancellationToken cancellationToken) => dbContext.DriverTruckSessions
        .SingleOrDefaultAsync(x => x.DriverId == driverId && x.EndedAt == null, cancellationToken);

    public async Task<IReadOnlyList<DriverTruckSession>> GetConflictingSessionsAsync(
        Guid driverId, Guid truckId, CancellationToken cancellationToken) =>
        await dbContext.DriverTruckSessions.Where(x => x.EndedAt == null
            && (x.DriverId == driverId || x.TruckId == truckId)).ToListAsync(cancellationToken);

    public void AddSession(DriverTruckSession session) => dbContext.DriverTruckSessions.Add(session);

    public Task<bool> UserLinkedAsync(Guid userId, Guid? excludingDriverId,
        CancellationToken cancellationToken) => dbContext.Drivers.AnyAsync(x =>
            x.UserId == userId && (!excludingDriverId.HasValue || x.Id != excludingDriverId),
            cancellationToken);

    public async Task SaveChangesAsync(CancellationToken cancellationToken) =>
        await dbContext.SaveChangesAsync(cancellationToken);

    private IQueryable<OperationNotification> Visible(Guid? driverId) => driverId.HasValue
        ? dbContext.OperationNotifications.Where(x => x.DriverId == driverId)
        : dbContext.OperationNotifications;
}
