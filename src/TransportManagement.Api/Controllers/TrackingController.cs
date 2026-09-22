using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Tracking;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.read")]
[Route("api/tracking")]
public sealed class TrackingController(TrackingService service) : ControllerBase
{
    [HttpGet("positions")]
    public Task<IReadOnlyList<TruckPositionResponse>> Positions(CancellationToken cancellationToken) =>
        service.CurrentAsync(cancellationToken);

    [HttpGet("trucks/{truckId:guid}/position")]
    public Task<TruckPositionResponse> Position(Guid truckId, CancellationToken cancellationToken) =>
        service.CurrentForTruckAsync(truckId, cancellationToken);

    [HttpGet("trucks/{truckId:guid}/history")]
    public Task<IReadOnlyList<TruckPositionResponse>> History(
        Guid truckId, [FromQuery] int limit = 50, CancellationToken cancellationToken = default) =>
        service.HistoryAsync(truckId, limit, cancellationToken);

    [HttpGet("trips/{tripId:guid}/history")]
    public Task<TripTrackingHistoryResponse> TripHistory(
        Guid tripId, [FromQuery] int limit = 500,
        CancellationToken cancellationToken = default) =>
        service.TripHistoryAsync(tripId, limit, cancellationToken);

    [HttpPost("simulator/control")]
    [Authorize(Roles = "Owner")]
    public Task<SimulatorStateResponse> Control(
        SimulatorControlRequest request, CancellationToken cancellationToken) =>
        service.ControlAsync(request, cancellationToken);

    [HttpGet("simulator/trucks")]
    [Authorize(Roles = "Owner")]
    public Task<IReadOnlyList<SimulatorTruckResponse>> SimulatorTrucks(
        CancellationToken cancellationToken) =>
        service.SimulatorInventoryAsync(true, cancellationToken);
}
