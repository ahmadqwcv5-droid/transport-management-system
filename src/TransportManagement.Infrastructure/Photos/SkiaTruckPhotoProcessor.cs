using SkiaSharp;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Common;

namespace TransportManagement.Infrastructure.Photos;

internal sealed class SkiaTruckPhotoProcessor : ITruckPhotoProcessor
{
    public ProcessedTruckPhoto Process(ReadOnlyMemory<byte> bytes, int maximumPixels)
    {
        using var data = SKData.CreateCopy(bytes.Span);
        using var codec = SKCodec.Create(data)
            ?? throw new DomainRuleException("The uploaded file is not a valid image.", "TRUCK_PHOTO_INVALID");
        if (codec.EncodedFormat is not (SKEncodedImageFormat.Jpeg
            or SKEncodedImageFormat.Png or SKEncodedImageFormat.Webp))
            throw new DomainRuleException("Only JPEG, PNG, and WebP photos are allowed.", "TRUCK_PHOTO_FORMAT_INVALID");
        var info = codec.Info;
        if (info.Width <= 0 || info.Height <= 0
            || (long)info.Width * info.Height > maximumPixels)
            throw new DomainRuleException("The photo dimensions are too large.", "TRUCK_PHOTO_DIMENSIONS_INVALID");
        using var decoded = SKBitmap.Decode(codec)
            ?? throw new DomainRuleException("The uploaded image could not be decoded.", "TRUCK_PHOTO_INVALID");
        var detail = EncodeResized(decoded, 1600, 85);
        var thumbnail = EncodeResized(decoded, 192, 80);
        return new(detail, thumbnail, "image/webp", info.Width, info.Height);
    }

    private static byte[] EncodeResized(SKBitmap source, int maximumSide, int quality)
    {
        var scale = Math.Min(1d, maximumSide / (double)Math.Max(source.Width, source.Height));
        var width = Math.Max(1, (int)Math.Round(source.Width * scale));
        var height = Math.Max(1, (int)Math.Round(source.Height * scale));
        using var resized = source.Resize(new SKImageInfo(width, height), new SKSamplingOptions(
            SKFilterMode.Linear, SKMipmapMode.Linear))
            ?? throw new DomainRuleException("The uploaded image could not be resized.", "TRUCK_PHOTO_INVALID");
        using var image = SKImage.FromBitmap(resized);
        using var encoded = image.Encode(SKEncodedImageFormat.Webp, quality)
            ?? throw new DomainRuleException("The uploaded image could not be encoded.", "TRUCK_PHOTO_INVALID");
        return encoded.ToArray();
    }
}
