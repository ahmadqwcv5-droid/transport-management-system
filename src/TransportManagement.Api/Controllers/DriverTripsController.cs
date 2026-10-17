using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Drivers;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "driver.workflow")]
[Route("api/driver/trips")]
public sealed class DriverTripsController(DriverTripHistoryService service)
    : ControllerBase
{
    [HttpGet]
    public Task<DriverTripHistoryPage> Query(
        [FromQuery] DriverTripHistoryQuery query,
        CancellationToken cancellationToken) =>
        service.QueryAsync(query, cancellationToken);

    [HttpGet("{tripId:guid}")]
    public Task<DriverTripHistoryDetail> Detail(
        Guid tripId, CancellationToken cancellationToken) =>
        service.DetailAsync(tripId, cancellationToken);
}
