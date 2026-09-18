using System.Text.Json;
using TransportManagement.Domain.Common;

namespace TransportManagement.Application.Routing;

public sealed record RouteProjection(
    decimal DistanceAlongRouteMeters,
    decimal DistanceFromRouteMeters,
    int SegmentIndex,
    GeoCoordinate ProjectedCoordinate);

public sealed record RouteInterpolation(
    GeoCoordinate Coordinate,
    decimal Heading,
    int SegmentIndex);

public static class RouteGeometry
{
    private const double EarthRadiusMeters = 6_371_000;
    public const int MaxCoordinates = 10_000;

    public static void ValidateCoordinate(GeoCoordinate coordinate)
    {
        if (coordinate.Latitude is < -90 or > 90 || coordinate.Longitude is < -180 or > 180)
            throw new DomainRuleException("Coordinates are outside valid latitude/longitude ranges.", "INVALID_COORDINATES");
    }

    public static string ToGeoJson(IReadOnlyList<GeoCoordinate> coordinates)
    {
        ValidateLine(coordinates);
        return JsonSerializer.Serialize(new
        {
            type = "LineString",
            coordinates = coordinates.Select(x => new[] { x.Longitude, x.Latitude })
        });
    }

    public static IReadOnlyList<GeoCoordinate> FromGeoJson(string geometry)
    {
        try
        {
            using var document = JsonDocument.Parse(geometry);
            var root = document.RootElement;
            if (!string.Equals(root.GetProperty("type").GetString(), "LineString", StringComparison.Ordinal))
                throw new DomainRuleException("Only GeoJSON LineString geometry is supported.", "INVALID_ROUTE_GEOMETRY");
            var values = root.GetProperty("coordinates");
            if (values.GetArrayLength() is < 2 or > MaxCoordinates)
                throw new DomainRuleException("Route geometry has an invalid point count.", "INVALID_ROUTE_GEOMETRY");
            var result = values.EnumerateArray().Select(value =>
            {
                if (value.GetArrayLength() < 2)
                    throw new DomainRuleException("Route coordinate is malformed.", "INVALID_ROUTE_GEOMETRY");
                // GeoJSON is longitude, latitude. Normalize at this boundary.
                var coordinate = new GeoCoordinate(value[1].GetDecimal(), value[0].GetDecimal());
                ValidateCoordinate(coordinate);
                return coordinate;
            }).ToArray();
            ValidateLine(result);
            return result;
        }
        catch (JsonException exception)
        {
            throw new DomainRuleException($"Route geometry is invalid: {exception.Message}", "INVALID_ROUTE_GEOMETRY");
        }
    }

    public static decimal DistanceMeters(IReadOnlyList<GeoCoordinate> coordinates)
    {
        ValidateLine(coordinates);
        decimal total = 0;
        for (var index = 1; index < coordinates.Count; index++)
            total += SegmentDistance(coordinates[index - 1], coordinates[index]);
        return decimal.Round(total, 2);
    }

    public static RouteInterpolation Interpolate(IReadOnlyList<GeoCoordinate> coordinates, decimal distanceMeters)
    {
        ValidateLine(coordinates);
        var target = Math.Max(0, distanceMeters);
        decimal consumed = 0;
        for (var index = 1; index < coordinates.Count; index++)
        {
            var start = coordinates[index - 1];
            var end = coordinates[index];
            var segment = SegmentDistance(start, end);
            if (target <= consumed + segment || index == coordinates.Count - 1)
            {
                var ratio = segment <= 0 ? 0 : Math.Clamp((target - consumed) / segment, 0, 1);
                return new(
                    new GeoCoordinate(
                        start.Latitude + ((end.Latitude - start.Latitude) * ratio),
                        start.Longitude + ((end.Longitude - start.Longitude) * ratio)),
                    Heading(start, end),
                    index - 1);
            }
            consumed += segment;
        }
        return new(coordinates[^1], Heading(coordinates[^2], coordinates[^1]), coordinates.Count - 2);
    }

    public static RouteProjection Project(IReadOnlyList<GeoCoordinate> coordinates, GeoCoordinate point)
    {
        ValidateLine(coordinates);
        ValidateCoordinate(point);
        var originLatRadians = (double)point.Latitude * Math.PI / 180;
        decimal consumed = 0;
        RouteProjection? best = null;
        for (var index = 1; index < coordinates.Count; index++)
        {
            var start = coordinates[index - 1];
            var end = coordinates[index];
            var sx = LongitudeMeters(start.Longitude - point.Longitude, originLatRadians);
            var sy = LatitudeMeters(start.Latitude - point.Latitude);
            var ex = LongitudeMeters(end.Longitude - point.Longitude, originLatRadians);
            var ey = LatitudeMeters(end.Latitude - point.Latitude);
            var dx = ex - sx;
            var dy = ey - sy;
            var denominator = dx * dx + dy * dy;
            var ratio = denominator <= 0 ? 0 : Math.Clamp(-(sx * dx + sy * dy) / denominator, 0, 1);
            var px = sx + ratio * dx;
            var py = sy + ratio * dy;
            var fromRoute = (decimal)Math.Sqrt(px * px + py * py);
            var segment = SegmentDistance(start, end);
            var projection = new RouteProjection(
                consumed + segment * (decimal)ratio,
                fromRoute,
                index - 1,
                new GeoCoordinate(
                    start.Latitude + (end.Latitude - start.Latitude) * (decimal)ratio,
                    start.Longitude + (end.Longitude - start.Longitude) * (decimal)ratio));
            if (best is null || projection.DistanceFromRouteMeters < best.DistanceFromRouteMeters)
                best = projection;
            consumed += segment;
        }
        return best!;
    }

    public static decimal Heading(GeoCoordinate start, GeoCoordinate end)
    {
        var lat1 = (double)start.Latitude * Math.PI / 180;
        var lat2 = (double)end.Latitude * Math.PI / 180;
        var longitudeDelta = (double)(end.Longitude - start.Longitude) * Math.PI / 180;
        var y = Math.Sin(longitudeDelta) * Math.Cos(lat2);
        var x = Math.Cos(lat1) * Math.Sin(lat2) - Math.Sin(lat1) * Math.Cos(lat2) * Math.Cos(longitudeDelta);
        return decimal.Round((decimal)((Math.Atan2(y, x) * 180 / Math.PI + 360) % 360), 2);
    }

    private static void ValidateLine(IReadOnlyList<GeoCoordinate> coordinates)
    {
        if (coordinates.Count is < 2 or > MaxCoordinates)
            throw new DomainRuleException("A route must contain between 2 and 10000 points.", "INVALID_ROUTE_GEOMETRY");
        foreach (var coordinate in coordinates) ValidateCoordinate(coordinate);
    }

    private static decimal SegmentDistance(GeoCoordinate start, GeoCoordinate end)
    {
        var lat1 = (double)start.Latitude * Math.PI / 180;
        var lat2 = (double)end.Latitude * Math.PI / 180;
        var deltaLat = lat2 - lat1;
        var deltaLon = (double)(end.Longitude - start.Longitude) * Math.PI / 180;
        var value = Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2)
            + Math.Cos(lat1) * Math.Cos(lat2) * Math.Sin(deltaLon / 2) * Math.Sin(deltaLon / 2);
        return (decimal)(EarthRadiusMeters * 2 * Math.Atan2(Math.Sqrt(value), Math.Sqrt(1 - value)));
    }

    private static double LatitudeMeters(decimal latitudeDelta) =>
        (double)latitudeDelta * Math.PI / 180 * EarthRadiusMeters;

    private static double LongitudeMeters(decimal longitudeDelta, double latitudeRadians) =>
        (double)longitudeDelta * Math.PI / 180 * EarthRadiusMeters * Math.Cos(latitudeRadians);
}
