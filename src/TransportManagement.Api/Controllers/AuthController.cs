using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TransportManagement.Application.Auth;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(AuthService authService) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("login")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    public Task<AuthResponse> Login(LoginRequest request, CancellationToken cancellationToken) =>
        authService.LoginAsync(request, cancellationToken);

    [AllowAnonymous]
    [HttpGet("external/providers")]
    public IReadOnlyList<ExternalProviderResponse> ExternalProviders() =>
        authService.ExternalProviders();

    [AllowAnonymous]
    [HttpPost("external/sign-in")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    public Task<AuthResponse> ExternalSignIn(
        ExternalSignInRequest request, CancellationToken cancellationToken) =>
        authService.ExternalSignInAsync(request, cancellationToken);

    [Authorize]
    [HttpGet("me/sign-in-methods")]
    public Task<IReadOnlyList<SignInMethodResponse>> SignInMethods(
        CancellationToken cancellationToken) =>
        authService.ListSignInMethodsAsync(cancellationToken);

    [Authorize]
    [HttpPost("me/external-logins")]
    public Task<IReadOnlyList<SignInMethodResponse>> LinkExternal(
        LinkExternalLoginRequest request, CancellationToken cancellationToken) =>
        authService.LinkExternalAsync(request, cancellationToken);

    [Authorize]
    [HttpDelete("me/external-logins/{provider}")]
    public Task<IReadOnlyList<SignInMethodResponse>> UnlinkExternal(
        string provider, CancellationToken cancellationToken) =>
        authService.UnlinkExternalAsync(provider, cancellationToken);


    [AllowAnonymous]
    [HttpPost("refresh")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    public Task<AuthResponse> Refresh(RefreshRequest request, CancellationToken cancellationToken) =>
        authService.RefreshAsync(request, cancellationToken);

    [Authorize]
    [HttpPost("logout")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
    {
        await authService.LogoutAsync(request, cancellationToken);
        return NoContent();
    }

    [Authorize]
    [HttpGet("me")]
    [ProducesResponseType<CurrentUserResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CurrentUserResponse>> Me(CancellationToken cancellationToken)
    {
        var result = await authService.GetCurrentAsync(cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [Authorize]
    [HttpGet("workspaces")]
    public Task<IReadOnlyList<WorkspaceResponse>> Workspaces(
        CancellationToken cancellationToken) =>
        authService.ListWorkspacesAsync(cancellationToken);

    [Authorize]
    [HttpPost("switch-workspace")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    public Task<AuthResponse> SwitchWorkspace(
        SwitchWorkspaceRequest request, CancellationToken cancellationToken) =>
        authService.SwitchWorkspaceAsync(request, cancellationToken);
    [Authorize]
    [HttpPut("me/preferences")]
    public Task<CurrentUserResponse> UpdatePreferences(
        LocalePreferenceRequest request, CancellationToken cancellationToken) =>
        authService.UpdateLocaleAsync(request, cancellationToken);

    [Authorize]
    [HttpPut("me/notification-sounds")]
    public Task<CurrentUserResponse> UpdateNotificationSounds(
        NotificationSoundsPreferenceRequest request, CancellationToken cancellationToken) =>
        authService.UpdateNotificationSoundsAsync(request, cancellationToken);

    [Authorize]
    [EnableRateLimiting("password-change")]
    [HttpPut("me/password")]
    public async Task<IActionResult> ChangePassword(
        ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        await authService.ChangePasswordAsync(request, cancellationToken);
        return NoContent();
    }
}
