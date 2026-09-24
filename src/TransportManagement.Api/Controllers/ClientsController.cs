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
    public async Task<IReadOnlyList<ClientResponse>> List([FromQuery] bool? isActive,
        [FromQuery] string? search, [FromQuery] TransportManagement.Domain.Clients.ClientLifecycleStatus? lifecycle,
        CancellationToken cancellationToken) =>
        await service.ListAsync(isActive, search, lifecycle, cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<ClientResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await service.GetAsync(id, cancellationToken);

    [HttpGet("{id:guid}/details")]
    public Task<ClientDetailsResponse> Details(Guid id, CancellationToken cancellationToken) =>
        service.DetailsAsync(id, cancellationToken);

    [HttpGet("{id:guid}/sites")]
    public Task<IReadOnlyList<ClientSiteResponse>> Sites(Guid id, [FromQuery] bool? isActive,
        [FromQuery] string? search, CancellationToken cancellationToken) =>
        service.SitesAsync(id, isActive, search, cancellationToken);

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

    [HttpPut("{id:guid}/lifecycle")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientResponse> ChangeLifecycle(Guid id, ClientLifecycleRequest request,
        CancellationToken cancellationToken) => service.ChangeLifecycleAsync(id, request, cancellationToken);

    [HttpDelete("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await service.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/contacts")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientContactResponse> AddContact(Guid id, ClientContactRequest request,
        CancellationToken cancellationToken) => service.AddContactAsync(id, request, cancellationToken);

    [HttpPut("{id:guid}/contacts/{contactId:guid}")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientContactResponse> UpdateContact(Guid id, Guid contactId,
        ClientContactRequest request, CancellationToken cancellationToken) =>
        service.UpdateContactAsync(id, contactId, request, cancellationToken);

    [HttpDelete("{id:guid}/contacts/{contactId:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> DeleteContact(Guid id, Guid contactId,
        CancellationToken cancellationToken)
    {
        await service.DeleteContactAsync(id, contactId, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/sites")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientSiteResponse> AddSite(Guid id, ClientSiteRequest request,
        CancellationToken cancellationToken) => service.AddSiteAsync(id, request, cancellationToken);

    [HttpPut("{id:guid}/sites/{siteId:guid}")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientSiteResponse> UpdateSite(Guid id, Guid siteId, ClientSiteRequest request,
        CancellationToken cancellationToken) => service.UpdateSiteAsync(id, siteId, request, cancellationToken);

    [HttpPost("{id:guid}/sites/{siteId:guid}/archive")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientSiteResponse> ArchiveSite(Guid id, Guid siteId,
        CancellationToken cancellationToken) => service.SetSiteActiveAsync(id, siteId, false, cancellationToken);

    [HttpPost("{id:guid}/sites/{siteId:guid}/restore")]
    [Authorize(Policy = "operations.manage")]
    public Task<ClientSiteResponse> RestoreSite(Guid id, Guid siteId,
        CancellationToken cancellationToken) => service.SetSiteActiveAsync(id, siteId, true, cancellationToken);
}
