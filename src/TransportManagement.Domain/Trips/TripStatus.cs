namespace TransportManagement.Domain.Trips;

public enum TripStatus
{
    Draft,
    Assigned,
    EnRouteToPickup,
    AtPickup,
    Started,
    InTransit,
    AtDelivery,
    Delivered,
    Completed,
    Cancelled
}
