using System.ComponentModel.DataAnnotations;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Fleet;

public sealed record DriverRequest(
    [param: Required, MaxLength(200)] string FullName,
    [param: MaxLength(50)] string? Phone,
    [param: Required, MaxLength(100)] string LicenseNumber,
    DateOnly? LicenseExpiryDate,
    [param: MaxLength(2000)] string? Notes);

public sealed record DriverStatusRequest(DriverStatus Status);
public sealed record LinkDriverUserRequest(Guid UserId);

public sealed record DriverResponse(
    Guid Id,
    string FullName,
    string? Phone,
    string LicenseNumber,
    DateOnly? LicenseExpiryDate,
    DriverStatus Status,
    string? Notes,
    bool IsActive,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    Guid? UserId);
