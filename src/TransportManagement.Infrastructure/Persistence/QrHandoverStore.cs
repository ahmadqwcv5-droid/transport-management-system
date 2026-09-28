using Microsoft.EntityFrameworkCore;
using Npgsql;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class QrHandoverStore(AppDbContext dbContext) : IQrHandoverStore
{
    private static readonly TripStatus[] ReservedStatuses =
        [TripStatus.Assigned, TripStatus.EnRouteToPickup, TripStatus.AtPickup,
         TripStatus.Started, TripStatus.InTransit, TripStatus.AtDelivery, TripStatus.Delivered];

    public Task<Truck?> FindTruckAsync(Guid truckId, CancellationToken cancellationToken) =>
        dbContext.Trucks.SingleOrDefaultAsync(x => x.Id == truckId, cancellationToken);

    public Task<Driver?> FindDriverAsync(Guid driverId, CancellationToken cancellationToken) =>
        dbContext.Drivers.SingleOrDefaultAsync(x => x.Id == driverId, cancellationToken);

    public Task<Driver?> FindDriverByAccountAsync(Guid accountId,
        CancellationToken cancellationToken) => dbContext.Drivers
        .SingleOrDefaultAsync(x => x.UserId == accountId, cancellationToken);

    public Task<string?> FindAccountDisplayNameAsync(Guid accountId,
        CancellationToken cancellationToken) => dbContext.Users.AsNoTracking()
        .Where(x => x.Id == accountId).Select(x => x.DisplayName)
        .SingleOrDefaultAsync(cancellationToken);

    public Task<TruckQrCredential?> FindActiveQrForTruckAsync(
        Guid truckId, CancellationToken cancellationToken) => dbContext.TruckQrCredentials
        .SingleOrDefaultAsync(x => x.TruckId == truckId && x.RevokedAt == null,
            cancellationToken);

    public Task<TruckQrCredential?> FindActiveQrByHashAsync(
        string tokenHash, CancellationToken cancellationToken) => dbContext.TruckQrCredentials
        .SingleOrDefaultAsync(x => x.TokenHash == tokenHash && x.RevokedAt == null,
            cancellationToken);

    public Task<DriverTruckSession?> FindActiveSessionForDriverAsync(
        Guid driverId, CancellationToken cancellationToken) => dbContext.DriverTruckSessions
        .SingleOrDefaultAsync(x => x.DriverId == driverId && x.EndedAt == null,
            cancellationToken);

    public Task<DriverTruckSession?> FindActiveSessionForTruckAsync(
        Guid truckId, CancellationToken cancellationToken) => dbContext.DriverTruckSessions
        .SingleOrDefaultAsync(x => x.TruckId == truckId && x.EndedAt == null,
            cancellationToken);

    public Task<Trip?> FindCurrentTripForTruckAsync(
        Guid truckId, CancellationToken cancellationToken) => dbContext.Trips
        .Include(x => x.Stops).Include(x => x.RoutePlan).Include(x => x.RepositioningPlans)
        .Where(x => x.TruckId == truckId && ReservedStatuses.Contains(x.Status))
        .OrderByDescending(x => x.UpdatedAt).FirstOrDefaultAsync(cancellationToken);

    public Task<Trip?> FindTripAsync(Guid tripId, CancellationToken cancellationToken) =>
        dbContext.Trips.Include(x => x.Stops).Include(x => x.RoutePlan)
        .Include(x => x.RepositioningPlans)
        .SingleOrDefaultAsync(x => x.Id == tripId, cancellationToken);

    public Task<TripDriverParticipation?> FindActiveParticipationAsync(
        Guid tripId, CancellationToken cancellationToken) =>
        dbContext.TripDriverParticipations.SingleOrDefaultAsync(
            x => x.TripId == tripId && x.EndedAt == null, cancellationToken);

    public Task<TripHandoverRequest?> FindHandoverAsync(
        Guid requestId, CancellationToken cancellationToken) =>
        dbContext.TripHandoverRequests.SingleOrDefaultAsync(
            x => x.Id == requestId, cancellationToken);

    public Task<TripHandoverRequest?> FindPendingHandoverAsync(
        Guid tripId, CancellationToken cancellationToken) =>
        dbContext.TripHandoverRequests.SingleOrDefaultAsync(
            x => x.TripId == tripId && x.Status == TripHandoverStatus.Pending,
            cancellationToken);

    public async Task<IReadOnlyList<TripHandoverRequest>> ListHandoversAsync(
        CancellationToken cancellationToken) => await dbContext.TripHandoverRequests
        .AsNoTracking().OrderByDescending(x => x.CreatedAt)
        .Take(100).ToListAsync(cancellationToken);

    public async Task<TruckPosition?> FindLatestPositionAsync(
        Guid truckId, CancellationToken cancellationToken)
    {
        var projected = await dbContext.TruckCurrentPositions.AsNoTracking()
            .Where(x => x.TruckId == truckId)
            .Join(dbContext.TruckPositions.AsNoTracking(), current => current.PositionId,
                position => position.Id, (_, position) => position)
            .SingleOrDefaultAsync(cancellationToken);
        return projected ?? await dbContext.TruckPositions.AsNoTracking()
            .Where(x => x.TruckId == truckId)
            .OrderByDescending(x => x.RecordedAt).ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public void AddQr(TruckQrCredential credential) =>
        dbContext.TruckQrCredentials.Add(credential);
    public void AddSession(DriverTruckSession session) =>
        dbContext.DriverTruckSessions.Add(session);
    public void AddHandover(TripHandoverRequest request) =>
        dbContext.TripHandoverRequests.Add(request);
    public void AddParticipation(TripDriverParticipation participation) =>
        dbContext.TripDriverParticipations.Add(participation);
    public void AddTripEvent(TripEvent tripEvent) => dbContext.TripEvents.Add(tripEvent);
    public void AddTruckEvent(TruckEvent truckEvent) => dbContext.TruckEvents.Add(truckEvent);
    public void AddNotification(OperationNotification notification) =>
        dbContext.OperationNotifications.Add(notification);

    public async Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation,
            ConstraintName: "IX_truck_qr_credentials_CompanyId_TruckId"
        })
        {
            throw new ConflictException(
                "The truck QR credential changed concurrently. Refresh and try again.",
                "TRUCK_QR_REGENERATION_CONFLICT", exception);
        }
    }
}
