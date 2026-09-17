namespace TransportManagement.Domain.Trips;

public enum TripStatus
{
    Draft,
    Assigned,
    Started,
    InTransit,
    Delivered,
    Completed,
    Cancelled
}
