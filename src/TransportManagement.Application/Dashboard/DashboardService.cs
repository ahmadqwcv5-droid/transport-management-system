using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Tracking;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Dashboard;

public sealed class DashboardService(
    IFleetStore fleetStore,
    ITripQueryStore tripStore,
    TrackingService trackingService,
    IClock clock)
{
    public async Task<DashboardResponse> GetAsync(CancellationToken cancellationToken)
    {
        var trucks = await fleetStore.ListTrucksAsync(null, true, null, null, cancellationToken);
        var trips = await tripStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var positions = await trackingService.CurrentAsync(cancellationToken);
        var simulatorTrucks = await trackingService.SimulatorInventoryAsync(false, cancellationToken);
        var activeStatuses = new[] { TripStatus.Assigned, TripStatus.EnRouteToPickup,
            TripStatus.AtPickup, TripStatus.Started, TripStatus.InTransit, TripStatus.Delivered };
        var today = clock.UtcNow.UtcDateTime.Date;
        var reservedTruckIds = trips.Where(x => x.TruckId.HasValue
                && activeStatuses.Contains(x.Status)).Select(x => x.TruckId!.Value)
            .ToHashSet();
        return new(
            new(trucks.Count,
                trucks.Count(x => x.Status == TruckStatus.Available && !reservedTruckIds.Contains(x.Id)),
                trucks.Count(x => reservedTruckIds.Contains(x.Id)),
                trucks.Count(x => x.Status == TruckStatus.Maintenance),
                trucks.Count(x => x.Status == TruckStatus.OutOfService)),
            new(trips.Count(x => activeStatuses.Contains(x.Status)),
                trips.Count(x => x.Status == TripStatus.Completed && x.CompletedAt?.UtcDateTime.Date == today)),
            new(positions.Count(x => x.IsOnline), positions.Count(x => !x.IsOnline)),
            positions,
            simulatorTrucks,
            trips.OrderByDescending(x => x.UpdatedAt).Take(8)
                .Select(x => new RecentTripResponse(x.Id, x.TripNumber, x.Origin,
                    x.Destination, x.Status.ToString(), x.PlannedStartAt)).ToArray());
    }
}
