using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Trips;
using TransportManagement.Application.Routing;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/trips")]
public sealed class TripsController(
    TripQueryService queries,
    TripDraftService drafts,
    TripRoutingService routing,
    TripAssignmentService assignments,
    TripDispatchService dispatch,
    TripLifecycleService lifecycle,
    RouteProgressService progressService) : ControllerBase
{
    [HttpGet]
    public async Task<TripPageResponse> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null,
        [FromQuery] string? operationalGroup = null,
        [FromQuery] TripStatus? status = null,
        [FromQuery] bool? archived = null,
        [FromQuery] Guid? clientId = null,
        [FromQuery] Guid? truckId = null,
        [FromQuery] Guid? driverId = null,
        [FromQuery] DateTimeOffset? plannedFrom = null,
        [FromQuery] DateTimeOffset? plannedTo = null,
        [FromQuery] string sort = "plannedStart",
        [FromQuery] string direction = "desc",
        CancellationToken cancellationToken = default) =>
        await queries.QueryAsync(new(page, pageSize, search, operationalGroup,
            status, archived, clientId, truckId, driverId, plannedFrom,
            plannedTo, sort, direction), cancellationToken);

    [HttpGet("{id:guid}")]
    public async Task<TripResponse> Get(Guid id, CancellationToken cancellationToken) =>
        await queries.GetAsync(id, cancellationToken);

    [HttpGet("{id:guid}/route-progress")]
    public Task<RouteProgressResponse> Progress(Guid id, CancellationToken cancellationToken) =>
        progressService.GetAsync(id, cancellationToken);

    [HttpPost]
    [Authorize(Policy = "operations.manage")]
    public async Task<ActionResult<TripResponse>> Create(TripRequest request, CancellationToken cancellationToken)
    {
        var result = await drafts.CreateAsync(request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "operations.manage")]
    public async Task<TripResponse> UpdateDraft(Guid id, TripRequest request, CancellationToken cancellationToken) =>
        await drafts.UpdateAsync(id, request, cancellationToken);

    [HttpPut("{id:guid}/stops")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> UpdateStops(Guid id, UpdateTripStopsRequest request,
        CancellationToken cancellationToken) =>
        drafts.UpdateStopsAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/calculate-route")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> CalculateRoute(Guid id, CalculateTripRouteRequest request,
        CancellationToken cancellationToken) =>
        routing.CalculateAsync(id, request, cancellationToken);

    [HttpGet("{id:guid}/assignment-options")]
    [Authorize(Policy = "operations.manage")]
    public Task<AssignmentOptionsResponse> AssignmentOptions(
        Guid id, CancellationToken cancellationToken) =>
        assignments.OptionsAsync(id, cancellationToken);

    [HttpGet("{id:guid}/timeline")]
    public Task<TripTimelineResponse> Timeline(Guid id, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50, CancellationToken cancellationToken = default) =>
        queries.TimelineAsync(id, page, pageSize, cancellationToken);

    [HttpPost("{id:guid}/assign")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Assign(Guid id, AssignTripRequest request, CancellationToken cancellationToken) =>
        assignments.AssignAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/reassign")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Reassign(Guid id, AssignTripRequest request,
        CancellationToken cancellationToken) =>
        assignments.ReassignAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/unassign")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Unassign(Guid id, CancellationToken cancellationToken) =>
        assignments.UnassignAsync(id, cancellationToken);

    [HttpDelete("{id:guid}/draft")]
    [Authorize(Policy = "operations.manage")]
    public async Task<IActionResult> DeleteDraft(Guid id, CancellationToken cancellationToken)
    {
        await drafts.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/duplicate")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Duplicate(Guid id, CancellationToken cancellationToken) =>
        drafts.DuplicateAsync(id, cancellationToken);

    [HttpPost("{id:guid}/repositioning/preview")]
    [Authorize(Policy = "operations.manage")]
    public Task<RepositioningPreviewResponse> PreviewRepositioning(
        Guid id, CancellationToken cancellationToken) =>
        routing.PreviewRepositioningAsync(id, cancellationToken);

    [HttpPost("{id:guid}/dispatch-to-pickup")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> DispatchToPickup(
        Guid id, ManagerDispatchToPickupRequest request, CancellationToken cancellationToken) =>
        dispatch.DispatchToPickupAsync(id, request.RepositioningPlanId,
            "ManagerOverride", request.Reason, cancellationToken);

    [HttpPost("{id:guid}/arrive-pickup")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> ArrivePickup(Guid id, CancellationToken cancellationToken) =>
        dispatch.ArrivePickupAsync(id, cancellationToken);

    [HttpGet("{id:guid}/repositioning-progress")]
    public Task<RepositioningProgressResponse> RepositioningProgress(
        Guid id, CancellationToken cancellationToken) =>
        dispatch.ProgressAsync(id, cancellationToken);

    [HttpPost("{id:guid}/start")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Start(Guid id, CancellationToken cancellationToken) =>
        dispatch.StartAsync(id, cancellationToken);

    [HttpPost("{id:guid}/mark-in-transit")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> MarkInTransit(Guid id, CancellationToken cancellationToken) =>
        lifecycle.MarkInTransitAsync(id, cancellationToken);

    [HttpPost("{id:guid}/deliver")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Deliver(Guid id, CancellationToken cancellationToken) =>
        lifecycle.DeliverAsync(id, cancellationToken);

    [HttpPost("{id:guid}/complete")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Complete(Guid id, CancellationToken cancellationToken) =>
        lifecycle.CompleteAsync(id, cancellationToken);

    [HttpPost("{id:guid}/override/confirm-loaded")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> OverrideConfirmLoaded(Guid id,
        ManagerOverrideRequest request, CancellationToken cancellationToken) =>
        lifecycle.ConfirmLoadedAsync(id, "ManagerOverride", request.Reason, cancellationToken);

    [HttpPost("{id:guid}/override/confirm-delivery")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> OverrideConfirmDelivery(Guid id,
        ManagerOverrideRequest request, CancellationToken cancellationToken) =>
        lifecycle.ConfirmDeliveryAsync(id, "ManagerOverride", request.Reason, cancellationToken);

    [HttpPost("{id:guid}/cancel")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Cancel(Guid id, CancelTripRequest request,
        CancellationToken cancellationToken) =>
        lifecycle.CancelAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/archive")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Archive(Guid id, CancellationToken cancellationToken) =>
        lifecycle.ArchiveAsync(id, cancellationToken);

    [HttpPost("{id:guid}/unarchive")]
    [Authorize(Policy = "operations.manage")]
    public Task<TripResponse> Unarchive(Guid id, CancellationToken cancellationToken) =>
        lifecycle.UnarchiveAsync(id, cancellationToken);
}
