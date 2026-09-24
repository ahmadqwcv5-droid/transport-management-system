using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Abstractions;

public interface ITruckPhotoStore
{
    Task<TruckPhoto?> GetAsync(Guid truckId, CancellationToken cancellationToken);
    Task<IReadOnlyList<TruckPhoto>> ListAsync(CancellationToken cancellationToken);
    void Add(TruckPhoto photo);
    void Remove(TruckPhoto photo);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}

public sealed record ProcessedTruckPhoto(byte[] DetailBytes, byte[] ThumbnailBytes,
    string ContentType, int Width, int Height);

public interface ITruckPhotoProcessor
{
    ProcessedTruckPhoto Process(ReadOnlyMemory<byte> bytes, int maximumPixels);
}

public interface ITruckPhotoStorage
{
    Task WriteAsync(string storageKey, ProcessedTruckPhoto photo,
        CancellationToken cancellationToken);
    Task<Stream> OpenReadAsync(string storageKey, bool thumbnail,
        CancellationToken cancellationToken);
    Task DeleteAsync(string storageKey, CancellationToken cancellationToken);
}
