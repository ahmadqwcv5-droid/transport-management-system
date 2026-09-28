using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Fleet;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Route("api/trucks/{truckId:guid}/qr")]
[Authorize(Policy = "operations.manage")]
public sealed class TruckQrController(QrHandoverService service) : ControllerBase
{
    [HttpGet]
    public Task<TruckQrStatusResponse> Status(
        Guid truckId, CancellationToken cancellationToken) =>
        service.GetQrStatusAsync(truckId, cancellationToken);

    [HttpPost("regenerate")]
    public Task<TruckQrCredentialResponse> Regenerate(
        Guid truckId, CancellationToken cancellationToken) =>
        service.GenerateQrAsync(truckId, cancellationToken);
}

[ApiController]
[Route("api/driver/truck-qr")]
[Authorize(Policy = "driver.workflow")]
public sealed class DriverTruckQrController(QrHandoverService service) : ControllerBase
{
    [HttpPost("preview")]
    public Task<TruckQrPreviewResponse> Preview(
        ResolveTruckQrRequest request, CancellationToken cancellationToken) =>
        service.PreviewAsync(request, cancellationToken);

    [HttpPost("confirm")]
    public Task<TruckSwitchResponse> Confirm(
        ConfirmTruckQrRequest request, CancellationToken cancellationToken) =>
        service.ConfirmAsync(request, cancellationToken);
}

[ApiController]
[Route("api/handovers")]
[Authorize(Policy = "operations.manage")]
public sealed class HandoversController(QrHandoverService service) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<HandoverResponse>> List(
        CancellationToken cancellationToken) =>
        service.ListAsync(cancellationToken);

    [HttpPost]
    public async Task<ActionResult<HandoverResponse>> Create(
        CreateHandoverRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateManagerHandoverAsync(request, cancellationToken);
        return Created($"/api/handovers/{result.Id}", result);
    }

    [HttpPost("{id:guid}/approve")]
    public Task<HandoverResponse> Approve(Guid id,
        ResolveHandoverRequest request, CancellationToken cancellationToken) =>
        service.ApproveAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/reject")]
    public Task<HandoverResponse> Reject(Guid id,
        ResolveHandoverRequest request, CancellationToken cancellationToken) =>
        service.RejectAsync(id, request, cancellationToken);
}
