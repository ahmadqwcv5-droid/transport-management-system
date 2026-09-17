using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Fleet;

public sealed class TruckService(IOperationsStore store, ICurrentUser currentUser, IClock clock)
{
    public async Task<TruckResponse> CreateAsync(TruckRequest request, CancellationToken cancellationToken)
    {
        var plate = NormalizePlate(request.PlateNumber);
        await EnsureUniquePlateAsync(plate, null, cancellationToken);
        var truck = new Truck(Guid.NewGuid(), currentUser.CompanyId, plate, request.Make, request.Model, request.Year, request.Notes, clock.UtcNow);
        store.AddTruck(truck);
        await store.SaveChangesAsync(cancellationToken);
        return Map(truck);
    }

    public async Task<TruckResponse> UpdateAsync(Guid id, TruckRequest request, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        if (truck.Status == TruckStatus.OnTrip)
            throw new ConflictException("A truck on a trip cannot be edited.");
        var plate = NormalizePlate(request.PlateNumber);
        await EnsureUniquePlateAsync(plate, id, cancellationToken);
        truck.Update(plate, request.Make, request.Model, request.Year, request.Notes, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(truck);
    }

    public async Task<TruckResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        Map(await RequiredAsync(id, cancellationToken));

    public async Task<IReadOnlyList<TruckResponse>> ListAsync(TruckStatus? status, bool? isActive, string? search, CancellationToken cancellationToken) =>
        (await store.ListTrucksAsync(status, isActive, search, cancellationToken)).Select(Map).ToArray();

    public async Task<TruckResponse> ChangeStatusAsync(Guid id, TruckStatusRequest request, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        if (request.Status == TruckStatus.OnTrip || truck.Status == TruckStatus.OnTrip)
            throw new DomainRuleException("OnTrip status is controlled by the trip lifecycle.");
        if (await store.TruckReservedAsync(id, null, cancellationToken))
            throw new ConflictException("The truck is reserved by an active trip.");
        truck.ChangeStatus(request.Status, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(truck);
    }

    public async Task DeactivateAsync(Guid id, CancellationToken cancellationToken)
    {
        var truck = await RequiredAsync(id, cancellationToken);
        if (await store.TruckReservedAsync(id, null, cancellationToken))
            throw new ConflictException("The truck is reserved by an active trip.");
        truck.Deactivate(clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureUniquePlateAsync(string plate, Guid? excludingId, CancellationToken cancellationToken)
    {
        if (await store.PlateExistsAsync(plate, excludingId, cancellationToken))
            throw new ConflictException("A truck with this plate number already exists in the company.");
    }

    private async Task<Truck> RequiredAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetTruckAsync(id, cancellationToken)
        ?? throw new NotFoundException("Truck was not found.");

    private static string NormalizePlate(string plate) => plate.Trim().ToUpperInvariant();
    private static TruckResponse Map(Truck truck) => new(
        truck.Id, truck.PlateNumber, truck.Make, truck.Model, truck.Year, truck.Status,
        truck.Notes, truck.IsActive, truck.CreatedAt, truck.UpdatedAt);
}
