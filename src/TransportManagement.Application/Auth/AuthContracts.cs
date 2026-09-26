using System.ComponentModel.DataAnnotations;

namespace TransportManagement.Application.Auth;

public sealed record LoginRequest(
    [param: Required, EmailAddress] string Email,
    [param: Required, MinLength(8)] string Password);

public sealed record RefreshRequest([param: Required] string RefreshToken);
public sealed record LogoutRequest(string? RefreshToken);

public sealed record AuthResponse(
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt,
    CurrentUserResponse User);

public sealed record CurrentUserResponse(
    Guid Id, Guid CompanyId, string CompanyName, string Email, string DisplayName,
    string Role, string PreferredLocale, bool NotificationSoundsEnabled,
    string EnvironmentName, Guid? DriverId = null, string? DriverName = null);

public sealed record LocalePreferenceRequest(
    [param: Required, RegularExpression("^(en|ar)$")] string PreferredLocale);

public sealed record NotificationSoundsPreferenceRequest(bool Enabled);

public sealed record ChangePasswordRequest(
    [param: Required] string CurrentPassword,
    [param: Required, MinLength(12), MaxLength(200)] string NewPassword,
    [param: Required] string ConfirmPassword);
