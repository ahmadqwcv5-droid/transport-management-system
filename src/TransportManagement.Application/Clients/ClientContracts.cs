using System.ComponentModel.DataAnnotations;

namespace TransportManagement.Application.Clients;

public sealed record ClientRequest(
    [param: Required, MaxLength(200)] string Name,
    [param: MaxLength(200)] string? ContactPerson,
    [param: MaxLength(50)] string? Phone,
    [param: EmailAddress, MaxLength(320)] string? Email,
    [param: MaxLength(500)] string? Address,
    [param: MaxLength(2000)] string? Notes);

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
    DateTimeOffset UpdatedAt);
