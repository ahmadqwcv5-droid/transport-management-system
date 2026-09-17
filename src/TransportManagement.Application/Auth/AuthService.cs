using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Auth;

public sealed class AuthService(
    IIdentityStore store,
    IPasswordHasher passwordHasher,
    ITokenService tokenService,
    IClock clock,
    ICurrentUser currentUser)
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
        return user is null ? null : Map(user);
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
            access.Token, access.ExpiresAt, generatedRefresh.PlainText, generatedRefresh.ExpiresAt, Map(user));
    }

    private static CurrentUserResponse Map(User user) =>
        new(user.Id, user.CompanyId, user.Email, user.DisplayName, user.Role);
}
