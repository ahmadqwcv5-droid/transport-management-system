using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Auth;

public sealed class AuthService(
    IIdentityStore store,
    IPasswordHasher passwordHasher,
    ITokenService tokenService,
    IClock clock,
    ICurrentUser currentUser,
    IRuntimeEnvironment runtimeEnvironment,
    IDriverIdentityStore driverIdentities)
{
    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var user = await store.FindUserByEmailAsync(request.Email.Trim().ToLowerInvariant(), cancellationToken);
        if (user is null || !user.IsActive || !passwordHasher.Verify(request.Password, user.PasswordHash))
            throw new AuthenticationException("The email address or password is incorrect.");

        return await IssueTokensAsync(user, null, cancellationToken);
    }

    public async Task<AuthResponse> RefreshAsync(RefreshRequest request, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        var oldToken = await store.FindActiveRefreshTokenAsync(
            tokenService.HashRefreshToken(request.RefreshToken), now, cancellationToken);

        if (oldToken is null)
            throw new AuthenticationException("The refresh token is invalid or expired.");

        var user = await store.FindUserByIdAsync(oldToken.UserId, cancellationToken);
        if (user is null || !user.IsActive)
            throw new AuthenticationException("The refresh token is invalid or expired.");

        return await IssueTokensAsync(user, oldToken, cancellationToken);
    }

    public async Task LogoutAsync(LogoutRequest request, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            var token = await store.FindActiveRefreshTokenAsync(
                tokenService.HashRefreshToken(request.RefreshToken), now, cancellationToken);
            if (token is not null && token.UserId == currentUser.UserId) token.Revoke(now);
        }
        else
        {
            await store.RevokeAllUserTokensAsync(currentUser.UserId, now, cancellationToken);
        }

        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task<CurrentUserResponse?> GetCurrentAsync(CancellationToken cancellationToken)
    {
        var user = await store.FindUserByIdAsync(currentUser.UserId, cancellationToken);
        return user is null ? null : await MapAsync(user, cancellationToken);
    }

    public async Task<CurrentUserResponse> UpdateLocaleAsync(
        LocalePreferenceRequest request, CancellationToken cancellationToken)
    {
        var user = await store.FindUserByIdAsync(currentUser.UserId, cancellationToken)
            ?? throw new Common.NotFoundException("User was not found.", "USER_NOT_FOUND");
        user.ChangePreferredLocale(request.PreferredLocale, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user, cancellationToken);
    }

    public async Task<CurrentUserResponse> UpdateNotificationSoundsAsync(
        NotificationSoundsPreferenceRequest request, CancellationToken cancellationToken)
    {
        var user = await store.FindUserByIdAsync(currentUser.UserId, cancellationToken)
            ?? throw new Common.NotFoundException("User was not found.", "USER_NOT_FOUND");
        user.ChangeNotificationSounds(request.Enabled, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user, cancellationToken);
    }

    public async Task ChangePasswordAsync(ChangePasswordRequest request,
        CancellationToken cancellationToken)
    {
        var user = await store.FindUserByIdAsync(currentUser.UserId, cancellationToken)
            ?? throw new Common.NotFoundException("User was not found.", "USER_NOT_FOUND");
        if (!passwordHasher.Verify(request.CurrentPassword, user.PasswordHash))
            throw new Domain.Common.DomainRuleException(
                "The current password is incorrect.", "CURRENT_PASSWORD_INCORRECT");
        if (!string.Equals(request.NewPassword, request.ConfirmPassword, StringComparison.Ordinal))
            throw new Domain.Common.DomainRuleException(
                "The password confirmation does not match.", "PASSWORD_CONFIRMATION_MISMATCH");
        if (request.NewPassword.Length < 12)
            throw new Domain.Common.DomainRuleException(
                "The new password must contain at least 12 characters.", "PASSWORD_POLICY_FAILED");
        if (passwordHasher.Verify(request.NewPassword, user.PasswordHash))
            throw new Domain.Common.DomainRuleException(
                "The new password must be different.", "PASSWORD_REUSE_NOT_ALLOWED");
        var now = clock.UtcNow;
        user.ResetPassword(passwordHasher.Hash(request.NewPassword), now);
        await store.RevokeAllUserTokensAsync(user.Id, now, cancellationToken);
        store.AddUserEvent(new CompanyUserEvent(Guid.NewGuid(), user.CompanyId,
            user.Id, user.Id, "PasswordChanged", null, now));
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthResponse> IssueTokensAsync(
        User user,
        RefreshToken? tokenToReplace,
        CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        var access = tokenService.CreateAccessToken(user);
        var generatedRefresh = tokenService.CreateRefreshToken(now);
        var refreshEntity = new RefreshToken(
            Guid.NewGuid(), user.CompanyId, user.Id, generatedRefresh.Hash, generatedRefresh.ExpiresAt, now);

        tokenToReplace?.Revoke(now, refreshEntity.Id);
        await store.AddRefreshTokenAsync(refreshEntity, cancellationToken);
        await store.SaveChangesAsync(cancellationToken);

        return new AuthResponse(
            access.Token, access.ExpiresAt, generatedRefresh.PlainText, generatedRefresh.ExpiresAt,
            await MapAsync(user, cancellationToken));
    }

    private async Task<CurrentUserResponse> MapAsync(User user, CancellationToken cancellationToken)
    {
        var company = await store.FindCompanyByIdAsync(user.CompanyId, cancellationToken);
        var driver = await driverIdentities.GetDriverByUserAsync(user.Id, cancellationToken);
        return new(user.Id, user.CompanyId, company?.Name ?? string.Empty, user.Email,
            user.DisplayName, user.Role, user.PreferredLocale,
            user.NotificationSoundsEnabled, runtimeEnvironment.Name,
            driver?.Id, driver?.FullName);
    }
}
