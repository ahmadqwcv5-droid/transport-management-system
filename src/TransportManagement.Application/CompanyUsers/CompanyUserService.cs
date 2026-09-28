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


    public async Task<CompanyUserResponse> SetActiveAsync(Guid id,
        CompanyUserActiveRequest request, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        var membership = await store.GetMembershipAsync(user.Id, cancellationToken)
            ?? throw new NotFoundException("Membership was not found.", "MEMBERSHIP_NOT_FOUND");
        if (!request.IsActive && user.Id == currentUser.UserId)
            throw new ConflictException("You cannot suspend your own membership.", "MEMBERSHIP_SELF_REVOCATION_FORBIDDEN");
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
        if (!user.IsActive)
            throw new ConflictException("An inactive user cannot be linked.", "USER_DEACTIVATED");
        var driver = await store.GetDriverAsync(request.DriverId, cancellationToken)
            ?? throw new NotFoundException("Driver was not found in the current company.", "DRIVER_NOT_FOUND");
        var existingForUser = await store.GetDriverByUserAsync(user.Id, cancellationToken);
        if (existingForUser?.Id == driver.Id && driver.UserId == user.Id)
            return await MapAsync(user, driver, cancellationToken);
        if (existingForUser is not null)
            throw new ConflictException("The user is already linked to another driver.", "DRIVER_USER_ALREADY_LINKED");

        var now = clock.UtcNow;
        if (driver.UserId is Guid oldUserId && oldUserId != user.Id)
        {
            driver.UnlinkUser(now);
            AddEvent(oldUserId, "DriverUnlinked", new { driverId = driver.Id, replaced = true }, now);
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
        trackedDriver.UnlinkUser(now);
        AddEvent(user.Id, "DriverUnlinked", new { driverId = driver.Id }, now);
        await store.SaveChangesAsync(cancellationToken);
        return await MapAsync(user, null, cancellationToken);
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
