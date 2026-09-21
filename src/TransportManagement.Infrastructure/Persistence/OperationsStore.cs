using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class OperationsStore(AppDbContext dbContext) : IOperationsStore
{
    private static readonly TripStatus[] ReservedStatuses =
        [TripStatus.Assigned, TripStatus.EnRouteToPickup, TripStatus.AtPickup,
            TripStatus.Started, TripStatus.InTransit, TripStatus.Delivered];

    public Task<Client?> GetClientAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Clients.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Client>> ListClientsAsync(bool? isActive, string? search, CancellationToken cancellationToken)
    {
        var query = dbContext.Clients.AsNoTracking();
        if (isActive.HasValue) query = query.Where(x => x.IsActive == isActive.Value);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            query = query.Where(x => EF.Functions.ILike(x.Name, pattern));
        }
        return await query.OrderBy(x => x.Name).ToListAsync(cancellationToken);
    }

    public void AddClient(Client client) => dbContext.Clients.Add(client);

    public Task<Truck?> GetTruckAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Trucks.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Truck>> ListTrucksAsync(TruckStatus? status, bool? isActive, string? search, CancellationToken cancellationToken)
    {
        var query = dbContext.Trucks.AsNoTracking();
        if (status.HasValue) query = query.Where(x => x.Status == status.Value);
        if (isActive.HasValue) query = query.Where(x => x.IsActive == isActive.Value);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            query = query.Where(x => EF.Functions.ILike(x.PlateNumber, pattern));
        }
        return await query.OrderBy(x => x.PlateNumber).ToListAsync(cancellationToken);
    }

    public Task<bool> PlateExistsAsync(string plateNumber, Guid? excludingId, CancellationToken cancellationToken) =>
        dbContext.Trucks.AnyAsync(x => x.PlateNumber == plateNumber && (!excludingId.HasValue || x.Id != excludingId), cancellationToken);

    public Task<bool> TruckReservedAsync(Guid truckId, Guid? excludingTripId, CancellationToken cancellationToken) =>
        dbContext.Trips.AnyAsync(x => x.TruckId == truckId && ReservedStatuses.Contains(x.Status)
            && (!excludingTripId.HasValue || x.Id != excludingTripId), cancellationToken);

    public void AddTruck(Truck truck) => dbContext.Trucks.Add(truck);

    public Task<Driver?> GetDriverAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Drivers.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Driver>> ListDriversAsync(DriverStatus? status, bool? isActive, string? search, CancellationToken cancellationToken)
    {
        var query = dbContext.Drivers.AsNoTracking();
        if (status.HasValue) query = query.Where(x => x.Status == status.Value);
        if (isActive.HasValue) query = query.Where(x => x.IsActive == isActive.Value);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            query = query.Where(x => EF.Functions.ILike(x.FullName, pattern));
        }
        return await query.OrderBy(x => x.FullName).ToListAsync(cancellationToken);
    }

    public Task<bool> LicenseExistsAsync(string licenseNumber, Guid? excludingId, CancellationToken cancellationToken) =>
        dbContext.Drivers.AnyAsync(x => x.LicenseNumber == licenseNumber && (!excludingId.HasValue || x.Id != excludingId), cancellationToken);

    public Task<bool> DriverReservedAsync(Guid driverId, Guid? excludingTripId, CancellationToken cancellationToken) =>
        dbContext.Trips.AnyAsync(x => x.DriverId == driverId && ReservedStatuses.Contains(x.Status)
            && (!excludingTripId.HasValue || x.Id != excludingTripId), cancellationToken);

    public void AddDriver(Driver driver) => dbContext.Drivers.Add(driver);

    public Task<Trip?> GetTripAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Trips.Include(x => x.Stops).Include(x => x.RoutePlan)
            .Include(x => x.RepositioningPlans)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Trip>> ListTripsAsync(
        TripStatus? status,
        Guid? clientId,
        Guid? truckId,
        Guid? driverId,
        DateTimeOffset? plannedFrom,
        DateTimeOffset? plannedTo,
        CancellationToken cancellationToken)
    {
        IQueryable<Trip> query = dbContext.Trips.AsNoTracking().Include(x => x.Stops)
            .Include(x => x.RoutePlan).Include(x => x.RepositioningPlans);
        if (status.HasValue) query = query.Where(x => x.Status == status.Value);
        if (clientId.HasValue) query = query.Where(x => x.ClientId == clientId.Value);
        if (truckId.HasValue) query = query.Where(x => x.TruckId == truckId.Value);
        if (driverId.HasValue) query = query.Where(x => x.DriverId == driverId.Value);
        if (plannedFrom.HasValue) query = query.Where(x => x.PlannedStartAt >= plannedFrom.Value);
        if (plannedTo.HasValue) query = query.Where(x => x.PlannedStartAt <= plannedTo.Value);
        return await query.OrderByDescending(x => x.PlannedStartAt).ToListAsync(cancellationToken);
    }

    public void AddTrip(Trip trip) => dbContext.Trips.Add(trip);
    public void AddRepositioningPlan(TripRepositioningPlan plan) =>
        dbContext.TripRepositioningPlans.Add(plan);

    public async Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception)
        {
            throw new ConflictException(
                "The operation conflicts with existing company data or a concurrent assignment.",
                innerException: exception);
        }
    }
}
