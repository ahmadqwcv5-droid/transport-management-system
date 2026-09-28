using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Memberships;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Route("api/membership-invitations")]
[Authorize(Policy = "operations.manage")]
public sealed class InvitationManagementController(MembershipService service) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<InvitationResponse>> List(CancellationToken cancellationToken) =>
        service.ListInvitationsAsync(cancellationToken);

    [HttpPost]
    public async Task<ActionResult<InvitationResponse>> Create(
        CreateInvitationRequest request, CancellationToken cancellationToken)
    {
        var invitation = await service.CreateInvitationAsync(request, cancellationToken);
        return Created($"/api/membership-invitations/{invitation.Id}", invitation);
    }

    [HttpPost("{id:guid}/revoke")]
    public async Task<IActionResult> Revoke(Guid id, CancellationToken cancellationToken)
    {
        await service.RevokeInvitationAsync(id, cancellationToken);
        return NoContent();
    }
}

[ApiController]
[Route("api/invitations")]
public sealed class InvitationsController(MembershipService service) : ControllerBase
{
    [AllowAnonymous]
    [EnableRateLimiting("identity-secrets")]
    [HttpGet("preview")]
    public Task<InvitationResponse> Preview(
        [FromQuery] string token, CancellationToken cancellationToken) =>
        service.PreviewInvitationAsync(token, cancellationToken);

    [AllowAnonymous]
    [EnableRateLimiting("identity-secrets")]
    [HttpPost("accept")]
    public Task<InvitationAcceptanceResponse> Accept(
        InvitationAcceptRequest request, CancellationToken cancellationToken) =>
        service.AcceptInvitationAsync(request, cancellationToken);

    [Authorize]
    [HttpPost("decline")]
    public async Task<IActionResult> Decline(
        InvitationDecisionRequest request, CancellationToken cancellationToken)
    {
        await service.DeclineInvitationAsync(request, cancellationToken);
        return NoContent();
    }
}

[ApiController]
[Route("api/company-connection-code")]
[Authorize(Policy = "operations.manage")]
public sealed class CompanyConnectionCodeController(MembershipService service) : ControllerBase
{
    [HttpGet]
    public Task<CompanyCodeResponse> Get(CancellationToken cancellationToken) =>
        service.GetCompanyCodeAsync(cancellationToken);

    [HttpPost("rotate")]
    public Task<CompanyCodeResponse> Rotate(CancellationToken cancellationToken) =>
        service.RotateCompanyCodeAsync(cancellationToken);
}

[ApiController]
[Route("api/company-connections")]
public sealed class CompanyConnectionsController(MembershipService service) : ControllerBase
{
    [Authorize]
    [EnableRateLimiting("identity-secrets")]
    [HttpPost("resolve")]
    public Task<CompanyCodeSummaryResponse> Resolve(
        ResolveCompanyCodeRequest request, CancellationToken cancellationToken) =>
        service.ResolveCompanyCodeAsync(request, cancellationToken);

    [Authorize]
    [EnableRateLimiting("identity-secrets")]
    [HttpPost]
    public async Task<ActionResult<ConnectionRequestResponse>> Create(
        CreateConnectionRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateConnectionRequestAsync(request, cancellationToken);
        return Created($"/api/company-connections/{result.Id}", result);
    }

    [Authorize]
    [HttpGet("mine")]
    public Task<IReadOnlyList<ConnectionRequestResponse>> Mine(
        CancellationToken cancellationToken) =>
        service.ListOwnConnectionsAsync(cancellationToken);

    [Authorize(Policy = "operations.manage")]
    [HttpGet("pending")]
    public Task<IReadOnlyList<ConnectionRequestResponse>> Pending(
        CancellationToken cancellationToken) =>
        service.ListCompanyConnectionsAsync(cancellationToken);

    [Authorize(Policy = "operations.manage")]
    [HttpPost("{id:guid}/approve")]
    public Task<ConnectionRequestResponse> Approve(Guid id,
        ResolveConnectionRequest request, CancellationToken cancellationToken) =>
        service.ApproveConnectionAsync(id, request, cancellationToken);

    [Authorize(Policy = "operations.manage")]
    [HttpPost("{id:guid}/reject")]
    public Task<ConnectionRequestResponse> Reject(Guid id,
        ResolveConnectionRequest request, CancellationToken cancellationToken) =>
        service.RejectConnectionAsync(id, request, cancellationToken);

    [Authorize]
    [HttpPost("{id:guid}/cancel")]
    public Task<ConnectionRequestResponse> Cancel(
        Guid id, CancellationToken cancellationToken) =>
        service.CancelConnectionAsync(id, cancellationToken);
}

[ApiController]
[Route("api/memberships")]
[Authorize(Policy = "owner")]
public sealed class MembershipsController(MembershipService service) : ControllerBase
{
    [HttpPut("{id:guid}/status")]
    public Task<WorkspaceResponse> SetStatus(Guid id,
        MembershipStatusRequest request, CancellationToken cancellationToken) =>
        service.SetMembershipStatusAsync(id, request, cancellationToken);
}
