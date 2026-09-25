using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Auth;

internal sealed class CurrentUser(IHttpContextAccessor accessor,
    ICompanyExecutionContext executionContext) : ICurrentUser
{
    private ClaimsPrincipal? Principal => accessor.HttpContext?.User;
    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;
    public Guid UserId => ReadGuid(CustomClaims.UserId);
    public Guid CompanyId
    {
        get
        {
            var claimed = ReadGuid(CustomClaims.CompanyId);
            return claimed != Guid.Empty ? claimed : executionContext.CompanyId ?? Guid.Empty;
        }
    }
    public string Role => Principal?.FindFirstValue(ClaimTypes.Role) ?? string.Empty;

    private Guid ReadGuid(string claim) =>
        Guid.TryParse(Principal?.FindFirstValue(claim), out var value) ? value : Guid.Empty;
}
