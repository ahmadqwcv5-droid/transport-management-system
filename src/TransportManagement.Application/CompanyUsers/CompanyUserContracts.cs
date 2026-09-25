using System.ComponentModel.DataAnnotations;

namespace TransportManagement.Application.CompanyUsers;

public sealed record CreateDriverUserRequest(
    [param: Required, EmailAddress, MaxLength(320)] string Email,
    [param: Required, MinLength(2), MaxLength(200)] string DisplayName,
    Guid? DriverId = null);

public sealed record CompanyUserActiveRequest(bool IsActive);
public sealed record LinkCompanyUserRequest(Guid DriverId);

public sealed record CompanyUserResponse(
    Guid Id, string Email, string DisplayName, string Role, bool IsActive,
    bool NotificationSoundsEnabled, Guid? DriverId, string? DriverName,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

public sealed record CompanyUserCredentialResponse(
    CompanyUserResponse User, string TemporaryPassword);
