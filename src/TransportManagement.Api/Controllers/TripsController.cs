using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Trips;
using TransportManagement.Application.Routing;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/trips")]
public sealed class TripsController(TripService service, RouteProgressService progressService) : ControllerBase
{
    [HttpGet]
    public async Task<IReadOnlyList<TripResponse>> List(
        [FromQuery] TripStatus? status,
        [FromQuery] Guid? clientId,
        [FromQuery] Guid? truckId,
        [FromQuery] Guid? driverId,
        [FromQuery] DateTimeOffset? plannedFrom,
        [FromQuery] DateTimeOffset? plannedTo,
        CancellationToken cancellationToken) =>
        await service.ListAsync(status, clientId, truckId, driverId, plannedFrom, plannedTo, cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<TripResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await service.GetAsync(id, cancellationToken);

    [HttpGet("{id:guid}/route-progress")]
    public Task<RouteProgressResponse> Progress(Guid id, CancellationToken cancellationToken) =>
        progressService.GetAsync(id, cancellationToken);

    [HttpPost]
    [Authorize(Policy = "operations.manage")]
    public async Task<ActionResult<TripResponse>> Create(TripRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateAsync(request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<TripResponse> UpdateDraft(Guid id, TripRequest request, CancellationToken cancellationToken) =>
        await service.UpdateDraftAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/assign")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Assign(Guid id, AssignTripRequest request, CancellationToken cancellationToken) =>
        service.AssignAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/repositioning/preview")]
    [Authorize(Policy = "operations.manage")]
    public Task<RepositioningPreviewResponse> PreviewRepositioning(
        Guid id, CancellationToken cancellationToken) =>
        service.PreviewRepositioningAsync(id, cancellationToken);

    [HttpPost("{id:guid}/dispatch-to-pickup")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> DispatchToPickup(
        Guid id, DispatchToPickupRequest request, CancellationToken cancellationToken) =>
        service.DispatchToPickupAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/arrive-pickup")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> ArrivePickup(Guid id, CancellationToken cancellationToken) =>
        service.ArrivePickupAsync(id, cancellationToken);

    [HttpGet("{id:guid}/repositioning-progress")]
    public Task<RepositioningProgressResponse> RepositioningProgress(
        Guid id, CancellationToken cancellationToken) =>
        service.RepositioningProgressAsync(id, cancellationToken);

    [HttpPost("{id:guid}/start")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Start(Guid id, CancellationToken cancellationToken) =>
        service.StartAsync(id, cancellationToken);

    [HttpPost("{id:guid}/mark-in-transit")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> MarkInTransit(Guid id, CancellationToken cancellationToken) =>
        service.MarkInTransitAsync(id, cancellationToken);

    [HttpPost("{id:guid}/deliver")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Deliver(Guid id, CancellationToken cancellationToken) =>
        service.DeliverAsync(id, cancellationToken);

    [HttpPost("{id:guid}/complete")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Complete(Guid id, CancellationToken cancellationToken) =>
        service.CompleteAsync(id, cancellationToken);

    [HttpPost("{id:guid}/cancel")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Cancel(Guid id, CancellationToken cancellationToken) =>
        service.CancelAsync(id, cancellationToken);
}
