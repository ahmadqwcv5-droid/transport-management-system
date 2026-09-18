using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Configuration;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;

namespace TransportManagement.Infrastructure.Routing;

public sealed class NominatimGeocodingProvider(HttpClient client, IConfiguration configuration) : IGeocodingProvider
{
    private readonly string? _baseUrl = configuration["Geocoding:BaseUrl"]?.TrimEnd('/');
    private readonly string _userAgent = configuration["Geocoding:UserAgent"] ?? "TransportManagement-Development";
    private readonly int _timeoutSeconds = Math.Clamp(configuration.GetValue("Geocoding:TimeoutSeconds", 8), 2, 30);
    public bool IsConfigured => Uri.TryCreate(_baseUrl, UriKind.Absolute, out _);
    public string ProviderName => "Nominatim";

    public async Task<IReadOnlyList<GeocodingProviderResult>> SearchAsync(
        string query, int limit, CancellationToken cancellationToken)
    {
        var uri = $"{_baseUrl}/search?format=jsonv2&limit={Math.Clamp(limit, 1, 5)}&q={Uri.EscapeDataString(query)}";
        var values = await GetAsync(uri, cancellationToken);
        return values.Select(Map).ToArray();
    }

    public async Task<GeocodingProviderResult?> ReverseAsync(
        decimal latitude, decimal longitude, CancellationToken cancellationToken)
    {
        var uri = $"{_baseUrl}/reverse?format=jsonv2&lat={latitude.ToString(CultureInfo.InvariantCulture)}&lon={longitude.ToString(CultureInfo.InvariantCulture)}";
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        request.Headers.UserAgent.ParseAdd(_userAgent);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_timeoutSeconds));
        try
        {
            using var response = await client.SendAsync(request, timeout.Token);
            if (!response.IsSuccessStatusCode) return null;
            var value = await response.Content.ReadFromJsonAsync<NominatimResult>(cancellationToken: timeout.Token);
            return value is null ? null : Map(value);
        }
        catch (OperationCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            throw new ProviderException("The geocoding provider timed out.", "GEOCODING_TIMEOUT", exception);
        }
        catch (HttpRequestException exception)
        {
            throw new ProviderException("The geocoding provider is unavailable.", "GEOCODING_PROVIDER_FAILURE", exception);
        }
    }

    private async Task<IReadOnlyList<NominatimResult>> GetAsync(string uri, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        request.Headers.UserAgent.ParseAdd(_userAgent);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_timeoutSeconds));
        try
        {
            using var response = await client.SendAsync(request, timeout.Token);
            if (!response.IsSuccessStatusCode)
                throw new ProviderException("The geocoding provider failed.", "GEOCODING_PROVIDER_FAILURE");
            return await response.Content.ReadFromJsonAsync<IReadOnlyList<NominatimResult>>(cancellationToken: timeout.Token) ?? [];
        }
        catch (OperationCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            throw new ProviderException("The geocoding provider timed out.", "GEOCODING_TIMEOUT", exception);
        }
        catch (HttpRequestException exception)
        {
            throw new ProviderException("The geocoding provider is unavailable.", "GEOCODING_PROVIDER_FAILURE", exception);
        }
    }

    private static GeocodingProviderResult Map(NominatimResult value)
    {
        if (!decimal.TryParse(value.Latitude, NumberStyles.Float, CultureInfo.InvariantCulture, out var latitude)
            || !decimal.TryParse(value.Longitude, NumberStyles.Float, CultureInfo.InvariantCulture, out var longitude))
            throw new ProviderException("The geocoding provider returned invalid coordinates.", "GEOCODING_PROVIDER_FAILURE");
        var bounds = value.BoundingBox?.Select(item => decimal.Parse(item, CultureInfo.InvariantCulture)).ToArray();
        return new(value.PlaceId.ToString(CultureInfo.InvariantCulture), value.DisplayName,
            value.DisplayName, latitude, longitude, bounds);
    }

    private sealed record NominatimResult(
        [property: JsonPropertyName("place_id")] long PlaceId,
        [property: JsonPropertyName("display_name")] string DisplayName,
        [property: JsonPropertyName("lat")] string Latitude,
        [property: JsonPropertyName("lon")] string Longitude,
        [property: JsonPropertyName("boundingbox")] IReadOnlyList<string>? BoundingBox);
}
