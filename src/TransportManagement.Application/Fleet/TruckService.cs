using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Clients;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Fleet;

public sealed class TruckService(IFleetStore store, ICurrentUser currentUser, IClock clock)
{
    public async Task<TruckResponse> CreateAsync(TruckRequest request, CancellationToken cancellationToken)
    {
        await ValidateAsync(request, null, null, cancellationToken);
        var now = clock.UtcNow;
        var truck = new Truck(Guid.NewGuid(), currentUser.CompanyId,
            Normalize(request.PlateNumber)!, request.Make, request.Model, request.Year,
            request.Notes, now);
        truck.UpdateProfile(request.PlateNumber, request.FleetCode, request.Vin,
            request.Make, request.Model, request.Year, request.Type,
            request.PayloadCapacity, request.PayloadUnit, request.FuelType,
            request.OdometerKilometers, request.DefaultDriverId, request.Notes, now);
        store.AddTruck(truck);
        Event(truck, "TruckCreated", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(truck, cancellationToken);
    }

    public async Task<TruckResponse> UpdateAsync(Guid id, TruckRequest request, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        await ValidateAsync(request, id, truck, cancellationToken);
        var now = clock.UtcNow;
        var oldDefaultDriver = truck.DefaultDriverId;
        var oldOdometer = truck.OdometerKilometers;
        truck.UpdateProfile(request.PlateNumber, request.FleetCode, request.Vin,
            request.Make, request.Model, request.Year, request.Type,
            request.PayloadCapacity, request.PayloadUnit, request.FuelType,
            request.OdometerKilometers, request.DefaultDriverId, request.Notes, now);
        Event(truck, oldDefaultDriver != request.DefaultDriverId
            ? "TruckDefaultDriverChanged" : oldOdometer != request.OdometerKilometers
                ? "TruckOdometerUpdated" : "TruckProfileUpdated", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(truck, cancellationToken);
    }

    public async Task<TruckResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        await MapAsync(await RequiredAsync(id, cancellationToken), cancellationToken);

    public async Task<IReadOnlyList<TruckResponse>> ListAsync(TruckStatus? status,
        bool? isActive, string? search, TruckType? type, string? operationalState,
        CancellationToken cancellationToken)
    {
        var trucks = await store.ListTrucksAsync(status, isActive, search, type, cancellationToken);
        var result = new List<TruckResponse>(trucks.Count);
        foreach (var truck in trucks) result.Add(await MapAsync(truck, cancellationToken));
        return string.IsNullOrWhiteSpace(operationalState) ? result
            : result.Where(x => x.OperationalState.Equals(operationalState,
                StringComparison.OrdinalIgnoreCase)).ToArray();
    }

    public async Task<TruckDetailsResponse> DetailsAsync(Guid id, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        var response = await MapAsync(truck, cancellationToken);
        var position = await store.LatestTruckPositionAsync(id, cancellationToken);
        var trips = await store.ListTruckTripsAsync(id, 50, cancellationToken);
        var events = await store.ListTruckEventsAsync(id, 50, cancellationToken);
        var positionResponse = position is null ? null : new LatestTruckPositionResponse(
            position.Latitude, position.Longitude, position.Speed, position.Heading,
            position.RecordedAt, position.IsOnline,
            !position.IsOnline ? "Offline" : clock.UtcNow - position.RecordedAt > TimeSpan.FromMinutes(5)
                ? "Stale" : "Current");
        var tripSummaries = new List<ResourceTripSummaryResponse>(trips.Count);
        foreach (var trip in trips)
            tripSummaries.Add(await MapTripAsync(trip, cancellationToken));
        return new(response, positionResponse, tripSummaries,
            events.Select(x => new OperationsEventResponse(x.Id, x.EventCode,
                x.Metadata, x.CreatedAt)).ToArray());
    }

    public async Task<TruckResponse> ChangeStatusAsync(Guid id,
        TruckStatusRequest request, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        if (request.Status == TruckStatus.OnTrip)
            throw new DomainRuleException("OnTrip status is controlled by the trip lifecycle.", "DERIVED_TRUCK_STATUS");
        if (await store.TruckReservedAsync(id, null, cancellationToken))
            throw new ConflictException("The truck is reserved by an active trip.", "TRUCK_RESERVED");
        var now = clock.UtcNow;
        truck.ChangeStatus(request.Status, now);
        Event(truck, request.Status == TruckStatus.Archived ? "TruckArchived"
            : request.Status == TruckStatus.Available ? "TruckRestored" : "TruckBaseStatusChanged",
            new { status = request.Status.ToString() }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(truck, cancellationToken);
    }

    public async Task<TruckResponse> CorrectOdometerAsync(Guid id,
        OdometerCorrectionRequest request, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        var now = clock.UtcNow;
        var previous = truck.OdometerKilometers;
        truck.CorrectOdometer(request.Kilometers, request.Reason, now);
        Event(truck, "TruckOdometerCorrected", new
            { previous, current = request.Kilometers, reason = request.Reason.Trim() }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(truck, cancellationToken);
    }

    public async Task DeactivateAsync(Guid id, CancellationToken cancellationToken) =>
        _ = await ChangeStatusAsync(id, new(TruckStatus.Archived), cancellationToken);

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        if (truck.Status != TruckStatus.Archived)
            throw new ConflictException("Archive the truck before deletion.", "TRUCK_ARCHIVE_REQUIRED");
        if (await store.TruckHasHistoryAsync(id, cancellationToken))
            throw new ConflictException("A truck with operational history cannot be deleted.", "TRUCK_HAS_HISTORY");
        store.RemoveTruck(truck);
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task ValidateAsync(TruckRequest request, Guid? excludingId,
        Truck? current, CancellationToken cancellationToken)
    {
        var plate = Normalize(request.PlateNumber)!;
        if (await store.PlateExistsAsync(plate, excludingId, cancellationToken))
            throw new ConflictException("A truck with this plate number already exists in the company.", "TRUCK_PLATE_EXISTS");
        var vin = Normalize(request.Vin);
        if (vin is not null && await store.VinExistsAsync(vin, excludingId, cancellationToken))
            throw new ConflictException("A truck with this VIN already exists in the company.", "TRUCK_VIN_EXISTS");
        var code = Normalize(request.FleetCode);
        if (code is not null && await store.FleetCodeExistsAsync(code, excludingId, cancellationToken))
            throw new ConflictException("A truck with this fleet code already exists in the company.", "TRUCK_FLEET_CODE_EXISTS");
        if (current?.OdometerKilometers is decimal prior
            && request.OdometerKilometers is decimal next && next < prior)
            throw new ConflictException("Use the odometer correction flow to reduce mileage.", "ODOMETER_DECREASE_REQUIRES_CORRECTION");
        if (request.DefaultDriverId is Guid driverId)
        {
            var driver = await store.GetDriverAsync(driverId, cancellationToken)
                ?? throw new NotFoundException("Default driver was not found.");
            if (!driver.IsActive)
                throw new ConflictException("The default driver must be active.", "DEFAULT_DRIVER_INACTIVE");
        }
    }

    private async Task<TruckResponse> MapAsync(Truck truck, CancellationToken cancellationToken)
    {
        var trip = await store.CurrentTruckTripAsync(truck.Id, cancellationToken);
        Driver? defaultDriver = null;
        if (truck.DefaultDriverId is Guid driverId)
            defaultDriver = await store.GetDriverAsync(driverId, cancellationToken);
        var operational = trip?.Status switch
        {
            TripStatus.Assigned => "Reserved",
            TripStatus.EnRouteToPickup => "EnRouteToPickup",
            TripStatus.AtPickup => "AtPickup",
            TripStatus.Started or TripStatus.InTransit or TripStatus.Delivered => "OnTrip",
            _ => truck.Status.ToString()
        };
        var legacyStatus = operational is "EnRouteToPickup" or "AtPickup" or "OnTrip"
            ? TruckStatus.OnTrip : truck.Status;
        var reason = truck.Status switch
        {
            TruckStatus.Archived => "RESOURCE_INACTIVE",
            TruckStatus.Maintenance => "TRUCK_MAINTENANCE",
            TruckStatus.OutOfService => "TRUCK_OUT_OF_SERVICE",
            _ when trip is not null => "TRUCK_ALREADY_ASSIGNED",
            _ => "AVAILABLE"
        };
        return new(truck.Id, truck.PlateNumber, truck.Make, truck.Model, truck.Year,
            legacyStatus, truck.Notes, truck.IsActive, truck.CreatedAt, truck.UpdatedAt,
            truck.FleetCode, truck.Vin, truck.Type, truck.PayloadCapacity,
            truck.PayloadUnit, truck.FuelType, truck.OdometerKilometers,
            truck.DefaultDriverId, defaultDriver?.FullName, truck.Status, operational,
            trip?.Id, trip?.TripNumber, trip?.DriverId, reason == "AVAILABLE", reason);
    }

    private async Task<Truck> RequiredAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetTruckAsync(id, cancellationToken)
        ?? throw new NotFoundException("Truck was not found.");
    private void Event(Truck truck, string code, object? metadata, DateTimeOffset now) =>
        store.AddTruckEvent(new(Guid.NewGuid(), truck.CompanyId, truck.Id,
            currentUser.UserId, code, metadata is null ? null : JsonSerializer.Serialize(metadata), now));
    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToUpperInvariant();
    private async Task<ResourceTripSummaryResponse> MapTripAsync(Trip x,
        CancellationToken cancellationToken)
    {
        var driver = x.DriverId is Guid driverId
            ? await store.GetDriverAsync(driverId, cancellationToken) : null;
        return new(x.Id, x.TripNumber, x.Origin, x.Destination,
            x.PlannedStartAt ?? x.CreatedAt, x.Status.ToString(), x.TruckId,
            x.TruckId == null ? null : (await store.GetTruckAsync(x.TruckId.Value,
                cancellationToken))?.PlateNumber, x.DriverId, driver?.FullName);
    }
}
