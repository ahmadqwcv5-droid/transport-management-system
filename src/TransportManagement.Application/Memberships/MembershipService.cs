using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Memberships;

public sealed class MembershipService(
    IMembershipWorkflowStore store,
    IIdentityStore identities,
    ICompanyCodeService companyCodes,
    IPasswordHasher passwordHasher,
    ICurrentUser currentUser,
    IClock clock)
{
    public async Task<IReadOnlyList<InvitationResponse>> ListInvitationsAsync(
        CancellationToken cancellationToken)
    {
        var invitations = await store.ListInvitationsAsync(cancellationToken);
        var result = new List<InvitationResponse>(invitations.Count);
        foreach (var invitation in invitations)
            result.Add(await MapInvitationAsync(invitation, null, cancellationToken));
        return result;
    }

    public async Task<InvitationResponse> CreateInvitationAsync(
        CreateInvitationRequest request, CancellationToken cancellationToken)
    {
        var roles = ValidateRoles(request.Roles);
        var email = request.Email.Trim().ToLowerInvariant();
        var existing = await store.ListInvitationsAsync(cancellationToken);
        if (existing.Any(x => x.Email == email
            && x.Status == CompanyInvitationStatus.Pending && !x.IsExpired(clock.UtcNow)))
            throw new ConflictException("A pending invitation already exists.",
                "INVITATION_ALREADY_PENDING");

        if (request.DriverId.HasValue)
        {
            var driver = await store.FindDriverAsync(
                request.DriverId.Value, currentUser.CompanyId, cancellationToken)
                ?? throw new NotFoundException("Driver was not found.", "DRIVER_NOT_FOUND");
            if (driver.UserId.HasValue)
                throw new ConflictException("The Driver already has app access.",
                    "DRIVER_USER_ALREADY_LINKED");
            if (!roles.Contains(AppRoles.Driver, StringComparer.Ordinal))
                throw new DomainRuleException(
                    "An invitation linked to a Driver requires the Driver role.",
                    "DRIVER_ROLE_REQUIRED");
        }

        var rawToken = GenerateSecret();
        var now = clock.UtcNow;
        var invitation = new CompanyInvitation(Guid.NewGuid(), currentUser.CompanyId,
            email, JsonSerializer.Serialize(roles), request.DriverId, Hash(rawToken),
            now.AddDays(request.ExpiresInDays), currentUser.UserId, now);
        store.AddInvitation(invitation);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            currentUser.CompanyId, null, currentUser.UserId, "CompanyInvitationCreated",
            JsonSerializer.Serialize(new { invitationId = invitation.Id, roles, request.DriverId }), now));
        Notify(invitation.CompanyId, "CompanyInvitationCreated", "Information",
            invitation.Id, invitation.DriverId, new
            {
                eventCode = "COMPANY_INVITATION_CREATED",
                invitationId = invitation.Id,
                invitation.Email,
                roles,
                invitation.DriverId
            }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapInvitationAsync(invitation,
            $"/accept-invitation?token={Uri.EscapeDataString(rawToken)}", cancellationToken);
    }

    public async Task<InvitationResponse> PreviewInvitationAsync(
        string token, CancellationToken cancellationToken)
    {
        var invitation = await RequiredInvitationAsync(token, cancellationToken);
        return await MapInvitationAsync(invitation, null, cancellationToken);
    }

    public async Task<InvitationAcceptanceResponse> AcceptInvitationAsync(
        InvitationAcceptRequest request, CancellationToken cancellationToken)
    {
        var invitation = await RequiredInvitationAsync(request.Token, cancellationToken);
        var now = clock.UtcNow;
        var accountCreated = false;
        User account;
        if (currentUser.IsAuthenticated)
        {
            account = await identities.FindUserByIdAsync(currentUser.UserId, cancellationToken)
                ?? throw new NotFoundException("Account was not found.", "ACCOUNT_NOT_FOUND");
            if (!account.Email.Equals(invitation.Email, StringComparison.OrdinalIgnoreCase))
                throw new DomainRuleException(
                    "Sign in with the invited email address.", "INVITATION_EMAIL_MISMATCH");
        }
        else
        {
            if (!string.Equals(request.Email?.Trim(), invitation.Email,
                    StringComparison.OrdinalIgnoreCase))
                throw new DomainRuleException(
                    "The invitation email does not match.", "INVITATION_EMAIL_MISMATCH");
            if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 12)
                throw new DomainRuleException(
                    "Choose a password containing at least 12 characters.",
                    "PASSWORD_POLICY_FAILED");
            if (await identities.FindUserByEmailAsync(invitation.Email, cancellationToken) is not null)
                throw new DomainRuleException(
                    "Sign in to the existing account before accepting this invitation.",
                    "INVITATION_AUTHENTICATION_REQUIRED");
            var displayName = string.IsNullOrWhiteSpace(request.DisplayName)
                ? invitation.Email.Split('@')[0] : request.DisplayName.Trim();
            account = new User(Guid.NewGuid(), invitation.Email, displayName,
                passwordHasher.Hash(request.Password), now);
            identities.AddUser(account);
            accountCreated = true;
        }

        var membership = await store.FindMembershipAsync(
            invitation.CompanyId, account.Id, cancellationToken);
        if (membership is null)
        {
            membership = new CompanyMembership(Guid.NewGuid(), invitation.CompanyId,
                account.Id, MembershipStatus.Active, invitation.InviterAccountId, now);
            identities.AddMembership(membership);
        }
        else if (!membership.IsActive)
        {
            membership.Activate(now);
        }

        var roles = ParseRoles(invitation.RolesJson);
        var existingRoles = await identities.ListMembershipRolesAsync(
            membership.Id, cancellationToken);
        identities.AddMembershipRoles(roles.Except(existingRoles, StringComparer.Ordinal)
            .Select(role => new CompanyMembershipRole(
                invitation.CompanyId, membership.Id, role)));

        if (invitation.DriverId.HasValue)
        {
            var driver = await store.FindDriverAsync(
                invitation.DriverId.Value, invitation.CompanyId, cancellationToken)
                ?? throw new NotFoundException("The linked Driver was not found.", "DRIVER_NOT_FOUND");
            if (driver.UserId.HasValue && driver.UserId != account.Id)
                throw new ConflictException("The Driver is linked to another account.",
                    "DRIVER_USER_ALREADY_LINKED");
            if (!driver.UserId.HasValue) driver.LinkUser(account.Id, now);
        }

        invitation.Accept(account.Id, now);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            invitation.CompanyId, account.Id, account.Id, "CompanyInvitationAccepted",
            JsonSerializer.Serialize(new { invitationId = invitation.Id }), now));
        Notify(invitation.CompanyId, "CompanyInvitationAccepted", "Information",
            invitation.Id, invitation.DriverId, new
            {
                eventCode = "COMPANY_INVITATION_ACCEPTED",
                invitationId = invitation.Id,
                accountId = account.Id,
                invitation.DriverId
            }, now);
        await store.SaveChangesAsync(cancellationToken);
        var company = await identities.FindCompanyByIdAsync(invitation.CompanyId, cancellationToken);
        return new(account.Id, membership.Id, invitation.CompanyId,
            company?.Name ?? string.Empty, roles, accountCreated);
    }

    public async Task DeclineInvitationAsync(
        InvitationDecisionRequest request, CancellationToken cancellationToken)
    {
        if (!currentUser.IsAuthenticated)
            throw new AuthenticationException("Authentication is required.");
        var invitation = await RequiredInvitationAsync(request.Token, cancellationToken);
        var account = await identities.FindUserByIdAsync(currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException("Account was not found.", "ACCOUNT_NOT_FOUND");
        if (!account.Email.Equals(invitation.Email, StringComparison.OrdinalIgnoreCase))
            throw new DomainRuleException(
                "Sign in with the invited email address.", "INVITATION_EMAIL_MISMATCH");
        invitation.Decline(clock.UtcNow);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            invitation.CompanyId, account.Id, account.Id, "CompanyInvitationDeclined",
            JsonSerializer.Serialize(new { invitationId = invitation.Id }), clock.UtcNow));
        Notify(invitation.CompanyId, "CompanyInvitationDeclined", "Information",
            invitation.Id, invitation.DriverId, new
            {
                eventCode = "COMPANY_INVITATION_DECLINED",
                invitationId = invitation.Id,
                accountId = account.Id,
                invitation.DriverId
            }, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task RevokeInvitationAsync(Guid invitationId,
        CancellationToken cancellationToken)
    {
        var invitation = await store.FindInvitationAsync(invitationId, cancellationToken)
            ?? throw new NotFoundException("Invitation was not found.", "INVITATION_NOT_FOUND");
        invitation.Revoke(clock.UtcNow);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            currentUser.CompanyId, null, currentUser.UserId, "CompanyInvitationRevoked",
            JsonSerializer.Serialize(new { invitationId }), clock.UtcNow));
        Notify(invitation.CompanyId, "CompanyInvitationRevoked", "Warning",
            invitation.Id, invitation.DriverId, new
            {
                eventCode = "COMPANY_INVITATION_REVOKED",
                invitationId = invitation.Id,
                invitation.DriverId
            }, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task<CompanyCodeResponse> GetCompanyCodeAsync(
        CancellationToken cancellationToken)
    {
        var company = await identities.FindCompanyByIdAsync(
            currentUser.CompanyId, cancellationToken)
            ?? throw new NotFoundException("Company was not found.", "COMPANY_NOT_FOUND");
        if (company.ConnectionCodeVersion == 0 || company.ConnectionCodeHash is null)
            return await RotateCompanyCodeAsync(cancellationToken);
        var code = companyCodes.Generate(company.Id, company.ConnectionCodeVersion);
        if (!companyCodes.Hash(code).Equals(company.ConnectionCodeHash, StringComparison.Ordinal))
            throw new InvalidOperationException("The company code configuration is inconsistent.");
        return new(code, company.ConnectionCodeHint ?? code[^6..],
            company.ConnectionCodeVersion);
    }

    public async Task<CompanyCodeResponse> RotateCompanyCodeAsync(
        CancellationToken cancellationToken)
    {
        var company = await identities.FindCompanyByIdAsync(
            currentUser.CompanyId, cancellationToken)
            ?? throw new NotFoundException("Company was not found.", "COMPANY_NOT_FOUND");
        var version = company.ConnectionCodeVersion + 1;
        var code = companyCodes.Generate(company.Id, version);
        company.RotateConnectionCode(companyCodes.Hash(code), code[^6..], clock.UtcNow);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            company.Id, currentUser.UserId, currentUser.UserId,
            "CompanyConnectionCodeRotated",
            JsonSerializer.Serialize(new { version }), clock.UtcNow));
        await identities.SaveChangesAsync(cancellationToken);
        return new(code, code[^6..], version);
    }

    public async Task<CompanyCodeSummaryResponse> ResolveCompanyCodeAsync(
        ResolveCompanyCodeRequest request, CancellationToken cancellationToken)
    {
        var company = await store.FindCompanyByCodeHashAsync(
            companyCodes.Hash(request.Code), cancellationToken)
            ?? throw new NotFoundException(
                "No company matched that exact code.", "COMPANY_CODE_INVALID");
        return new(company.Name, company.ConnectionCodeHint ?? string.Empty);
    }

    public async Task<ConnectionRequestResponse> CreateConnectionRequestAsync(
        CreateConnectionRequest request, CancellationToken cancellationToken)
    {
        var account = await RequiredCurrentAccountAsync(cancellationToken);
        var company = await store.FindCompanyByCodeHashAsync(
            companyCodes.Hash(request.Code), cancellationToken)
            ?? throw new NotFoundException(
                "No company matched that exact code.", "COMPANY_CODE_INVALID");
        if (await store.FindMembershipAsync(company.Id, account.Id, cancellationToken) is not null)
            throw new ConflictException("The account already has a company relationship.",
                "MEMBERSHIP_ALREADY_EXISTS");
        var ownRequests = await store.ListAccountRequestsAsync(account.Id, cancellationToken);
        if (ownRequests.Any(x => x.CompanyId == company.Id
            && x.Status == CompanyConnectionRequestStatus.Pending))
            throw new ConflictException("A connection request is already pending.",
                "CONNECTION_REQUEST_ALREADY_PENDING");

        var connection = new CompanyConnectionRequest(Guid.NewGuid(), company.Id,
            account.Id, JsonSerializer.Serialize(new[] { AppRoles.Driver }), clock.UtcNow);
        store.AddConnectionRequest(connection);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(), company.Id,
            account.Id, account.Id, "CompanyConnectionRequested",
            JsonSerializer.Serialize(new { requestId = connection.Id }), clock.UtcNow));
        Notify(connection.CompanyId, "CompanyConnectionRequested", "Information",
            connection.Id, null, new
            {
                eventCode = "COMPANY_CONNECTION_REQUESTED",
                requestId = connection.Id,
                accountId = account.Id
            }, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return await MapConnectionAsync(connection, cancellationToken);
    }

    public async Task<IReadOnlyList<ConnectionRequestResponse>> ListOwnConnectionsAsync(
        CancellationToken cancellationToken)
    {
        var requests = await store.ListAccountRequestsAsync(
            currentUser.UserId, cancellationToken);
        var result = new List<ConnectionRequestResponse>(requests.Count);
        foreach (var request in requests)
            result.Add(await MapConnectionAsync(request, cancellationToken));
        return result;
    }

    public async Task<IReadOnlyList<ConnectionRequestResponse>> ListCompanyConnectionsAsync(
        CancellationToken cancellationToken)
    {
        var requests = await store.ListCompanyRequestsAsync(cancellationToken);
        var result = new List<ConnectionRequestResponse>(requests.Count);
        foreach (var request in requests)
            result.Add(await MapConnectionAsync(request, cancellationToken));
        return result;
    }

    public async Task<ConnectionRequestResponse> ApproveConnectionAsync(
        Guid requestId, ResolveConnectionRequest request,
        CancellationToken cancellationToken)
    {
        var connection = await store.FindCompanyRequestAsync(requestId, cancellationToken)
            ?? throw new NotFoundException("Connection request was not found.",
                "CONNECTION_REQUEST_NOT_FOUND");
        var now = clock.UtcNow;
        var membership = await store.FindMembershipAsync(
            connection.CompanyId, connection.AccountId, cancellationToken);
        if (membership is null)
        {
            membership = new CompanyMembership(Guid.NewGuid(), connection.CompanyId,
                connection.AccountId, MembershipStatus.Active, currentUser.UserId, now);
            identities.AddMembership(membership);
        }
        else if (!membership.IsActive)
        {
            membership.Activate(now);
        }
        var roles = ParseRoles(connection.RequestedRolesJson);
        if (roles.Contains(AppRoles.Driver, StringComparer.Ordinal)
            && !request.DriverId.HasValue)
            throw new ConflictException(
                "A Driver record must be selected before approving Driver access.",
                "DRIVER_LINK_REQUIRED");
        var existingRoles = await identities.ListMembershipRolesAsync(
            membership.Id, cancellationToken);
        identities.AddMembershipRoles(roles.Except(existingRoles, StringComparer.Ordinal)
            .Select(role => new CompanyMembershipRole(
                connection.CompanyId, membership.Id, role)));

        if (request.DriverId.HasValue)
        {
            var driver = await store.FindDriverAsync(
                request.DriverId.Value, connection.CompanyId, cancellationToken)
                ?? throw new NotFoundException("Driver was not found.", "DRIVER_NOT_FOUND");
            if (driver.UserId.HasValue && driver.UserId != connection.AccountId)
                throw new ConflictException("The Driver is linked to another account.",
                    "DRIVER_USER_ALREADY_LINKED");
            if (!driver.UserId.HasValue) driver.LinkUser(connection.AccountId, now);
        }

        connection.Approve(currentUser.UserId, request.DriverId, now);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            connection.CompanyId, connection.AccountId, currentUser.UserId,
            "CompanyConnectionApproved",
            JsonSerializer.Serialize(new { requestId, request.DriverId }), now));
        Notify(connection.CompanyId, "CompanyConnectionApproved", "Information",
            connection.Id, request.DriverId, new
            {
                eventCode = "COMPANY_CONNECTION_APPROVED",
                requestId = connection.Id,
                connection.AccountId,
                request.DriverId
            }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapConnectionAsync(connection, cancellationToken);
    }

    public async Task<ConnectionRequestResponse> RejectConnectionAsync(
        Guid requestId, ResolveConnectionRequest request,
        CancellationToken cancellationToken)
    {
        var connection = await store.FindCompanyRequestAsync(requestId, cancellationToken)
            ?? throw new NotFoundException("Connection request was not found.",
                "CONNECTION_REQUEST_NOT_FOUND");
        connection.Reject(currentUser.UserId, request.Reason, clock.UtcNow);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            connection.CompanyId, connection.AccountId, currentUser.UserId,
            "CompanyConnectionRejected",
            JsonSerializer.Serialize(new { requestId, request.Reason }), clock.UtcNow));
        Notify(connection.CompanyId, "CompanyConnectionRejected", "Warning",
            connection.Id, null, new
            {
                eventCode = "COMPANY_CONNECTION_REJECTED",
                requestId = connection.Id,
                connection.AccountId,
                request.Reason
            }, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return await MapConnectionAsync(connection, cancellationToken);
    }

    public async Task<ConnectionRequestResponse> CancelConnectionAsync(
        Guid requestId, CancellationToken cancellationToken)
    {
        var connection = await store.FindAccountRequestAsync(
            requestId, currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException("Connection request was not found.",
                "CONNECTION_REQUEST_NOT_FOUND");
        connection.Cancel(clock.UtcNow);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            connection.CompanyId, connection.AccountId, connection.AccountId,
            "CompanyConnectionCancelled",
            JsonSerializer.Serialize(new { requestId }), clock.UtcNow));
        Notify(connection.CompanyId, "CompanyConnectionCancelled", "Information",
            connection.Id, null, new
            {
                eventCode = "COMPANY_CONNECTION_CANCELLED",
                requestId = connection.Id,
                connection.AccountId
            }, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return await MapConnectionAsync(connection, cancellationToken);
    }

    public async Task<WorkspaceResponse> SetMembershipStatusAsync(
        Guid membershipId, MembershipStatusRequest request,
        CancellationToken cancellationToken)
    {
        var membership = await store.FindCompanyMembershipAsync(
            membershipId, cancellationToken)
            ?? throw new NotFoundException("Membership was not found.", "MEMBERSHIP_NOT_FOUND");
        if (membership.AccountId == currentUser.UserId
            && request.Status is "Suspended" or "Revoked")
            throw new ConflictException("You cannot remove your current membership.",
                "MEMBERSHIP_SELF_REVOCATION_FORBIDDEN");
        var now = clock.UtcNow;
        switch (request.Status)
        {
            case "Active": membership.Activate(now); break;
            case "Suspended": membership.Suspend(now); break;
            case "Revoked": membership.Revoke(now); break;
            default: throw new DomainRuleException(
                "The membership status is invalid.", "MEMBERSHIP_STATUS_INVALID");
        }
        if (!membership.IsActive)
            await identities.RevokeMembershipTokensAsync(membership.Id, now, cancellationToken);
        identities.AddIdentityAudit(new IdentityAuditEvent(Guid.NewGuid(),
            membership.CompanyId, membership.AccountId, currentUser.UserId,
            $"Membership{request.Status}", null, now));
        Notify(membership.CompanyId, $"Membership{request.Status}", "Warning",
            membership.Id, null, new
            {
                eventCode = $"MEMBERSHIP_{request.Status.ToUpperInvariant()}",
                membershipId = membership.Id,
                membership.AccountId
            }, now);
        await store.SaveChangesAsync(cancellationToken);
        var company = await identities.FindCompanyByIdAsync(
            membership.CompanyId, cancellationToken);
        var roles = await identities.ListMembershipRolesAsync(
            membership.Id, cancellationToken);
        return new(membership.Id, membership.CompanyId,
            company?.Name ?? string.Empty, roles, membership.Status.ToString());
    }

    private async Task<CompanyInvitation> RequiredInvitationAsync(
        string rawToken, CancellationToken cancellationToken)
    {
        var invitation = await store.FindInvitationByHashAsync(
            Hash(rawToken), cancellationToken)
            ?? throw new NotFoundException("Invitation was not found.", "INVITATION_NOT_FOUND");
        if (invitation.IsExpired(clock.UtcNow))
        {
            invitation.Expire(clock.UtcNow);
            Notify(invitation.CompanyId, "CompanyInvitationExpired", "Warning",
                invitation.Id, invitation.DriverId, new
                {
                    eventCode = "COMPANY_INVITATION_EXPIRED",
                    invitationId = invitation.Id,
                    invitation.DriverId
                }, clock.UtcNow);
            await store.SaveChangesAsync(cancellationToken);
            throw new DomainRuleException("The invitation has expired.", "INVITATION_EXPIRED");
        }
        if (invitation.Status != CompanyInvitationStatus.Pending)
            throw new DomainRuleException(
                "The invitation was already resolved.", "INVITATION_ALREADY_USED");
        return invitation;
    }

    private async Task<User> RequiredCurrentAccountAsync(
        CancellationToken cancellationToken) =>
        await identities.FindUserByIdAsync(currentUser.UserId, cancellationToken)
        ?? throw new NotFoundException("Account was not found.", "ACCOUNT_NOT_FOUND");

    private async Task<InvitationResponse> MapInvitationAsync(
        CompanyInvitation invitation, string? acceptancePath,
        CancellationToken cancellationToken)
    {
        string? driverName = null;
        if (invitation.DriverId.HasValue)
            driverName = (await store.FindDriverAsync(invitation.DriverId.Value,
                invitation.CompanyId, cancellationToken))?.FullName;
        return new(invitation.Id, invitation.Email, ParseRoles(invitation.RolesJson),
            invitation.DriverId, driverName, invitation.Status.ToString(),
            invitation.ExpiresAt, acceptancePath);
    }

    private async Task<ConnectionRequestResponse> MapConnectionAsync(
        CompanyConnectionRequest request, CancellationToken cancellationToken)
    {
        var company = await identities.FindCompanyByIdAsync(
            request.CompanyId, cancellationToken);
        var account = await identities.FindUserByIdAsync(
            request.AccountId, cancellationToken);
        return new(request.Id, request.CompanyId, company?.Name ?? string.Empty,
            request.AccountId, account?.Email ?? string.Empty,
            account?.DisplayName ?? string.Empty,
            ParseRoles(request.RequestedRolesJson), request.Status.ToString(),
            request.DriverId, request.ResolutionReason,
            request.CreatedAt, request.ResolvedAt);
    }

    private static string[] ValidateRoles(IReadOnlyList<string> roles)
    {
        var normalized = roles.Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim()).Distinct(StringComparer.Ordinal).OrderBy(x => x).ToArray();
        if (normalized.Length == 0 || normalized.Any(x => !AppRoles.All.Contains(x)))
            throw new DomainRuleException("At least one valid role is required.",
                "USER_ROLE_INVALID");
        return normalized;
    }

    private static string[] ParseRoles(string json) =>
        JsonSerializer.Deserialize<string[]>(json) ?? [];

    private void Notify(Guid companyId, string type, string severity,
        Guid eventId, Guid? driverId, object data, DateTimeOffset now)
    {
        store.AddNotification(new OperationNotification(Guid.NewGuid(), companyId,
            type, severity, null, null, driverId, $"{type}:{eventId}",
            JsonSerializer.Serialize(data), now));
    }

    private static string GenerateSecret()
    {
        var value = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        return value.Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }

    private static string Hash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
