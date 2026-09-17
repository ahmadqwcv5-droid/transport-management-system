using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Companies;

namespace TransportManagement.Api.Controllers;

[ApiController]
[Authorize(Policy = "companies.read")]
[Route("api/companies")]
public sealed class CompaniesController(CompanyService companyService) : ControllerBase
{
    [HttpGet("me")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> Me(CancellationToken cancellationToken)
    {
        var result = await companyService.GetCurrentAsync(cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    // This ID-based route intentionally remains tenant-filtered. It allows the isolation
    // contract to be integration-tested against an attempted cross-company ID lookup.
    [HttpGet("{id:guid}")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CompanyResponse>> ById(Guid id, CancellationToken cancellationToken)
    {
        var result = await companyService.GetByIdAsync(id, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }
}
