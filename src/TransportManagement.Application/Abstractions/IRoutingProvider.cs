using TransportManagement.Application.Routing;

namespace TransportManagement.Application.Abstractions;

public sealed record RoutingProviderRequest(
    IReadOnlyList<GeoCoordinate> Stops,
    RouteProfile Profile);

public sealed record RoutingProviderResult(
    IReadOnlyList<GeoCoordinate> Coordinates,
    decimal DistanceMeters,
    int EstimatedDurationSeconds,
    string ProviderName,
    string? ProviderRouteId,
    IReadOnlyList<string> Warnings);

public interface IRoutingProvider
{
    bool IsConfigured { get; }
    Task<RoutingProviderResult> CalculateAsync(
        RoutingProviderRequest request, CancellationToken cancellationToken);
}
