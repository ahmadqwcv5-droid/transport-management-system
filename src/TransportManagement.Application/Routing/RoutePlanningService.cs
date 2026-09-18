using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;

namespace TransportManagement.Application.Routing;

public sealed class RoutePlanningService(IRoutingProvider provider, IClock clock)
{
    private readonly ConcurrentDictionary<string, RouteResultResponse> _cache = new();

    public async Task<RouteResultResponse> PreviewAsync(
        RoutePreviewRequest request, CancellationToken cancellationToken)
    {
        var coordinates = ValidateStops(request.Stops);
        var fingerprint = Fingerprint(request.Stops, request.Profile);
        if (_cache.TryGetValue(fingerprint, out var cached)) return cached;
        if (!provider.IsConfigured)
            throw new ProviderException("Routing is not configured.", "ROUTING_UNAVAILABLE");

        var result = await provider.CalculateAsync(
            new RoutingProviderRequest(coordinates, request.Profile), cancellationToken);
        if (result.Coordinates.Count < 2 || result.DistanceMeters <= 0 || result.EstimatedDurationSeconds <= 0)
            throw new ProviderException("The routing provider returned an invalid route.", "ROUTING_PROVIDER_FAILURE");
        var response = new RouteResultResponse(
            result.Coordinates,
            RouteGeometry.ToGeoJson(result.Coordinates),
            "geojson-linestring",
            1,
            result.DistanceMeters,
            result.EstimatedDurationSeconds,
            result.ProviderName,
            result.ProviderRouteId,
            clock.UtcNow,
            request.Profile,
            result.Warnings,
            fingerprint);
        _cache[fingerprint] = response;
        return response;
    }

    public static IReadOnlyList<GeoCoordinate> ValidateStops(IReadOnlyList<RouteStopRequest>? stops)
    {
        if (stops is null || stops.Count < 2)
            throw new DomainRuleException("Pickup and delivery stops are required.", "INVALID_TRIP_STOPS");
        var ordered = stops.OrderBy(x => x.Sequence).ToArray();
        if (ordered[0].Sequence != 0
            || !string.Equals(ordered[0].Type, "Pickup", StringComparison.OrdinalIgnoreCase)
            || !string.Equals(ordered[^1].Type, "Delivery", StringComparison.OrdinalIgnoreCase)
            || ordered.Select(x => x.Sequence).Distinct().Count() != ordered.Length
            || ordered.Any(x => string.IsNullOrWhiteSpace(x.Name)))
            throw new DomainRuleException("Stops must be uniquely ordered from pickup to delivery.", "INVALID_TRIP_STOPS");
        var coordinates = ordered.Select(x => new GeoCoordinate(x.Latitude, x.Longitude)).ToArray();
        foreach (var coordinate in coordinates) RouteGeometry.ValidateCoordinate(coordinate);
        if (RouteGeometry.DistanceMeters([coordinates[0], coordinates[^1]]) < 2)
            throw new DomainRuleException("Pickup and delivery must be different locations.", "IDENTICAL_TRIP_STOPS");
        return coordinates;
    }

    public static string Fingerprint(IReadOnlyList<RouteStopRequest> stops, RouteProfile profile)
    {
        var value = string.Join('|', stops.OrderBy(x => x.Sequence)
            .Select(x => $"{x.Sequence}:{x.Latitude:F6}:{x.Longitude:F6}")) + $"|{profile}";
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    }
}
