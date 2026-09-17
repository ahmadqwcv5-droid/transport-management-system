using System.ComponentModel.DataAnnotations;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Fleet;

public sealed record TruckRequest(
    [param: Required, MaxLength(30)] string PlateNumber,
    [param: MaxLength(100)] string? Make,
    [param: MaxLength(100)] string? Model,
    [param: Range(1900, 2100)] int? Year,
    [param: MaxLength(2000)] string? Notes);

public sealed record TruckStatusRequest(TruckStatus Status);

public sealed record TruckResponse(
    Guid Id,
    string PlateNumber,
    string? Make,
    string? Model,
    int? Year,
    TruckStatus Status,
    string? Notes,
    bool IsActive,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
