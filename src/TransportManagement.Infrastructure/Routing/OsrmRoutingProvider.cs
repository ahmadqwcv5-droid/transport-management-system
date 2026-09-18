using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Configuration;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;

namespace TransportManagement.Infrastructure.Routing;

public sealed class OsrmRoutingProvider(HttpClient client, IConfiguration configuration) : IRoutingProvider
{
    private readonly string? _baseUrl = configuration["Routing:BaseUrl"]?.TrimEnd('/');
    private readonly int _timeoutSeconds = Math.Clamp(configuration.GetValue("Routing:TimeoutSeconds", 12), 2, 60);
    public bool IsConfigured => Uri.TryCreate(_baseUrl, UriKind.Absolute, out _);

    public async Task<RoutingProviderResult> CalculateAsync(
        RoutingProviderRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            throw new ProviderException("Routing is not configured.", "ROUTING_UNAVAILABLE");
        if (request.Profile != RouteProfile.Driving)
            throw new ProviderException("The configured provider supports general driving only.", "ROUTING_PROFILE_UNSUPPORTED");
        var points = string.Join(';', request.Stops.Select(point =>
            $"{point.Longitude.ToString(CultureInfo.InvariantCulture)},{point.Latitude.ToString(CultureInfo.InvariantCulture)}"));
        var uri = $"{_baseUrl}/route/v1/driving/{points}?overview=full&geometries=geojson&steps=false";
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_timeoutSeconds));
        try
        {
            HttpResponseMessage? response = null;
            for (var attempt = 0; attempt < 2; attempt++)
            {
                response?.Dispose();
                response = await client.GetAsync(uri, timeout.Token);
                if (response.StatusCode != HttpStatusCode.TooManyRequests && (int)response.StatusCode < 500) break;
                if (attempt == 0) await Task.Delay(150, timeout.Token);
            }
            using (response)
            {
                if (response is null || !response.IsSuccessStatusCode)
                    throw new ProviderException("The routing provider failed.", "ROUTING_PROVIDER_FAILURE");
                var payload = await response.Content.ReadFromJsonAsync<OsrmResponse>(cancellationToken: timeout.Token)
                    ?? throw new ProviderException("The routing provider returned no data.", "ROUTING_PROVIDER_FAILURE");
                if (!string.Equals(payload.Code, "Ok", StringComparison.Ordinal) || payload.Routes.Count == 0)
                    throw new ProviderException("No road route was found for these stops.", "ROUTING_NO_ROUTE");
                var route = payload.Routes[0];
                var coordinates = route.Geometry.Coordinates.Select(value =>
                {
                    if (value.Count < 2)
                        throw new ProviderException("The provider returned malformed geometry.", "ROUTING_PROVIDER_FAILURE");
                    // OSRM GeoJSON uses longitude, latitude.
                    return new GeoCoordinate(value[1], value[0]);
                }).ToArray();
                return new(coordinates, route.Distance, (int)Math.Ceiling(route.Duration),
                    "OSRM", null, ["General driving profile; no HGV restrictions or live traffic."]);
            }
        }
        catch (OperationCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            throw new ProviderException("The routing provider timed out.", "ROUTING_TIMEOUT", exception);
        }
        catch (HttpRequestException exception)
        {
            throw new ProviderException("The routing provider is unavailable.", "ROUTING_PROVIDER_FAILURE", exception);
        }
    }

    private sealed record OsrmResponse(
        [property: JsonPropertyName("code")] string Code,
        [property: JsonPropertyName("routes")] IReadOnlyList<OsrmRoute> Routes);
    private sealed record OsrmRoute(
        [property: JsonPropertyName("distance")] decimal Distance,
        [property: JsonPropertyName("duration")] decimal Duration,
        [property: JsonPropertyName("geometry")] OsrmGeometry Geometry);
    private sealed record OsrmGeometry(
        [property: JsonPropertyName("coordinates")] IReadOnlyList<IReadOnlyList<decimal>> Coordinates);
}
