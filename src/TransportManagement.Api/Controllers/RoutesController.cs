using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Routing;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.manage")]
[Route("api/routes")]
public sealed class RoutesController(RoutePlanningService service) : ControllerBase
{
    [HttpPost("preview")]
    public Task<RouteResultResponse> Preview(
        RoutePreviewRequest request, CancellationToken cancellationToken) =>
        service.PreviewAsync(request, cancellationToken);
}
