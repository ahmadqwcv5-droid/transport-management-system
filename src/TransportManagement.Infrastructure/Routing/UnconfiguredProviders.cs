using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;

namespace TransportManagement.Infrastructure.Routing;

public sealed class UnconfiguredRoutingProvider : IRoutingProvider
{
    public bool IsConfigured => false;
    public Task<RoutingProviderResult> CalculateAsync(RoutingProviderRequest request, CancellationToken cancellationToken) =>
        throw new ProviderException("Routing is not configured.", "ROUTING_UNAVAILABLE");
}

public sealed class UnconfiguredGeocodingProvider : IGeocodingProvider
{
    public bool IsConfigured => false;
    public string ProviderName => "Unconfigured";
    public Task<IReadOnlyList<GeocodingProviderResult>> SearchAsync(string query, int limit, CancellationToken cancellationToken) =>
        throw new ProviderException("Geocoding is not configured.", "GEOCODING_UNAVAILABLE");
    public Task<GeocodingProviderResult?> ReverseAsync(decimal latitude, decimal longitude, CancellationToken cancellationToken) =>
        throw new ProviderException("Geocoding is not configured.", "GEOCODING_UNAVAILABLE");
}
