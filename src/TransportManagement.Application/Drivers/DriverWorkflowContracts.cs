using TransportManagement.Application.Trips;

namespace TransportManagement.Application.Drivers;

public sealed record DriverMyTripResponse(Guid DriverId, string DriverName,
    TripResponse? Trip);
