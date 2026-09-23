using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Fleet;

public sealed class DriverService(IFleetStore store, ICurrentUser currentUser, IClock clock)
{
    public async Task<DriverResponse> CreateAsync(DriverRequest request, CancellationToken cancellationToken)
    {
        var license = NormalizeLicense(request.LicenseNumber);
        await EnsureUniqueLicenseAsync(license, null, cancellationToken);
        var driver = new Driver(Guid.NewGuid(), currentUser.CompanyId, request.FullName, request.Phone, license, request.LicenseExpiryDate, request.Notes, clock.UtcNow);
        store.AddDriver(driver);
        await store.SaveChangesAsync(cancellationToken);
        return Map(driver);
    }

    public async Task<DriverResponse> UpdateAsync(Guid id, DriverRequest request, CancellationToken cancellationToken)
    {
        var driver = await RequiredAsync(id, cancellationToken);
        if (driver.Status == DriverStatus.OnTrip)
            throw new ConflictException("A driver on a trip cannot be edited.");
        var license = NormalizeLicense(request.LicenseNumber);
        await EnsureUniqueLicenseAsync(license, id, cancellationToken);
        driver.Update(request.FullName, request.Phone, license, request.LicenseExpiryDate, request.Notes, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(driver);
    }

    public async Task<DriverResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        Map(await RequiredAsync(id, cancellationToken));

    public async Task<IReadOnlyList<DriverResponse>> ListAsync(DriverStatus? status, bool? isActive, string? search, CancellationToken cancellationToken) =>
        (await store.ListDriversAsync(status, isActive, search, cancellationToken)).Select(Map).ToArray();

    public async Task<DriverResponse> ChangeStatusAsync(Guid id, DriverStatusRequest request, CancellationToken cancellationToken)
    {
        var driver = await RequiredAsync(id, cancellationToken);
        if (request.Status == DriverStatus.OnTrip || driver.Status == DriverStatus.OnTrip)
            throw new DomainRuleException("OnTrip status is controlled by the trip lifecycle.");
        if (await store.DriverReservedAsync(id, null, cancellationToken))
            throw new ConflictException("The driver is reserved by an active trip.");
        driver.ChangeStatus(request.Status, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(driver);
    }

    public async Task DeactivateAsync(Guid id, CancellationToken cancellationToken)
    {
        var driver = await RequiredAsync(id, cancellationToken);
        if (await store.DriverReservedAsync(id, null, cancellationToken))
            throw new ConflictException("The driver is reserved by an active trip.");
        driver.Deactivate(clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureUniqueLicenseAsync(string license, Guid? excludingId, CancellationToken cancellationToken)
    {
        if (await store.LicenseExistsAsync(license, excludingId, cancellationToken))
            throw new ConflictException("A driver with this license number already exists in the company.");
    }

    private async Task<Driver> RequiredAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetDriverAsync(id, cancellationToken)
        ?? throw new NotFoundException("Driver was not found.");

    private static string NormalizeLicense(string license) => license.Trim().ToUpperInvariant();
    private static DriverResponse Map(Driver driver) => new(
        driver.Id, driver.FullName, driver.Phone, driver.LicenseNumber, driver.LicenseExpiryDate,
        driver.Status, driver.Notes, driver.IsActive, driver.CreatedAt, driver.UpdatedAt);
}
