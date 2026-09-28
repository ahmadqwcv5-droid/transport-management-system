using System.ComponentModel.DataAnnotations;

namespace TransportManagement.Application.Fleet;

public sealed record TruckQrCredentialResponse(
    Guid TruckId, string PlateNumber, string? FleetCode,
    string Code, string CodeHint, string QrPayload, DateTimeOffset GeneratedAt);

public sealed record TruckQrStatusResponse(
    Guid TruckId, string PlateNumber, string? FleetCode,
    bool HasActiveCredential, string? CodeHint, DateTimeOffset? GeneratedAt,
    string? GeneratedByDisplayName);

public sealed record ResolveTruckQrRequest([param: Required] string Code);

public sealed record TruckQrPreviewResponse(
    Guid TruckId, string PlateNumber, string? FleetCode, string TruckStatus,
    string? PhotoThumbnailUrl, Guid? CurrentDriverId, string? CurrentDriverName,
    Guid? TripId, string? TripNumber, string? TripStatus,
    bool RequiresHandover, DateTimeOffset? PositionRecordedAt);

public sealed record ConfirmTruckQrRequest(
    [param: Required] string Code, string? Reason = null);

public sealed record TruckSwitchResponse(
    string State, Guid TruckId, Guid DriverId,
    Guid? SessionId, Guid? HandoverRequestId, Guid? TripId);

public sealed record CreateHandoverRequest(
    Guid TripId, Guid RequestingDriverId, string? Reason = null);

public sealed record ResolveHandoverRequest(string? Reason = null);

public sealed record HandoverResponse(
    Guid Id, Guid TripId, string TripNumber, Guid TruckId, string PlateNumber,
    Guid CurrentDriverId, string CurrentDriverName,
    Guid RequestingDriverId, string RequestingDriverName,
    string TripStatus, string Status, string? Reason, string? ResolutionReason,
    long ExpectedTripVersion, DateTimeOffset ExpiresAt,
    DateTimeOffset CreatedAt, DateTimeOffset? ResolvedAt);
