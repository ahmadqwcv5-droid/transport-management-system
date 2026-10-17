using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Drivers;

public sealed record DriverTripHistoryQuery(
    int Page = 1,
    int PageSize = 20,
    string Category = "current",
    DateTimeOffset? From = null,
    DateTimeOffset? To = null);

public sealed record DriverTripHistorySummary(
    Guid Id,
    string TripNumber,
    string Status,
    string Category,
    DateTimeOffset? PlannedStartAt,
    DateTimeOffset? ActualStartAt,
    DateTimeOffset? ArrivedPickupAt,
    DateTimeOffset? ArrivedDeliveryAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? CancelledAt,
    string? TruckPlate,
    string? ClientName,
    string? Pickup,
    string? Delivery,
    decimal? PlannedDistanceMeters,
    int? PlannedDurationSeconds,
    DateTimeOffset ParticipationStartedAt,
    DateTimeOffset? ParticipationEndedAt,
    string ParticipationSource);

public sealed record DriverTripHistoryPage(
    IReadOnlyList<DriverTripHistorySummary> Items,
    int TotalCount,
    int Page,
    int PageSize,
    int TotalPages);

public sealed record DriverTripHistoryStop(
    int Sequence,
    string Type,
    string Name,
    string? Address,
    decimal? Latitude,
    decimal? Longitude,
    DateTimeOffset? PlannedArrivalAt);

public sealed record DriverTripHistoryEvent(
    string Type,
    DateTimeOffset OccurredAt,
    string Source);

public sealed record DriverTripHistoryPosition(
    decimal Latitude,
    decimal Longitude,
    decimal Speed,
    decimal Heading,
    DateTimeOffset RecordedAt,
    bool IsOnline);

public sealed record DriverTripParticipationResponse(
    DateTimeOffset StartedAt,
    DateTimeOffset? EndedAt,
    string Source,
    string StartedPhase,
    string? EndedPhase);

public sealed record DriverTripHistoryDetail(
    DriverTripHistorySummary Summary,
    string CargoDescription,
    string? CancellationReason,
    IReadOnlyList<DriverTripHistoryStop> Stops,
    string? RouteGeometry,
    string? RouteGeometryFormat,
    decimal? PlannedDistanceMeters,
    int? PlannedDurationSeconds,
    IReadOnlyList<DriverTripHistoryEvent> Timeline,
    IReadOnlyList<DriverTripParticipationResponse> Participations,
    IReadOnlyList<DriverTripHistoryPosition> Trail,
    bool TrailWasDownsampled);

public sealed record DriverTripHistoryListRecord(
    Guid Id,
    string TripNumber,
    TripStatus Status,
    DateTimeOffset? PlannedStartAt,
    DateTimeOffset? ActualStartAt,
    DateTimeOffset? ArrivedPickupAt,
    DateTimeOffset? ArrivedDeliveryAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? CancelledAt,
    string? TruckPlate,
    string? ClientName,
    string? Origin,
    string? Destination,
    decimal? PlannedDistanceMeters,
    int? PlannedDurationSeconds,
    DateTimeOffset ParticipationStartedAt,
    DateTimeOffset? ParticipationEndedAt,
    string ParticipationSource);

public sealed record DriverTripHistoryDetailRecord(
    Trip Trip,
    string? TruckPlate,
    string? ClientName,
    IReadOnlyList<TripDriverParticipation> Participations,
    IReadOnlyList<TripEvent> Events);
