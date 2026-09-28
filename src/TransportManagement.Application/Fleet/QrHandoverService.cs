using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Fleet;

public sealed class QrHandoverService(
    IQrHandoverStore store,
    ITruckPhotoStore photos,
    ICurrentUser currentUser,
    IClock clock)
{
    public async Task<TruckQrCredentialResponse> GenerateQrAsync(
        Guid truckId, CancellationToken cancellationToken)
    {
        var truck = await RequiredTruckAsync(truckId, cancellationToken);
        var now = clock.UtcNow;
        var current = await store.FindActiveQrForTruckAsync(truckId, cancellationToken);
        current?.Revoke(currentUser.UserId, now);
        var code = GenerateSecret();
        var credential = new TruckQrCredential(Guid.NewGuid(), currentUser.CompanyId,
            truckId, Hash(code), code[^8..], currentUser.UserId, now);
        store.AddQr(credential);
        store.AddTruckEvent(new TruckEvent(Guid.NewGuid(), currentUser.CompanyId,
            truckId, currentUser.UserId, "TruckQrRegenerated",
            JsonSerializer.Serialize(new { credentialId = credential.Id }), now));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "TruckQrRegenerated", "Information",
            null, truck.Id, null, $"TruckQrRegenerated:{credential.Id}",
            JsonSerializer.Serialize(new
            {
                eventCode = "TRUCK_QR_REGENERATED",
                credentialId = credential.Id,
                truckId = truck.Id,
                truck.PlateNumber
            }), now));
        await store.SaveChangesAsync(cancellationToken);
        return new(truck.Id, truck.PlateNumber, truck.FleetCode, code,
            credential.CodeHint, $"tms-truck://qr/{code}", credential.GeneratedAt);
    }

    public async Task<TruckQrPreviewResponse> PreviewAsync(
        ResolveTruckQrRequest request, CancellationToken cancellationToken)
    {
        var driver = await RequiredCurrentDriverAsync(cancellationToken);
        var (credential, truck) = await ResolveAsync(request.Code, cancellationToken);
        var session = await store.FindActiveSessionForTruckAsync(truck.Id, cancellationToken);
        var sessionDriver = session is null ? null
            : await store.FindDriverAsync(session.DriverId, cancellationToken);
        var trip = await store.FindCurrentTripForTruckAsync(truck.Id, cancellationToken);
        var photo = await photos.GetAsync(truck.Id, cancellationToken);
        var position = await store.FindLatestPositionAsync(truck.Id, cancellationToken);
        return new(truck.Id, truck.PlateNumber, truck.FleetCode, truck.Status.ToString(),
            photo is null ? null : $"/api/driver/my-trip/truck-photo/thumbnail?v={photo.Version}",
            session?.DriverId, sessionDriver?.FullName, trip?.Id, trip?.TripNumber,
            trip?.Status.ToString(), trip?.DriverId.HasValue == true
                && trip.DriverId != driver.Id, position?.RecordedAt);
    }

    public async Task<TruckSwitchResponse> ConfirmAsync(
        ConfirmTruckQrRequest request, CancellationToken cancellationToken)
    {
        var driver = await RequiredCurrentDriverAsync(cancellationToken);
        var (_, truck) = await ResolveAsync(request.Code, cancellationToken);
        if (!truck.IsActive || truck.Status is TruckStatus.Maintenance or TruckStatus.OutOfService)
            throw new ConflictException("The truck is not available for a session.",
                "TRUCK_NOT_AVAILABLE");

        var trip = await store.FindCurrentTripForTruckAsync(truck.Id, cancellationToken);
        if (trip?.DriverId is Guid currentDriverId && currentDriverId != driver.Id)
        {
            var existing = await store.FindPendingHandoverAsync(trip.Id, cancellationToken);
            if (existing is not null)
                return new("HandoverPending", truck.Id, driver.Id, null,
                    existing.Id, trip.Id);
            var handover = new TripHandoverRequest(Guid.NewGuid(), currentUser.CompanyId,
                trip.Id, truck.Id, currentDriverId, driver.Id, trip.Version,
                clock.UtcNow.AddMinutes(15), currentUser.UserId, request.Reason, clock.UtcNow);
            store.AddHandover(handover);
            AddHandoverRequestedAudit(handover, trip, clock.UtcNow);
            await store.SaveChangesAsync(cancellationToken);
            return new("HandoverPending", truck.Id, driver.Id, null,
                handover.Id, trip.Id);
        }

        var truckSession = await store.FindActiveSessionForTruckAsync(
            truck.Id, cancellationToken);
        if (truckSession is not null && truckSession.DriverId != driver.Id)
            throw new ConflictException("The truck is operated by another Driver.",
                "TRUCK_SESSION_CONFLICT");
        if (truckSession?.DriverId == driver.Id)
            return new("AlreadyActive", truck.Id, driver.Id,
                truckSession.Id, null, trip?.Id);

        var driverSession = await store.FindActiveSessionForDriverAsync(
            driver.Id, cancellationToken);
        if (driverSession is not null && driverSession.TruckId != truck.Id)
        {
            if (driverSession.LastTripId.HasValue)
            {
                var previousTrip = await store.FindTripAsync(
                    driverSession.LastTripId.Value, cancellationToken);
                if (previousTrip?.ReservesResources == true)
                    throw new ConflictException(
                        "Complete or hand over the active trip before switching trucks.",
                        "DRIVER_ACTIVE_TRIP_CONFLICT");
            }
            driverSession.End("DriverQrSwitch", clock.UtcNow);
        }

        var session = new DriverTruckSession(Guid.NewGuid(), currentUser.CompanyId,
            driver.Id, truck.Id, trip?.Id, "DriverQrScan",
            currentUser.UserId, null, clock.UtcNow);
        store.AddSession(session);
        store.AddTruckEvent(new TruckEvent(Guid.NewGuid(), currentUser.CompanyId,
            truck.Id, currentUser.UserId, "TruckSessionStarted",
            JsonSerializer.Serialize(new { sessionId = session.Id, source = "DriverQrScan" }),
            clock.UtcNow));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "TruckSessionStarted", "Information",
            trip?.Id, truck.Id, driver.Id, $"TruckSessionStarted:{session.Id}",
            JsonSerializer.Serialize(new { eventCode = "TRUCK_SESSION_STARTED",
                sessionId = session.Id, truck.PlateNumber, source = "DriverQrScan" }),
            clock.UtcNow));
        await store.SaveChangesAsync(cancellationToken);
        return new("SessionStarted", truck.Id, driver.Id, session.Id, null, trip?.Id);
    }

    public async Task<HandoverResponse> CreateManagerHandoverAsync(
        CreateHandoverRequest request, CancellationToken cancellationToken)
    {
        var trip = await store.FindTripAsync(request.TripId, cancellationToken)
            ?? throw new NotFoundException("Trip was not found.", "TRIP_NOT_FOUND");
        if (!trip.ReservesResources || !trip.TruckId.HasValue || !trip.DriverId.HasValue)
            throw new ConflictException("The trip is not eligible for handover.",
                "HANDOVER_REQUEST_STALE");
        var requesting = await store.FindDriverAsync(
            request.RequestingDriverId, cancellationToken)
            ?? throw new NotFoundException("Driver was not found.", "DRIVER_NOT_FOUND");
        if (!requesting.IsActive || requesting.Id == trip.DriverId)
            throw new ConflictException("Select a different active Driver.",
                "HANDOVER_DRIVER_INVALID");
        var pending = await store.FindPendingHandoverAsync(trip.Id, cancellationToken);
        if (pending is not null)
            throw new ConflictException("A handover is already pending.",
                "HANDOVER_ALREADY_PENDING");
        var handover = new TripHandoverRequest(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, trip.TruckId.Value, trip.DriverId.Value, requesting.Id,
            trip.Version, clock.UtcNow.AddMinutes(15), currentUser.UserId,
            request.Reason, clock.UtcNow);
        store.AddHandover(handover);
        AddHandoverRequestedAudit(handover, trip, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(handover, cancellationToken);
    }

    public async Task<IReadOnlyList<HandoverResponse>> ListAsync(
        CancellationToken cancellationToken)
    {
        var handovers = await store.ListHandoversAsync(cancellationToken);
        var result = new List<HandoverResponse>(handovers.Count);
        foreach (var handover in handovers)
            result.Add(await MapAsync(handover, cancellationToken));
        return result;
    }

    public async Task<HandoverResponse> ApproveAsync(
        Guid requestId, ResolveHandoverRequest request,
        CancellationToken cancellationToken)
    {
        var handover = await store.FindHandoverAsync(requestId, cancellationToken)
            ?? throw new NotFoundException("Handover was not found.", "HANDOVER_NOT_FOUND");
        if (handover.Status == TripHandoverStatus.Approved)
            return await MapAsync(handover, cancellationToken);
        if (handover.Status != TripHandoverStatus.Pending || handover.IsExpired(clock.UtcNow))
        {
            handover.Expire(clock.UtcNow);
            await store.SaveChangesAsync(cancellationToken);
            throw new ConflictException("The handover request is stale.",
                "HANDOVER_REQUEST_STALE");
        }

        var trip = await store.FindTripAsync(handover.TripId, cancellationToken)
            ?? throw new ConflictException("The trip no longer exists.",
                "HANDOVER_REQUEST_STALE");
        if (trip.Version != handover.ExpectedTripVersion
            || trip.TruckId != handover.TruckId
            || trip.DriverId != handover.CurrentDriverId)
            throw new ConflictException("The trip assignment changed.",
                "HANDOVER_REQUEST_STALE");
        var oldDriver = await store.FindDriverAsync(
            handover.CurrentDriverId, cancellationToken)
            ?? throw new ConflictException("The current Driver is unavailable.",
                "HANDOVER_REQUEST_STALE");
        var newDriver = await store.FindDriverAsync(
            handover.RequestingDriverId, cancellationToken)
            ?? throw new ConflictException("The requesting Driver is unavailable.",
                "HANDOVER_REQUEST_STALE");
        if (!newDriver.IsActive)
            throw new ConflictException("The requesting Driver is inactive.",
                "HANDOVER_REQUEST_STALE");

        var now = clock.UtcNow;
        var newDriverSession = await store.FindActiveSessionForDriverAsync(
            newDriver.Id, cancellationToken);
        if (newDriverSession is not null && newDriverSession.TruckId != handover.TruckId)
        {
            if (newDriverSession.LastTripId.HasValue)
            {
                var conflictingTrip = await store.FindTripAsync(
                    newDriverSession.LastTripId.Value, cancellationToken);
                if (conflictingTrip?.ReservesResources == true)
                    throw new ConflictException(
                        "The requesting Driver is operating another active trip.",
                        "DRIVER_ACTIVE_TRIP_CONFLICT");
            }
            newDriverSession.End("ApprovedHandover", now);
        }

        var oldSession = await store.FindActiveSessionForTruckAsync(
            handover.TruckId, cancellationToken);
        if (oldSession is not null && oldSession.DriverId != oldDriver.Id)
            throw new ConflictException("The active truck session changed.",
                "HANDOVER_REQUEST_STALE");
        oldSession?.End("ApprovedHandover", now);

        var position = await store.FindLatestPositionAsync(
            handover.TruckId, cancellationToken);
        var activeParticipation = await store.FindActiveParticipationAsync(
            trip.Id, cancellationToken);
        if (activeParticipation is null)
        {
            activeParticipation = new TripDriverParticipation(Guid.NewGuid(),
                currentUser.CompanyId, trip.Id, oldDriver.Id, trip.CreatedAt,
                "Assignment", TripStatus.Assigned, null, null, null, trip.CreatedAt);
            store.AddParticipation(activeParticipation);
        }
        else if (activeParticipation.DriverId != oldDriver.Id)
        {
            throw new ConflictException("The Driver participation changed.",
                "HANDOVER_REQUEST_STALE");
        }
        activeParticipation.End(now, trip.Status, position?.Id, currentUser.UserId);

        trip.HandoverDriver(oldDriver.Id, newDriver.Id,
            handover.ExpectedTripVersion, now);
        oldDriver.ChangeStatus(DriverStatus.Available, now);
        newDriver.ChangeStatus(DriverStatus.OnTrip, now);
        var newSession = new DriverTruckSession(Guid.NewGuid(), currentUser.CompanyId,
            newDriver.Id, handover.TruckId, trip.Id, "ApprovedHandover",
            handover.RequestedByAccountId, currentUser.UserId, now);
        store.AddSession(newSession);
        store.AddParticipation(new TripDriverParticipation(Guid.NewGuid(),
            currentUser.CompanyId, trip.Id, newDriver.Id, now, "ApprovedHandover",
            trip.Status, currentUser.UserId, handover.Id, position?.Id, now));
        handover.Approve(currentUser.UserId, request.Reason, now);

        var metadata = JsonSerializer.Serialize(new
        {
            requestId = handover.Id,
            previousDriverId = oldDriver.Id,
            newDriverId = newDriver.Id,
            initiatorAccountId = handover.RequestedByAccountId,
            approverAccountId = currentUser.UserId,
            handover.TruckId,
            phase = trip.Status.ToString(),
            reason = request.Reason,
            positionId = position?.Id
        });
        store.AddTripEvent(new TripEvent(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, "DriverHandoverApproved", now, currentUser.UserId,
            "ManagerOverride", metadata, now));
        store.AddTruckEvent(new TruckEvent(Guid.NewGuid(), currentUser.CompanyId,
            handover.TruckId, currentUser.UserId, "TruckSessionSwitched",
            metadata, now));
        AddHandoverNotifications(handover, trip, oldDriver, newDriver, metadata, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(handover, cancellationToken);
    }

    public async Task<HandoverResponse> RejectAsync(
        Guid requestId, ResolveHandoverRequest request,
        CancellationToken cancellationToken)
    {
        var handover = await store.FindHandoverAsync(requestId, cancellationToken)
            ?? throw new NotFoundException("Handover was not found.", "HANDOVER_NOT_FOUND");
        handover.Reject(currentUser.UserId, request.Reason, clock.UtcNow);
        var trip = await store.FindTripAsync(handover.TripId, cancellationToken);
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "DriverHandoverRejected", "Warning",
            handover.TripId, handover.TruckId, handover.RequestingDriverId,
            $"DriverHandoverRejected:{handover.Id}",
            JsonSerializer.Serialize(new { eventCode = "HANDOVER_REJECTED",
                requestId = handover.Id, request.Reason }), clock.UtcNow));
        if (trip is not null)
            store.AddTripEvent(new TripEvent(Guid.NewGuid(), currentUser.CompanyId,
                trip.Id, "DriverHandoverRejected", clock.UtcNow,
                currentUser.UserId, "ManagerOverride",
                JsonSerializer.Serialize(new { requestId = handover.Id, request.Reason }),
                clock.UtcNow));
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(handover, cancellationToken);
    }

    private void AddHandoverRequestedAudit(
        TripHandoverRequest handover, Trip trip, DateTimeOffset now)
    {
        var metadata = JsonSerializer.Serialize(new
        {
            requestId = handover.Id,
            handover.CurrentDriverId,
            handover.RequestingDriverId,
            handover.TruckId,
            phase = trip.Status.ToString(),
            handover.Reason
        });
        store.AddTripEvent(new TripEvent(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, "DriverHandoverRequested", now, currentUser.UserId,
            "User", metadata, now));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "DriverHandoverRequested", "Warning",
            trip.Id, handover.TruckId, null,
            $"DriverHandoverRequested:{handover.Id}", metadata, now));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "DriverHandoverPending", "Information",
            trip.Id, handover.TruckId, handover.RequestingDriverId,
            $"DriverHandoverPending:{handover.Id}", metadata, now));
    }

    private void AddHandoverNotifications(TripHandoverRequest handover, Trip trip,
        Driver oldDriver, Driver newDriver, string metadata, DateTimeOffset now)
    {
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "DriverHandoverApproved", "Information",
            trip.Id, handover.TruckId, oldDriver.Id,
            $"DriverHandoverApproved:old:{handover.Id}", metadata, now));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "DriverHandoverApproved", "Information",
            trip.Id, handover.TruckId, newDriver.Id,
            $"DriverHandoverApproved:new:{handover.Id}", metadata, now));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "DriverHandoverApproved", "Information",
            trip.Id, handover.TruckId, null,
            $"DriverHandoverApproved:manager:{handover.Id}", metadata, now));
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, "TruckSessionSwitched", "Information",
            trip.Id, handover.TruckId, newDriver.Id,
            $"TruckSessionSwitched:{handover.Id}", metadata, now));
    }

    private async Task<(TruckQrCredential Credential, Truck Truck)> ResolveAsync(
        string rawCode, CancellationToken cancellationToken)
    {
        var credential = await store.FindActiveQrByHashAsync(
            Hash(rawCode), cancellationToken)
            ?? throw new NotFoundException("Truck QR code was not found.",
                "TRUCK_QR_INVALID");
        var truck = await RequiredTruckAsync(credential.TruckId, cancellationToken);
        return (credential, truck);
    }

    private async Task<Truck> RequiredTruckAsync(
        Guid truckId, CancellationToken cancellationToken) =>
        await store.FindTruckAsync(truckId, cancellationToken)
        ?? throw new NotFoundException("Truck was not found.", "TRUCK_NOT_FOUND");

    private async Task<Driver> RequiredCurrentDriverAsync(
        CancellationToken cancellationToken)
    {
        var driver = await store.FindDriverByAccountAsync(
            currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(
                "The signed-in account is not linked to a Driver.", "DRIVER_LINK_REQUIRED");
        if (!driver.IsActive)
            throw new ConflictException("The Driver is inactive.", "DRIVER_INACTIVE");
        return driver;
    }

    private async Task<HandoverResponse> MapAsync(
        TripHandoverRequest handover, CancellationToken cancellationToken)
    {
        var trip = await store.FindTripAsync(handover.TripId, cancellationToken)
            ?? throw new NotFoundException("Trip was not found.", "TRIP_NOT_FOUND");
        var truck = await RequiredTruckAsync(handover.TruckId, cancellationToken);
        var current = await store.FindDriverAsync(
            handover.CurrentDriverId, cancellationToken)
            ?? throw new NotFoundException("Current Driver was not found.", "DRIVER_NOT_FOUND");
        var requesting = await store.FindDriverAsync(
            handover.RequestingDriverId, cancellationToken)
            ?? throw new NotFoundException("Requesting Driver was not found.", "DRIVER_NOT_FOUND");
        return new(handover.Id, trip.Id, trip.TripNumber, truck.Id, truck.PlateNumber,
            current.Id, current.FullName, requesting.Id, requesting.FullName,
            trip.Status.ToString(), handover.Status.ToString(), handover.Reason,
            handover.ResolutionReason, handover.ExpectedTripVersion,
            handover.ExpiresAt, handover.CreatedAt, handover.ResolvedAt);
    }

    private static string GenerateSecret()
    {
        var value = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        return value.Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }

    private static string Hash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value.Trim())));
}
