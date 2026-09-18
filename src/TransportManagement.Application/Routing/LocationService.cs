using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;

namespace TransportManagement.Application.Routing;

public sealed class LocationService(IGeocodingProvider provider)
{
    public async Task<IReadOnlyList<LocationSearchResponse>> SearchAsync(
        string query, CancellationToken cancellationToken)
    {
        var normalized = query?.Trim() ?? string.Empty;
        if (normalized.Length < 3)
            throw new DomainRuleException("Search requires at least three characters.", "LOCATION_QUERY_TOO_SHORT");
        if (normalized.Length > 200)
            throw new DomainRuleException("Search query is too long.", "LOCATION_QUERY_TOO_LONG");
        if (!provider.IsConfigured)
            throw new ProviderException("Geocoding is not configured; select the location on the map.", "GEOCODING_UNAVAILABLE");
        var results = await provider.SearchAsync(normalized, 5, cancellationToken);
        return results.Select(x => new LocationSearchResponse(
            x.ProviderPlaceId, x.DisplayName, x.Address, x.Latitude, x.Longitude,
            x.BoundingBox, provider.ProviderName)).ToArray();
    }

    public async Task<LocationSearchResponse> ReverseAsync(
        decimal latitude, decimal longitude, CancellationToken cancellationToken)
    {
        RouteGeometry.ValidateCoordinate(new(latitude, longitude));
        if (!provider.IsConfigured)
            throw new ProviderException("Reverse geocoding is not configured.", "GEOCODING_UNAVAILABLE");
        var result = await provider.ReverseAsync(latitude, longitude, cancellationToken)
            ?? throw new ProviderException("No location was found for this point.", "GEOCODING_NO_RESULTS");
        return new(result.ProviderPlaceId, result.DisplayName, result.Address,
            result.Latitude, result.Longitude, result.BoundingBox, provider.ProviderName);
    }
}
