using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using System.Data;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class OperationsStore(AppDbContext dbContext) : IOperationsStore
{
    private static readonly SemaphoreSlim CounterLock = new(1, 1);
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
            .Include(x => x.RepositioningPlans).Include(x => x.Events)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<string> AllocateTripNumberAsync(
        Guid companyId, int year, CancellationToken cancellationToken)
    {
        long value;
        if (dbContext.Database.IsRelational())
        {
            var connection = dbContext.Database.GetDbConnection();
            var closeAfterward = connection.State != ConnectionState.Open;
            if (closeAfterward) await connection.OpenAsync(cancellationToken);
            try
            {
                await using var command = connection.CreateCommand();
                command.CommandText = """
                INSERT INTO trip_number_counters ("CompanyId", "Year", "LastValue")
                VALUES (@companyId, @year, 1)
                ON CONFLICT ("CompanyId", "Year")
                DO UPDATE SET "LastValue" = trip_number_counters."LastValue" + 1
                RETURNING "LastValue"
                """;
                var companyParameter = command.CreateParameter();
                companyParameter.ParameterName = "companyId";
                companyParameter.Value = companyId;
                command.Parameters.Add(companyParameter);
                var yearParameter = command.CreateParameter();
                yearParameter.ParameterName = "year";
                yearParameter.Value = year;
                command.Parameters.Add(yearParameter);
                if (dbContext.Database.CurrentTransaction is { } transaction)
                    command.Transaction = transaction.GetDbTransaction();
                var result = await command.ExecuteScalarAsync(cancellationToken)
                    ?? throw new InvalidOperationException("Trip number allocation returned no value.");
                value = Convert.ToInt64(result, System.Globalization.CultureInfo.InvariantCulture);
            }
            finally
            {
                if (closeAfterward) await connection.CloseAsync();
            }
        }
        else
        {
            await CounterLock.WaitAsync(cancellationToken);
            try
            {
                var counter = await dbContext.TripNumberCounters
                    .SingleOrDefaultAsync(x => x.CompanyId == companyId && x.Year == year, cancellationToken);
                value = counter?.LastValue + 1 ?? 1;
                if (counter is null) dbContext.TripNumberCounters.Add(new(companyId, year, value));
                else dbContext.Entry(counter).Property(x => x.LastValue).CurrentValue = value;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            finally { CounterLock.Release(); }
        }
        return $"TRP-{year}-{value:000000}";
    }

    public async Task<(IReadOnlyList<Trip> Items, int TotalCount)> QueryTripsAsync(
        TripListQuery query, CancellationToken cancellationToken)
    {
        IQueryable<Trip> source = dbContext.Trips.AsNoTracking();
        if (query.Status.HasValue) source = source.Where(x => x.Status == query.Status.Value);
        if (query.Archived.HasValue)
            source = source.Where(x => x.ArchivedAt.HasValue == query.Archived.Value);
        if (!string.IsNullOrWhiteSpace(query.OperationalGroup))
        {
            source = query.OperationalGroup.Trim().ToLowerInvariant() switch
            {
                "active" => source.Where(x => !x.ArchivedAt.HasValue &&
                    (x.Status == TripStatus.EnRouteToPickup || x.Status == TripStatus.AtPickup ||
                     x.Status == TripStatus.Started || x.Status == TripStatus.InTransit || x.Status == TripStatus.Delivered)),
                "planned" => source.Where(x => !x.ArchivedAt.HasValue &&
                    (x.Status == TripStatus.Draft || x.Status == TripStatus.Assigned)),
                "completed" => source.Where(x => !x.ArchivedAt.HasValue && x.Status == TripStatus.Completed),
                "cancelled" => source.Where(x => !x.ArchivedAt.HasValue && x.Status == TripStatus.Cancelled),
                "archived" => source.Where(x => x.ArchivedAt.HasValue &&
                    (x.Status == TripStatus.Completed || x.Status == TripStatus.Cancelled)),
                _ => source.Where(_ => false)
            };
        }
        if (query.ClientId.HasValue) source = source.Where(x => x.ClientId == query.ClientId.Value);
        if (query.TruckId.HasValue) source = source.Where(x => x.TruckId == query.TruckId.Value);
        if (query.DriverId.HasValue) source = source.Where(x => x.DriverId == query.DriverId.Value);
        if (query.PlannedFrom.HasValue) source = source.Where(x => x.PlannedStartAt >= query.PlannedFrom.Value);
        if (query.PlannedTo.HasValue) source = source.Where(x => x.PlannedStartAt <= query.PlannedTo.Value);
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var term = query.Search.Trim();
            if (dbContext.Database.IsRelational())
            {
                var pattern = $"%{term}%";
                source = source.Where(x => EF.Functions.ILike(x.TripNumber, pattern)
                    || (x.Origin != null && EF.Functions.ILike(x.Origin, pattern))
                    || (x.Destination != null && EF.Functions.ILike(x.Destination, pattern))
                    || dbContext.Clients.Any(c => c.Id == x.ClientId && EF.Functions.ILike(c.Name, pattern))
                    || (x.TruckId != null && dbContext.Trucks.Any(t => t.Id == x.TruckId && EF.Functions.ILike(t.PlateNumber, pattern))));
            }
            else
            {
                source = source.Where(x => x.TripNumber.Contains(term, StringComparison.OrdinalIgnoreCase)
                    || (x.Origin != null && x.Origin.Contains(term, StringComparison.OrdinalIgnoreCase))
                    || (x.Destination != null && x.Destination.Contains(term, StringComparison.OrdinalIgnoreCase))
                    || dbContext.Clients.Any(c => c.Id == x.ClientId && c.Name.Contains(term, StringComparison.OrdinalIgnoreCase))
                    || (x.TruckId != null && dbContext.Trucks.Any(t => t.Id == x.TruckId && t.PlateNumber.Contains(term, StringComparison.OrdinalIgnoreCase))));
            }
        }
        var total = await source.CountAsync(cancellationToken);
        var ascending = query.Direction.Equals("asc", StringComparison.OrdinalIgnoreCase);
        IOrderedQueryable<Trip> ordered = query.Sort.ToLowerInvariant() switch
        {
            "tripnumber" => ascending ? source.OrderBy(x => x.TripNumber) : source.OrderByDescending(x => x.TripNumber),
            "created" => ascending ? source.OrderBy(x => x.CreatedAt) : source.OrderByDescending(x => x.CreatedAt),
            "status" => ascending ? source.OrderBy(x => x.Status) : source.OrderByDescending(x => x.Status),
            _ => ascending ? source.OrderBy(x => x.PlannedStartAt) : source.OrderByDescending(x => x.PlannedStartAt)
        };
        var items = await ordered.ThenBy(x => x.Id)
            .Skip((query.Page - 1) * query.PageSize).Take(query.PageSize)
            .Include(x => x.Stops).Include(x => x.RoutePlan).Include(x => x.RepositioningPlans)
            .ToListAsync(cancellationToken);
        return (items, total);
    }

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
    public void AddTripStops(IReadOnlyCollection<TripStop> stops) =>
        dbContext.TripStops.AddRange(stops);
    public void RemoveTrip(Trip trip) => dbContext.Trips.Remove(trip);
    public void AddTripEvent(TripEvent tripEvent) => dbContext.TripEvents.Add(tripEvent);
    public async Task<(IReadOnlyList<TripEvent> Items, int TotalCount)> ListTripEventsAsync(
        Guid tripId, int page, int pageSize, CancellationToken cancellationToken)
    {
        var source = dbContext.TripEvents.AsNoTracking().Where(x => x.TripId == tripId);
        var total = await source.CountAsync(cancellationToken);
        var items = await source.OrderByDescending(x => x.OccurredAt).ThenByDescending(x => x.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return (items, total);
    }
    public Task<string?> UserDisplayNameAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.Users.Where(x => x.Id == userId).Select(x => x.DisplayName)
            .SingleOrDefaultAsync(cancellationToken);
    public void AddRepositioningPlan(TripRepositioningPlan plan) =>
        dbContext.TripRepositioningPlans.Add(plan);
    public void AddTripRoutePlan(TripRoutePlan plan) =>
        dbContext.TripRoutePlans.Add(plan);

    public async Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException exception)
        {
            throw new ConflictException("The trip was changed by another user.",
                "TRIP_CONCURRENCY_CONFLICT", exception);
        }
        catch (DbUpdateException exception)
        {
            throw new ConflictException(
                "The operation conflicts with existing company data or a concurrent assignment.",
                innerException: exception);
        }
    }
}
