namespace TransportManagement.IntegrationTests;

internal static class RouteTestData
{
    public static object TripPayload(
        Guid clientId,
        decimal pickupLatitude = 39.9208m,
        decimal pickupLongitude = 32.8541m,
        decimal deliveryLatitude = 40.9208m,
        decimal deliveryLongitude = 31.8541m) => new
    {
        clientId,
        cargoDescription = "Palletized goods",
        plannedStartAt = DateTimeOffset.UtcNow.AddDays(1),
        price = 1250.50m,
        routeProfile = "Driving",
        stops = new object[]
        {
            new
            {
                sequence = 0,
                type = "Pickup",
                name = "Factory A",
                address = "Ankara test pickup",
                latitude = pickupLatitude,
                longitude = pickupLongitude
            },
            new
            {
                sequence = 1,
                type = "Delivery",
                name = "Warehouse B",
                address = "Test delivery",
                latitude = deliveryLatitude,
                longitude = deliveryLongitude
            }
        }
    };
}
