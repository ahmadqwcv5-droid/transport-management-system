using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.CompanyUsers;

public sealed class CompanyUserService(
    ICompanyUserStore store,
    ICurrentUser currentUser,
    IClock clock)
{
    public async Task<IReadOnlyList<CompanyUserResponse>> ListAsync(
        string? role, bool? isActive, CancellationToken cancellationToken)
    {
        if (role is not null && !AppRoles.All.Contains(role))
            throw new Domain.Common.DomainRuleException("The selected user role is invalid.", "USER_ROLE_INVALID");
        var users = await store.ListUsersAsync(role, isActive, cancellationToken);
        var result = new List<CompanyUserResponse>(users.Count);
        foreach (var user in users)
            result.Add(await MapAsync(user, await store.GetDriverByUserAsync(user.Id, cancellationToken), cancellationToken));
        return result;
    }

    public async Task<CompanyUserResponse> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        return await MapAsync(user, await store.GetDriverByUserAsync(user.Id, cancellationToken), cancellationToken);
    }


    public async Task<CompanyUserResponse> UpdateRolesAsync(Guid id,
        UpdateCompanyUserRolesRequest request, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        var membership = await store.GetMembershipAsync(user.Id, cancellationToken)
            ?? throw new NotFoundException("Membership was not found.", "MEMBERSHIP_NOT_FOUND");
        if (!membership.IsActive)
            throw new ConflictException("Only active memberships can be edited.",
                "MEMBERSHIP_NOT_ACTIVE");
        var roles = request.Roles.Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim()).Distinct(StringComparer.Ordinal)
            .OrderBy(x => x).ToArray();
        if (roles.Length == 0 || roles.Any(x => !AppRoles.All.Contains(x)))
            throw new Domain.Common.DomainRuleException(
                "At least one valid role is required.", "USER_ROLE_INVALID");

        var existing = await store.GetRoleEntitiesAsync(membership.Id, cancellationToken);
        var existingNames = existing.Select(x => x.Role).ToArray();
        if (existingNames.SequenceEqual(roles, StringComparer.Ordinal))
            return await MapAsync(user,
                await store.GetDriverByUserAsync(user.Id, cancellationToken), cancellationToken);

        var removingOwner = existingNames.Contains(AppRoles.Owner, StringComparer.Ordinal)
            && !roles.Contains(AppRoles.Owner, StringComparer.Ordinal);
        if (removingOwner && user.Id == currentUser.UserId)
            throw new ConflictException("You cannot remove your own Owner role.",
                "MEMBERSHIP_SELF_OWNER_REMOVAL_FORBIDDEN");
        if (removingOwner && await store.CountActiveOwnersAsync(cancellationToken) <= 1)
            throw new ConflictException("The company must retain an active Owner.",
                "LAST_ACTIVE_OWNER_REQUIRED");
        if (existingNames.Contains(AppRoles.Driver, StringComparer.Ordinal)
            && !roles.Contains(AppRoles.Driver, StringComparer.Ordinal)
            && await store.GetDriverByUserAsync(user.Id, cancellationToken) is not null)
            throw new ConflictException(
                "Unlink the Driver profile before removing the Driver role.",
                "DRIVER_ROLE_LINKED");

        store.RemoveRoles(existing.Where(x => !roles.Contains(x.Role, StringComparer.Ordinal)));
        store.AddRoles(roles.Except(existingNames, StringComparer.Ordinal)
            .Select(role => new CompanyMembershipRole(currentUser.CompanyId, membership.Id, role)));
        var now = clock.UtcNow;
        await store.RevokeTokensAsync(user.Id, now, cancellationToken);
        AddEvent(user.Id, "MembershipRolesUpdated",
            new { previousRoles = existingNames, roles }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user,
            await store.GetDriverByUserAsync(user.Id, cancellationToken), cancellationToken);
    }


    public async Task<CompanyUserResponse> SetActiveAsync(Guid id,
        CompanyUserActiveRequest request, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        var membership = await store.GetMembershipAsync(user.Id, cancellationToken)
            ?? throw new NotFoundException("Membership was not found.", "MEMBERSHIP_NOT_FOUND");
        if (!request.IsActive && user.Id == currentUser.UserId)
            throw new ConflictException("You cannot suspend your own membership.", "MEMBERSHIP_SELF_REVOCATION_FORBIDDEN");
        var roles = await store.GetRolesAsync(user.Id, cancellationToken);
        if (!request.IsActive && roles.Contains(AppRoles.Owner, StringComparer.Ordinal)
            && await store.CountActiveOwnersAsync(cancellationToken) <= 1)
            throw new ConflictException("The company must retain an active Owner.",
                "LAST_ACTIVE_OWNER_REQUIRED");
        var now = clock.UtcNow;
        if (request.IsActive) membership.Activate(now); else membership.Suspend(now);
        if (!request.IsActive) await store.RevokeTokensAsync(user.Id, now, cancellationToken);
        AddEvent(user.Id, request.IsActive ? "MembershipReactivated" : "MembershipSuspended", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user,
            await store.GetDriverByUserAsync(user.Id, cancellationToken), cancellationToken);
    }


    public async Task<CompanyUserResponse> LinkAsync(Guid userId,
        LinkCompanyUserRequest request, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(userId, cancellationToken);
        var roles = await store.GetRolesAsync(user.Id, cancellationToken);
        if (!roles.Contains(AppRoles.Driver, StringComparer.Ordinal))
            throw new ConflictException("The selected user must have the Driver role.", "DRIVER_ROLE_REQUIRED");
        var membership = await store.GetMembershipAsync(user.Id, cancellationToken)
            ?? throw new NotFoundException("Membership was not found.", "MEMBERSHIP_NOT_FOUND");
        if (!user.IsActive || !membership.IsActive)
            throw new ConflictException("An inactive user cannot be linked.", "MEMBERSHIP_NOT_ACTIVE");
        var driver = await store.GetDriverAsync(request.DriverId, cancellationToken)
            ?? throw new NotFoundException("Driver was not found in the current company.", "DRIVER_NOT_FOUND");
        if (!driver.IsActive)
            throw new ConflictException("An inactive Driver cannot be linked.", "DRIVER_INACTIVE");
        var existingForUser = await store.GetDriverByUserAsync(user.Id, cancellationToken);
        if (existingForUser?.Id == driver.Id && driver.UserId == user.Id)
            return await MapAsync(user, driver, cancellationToken);
        if (existingForUser is not null)
            throw new ConflictException("The user is already linked to another driver.", "DRIVER_USER_ALREADY_LINKED");

        var now = clock.UtcNow;
        if (driver.UserId is Guid oldUserId && oldUserId != user.Id)
        {
            AddEvent(user.Id, "DriverLinkRejected",
                new { driverId = driver.Id, reason = "AlreadyLinked" }, now);
            await store.SaveChangesAsync(cancellationToken);
            throw new ConflictException("The Driver is linked to another account.",
                "DRIVER_ACCOUNT_ALREADY_LINKED");
        }
        driver.LinkUser(user.Id, now);
        AddEvent(user.Id, "DriverLinked", new { driverId = driver.Id }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user, driver, cancellationToken);
    }

    public async Task<CompanyUserResponse> UnlinkAsync(Guid userId,
        CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(userId, cancellationToken);
        var driver = await store.GetDriverByUserAsync(user.Id, cancellationToken)
            ?? throw new NotFoundException("The user is not linked to a driver.", "DRIVER_LINK_REQUIRED");
        var trackedDriver = await store.GetDriverAsync(driver.Id, cancellationToken)
            ?? throw new NotFoundException("Driver was not found.", "DRIVER_NOT_FOUND");
        var now = clock.UtcNow;
        if (await store.HasActiveTripAsync(driver.Id, cancellationToken))
            await RejectUnlinkAsync(user.Id, driver.Id, "ActiveTrip",
                "The Driver has an active trip.", "DRIVER_UNLINK_ACTIVE_TRIP", now, cancellationToken);
        if (await store.HasActiveSessionAsync(driver.Id, cancellationToken))
            await RejectUnlinkAsync(user.Id, driver.Id, "ActiveSession",
                "The Driver has an active truck session.", "DRIVER_UNLINK_ACTIVE_SESSION", now, cancellationToken);
        if (await store.HasPendingHandoverAsync(driver.Id, cancellationToken))
            await RejectUnlinkAsync(user.Id, driver.Id, "PendingHandover",
                "The Driver has a pending handover.", "DRIVER_UNLINK_PENDING_HANDOVER", now, cancellationToken);
        trackedDriver.UnlinkUser(now);
        AddEvent(user.Id, "DriverUnlinked", new { driverId = driver.Id }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user, null, cancellationToken);
    }

    private async Task RejectUnlinkAsync(Guid userId, Guid driverId, string reason,
        string message, string errorCode, DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        AddEvent(userId, "DriverUnlinkRejected", new { driverId, reason }, now);
        await store.SaveChangesAsync(cancellationToken);
        throw new ConflictException(message, errorCode);
    }

    private async Task<User> RequiredUserAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetUserAsync(id, cancellationToken)
        ?? throw new NotFoundException("User was not found in the current company.", "USER_NOT_FOUND");

    private void AddEvent(Guid subjectUserId, string code, object? metadata, DateTimeOffset now) =>
        store.AddEvent(new CompanyUserEvent(Guid.NewGuid(), currentUser.CompanyId,
            subjectUserId, currentUser.UserId, code,
            metadata is null ? null : JsonSerializer.Serialize(metadata), now));

    private async Task<CompanyUserResponse> MapAsync(User user, Driver? driver,
        CancellationToken cancellationToken)
    {
        var roles = await store.GetRolesAsync(user.Id, cancellationToken);
        var role = roles.Count == 0 ? string.Empty : roles[0];
        var membership = await store.GetMembershipAsync(user.Id, cancellationToken);
        return new(user.Id, user.Email, user.DisplayName, role, membership?.IsActive == true,
            user.NotificationSoundsEnabled, driver?.Id, driver?.FullName,
            user.CreatedAt, user.UpdatedAt, membership?.Id,
            membership?.Status.ToString() ?? MembershipStatus.Revoked.ToString(), roles);
    }

}
