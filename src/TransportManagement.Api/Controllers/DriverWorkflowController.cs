using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Drivers;
using TransportManagement.Application.Trips;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "driver.workflow")]
[Route("api/driver/my-trip")]
public sealed class DriverWorkflowController(DriverWorkflowService service) : ControllerBase
{
    [HttpGet]
    public Task<DriverMyTripResponse> Get(CancellationToken cancellationToken) =>
        service.MyTripAsync(cancellationToken);

    [HttpGet("workspace")]
    public Task<DriverWorkspaceResponse> Workspace(CancellationToken cancellationToken) =>
        service.WorkspaceAsync(cancellationToken);

    [HttpGet("truck-photo/thumbnail")]
    public async Task<IActionResult> TruckPhoto(CancellationToken cancellationToken)
    {
        var photo = await service.TruckPhotoAsync(cancellationToken);
        Response.Headers.ETag = $"\"{photo.Version}\"";
        Response.Headers.CacheControl = "private,max-age=86400";
        return File(photo.Content, photo.ContentType);
    }

    [HttpPost("confirm-loaded")]
    public Task<TripResponse> ConfirmLoaded(CancellationToken cancellationToken) =>
        service.ConfirmLoadedAsync(cancellationToken);

    [HttpPost("confirm-delivery")]
    public Task<TripResponse> ConfirmDelivery(CancellationToken cancellationToken) =>
        service.ConfirmDeliveryAsync(cancellationToken);
}
