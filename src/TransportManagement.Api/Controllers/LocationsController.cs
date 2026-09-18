using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TransportManagement.Application.Routing;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[EnableRateLimiting("geocoding")]
[Route("api/locations")]
public sealed class LocationsController(LocationService service) : ControllerBase
{
    [HttpGet("search")]
    public Task<IReadOnlyList<LocationSearchResponse>> Search(
        [FromQuery] string query, CancellationToken cancellationToken) =>
        service.SearchAsync(query, cancellationToken);

    [HttpGet("reverse")]
    public Task<LocationSearchResponse> Reverse(
        [FromQuery] decimal latitude,
        [FromQuery] decimal longitude,
        CancellationToken cancellationToken) =>
        service.ReverseAsync(latitude, longitude, cancellationToken);
}
