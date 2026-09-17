using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Tracking;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Dashboard;

public sealed class DashboardService(
    IOperationsStore operationsStore,
    TrackingService trackingService,
    IClock clock)
{
    public async Task<DashboardResponse> GetAsync(CancellationToken cancellationToken)
    {
        var trucks = await operationsStore.ListTrucksAsync(null, true, null, cancellationToken);
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var positions = await trackingService.CurrentAsync(cancellationToken);
        var activeStatuses = new[] { TripStatus.Assigned, TripStatus.Started, TripStatus.InTransit, TripStatus.Delivered };
        var today = clock.UtcNow.UtcDateTime.Date;
        return new(
            new(trucks.Count,
                trucks.Count(x => x.Status == TruckStatus.Available),
                trucks.Count(x => x.Status == TruckStatus.OnTrip),
                trucks.Count(x => x.Status == TruckStatus.Maintenance),
                trucks.Count(x => x.Status == TruckStatus.OutOfService)),
            new(trips.Count(x => activeStatuses.Contains(x.Status)),
                trips.Count(x => x.Status == TripStatus.Completed && x.CompletedAt?.UtcDateTime.Date == today)),
            new(positions.Count(x => x.IsOnline), positions.Count(x => !x.IsOnline)),
            positions,
            trips.OrderByDescending(x => x.UpdatedAt).Take(8)
                .Select(x => new RecentTripResponse(x.Id, x.Origin, x.Destination, x.Status.ToString(), x.PlannedStartAt)).ToArray());
    }
}
