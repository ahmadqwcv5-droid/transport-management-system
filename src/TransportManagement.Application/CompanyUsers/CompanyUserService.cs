using System.Security.Cryptography;
using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.CompanyUsers;

public sealed class CompanyUserService(
    ICompanyUserStore store,
    IIdentityStore identityStore,
    IPasswordHasher passwordHasher,
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
            result.Add(Map(user, await store.GetDriverByUserAsync(user.Id, cancellationToken)));
        return result;
    }

    public async Task<CompanyUserResponse> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        return Map(user, await store.GetDriverByUserAsync(user.Id, cancellationToken));
    }

    public async Task<CompanyUserCredentialResponse> CreateDriverAsync(
        CreateDriverUserRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        if (await identityStore.FindUserByEmailAsync(email, cancellationToken) is not null)
            throw new ConflictException("A user with this email already exists.", "USER_EMAIL_ALREADY_EXISTS");

        Driver? driver = null;
        if (request.DriverId.HasValue)
        {
            driver = await store.GetDriverAsync(request.DriverId.Value, cancellationToken)
                ?? throw new NotFoundException("Driver was not found in the current company.", "DRIVER_NOT_FOUND");
            if (driver.UserId.HasValue)
                throw new ConflictException("The driver already has an app account.", "DRIVER_USER_ALREADY_LINKED");
        }

        var now = clock.UtcNow;
        var temporaryPassword = GenerateTemporaryPassword();
        var user = new User(Guid.NewGuid(), currentUser.CompanyId, email,
            request.DisplayName, passwordHasher.Hash(temporaryPassword), AppRoles.Driver, now);
        store.AddUser(user);
        driver?.LinkUser(user.Id, now);
        AddEvent(user.Id, "UserCreated", new { role = AppRoles.Driver }, now);
        if (driver is not null)
            AddEvent(user.Id, "DriverLinked", new { driverId = driver.Id }, now);
        await store.SaveChangesAsync(cancellationToken);
        return new(Map(user, driver), temporaryPassword);
    }

    public async Task<CompanyUserResponse> SetActiveAsync(Guid id,
        CompanyUserActiveRequest request, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        if (!request.IsActive && user.Id == currentUser.UserId)
            throw new ConflictException("You cannot deactivate your own account.", "USER_SELF_DEACTIVATION_FORBIDDEN");
        var now = clock.UtcNow;
        if (request.IsActive) user.Reactivate(now); else user.Deactivate(now);
        if (!request.IsActive) await store.RevokeTokensAsync(user.Id, now, cancellationToken);
        AddEvent(user.Id, request.IsActive ? "UserReactivated" : "UserDeactivated", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(user, await store.GetDriverByUserAsync(user.Id, cancellationToken));
    }

    public async Task<CompanyUserCredentialResponse> ResetPasswordAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(id, cancellationToken);
        var now = clock.UtcNow;
        var temporaryPassword = GenerateTemporaryPassword();
        user.ResetPassword(passwordHasher.Hash(temporaryPassword), now);
        await store.RevokeTokensAsync(user.Id, now, cancellationToken);
        AddEvent(user.Id, "TemporaryPasswordReset", null, now);
        await store.SaveChangesAsync(cancellationToken);
        return new(Map(user, await store.GetDriverByUserAsync(user.Id, cancellationToken)),
            temporaryPassword);
    }

    public async Task<CompanyUserResponse> LinkAsync(Guid userId,
        LinkCompanyUserRequest request, CancellationToken cancellationToken)
    {
        var user = await RequiredUserAsync(userId, cancellationToken);
        if (user.Role != AppRoles.Driver)
            throw new ConflictException("The selected user must have the Driver role.", "DRIVER_ROLE_REQUIRED");
        if (!user.IsActive)
            throw new ConflictException("An inactive user cannot be linked.", "USER_DEACTIVATED");
        var driver = await store.GetDriverAsync(request.DriverId, cancellationToken)
            ?? throw new NotFoundException("Driver was not found in the current company.", "DRIVER_NOT_FOUND");
        var existingForUser = await store.GetDriverByUserAsync(user.Id, cancellationToken);
        if (existingForUser?.Id == driver.Id && driver.UserId == user.Id) return Map(user, driver);
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
        return Map(user, driver);
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
        return Map(user, null);
    }

    private async Task<User> RequiredUserAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetUserAsync(id, cancellationToken)
        ?? throw new NotFoundException("User was not found in the current company.", "USER_NOT_FOUND");

    private void AddEvent(Guid subjectUserId, string code, object? metadata, DateTimeOffset now) =>
        store.AddEvent(new CompanyUserEvent(Guid.NewGuid(), currentUser.CompanyId,
            subjectUserId, currentUser.UserId, code,
            metadata is null ? null : JsonSerializer.Serialize(metadata), now));

    private static CompanyUserResponse Map(User user, Driver? driver) => new(
        user.Id, user.Email, user.DisplayName, user.Role, user.IsActive,
        user.NotificationSoundsEnabled, driver?.Id, driver?.FullName,
        user.CreatedAt, user.UpdatedAt);

    private static string GenerateTemporaryPassword()
    {
        Span<byte> bytes = stackalloc byte[18];
        RandomNumberGenerator.Fill(bytes);
        return $"Tms!{Convert.ToHexString(bytes)}a7";
    }
}
