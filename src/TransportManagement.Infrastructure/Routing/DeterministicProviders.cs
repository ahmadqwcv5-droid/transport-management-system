using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;

namespace TransportManagement.Infrastructure.Routing;

public sealed class DeterministicRoutingProvider : IRoutingProvider
{
    public bool IsConfigured => true;

    public Task<RoutingProviderResult> CalculateAsync(
        RoutingProviderRequest request, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (request.Profile != RouteProfile.Driving)
            throw new ProviderException("The route profile is unsupported.", "ROUTING_PROFILE_UNSUPPORTED");
        var result = new List<GeoCoordinate>();
        for (var index = 1; index < request.Stops.Count; index++)
        {
            var start = request.Stops[index - 1];
            var end = request.Stops[index];
            if (result.Count == 0) result.Add(start);
            var latitudeDelta = end.Latitude - start.Latitude;
            var longitudeDelta = end.Longitude - start.Longitude;
            // A deterministic bend makes tests prove that provider geometry,
            // rather than a straight pickup/delivery chord, is preserved.
            result.Add(new(start.Latitude + latitudeDelta * 0.30m, start.Longitude + longitudeDelta * 0.15m));
            result.Add(new(start.Latitude + latitudeDelta * 0.55m, start.Longitude + longitudeDelta * 0.70m));
            result.Add(end);
        }
        var distance = RouteGeometry.DistanceMeters(result);
        return Task.FromResult(new RoutingProviderResult(
            result, distance, Math.Max(1, (int)Math.Ceiling(distance / (50_000m / 3600))),
            "DeterministicTest", null,
            ["General driving profile; no HGV restrictions or live traffic."]));
    }
}

public sealed class DeterministicGeocodingProvider : IGeocodingProvider
{
    public bool IsConfigured => true;
    public string ProviderName => "DeterministicTest";

    public Task<IReadOnlyList<GeocodingProviderResult>> SearchAsync(
        string query, int limit, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        IReadOnlyList<GeocodingProviderResult> results = query.Contains("istanbul", StringComparison.OrdinalIgnoreCase)
            ? [new("istanbul", "Istanbul Test Depot", "Istanbul, Türkiye", 41.0082m, 28.9784m, [40.8m, 28.7m, 41.3m, 29.4m])]
            : [new("ankara", "Ankara Test Depot", "Ankara, Türkiye", 39.9208m, 32.8541m, [39.7m, 32.5m, 40.1m, 33.2m])];
        return Task.FromResult(results);
    }

    public Task<GeocodingProviderResult?> ReverseAsync(
        decimal latitude, decimal longitude, CancellationToken cancellationToken) =>
        Task.FromResult<GeocodingProviderResult?>(new(
            null, $"Selected point {latitude:F5}, {longitude:F5}", null,
            latitude, longitude, null));
}
