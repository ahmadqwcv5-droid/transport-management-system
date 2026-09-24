using Microsoft.Extensions.Options;
using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Photos;

public sealed class TruckPhotoStorageOptions
{
    public const string SectionName = "TruckPhotos";
    public string RootPath { get; set; } = "data/truck-photos";
    public int MaximumBytes { get; set; } = 5 * 1024 * 1024;
    public int MaximumPixels { get; set; } = 40_000_000;
}

internal sealed class LocalTruckPhotoStorage(IOptions<TruckPhotoStorageOptions> options)
    : ITruckPhotoStorage
{
    private readonly string root = Path.GetFullPath(options.Value.RootPath);

    public async Task WriteAsync(string storageKey, ProcessedTruckPhoto photo,
        CancellationToken cancellationToken)
    {
        var directory = Resolve(storageKey);
        Directory.CreateDirectory(directory);
        await File.WriteAllBytesAsync(Path.Combine(directory, "detail.webp"),
            photo.DetailBytes, cancellationToken);
        await File.WriteAllBytesAsync(Path.Combine(directory, "thumbnail.webp"),
            photo.ThumbnailBytes, cancellationToken);
    }

    public Task<Stream> OpenReadAsync(string storageKey, bool thumbnail,
        CancellationToken cancellationToken)
    {
        var path = Path.Combine(Resolve(storageKey), thumbnail ? "thumbnail.webp" : "detail.webp");
        Stream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read,
            64 * 1024, FileOptions.Asynchronous | FileOptions.SequentialScan);
        return Task.FromResult(stream);
    }

    public Task DeleteAsync(string storageKey, CancellationToken cancellationToken)
    {
        var directory = Resolve(storageKey);
        if (Directory.Exists(directory)) Directory.Delete(directory, true);
        return Task.CompletedTask;
    }

    private string Resolve(string storageKey)
    {
        if (storageKey.Length is < 10 or > 200 || storageKey.Any(ch =>
                !(char.IsAsciiHexDigit(ch) || ch == '/')))
            throw new InvalidOperationException("Invalid photo storage key.");
        var path = Path.GetFullPath(Path.Combine(root, storageKey));
        if (!path.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
            throw new InvalidOperationException("Invalid photo storage path.");
        return path;
    }
}
