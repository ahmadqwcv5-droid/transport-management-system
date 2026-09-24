using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Fleet;

public sealed record TruckPhotoPolicy(int MaximumBytes, int MaximumPixels);
public sealed record TruckPhotoResponse(Guid TruckId, string Version,
    string ContentType, int Width, int Height, long OriginalByteSize,
    DateTimeOffset UploadedAt, string ThumbnailUrl, string DetailUrl);
public sealed record TruckPhotoContent(Stream Content, string ContentType,
    string Version);

public sealed class TruckPhotoService(IFleetStore fleet, ITruckPhotoStore photos,
    ITruckPhotoStorage storage, ITruckPhotoProcessor processor,
    ICurrentUser currentUser, IClock clock, TruckPhotoPolicy policy)
{
    public async Task<TruckPhotoResponse> UploadAsync(Guid truckId, Stream input,
        CancellationToken cancellationToken)
    {
        _ = await RequiredTruckAsync(truckId, cancellationToken);
        using var buffer = new MemoryStream();
        await input.CopyToAsync(buffer, cancellationToken);
        if (buffer.Length is 0 || buffer.Length > policy.MaximumBytes)
            throw new DomainRuleException("The photo must be non-empty and no larger than the configured limit.",
                "TRUCK_PHOTO_SIZE_INVALID");
        var processed = processor.Process(buffer.ToArray(), policy.MaximumPixels);
        var version = Guid.NewGuid().ToString("N");
        var key = $"{currentUser.CompanyId:N}/{truckId:N}/{version}";
        await storage.WriteAsync(key, processed, cancellationToken);
        var existing = await photos.GetAsync(truckId, cancellationToken);
        var previousKey = existing?.StorageKey;
        var now = clock.UtcNow;
        try
        {
            if (existing is null)
            {
                existing = new TruckPhoto(Guid.NewGuid(), currentUser.CompanyId, truckId,
                    key, processed.ContentType, buffer.Length,
                    processed.ThumbnailBytes.LongLength, processed.Width, processed.Height,
                    version, currentUser.UserId, now);
                photos.Add(existing);
            }
            else existing.Replace(key, processed.ContentType, buffer.Length,
                processed.ThumbnailBytes.LongLength, processed.Width, processed.Height,
                version, currentUser.UserId, now);
            fleet.AddTruckEvent(new TruckEvent(Guid.NewGuid(), currentUser.CompanyId,
                truckId, currentUser.UserId, previousKey is null
                    ? "TruckPhotoUploaded" : "TruckPhotoReplaced", null, now));
            await photos.SaveChangesAsync(cancellationToken);
        }
        catch
        {
            await storage.DeleteAsync(key, cancellationToken);
            throw;
        }
        if (previousKey is not null)
            await storage.DeleteAsync(previousKey, cancellationToken);
        return Map(existing);
    }

    public async Task<TruckPhotoResponse?> MetadataAsync(Guid truckId,
        CancellationToken cancellationToken)
    {
        _ = await RequiredTruckAsync(truckId, cancellationToken);
        var photo = await photos.GetAsync(truckId, cancellationToken);
        return photo is null ? null : Map(photo);
    }

    public async Task<TruckPhotoContent> ReadAsync(Guid truckId, bool thumbnail,
        CancellationToken cancellationToken)
    {
        _ = await RequiredTruckAsync(truckId, cancellationToken);
        var photo = await photos.GetAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("Truck photo was not found.", "TRUCK_PHOTO_NOT_FOUND");
        return new(await storage.OpenReadAsync(photo.StorageKey, thumbnail, cancellationToken),
            photo.ContentType, photo.Version);
    }

    public async Task RemoveAsync(Guid truckId, CancellationToken cancellationToken)
    {
        _ = await RequiredTruckAsync(truckId, cancellationToken);
        var photo = await photos.GetAsync(truckId, cancellationToken);
        if (photo is null) return;
        photos.Remove(photo);
        fleet.AddTruckEvent(new TruckEvent(Guid.NewGuid(), currentUser.CompanyId,
            truckId, currentUser.UserId, "TruckPhotoRemoved", null, clock.UtcNow));
        await photos.SaveChangesAsync(cancellationToken);
        await storage.DeleteAsync(photo.StorageKey, cancellationToken);
    }

    private async Task<Truck> RequiredTruckAsync(Guid truckId, CancellationToken cancellationToken) =>
        await fleet.GetTruckAsync(truckId, cancellationToken)
        ?? throw new NotFoundException("Truck was not found.", "TRUCK_NOT_FOUND");

    public static TruckPhotoResponse Map(TruckPhoto photo) => new(photo.TruckId,
        photo.Version, photo.ContentType, photo.Width, photo.Height,
        photo.OriginalByteSize, photo.UploadedAt,
        $"/api/trucks/{photo.TruckId}/photo/thumbnail?v={photo.Version}",
        $"/api/trucks/{photo.TruckId}/photo?v={photo.Version}");
}
