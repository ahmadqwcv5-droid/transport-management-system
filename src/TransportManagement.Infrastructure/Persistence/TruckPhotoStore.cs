using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class TruckPhotoStore(AppDbContext dbContext) : ITruckPhotoStore
{
    public Task<TruckPhoto?> GetAsync(Guid truckId, CancellationToken cancellationToken) =>
        dbContext.TruckPhotos.SingleOrDefaultAsync(x => x.TruckId == truckId, cancellationToken);
    public async Task<IReadOnlyList<TruckPhoto>> ListAsync(CancellationToken cancellationToken) =>
        await dbContext.TruckPhotos.AsNoTracking().ToListAsync(cancellationToken);
    public void Add(TruckPhoto photo) => dbContext.TruckPhotos.Add(photo);
    public void Remove(TruckPhoto photo) => dbContext.TruckPhotos.Remove(photo);
    public async Task SaveChangesAsync(CancellationToken cancellationToken) =>
        await dbContext.SaveChangesAsync(cancellationToken);
}
