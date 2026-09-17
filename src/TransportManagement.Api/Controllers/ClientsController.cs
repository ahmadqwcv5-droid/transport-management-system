using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Clients;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/clients")]
public sealed class ClientsController(ClientService service) : ControllerBase
{
    [HttpGet]
    public async Task<IReadOnlyList<ClientResponse>> List([FromQuery] bool? isActive, [FromQuery] string? search, CancellationToken cancellationToken) =>
        await service.ListAsync(isActive, search, cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<ClientResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await service.GetAsync(id, cancellationToken);

    [HttpPost]
    [Authorize(Policy = "operations.manage")]
    public async Task<ActionResult<ClientResponse>> Create(ClientRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateAsync(request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<ClientResponse> Update(Guid id, ClientRequest request, CancellationToken cancellationToken) =>
        await service.UpdateAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/deactivate")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateAsync(id, cancellationToken);
        return NoContent();
    }
}
