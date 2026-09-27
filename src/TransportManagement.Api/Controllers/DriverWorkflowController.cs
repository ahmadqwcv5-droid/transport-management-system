using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Drivers;
using TransportManagement.Application.Trips;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "driver.workflow")]
[Route("api/driver/my-trip")]
public sealed class DriverWorkflowController(DriverWorkflowService service,
    ILogger<DriverWorkflowController> logger) : ControllerBase
{
    private static readonly Action<ILogger, Exception?> LogAmbiguousVehicle =
        LoggerMessage.Define(LogLevel.Warning, new EventId(4222, "DriverVehicleAmbiguous"),
            "Driver workspace detected multiple active default-linked trucks; " +
            "Owner action is required.");

    [HttpGet]
    public Task<DriverMyTripResponse> Get(CancellationToken cancellationToken) =>
        service.MyTripAsync(cancellationToken);

    [HttpGet("workspace")]
    public async Task<DriverWorkspaceResponse> Workspace(CancellationToken cancellationToken)
    {
        var result = await service.WorkspaceAsync(cancellationToken);
        if (result.State == "VEHICLE_ASSIGNMENT_AMBIGUOUS")
        {
            LogAmbiguousVehicle(logger, null);
        }
        return result;
    }

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

    [HttpPost("depart-to-pickup")]
    public Task<TripResponse> DepartToPickup(CancellationToken cancellationToken) =>
        service.DepartToPickupAsync(cancellationToken);

    [HttpPost("confirm-delivery")]
    public Task<TripResponse> ConfirmDelivery(CancellationToken cancellationToken) =>
        service.ConfirmDeliveryAsync(cancellationToken);

    [HttpPost("end-vehicle-session")]
    public async Task<IActionResult> EndVehicleSession(CancellationToken cancellationToken)
    {
        await service.EndVehicleSessionAsync(cancellationToken);
        return NoContent();
    }
}
