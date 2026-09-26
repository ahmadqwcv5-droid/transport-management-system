using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Dashboard;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/dashboard")]
public sealed class DashboardController(
    DashboardService service,
    ActiveOperationsService activeOperations) : ControllerBase
{
    [HttpGet]
    public Task<DashboardResponse> Get(CancellationToken cancellationToken) =>
        service.GetAsync(cancellationToken);

    [HttpGet("active-trips")]
    public Task<ActiveOperationsResponse> ActiveTrips(
        [FromQuery] int limit = 100, [FromQuery] string? search = null,
        [FromQuery] Guid? clientId = null, [FromQuery] Guid? truckId = null,
        [FromQuery] Guid? driverId = null, [FromQuery] string? phase = null,
        [FromQuery] bool attentionOnly = false, CancellationToken cancellationToken = default) =>
        activeOperations.QueryAsync(new(limit, search, clientId, truckId, driverId, phase, attentionOnly), cancellationToken);
}
