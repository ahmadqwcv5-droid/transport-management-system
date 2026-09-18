namespace TransportManagement.Application.Abstractions;

public sealed record GeocodingProviderResult(
    string? ProviderPlaceId,
    string DisplayName,
    string? Address,
    decimal Latitude,
    decimal Longitude,
    IReadOnlyList<decimal>? BoundingBox);

public interface IGeocodingProvider
{
    bool IsConfigured { get; }
    string ProviderName { get; }
    Task<IReadOnlyList<GeocodingProviderResult>> SearchAsync(
        string query, int limit, CancellationToken cancellationToken);
    Task<GeocodingProviderResult?> ReverseAsync(
        decimal latitude, decimal longitude, CancellationToken cancellationToken);
}
