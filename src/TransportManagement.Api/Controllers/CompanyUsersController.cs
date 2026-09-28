using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.CompanyUsers;
using TransportManagement.Application.Memberships;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "operations.manage")]
[Route("api/company-users")]
public sealed class CompanyUsersController(
    CompanyUserService service, MembershipService memberships) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<CompanyUserResponse>> List([FromQuery] string? role,
        [FromQuery] bool? isActive, CancellationToken cancellationToken) =>
        service.ListAsync(role, isActive, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<CompanyUserResponse> Get(Guid id, CancellationToken cancellationToken) =>
        service.GetAsync(id, cancellationToken);

    [HttpPost("drivers")]
    public async Task<ActionResult<InvitationResponse>> CreateDriver(
        CreateDriverUserRequest request, CancellationToken cancellationToken)
    {
        var result = await memberships.CreateInvitationAsync(
            new(request.Email, [Domain.Identity.AppRoles.Driver],
                request.DriverId, DisplayName: request.DisplayName), cancellationToken);
        return Created($"/api/membership-invitations/{result.Id}", result);
    }

    [HttpPut("{id:guid}/active")]
    public Task<CompanyUserResponse> SetActive(Guid id, CompanyUserActiveRequest request,
        CancellationToken cancellationToken) => service.SetActiveAsync(id, request, cancellationToken);

    [HttpPut("{id:guid}/driver-link")]
    public Task<CompanyUserResponse> Link(Guid id, LinkCompanyUserRequest request,
        CancellationToken cancellationToken) => service.LinkAsync(id, request, cancellationToken);

    [HttpDelete("{id:guid}/driver-link")]
    public Task<CompanyUserResponse> Unlink(Guid id, CancellationToken cancellationToken) =>
        service.UnlinkAsync(id, cancellationToken);
}
