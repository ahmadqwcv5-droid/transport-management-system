using System.ComponentModel.DataAnnotations;
using TransportManagement.Domain.Clients;

namespace TransportManagement.Application.Clients;

public sealed record ClientRequest(
    [param: Required, MaxLength(200)] string Name,
    [param: MaxLength(200)] string? ContactPerson,
    [param: MaxLength(50)] string? Phone,
    [param: EmailAddress, MaxLength(320)] string? Email,
    [param: MaxLength(500)] string? Address,
    [param: MaxLength(2000)] string? Notes,
    [param: MaxLength(200)] string? LegalName = null);

public sealed record ClientLifecycleRequest(ClientLifecycleStatus Status);

public sealed record ClientContactRequest(
    [param: Required, MaxLength(200)] string Name,
    [param: MaxLength(150)] string? JobTitle,
    [param: MaxLength(50)] string? Phone,
    [param: MaxLength(50)] string? WhatsApp,
    [param: EmailAddress, MaxLength(320)] string? Email,
    bool IsPrimary,
    [param: MaxLength(1000)] string? Notes);

public sealed record ClientSiteRequest(
    [param: Required, MaxLength(200)] string Name,
    ClientSiteType Type,
    [param: MaxLength(500)] string? Address,
    [param: Range(-90, 90)] decimal Latitude,
    [param: Range(-180, 180)] decimal Longitude,
    [param: MaxLength(200)] string? ContactName,
    [param: MaxLength(50)] string? ContactPhone,
    [param: MaxLength(1000)] string? Instructions);

public sealed record ClientResponse(
    Guid Id,
    string Name,
    string? ContactPerson,
    string? Phone,
    string? Email,
    string? Address,
    string? Notes,
    bool IsActive,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    string? LegalName,
    ClientLifecycleStatus LifecycleStatus,
    int ActiveSiteCount = 0,
    int ActiveTripCount = 0);

public sealed record ClientContactResponse(
    Guid Id, Guid ClientId, string Name, string? JobTitle, string? Phone,
    string? WhatsApp, string? Email, bool IsPrimary, string? Notes,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

public sealed record ClientSiteResponse(
    Guid Id, Guid ClientId, string Name, ClientSiteType Type, string? Address,
    decimal Latitude, decimal Longitude, string? ContactName,
    string? ContactPhone, string? Instructions, bool IsActive,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

public sealed record OperationsEventResponse(
    Guid Id, string EventCode, string? Metadata, DateTimeOffset OccurredAt);

public sealed record ResourceTripSummaryResponse(
    Guid Id, string TripNumber, string? Origin, string? Destination,
    DateTimeOffset PlannedStartAt, string Status, Guid? TruckId,
    string? TruckPlate, Guid? DriverId, string? DriverName);

public sealed record ClientDetailsResponse(
    ClientResponse Client, IReadOnlyList<ClientContactResponse> Contacts,
    IReadOnlyList<ClientSiteResponse> Sites,
    IReadOnlyList<ResourceTripSummaryResponse> Trips,
    IReadOnlyList<OperationsEventResponse> Events,
    int PlannedTripCount, int ActiveTripCount, int CompletedTripCount,
    int CancelledTripCount);
