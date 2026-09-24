using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Fleet;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/trucks")]
public sealed class TrucksController(TruckService service, TruckPhotoService photos) : ControllerBase
{
    [HttpGet]
    public async Task<IReadOnlyList<TruckResponse>> List(
        [FromQuery] TruckStatus? status, [FromQuery] bool? isActive,
        [FromQuery] string? search, [FromQuery] TruckType? type,
        [FromQuery] string? operationalState, CancellationToken cancellationToken) =>
        await service.ListAsync(status, isActive, search, type, operationalState, cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<TruckResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await service.GetAsync(id, cancellationToken);

    [HttpGet("{id:guid}/details")]
    public Task<TruckDetailsResponse> Details(Guid id, CancellationToken cancellationToken) =>
        service.DetailsAsync(id, cancellationToken);

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

    [HttpPut("{id:guid}/odometer-correction")]
    [Authorize(Policy = "operations.manage")]
    public Task<TruckResponse> CorrectOdometer(Guid id, OdometerCorrectionRequest request,
        CancellationToken cancellationToken) => service.CorrectOdometerAsync(id, request, cancellationToken);

    [HttpDelete("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await service.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/photo")]
    [Authorize(Policy = "operations.manage")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<TruckPhotoResponse> UploadPhoto(Guid id, IFormFile file,
        CancellationToken cancellationToken)
    {
        await using var stream = file.OpenReadStream();
        return await photos.UploadAsync(id, stream, cancellationToken);
    }

    [HttpGet("{id:guid}/photo")]
    public async Task<IActionResult> Photo(Guid id, CancellationToken cancellationToken)
    {
        var photo = await photos.ReadAsync(id, false, cancellationToken);
        Response.Headers.ETag = $"\"{photo.Version}\"";
        Response.Headers.CacheControl = "private,max-age=86400";
        return File(photo.Content, photo.ContentType);
    }

    [HttpGet("{id:guid}/photo/thumbnail")]
    public async Task<IActionResult> Thumbnail(Guid id, CancellationToken cancellationToken)
    {
        var photo = await photos.ReadAsync(id, true, cancellationToken);
        Response.Headers.ETag = $"\"{photo.Version}\"";
        Response.Headers.CacheControl = "private,max-age=86400";
        return File(photo.Content, photo.ContentType);
    }

    [HttpDelete("{id:guid}/photo")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> RemovePhoto(Guid id, CancellationToken cancellationToken)
    {
        await photos.RemoveAsync(id, cancellationToken);
        return NoContent();
    }
}
