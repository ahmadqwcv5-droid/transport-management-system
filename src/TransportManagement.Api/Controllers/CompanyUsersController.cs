using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.CompanyUsers;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "owner")]
[Route("api/company-users")]
public sealed class CompanyUsersController(CompanyUserService service) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<CompanyUserResponse>> List([FromQuery] string? role,
        [FromQuery] bool? isActive, CancellationToken cancellationToken) =>
        service.ListAsync(role, isActive, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<CompanyUserResponse> Get(Guid id, CancellationToken cancellationToken) =>
        service.GetAsync(id, cancellationToken);

    [HttpPost("drivers")]
    public async Task<ActionResult<CompanyUserCredentialResponse>> CreateDriver(
        CreateDriverUserRequest request, CancellationToken cancellationToken)
    {
        var result = await service.CreateDriverAsync(request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { id = result.User.Id }, result);
    }

    [HttpPut("{id:guid}/active")]
    public Task<CompanyUserResponse> SetActive(Guid id, CompanyUserActiveRequest request,
        CancellationToken cancellationToken) => service.SetActiveAsync(id, request, cancellationToken);

    [HttpPost("{id:guid}/reset-temporary-password")]
    public Task<CompanyUserCredentialResponse> ResetPassword(Guid id,
        CancellationToken cancellationToken) => service.ResetPasswordAsync(id, cancellationToken);

    [HttpPut("{id:guid}/driver-link")]
    public Task<CompanyUserResponse> Link(Guid id, LinkCompanyUserRequest request,
        CancellationToken cancellationToken) => service.LinkAsync(id, request, cancellationToken);

    [HttpDelete("{id:guid}/driver-link")]
    public Task<CompanyUserResponse> Unlink(Guid id, CancellationToken cancellationToken) =>
        service.UnlinkAsync(id, cancellationToken);
}
