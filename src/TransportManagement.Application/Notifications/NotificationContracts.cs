namespace TransportManagement.Application.Notifications;

public sealed record NotificationResponse(Guid Id, string Type, string Severity,
    Guid? TripId, Guid? TruckId, Guid? DriverId, string? DataJson,
    DateTimeOffset CreatedAt, DateTimeOffset? ReadAt);
public sealed record NotificationPageResponse(IReadOnlyList<NotificationResponse> Items,
    int TotalCount, int Page, int PageSize, int TotalPages);
public sealed record UnreadNotificationCountResponse(int Count);
