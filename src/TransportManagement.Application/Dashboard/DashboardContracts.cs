using TransportManagement.Application.Tracking;

namespace TransportManagement.Application.Dashboard;

public sealed record FleetSummaryResponse(
    int Total, int Available, int OnTrip, int Maintenance, int OutOfService);
public sealed record TripSummaryResponse(int Active, int CompletedToday);
public sealed record TrackingSummaryResponse(int Online, int Offline);
public sealed record RecentTripResponse(
    Guid Id, string Origin, string Destination, string Status, DateTimeOffset PlannedStartAt);
public sealed record DashboardResponse(
    FleetSummaryResponse Fleet,
    TripSummaryResponse Trips,
    TrackingSummaryResponse Tracking,
    IReadOnlyList<TruckPositionResponse> Positions,
    IReadOnlyList<RecentTripResponse> RecentTrips);
