using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class TruckPhoto : Entity, ITenantOwned
{
    private TruckPhoto() { }

    public TruckPhoto(Guid id, Guid companyId, Guid truckId, string storageKey,
        string contentType, long originalByteSize, long thumbnailByteSize,
        int width, int height, string version, Guid uploadedByUserId,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        TruckId = truckId;
        StorageKey = storageKey;
        ContentType = contentType;
        OriginalByteSize = originalByteSize;
        ThumbnailByteSize = thumbnailByteSize;
        Width = width;
        Height = height;
        Version = version;
        UploadedByUserId = uploadedByUserId;
        UploadedAt = now;
    }

    public Guid CompanyId { get; private set; }
    public Guid TruckId { get; private set; }
    public string StorageKey { get; private set; } = string.Empty;
    public string ContentType { get; private set; } = string.Empty;
    public long OriginalByteSize { get; private set; }
    public long ThumbnailByteSize { get; private set; }
    public int Width { get; private set; }
    public int Height { get; private set; }
    public string Version { get; private set; } = string.Empty;
    public DateTimeOffset UploadedAt { get; private set; }
    public Guid UploadedByUserId { get; private set; }

    public void Replace(string storageKey, string contentType, long originalByteSize,
        long thumbnailByteSize, int width, int height, string version,
        Guid uploadedByUserId, DateTimeOffset now)
    {
        StorageKey = storageKey;
        ContentType = contentType;
        OriginalByteSize = originalByteSize;
        ThumbnailByteSize = thumbnailByteSize;
        Width = width;
        Height = height;
        Version = version;
        UploadedByUserId = uploadedByUserId;
        UploadedAt = now;
        Touch(now);
    }
}
