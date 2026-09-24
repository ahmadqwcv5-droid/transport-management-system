using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Trips;

namespace TransportManagement.Application.Drivers;

public sealed class DriverWorkflowService(IDriverIdentityStore identities,
    ICurrentUser currentUser, TripLifecycleService lifecycle)
{
    public async Task<DriverMyTripResponse> MyTripAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        var trip = await identities.GetCurrentTripAsync(driver.Id, cancellationToken);
        return new(driver.Id, driver.FullName,
            trip is null ? null : TripResponseMapper.Map(trip));
    }

    public async Task<TripResponse> ConfirmLoadedAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        return await lifecycle.ConfirmLoadedAsync(trip.Id, "User", null, cancellationToken);
    }

    public async Task<TripResponse> ConfirmDeliveryAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        return await lifecycle.ConfirmDeliveryAsync(trip.Id, "User", null, cancellationToken);
    }

    private async Task<Domain.Fleet.Driver> RequiredDriverAsync(CancellationToken cancellationToken) =>
        await identities.GetDriverByUserAsync(currentUser.UserId, cancellationToken)
        ?? throw new NotFoundException("The signed-in user is not linked to a driver.",
            "DRIVER_LINK_REQUIRED");

    private async Task<Domain.Trips.Trip> RequiredTripAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        return await identities.GetCurrentTripAsync(driver.Id, cancellationToken)
            ?? throw new NotFoundException("No current trip is assigned to this driver.",
                "DRIVER_TRIP_NOT_FOUND");
    }
}
