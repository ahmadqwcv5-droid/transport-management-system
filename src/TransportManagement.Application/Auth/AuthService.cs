using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Auth;

public sealed class AuthService(
    IIdentityStore store,
    IPasswordHasher passwordHasher,
    ITokenService tokenService,
    IClock clock,
    ICurrentUser currentUser,
    IRuntimeEnvironment runtimeEnvironment,
    IExternalIdentityVerifier externalIdentities)
{
    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var account = await store.FindUserByEmailAsync(
            request.Email.Trim().ToLowerInvariant(), cancellationToken);
        if (account is null || !account.IsActive || account.PasswordHash is null
            || !passwordHasher.Verify(request.Password, account.PasswordHash))
            throw new AuthenticationException("The email address or password is incorrect.");

        var memberships = await store.ListMembershipsAsync(account.Id, true, cancellationToken);
        var membership = memberships.Count == 1 ? memberships[0] : null;
        return await IssueTokensAsync(account, membership, null, cancellationToken);
    }

    public IReadOnlyList<ExternalProviderResponse> ExternalProviders() =>
        [new("google", externalIdentities.IsConfigured("google"))];

    public async Task<AuthResponse> ExternalSignInAsync(
        ExternalSignInRequest request, CancellationToken cancellationToken)
    {
        var identity = await externalIdentities.VerifyAsync(
            request.Provider, request.IdToken, request.Nonce, cancellationToken);
        if (!identity.EmailVerified)
            throw new Domain.Common.DomainRuleException(
                "The external email address is not verified.", "EXTERNAL_EMAIL_NOT_VERIFIED");

        var login = await store.FindExternalLoginAsync(
            identity.Provider, identity.Subject, cancellationToken);
        User account;
        if (login is null)
        {
            var sameEmail = await store.FindUserByEmailAsync(identity.Email, cancellationToken);
            if (sameEmail is not null)
                throw new Domain.Common.DomainRuleException(
                    "Authenticate with the existing account and link Google explicitly.",
                    "EXTERNAL_ACCOUNT_LINK_REQUIRED");
            var displayName = string.IsNullOrWhiteSpace(identity.DisplayName)
                ? identity.Email.Split('@')[0] : identity.DisplayName;
            account = new User(Guid.NewGuid(), identity.Email, displayName, null, clock.UtcNow);
            store.AddUser(account);
            store.AddExternalLogin(new ExternalLogin(Guid.NewGuid(), account.Id,
                identity.Provider, identity.Subject, identity.Email, clock.UtcNow));
        }
        else
        {
            account = await store.FindUserByIdAsync(login.AccountId, cancellationToken)
                ?? throw new AuthenticationException("The external account is unavailable.");
            if (!account.IsActive)
                throw new AuthenticationException("The external account is unavailable.");
        }

        var memberships = await store.ListMembershipsAsync(account.Id, true, cancellationToken);
        return await IssueTokensAsync(account,
            memberships.Count == 1 ? memberships[0] : null, null, cancellationToken);
    }

    public async Task<IReadOnlyList<SignInMethodResponse>> ListSignInMethodsAsync(
        CancellationToken cancellationToken)
    {
        var account = await RequireCurrentAccountAsync(cancellationToken);
        var external = await store.ListExternalLoginsAsync(account.Id, cancellationToken);
        var methodCount = external.Count + (account.PasswordHash is null ? 0 : 1);
        var result = new List<SignInMethodResponse>();
        if (account.PasswordHash is not null)
            result.Add(new("local", "Email and password", account.Email, methodCount > 1));
        result.AddRange(external.Select(login => new SignInMethodResponse(
            login.Provider, login.Provider == "google" ? "Google" : login.Provider,
            login.EmailSnapshot, methodCount > 1)));
        return result;
    }

    public async Task<IReadOnlyList<SignInMethodResponse>> LinkExternalAsync(
        LinkExternalLoginRequest request, CancellationToken cancellationToken)
    {
        var account = await RequireCurrentAccountAsync(cancellationToken);
        var identity = await externalIdentities.VerifyAsync(
            request.Provider, request.IdToken, request.Nonce, cancellationToken);
        if (!identity.EmailVerified)
            throw new Domain.Common.DomainRuleException(
                "The external email address is not verified.", "EXTERNAL_EMAIL_NOT_VERIFIED");
        var bySubject = await store.FindExternalLoginAsync(
            identity.Provider, identity.Subject, cancellationToken);
        if (bySubject is not null && bySubject.AccountId != account.Id)
            throw new Domain.Common.DomainRuleException(
                "This external login is linked to another account.", "EXTERNAL_LOGIN_CONFLICT");
        var methods = await store.ListExternalLoginsAsync(account.Id, cancellationToken);
        var sameProvider = methods.SingleOrDefault(x =>
            x.Provider.Equals(identity.Provider, StringComparison.OrdinalIgnoreCase));
        if (sameProvider is null)
        {
            store.AddExternalLogin(new ExternalLogin(Guid.NewGuid(), account.Id,
                identity.Provider, identity.Subject, identity.Email, clock.UtcNow));
            AddIdentityAudit(account.Id, "ExternalLoginLinked",
                $"{{\"provider\":\"{identity.Provider}\"}}");
            AddSecurityNotification(account.Id, "ExternalLoginLinked",
                "EXTERNAL_LOGIN_LINKED", identity.Provider);
            await store.SaveChangesAsync(cancellationToken);
        }
        else if (sameProvider.ProviderSubject != identity.Subject)
        {
            throw new Domain.Common.DomainRuleException(
                "A different login from this provider is already linked.",
                "EXTERNAL_PROVIDER_ALREADY_LINKED");
        }
        return await ListSignInMethodsAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<SignInMethodResponse>> UnlinkExternalAsync(
        string provider, CancellationToken cancellationToken)
    {
        var account = await RequireCurrentAccountAsync(cancellationToken);
        var methods = await store.ListExternalLoginsAsync(account.Id, cancellationToken);
        var login = methods.SingleOrDefault(x =>
            x.Provider.Equals(provider, StringComparison.OrdinalIgnoreCase))
            ?? throw new Common.NotFoundException(
                "The external login was not found.", "EXTERNAL_LOGIN_NOT_FOUND");
        if (account.PasswordHash is null && methods.Count == 1)
            throw new Domain.Common.DomainRuleException(
                "Another usable sign-in method is required before unlinking.",
                "LAST_SIGN_IN_METHOD");
        store.RemoveExternalLogin(login);
        AddIdentityAudit(account.Id, "ExternalLoginUnlinked",
            $"{{\"provider\":\"{login.Provider}\"}}");
        AddSecurityNotification(account.Id, "ExternalLoginUnlinked",
            "EXTERNAL_LOGIN_UNLINKED", login.Provider);
        await store.SaveChangesAsync(cancellationToken);
        return await ListSignInMethodsAsync(cancellationToken);
    }


    public async Task<AuthResponse> RefreshAsync(RefreshRequest request, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        var oldToken = await store.FindActiveRefreshTokenAsync(
            tokenService.HashRefreshToken(request.RefreshToken), now, cancellationToken);

        if (oldToken is null)
            throw new AuthenticationException("The refresh token is invalid or expired.");

        var account = await store.FindUserByIdAsync(oldToken.AccountId, cancellationToken);
        if (account is null || !account.IsActive)
            throw new AuthenticationException("The refresh token is invalid or expired.");

        CompanyMembership? membership = null;
        if (oldToken.MembershipId.HasValue)
        {
            membership = await store.FindMembershipAsync(oldToken.MembershipId.Value,
                account.Id, cancellationToken);
            if (membership is null || !membership.IsActive || membership.CompanyId != oldToken.CompanyId)
                throw new AuthenticationException("The workspace membership is not active.");
        }

        return await IssueTokensAsync(account, membership, oldToken, cancellationToken);
    }

    public async Task LogoutAsync(LogoutRequest request, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            var token = await store.FindActiveRefreshTokenAsync(
                tokenService.HashRefreshToken(request.RefreshToken), now, cancellationToken);
            if (token is not null && token.AccountId == currentUser.UserId) token.Revoke(now);
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

    public async Task<IReadOnlyList<WorkspaceResponse>> ListWorkspacesAsync(
        CancellationToken cancellationToken)
    {
        var account = await store.FindUserByIdAsync(currentUser.UserId, cancellationToken)
            ?? throw new Common.NotFoundException("Account was not found.", "ACCOUNT_NOT_FOUND");
        var memberships = await store.ListMembershipsAsync(account.Id, false, cancellationToken);
        var result = new List<WorkspaceResponse>(memberships.Count);
        foreach (var membership in memberships)
        {
            var company = await store.FindCompanyByIdAsync(membership.CompanyId, cancellationToken);
            var roles = await store.ListMembershipRolesAsync(membership.Id, cancellationToken);
            result.Add(new(membership.Id, membership.CompanyId, company?.Name ?? string.Empty,
                roles, membership.Status.ToString()));
        }
        return result;
    }

    public async Task<AuthResponse> SwitchWorkspaceAsync(
        SwitchWorkspaceRequest request, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        var oldToken = await store.FindActiveRefreshTokenAsync(
            tokenService.HashRefreshToken(request.RefreshToken), now, cancellationToken);
        if (oldToken is null || oldToken.AccountId != currentUser.UserId)
            throw new AuthenticationException("The refresh token is invalid or expired.");
        var membership = await store.FindMembershipAsync(
            request.MembershipId, currentUser.UserId, cancellationToken);
        if (membership is null || !membership.IsActive)
            throw new AuthenticationException("The workspace membership is not active.");
        return await IssueTokensAsync(await RequireCurrentAccountAsync(cancellationToken),
            membership, oldToken, cancellationToken);
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
        var currentHash = user.PasswordHash;
        if (currentHash is null || !passwordHasher.Verify(request.CurrentPassword, currentHash))
            throw new Domain.Common.DomainRuleException(
                "The current password is incorrect.", "CURRENT_PASSWORD_INCORRECT");
        if (!string.Equals(request.NewPassword, request.ConfirmPassword, StringComparison.Ordinal))
            throw new Domain.Common.DomainRuleException(
                "The password confirmation does not match.", "PASSWORD_CONFIRMATION_MISMATCH");
        if (request.NewPassword.Length < 12)
            throw new Domain.Common.DomainRuleException(
                "The new password must contain at least 12 characters.", "PASSWORD_POLICY_FAILED");
        if (passwordHasher.Verify(request.NewPassword, currentHash))
            throw new Domain.Common.DomainRuleException(
                "The new password must be different.", "PASSWORD_REUSE_NOT_ALLOWED");
        var now = clock.UtcNow;
        user.ResetPassword(passwordHasher.Hash(request.NewPassword), now);
        await store.RevokeAllUserTokensAsync(user.Id, now, cancellationToken);
        if (currentUser.CompanyId != Guid.Empty)
            store.AddUserEvent(new CompanyUserEvent(Guid.NewGuid(), currentUser.CompanyId,
                user.Id, user.Id, "PasswordChanged", null, now));
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthResponse> IssueTokensAsync(
        User account,
        CompanyMembership? membership,
        RefreshToken? tokenToReplace,
        CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        IReadOnlyList<string> roles = membership is null
            ? []
            : await store.ListMembershipRolesAsync(membership.Id, cancellationToken);
        var access = tokenService.CreateAccessToken(account, membership, roles);
        var generatedRefresh = tokenService.CreateRefreshToken(now);
        var refreshEntity = new RefreshToken(
            Guid.NewGuid(), account.Id, membership?.Id, membership?.CompanyId,
            generatedRefresh.Hash, generatedRefresh.ExpiresAt, now);

        tokenToReplace?.Revoke(now, refreshEntity.Id);
        await store.AddRefreshTokenAsync(refreshEntity, cancellationToken);
        await store.SaveChangesAsync(cancellationToken);

        return new AuthResponse(
            access.Token, access.ExpiresAt, generatedRefresh.PlainText, generatedRefresh.ExpiresAt,
            await MapAsync(account, membership, cancellationToken));
    }

    private void AddIdentityAudit(Guid accountId, string code, string? data)
    {
        if (currentUser.CompanyId == Guid.Empty) return;
        store.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(), currentUser.CompanyId,
            accountId, currentUser.UserId, code, data, clock.UtcNow));
    }


    private void AddSecurityNotification(
        Guid accountId, string type, string eventCode, string provider)
    {
        if (currentUser.CompanyId == Guid.Empty) return;
        store.AddNotification(new OperationNotification(Guid.NewGuid(),
            currentUser.CompanyId, type, "Information", null, null, null,
            $"{type}:{accountId}:{provider}",
            JsonSerializer.Serialize(new { eventCode, accountId, provider }),
            clock.UtcNow));
    }

    private async Task<User> RequireCurrentAccountAsync(
        CancellationToken cancellationToken) =>
        await store.FindUserByIdAsync(currentUser.UserId, cancellationToken)
        ?? throw new Common.NotFoundException("Account was not found.", "ACCOUNT_NOT_FOUND");

    private async Task<CurrentUserResponse> MapAsync(
        User account, CancellationToken cancellationToken)
    {
        CompanyMembership? membership = null;
        if (currentUser.MembershipId != Guid.Empty)
            membership = await store.FindMembershipAsync(
                currentUser.MembershipId, account.Id, cancellationToken);
        return await MapAsync(account, membership, cancellationToken);
    }

    private async Task<CurrentUserResponse> MapAsync(
        User account, CompanyMembership? membership, CancellationToken cancellationToken)
    {
        var memberships = await store.ListMembershipsAsync(account.Id, true, cancellationToken);
        IReadOnlyList<string> roles = membership is null
            ? []
            : await store.ListMembershipRolesAsync(membership.Id, cancellationToken);
        var company = membership is null
            ? null
            : await store.FindCompanyByIdAsync(membership.CompanyId, cancellationToken);
        var driver = membership is null
            ? null
            : await store.FindDriverAsync(account.Id, membership.CompanyId, cancellationToken);
        var primaryRole = PrimaryRole(roles);
        return new(account.Id, membership?.Id, membership?.CompanyId,
            company?.Name ?? string.Empty, account.Email, account.DisplayName,
            roles, primaryRole, account.PreferredLocale,
            account.NotificationSoundsEnabled, runtimeEnvironment.Name,
            account.PasswordHash is not null, membership is null && memberships.Count > 1,
            driver?.Id, driver?.FullName);
    }

    private static string PrimaryRole(IReadOnlyList<string> roles)
    {
        string[] priority =
            [AppRoles.Owner, AppRoles.Operations, AppRoles.Accountant, AppRoles.Employee, AppRoles.Driver];
        foreach (var role in priority)
            if (roles.Contains(role, StringComparer.Ordinal)) return role;
        return string.Empty;
    }
}
