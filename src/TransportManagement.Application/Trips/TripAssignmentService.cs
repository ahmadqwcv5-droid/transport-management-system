using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed class TripAssignmentService(
    ITripStore tripStore,
    IFleetStore fleetStore,
    IClock clock,
    TripEntityResolver resolver,
    TripEventWriter events,
    ResourceEventWriter resourceEvents)
{
    public async Task<AssignmentOptionsResponse> OptionsAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        var readiness = TripResponseMapper.Readiness(trip);
        var canChoose = trip.Status == TripStatus.Draft
            ? readiness.CanAssign : trip.Status == TripStatus.Assigned;
        var trucks = await fleetStore.ListTrucksAsync(null, null, null, null, cancellationToken);
        var drivers = await fleetStore.ListDriversAsync(null, null, null, cancellationToken);
        var truckReservations = (await fleetStore.TruckReservationsAsync(trip.Id, cancellationToken))
            .GroupBy(x => x.ResourceId).ToDictionary(x => x.Key, x => x.First());
        var driverReservations = (await fleetStore.DriverReservationsAsync(trip.Id, cancellationToken))
            .GroupBy(x => x.ResourceId).ToDictionary(x => x.Key, x => x.First());
        var selectedTruck = trip.TruckId.HasValue
            ? trucks.FirstOrDefault(x => x.Id == trip.TruckId.Value) : null;
        var suggestedDriver = selectedTruck?.DefaultDriverId is Guid defaultId
            ? drivers.FirstOrDefault(x => x.Id == defaultId) : null;
        var defaultReservation = suggestedDriver is null ? null
            : driverReservations.GetValueOrDefault(suggestedDriver.Id);
        var suggestionReason = suggestedDriver is null ? null
            : !suggestedDriver.IsActive ? "DEFAULT_DRIVER_INACTIVE"
            : defaultReservation is not null ? "DRIVER_ALREADY_ASSIGNED"
            : suggestedDriver.Status != DriverStatus.Available ? "DRIVER_NOT_AVAILABLE"
            : "AVAILABLE";
        return new(trip.Id, trip.TruckId, trip.DriverId, canChoose,
            trucks.Select(truck => TruckOption(truck, canChoose,
                truckReservations.GetValueOrDefault(truck.Id))).ToArray(),
            drivers.Select(driver => DriverOption(driver, canChoose,
                driverReservations.GetValueOrDefault(driver.Id))).ToArray(),
            suggestionReason == "AVAILABLE" ? suggestedDriver?.Id : null,
            suggestionReason);
    }

    public async Task<TripResponse> AssignAsync(
        Guid id, AssignTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (!TripResponseMapper.Readiness(trip).CanAssign)
            throw new ConflictException("Complete the Draft and calculate its current route before assignment.", "TRIP_NOT_READY_FOR_ASSIGNMENT");
        await resolver.ActiveClientAsync(trip.ClientId, cancellationToken);
        var (truck, driver) = await AvailableResourcesAsync(trip, request, cancellationToken);
        trip.Assign(truck.Id, driver.Id, clock.UtcNow);
        events.Append(trip, "Assigned", new { truckId = truck.Id, driverId = driver.Id });
        resourceEvents.Truck(truck.Id, "TruckAssignedToTrip",
            new { tripId = trip.Id, trip.TripNumber, driverId = driver.Id });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> ReassignAsync(
        Guid id, AssignTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new ConflictException("Only a trip awaiting dispatch can be reassigned.", "TRIP_REASSIGN_NOT_ALLOWED");
        var oldTruckId = trip.TruckId;
        var oldDriverId = trip.DriverId;
        var (truck, driver) = await AvailableResourcesAsync(trip, request, cancellationToken);
        trip.Reassign(truck.Id, driver.Id, clock.UtcNow);
        events.Append(trip, "Reassigned", new
            { oldTruckId, oldDriverId, newTruckId = truck.Id, newDriverId = driver.Id });
        if (oldTruckId is Guid previousTruckId)
            resourceEvents.Truck(previousTruckId, "TruckUnassignedFromTrip",
                new { tripId = trip.Id, trip.TripNumber });
        resourceEvents.Truck(truck.Id, "TruckAssignedToTrip",
            new { tripId = trip.Id, trip.TripNumber, driverId = driver.Id });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> UnassignAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new ConflictException("Only a trip awaiting dispatch can be unassigned.", "TRIP_UNASSIGN_NOT_ALLOWED");
        var oldTruckId = trip.TruckId;
        var oldDriverId = trip.DriverId;
        trip.Unassign(clock.UtcNow);
        events.Append(trip, "Unassigned", new { oldTruckId, oldDriverId });
        if (oldTruckId is Guid truckId)
            resourceEvents.Truck(truckId, "TruckUnassignedFromTrip",
                new { tripId = trip.Id, trip.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    private async Task<(Truck Truck, Driver Driver)> AvailableResourcesAsync(
        Trip trip, AssignTripRequest request, CancellationToken cancellationToken)
    {
        var truck = await resolver.TruckAsync(request.TruckId, cancellationToken);
        var driver = await resolver.DriverAsync(request.DriverId, cancellationToken);
        if (!truck.IsActive || truck.Status != TruckStatus.Available)
            throw new ConflictException("The selected truck is not active and available.", "TRUCK_NOT_AVAILABLE");
        if (!driver.IsActive || driver.Status != DriverStatus.Available)
            throw new ConflictException("The selected driver is not active and available.", "DRIVER_NOT_AVAILABLE");
        if (await fleetStore.TruckReservedAsync(truck.Id, trip.Id, cancellationToken))
            throw new ConflictException("The selected truck is already reserved by an active trip.", "TRUCK_ALREADY_ASSIGNED");
        if (await fleetStore.DriverReservedAsync(driver.Id, trip.Id, cancellationToken))
            throw new ConflictException("The selected driver is already reserved by an active trip.", "DRIVER_ALREADY_ASSIGNED");
        return (truck, driver);
    }

    private static AssignmentResourceOptionResponse TruckOption(
        Truck truck, bool tripCanAssign, ResourceReservation? reservation)
    {
        var reason = !tripCanAssign ? "TRIP_NOT_READY_FOR_ASSIGNMENT"
            : !truck.IsActive ? "RESOURCE_INACTIVE"
            : reservation is not null ? "TRUCK_ALREADY_ASSIGNED"
            : truck.Status == TruckStatus.Maintenance ? "TRUCK_MAINTENANCE"
            : truck.Status == TruckStatus.OutOfService ? "TRUCK_OUT_OF_SERVICE"
            : truck.Status == TruckStatus.Archived ? "RESOURCE_INACTIVE" : "AVAILABLE";
        return new(truck.Id, truck.PlateNumber, truck.Status.ToString(),
            reason == "AVAILABLE", reason, reservation?.TripId, reservation?.TripNumber,
            truck.FleetCode, truck.Type?.ToString(), truck.PayloadCapacity,
            truck.PayloadUnit.ToString(), truck.DefaultDriverId);
    }

    private static AssignmentResourceOptionResponse DriverOption(
        Driver driver, bool tripCanAssign, ResourceReservation? reservation)
    {
        var reason = !tripCanAssign ? "TRIP_NOT_READY_FOR_ASSIGNMENT"
            : !driver.IsActive ? "RESOURCE_INACTIVE"
            : reservation is not null ? "DRIVER_ALREADY_ASSIGNED"
            : driver.Status == DriverStatus.OnTrip ? "DRIVER_ON_TRIP"
            : driver.Status != DriverStatus.Available ? "DRIVER_NOT_AVAILABLE" : "AVAILABLE";
        return new(driver.Id, driver.FullName, driver.Status.ToString(),
            reason == "AVAILABLE", reason, reservation?.TripId, reservation?.TripNumber);
    }
}
