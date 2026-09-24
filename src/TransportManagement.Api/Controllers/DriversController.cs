using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Fleet;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/drivers")]
public sealed class DriversController(DriverService service) : ControllerBase
{
    [HttpGet]
    public async Task<IReadOnlyList<DriverResponse>> List(
        [FromQuery] DriverStatus? status, [FromQuery] bool? isActive,
        [FromQuery] string? search, CancellationToken cancellationToken) =>
        await service.ListAsync(status, isActive, search, cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<DriverResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await service.GetAsync(id, cancellationToken);

    [HttpPost]
    [Authorize(Policy = "operations.manage")]
    public async Task<ActionResult<DriverResponse>> Create(DriverRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateAsync(request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<DriverResponse> Update(Guid id, DriverRequest request, CancellationToken cancellationToken) =>
        await service.UpdateAsync(id, request, cancellationToken);

    [HttpPut("{id:guid}/status")]
    [Authorize(Policy = "operations.manage")]
    public async Task<DriverResponse> ChangeStatus(Guid id, DriverStatusRequest request, CancellationToken cancellationToken) =>
        await service.ChangeStatusAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/deactivate")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPut("{id:guid}/user-link")]
    [Authorize(Policy = "owner")]
    public Task<DriverResponse> LinkUser(Guid id, LinkDriverUserRequest request,
        CancellationToken cancellationToken) => service.LinkUserAsync(id, request, cancellationToken);

    [HttpDelete("{id:guid}/user-link")]
    [Authorize(Policy = "owner")]
    public Task<DriverResponse> UnlinkUser(Guid id, CancellationToken cancellationToken) =>
        service.UnlinkUserAsync(id, cancellationToken);
}
