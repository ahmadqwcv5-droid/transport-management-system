using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Fleet;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/trucks")]
public sealed class TrucksController(TruckService service) : ControllerBase
{
    [HttpGet]
    public async Task<IReadOnlyList<TruckResponse>> List(
        [FromQuery] TruckStatus? status, [FromQuery] bool? isActive,
        [FromQuery] string? search, CancellationToken cancellationToken) =>
        await service.ListAsync(status, isActive, search, cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<TruckResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await service.GetAsync(id, cancellationToken);

    [HttpPost]
    [Authorize(Policy = "operations.manage")]
    public async Task<ActionResult<TruckResponse>> Create(TruckRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateAsync(request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<TruckResponse> Update(Guid id, TruckRequest request, CancellationToken cancellationToken) =>
        await service.UpdateAsync(id, request, cancellationToken);

    [HttpPut("{id:guid}/status")]
    [Authorize(Policy = "operations.manage")]
    public async Task<TruckResponse> ChangeStatus(Guid id, TruckStatusRequest request, CancellationToken cancellationToken) =>
        await service.ChangeStatusAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/deactivate")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateAsync(id, cancellationToken);
        return NoContent();
    }
}
