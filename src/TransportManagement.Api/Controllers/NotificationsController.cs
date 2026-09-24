using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Notifications;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "notifications.read")]
[Route("api/notifications")]
public sealed class NotificationsController(NotificationService service) : ControllerBase
{
    [HttpGet]
    public Task<NotificationPageResponse> List([FromQuery] int page = 1,
        [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default) =>
        service.ListAsync(page, pageSize, cancellationToken);

    [HttpGet("unread-count")]
    public Task<UnreadNotificationCountResponse> Unread(CancellationToken cancellationToken) =>
        service.UnreadAsync(cancellationToken);

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken)
    {
        await service.MarkReadAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        await service.MarkAllReadAsync(cancellationToken);
        return NoContent();
    }
}
