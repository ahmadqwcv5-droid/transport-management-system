using System.ComponentModel.DataAnnotations;

namespace TransportManagement.Application.Memberships;

public sealed record CreateInvitationRequest(
    [param: Required, EmailAddress, MaxLength(320)] string Email,
    [param: Required, MinLength(1)] IReadOnlyList<string> Roles,
    Guid? DriverId = null,
    [param: Range(1, 30)] int ExpiresInDays = 7,
    [param: MaxLength(200)] string? DisplayName = null);

public sealed record InvitationResponse(
    Guid Id, string Email, IReadOnlyList<string> Roles, Guid? DriverId,
    string? DriverName, string Status, DateTimeOffset ExpiresAt,
    string? AcceptancePath = null);

public sealed record InvitationAcceptRequest(
    [param: Required] string Token,
    [param: EmailAddress, MaxLength(320)] string? Email = null,
    [param: MaxLength(200)] string? DisplayName = null,
    [param: MinLength(12), MaxLength(200)] string? Password = null);

public sealed record InvitationDecisionRequest([param: Required] string Token);

public sealed record InvitationAcceptanceResponse(
    Guid AccountId, Guid MembershipId, Guid CompanyId, string CompanyName,
    IReadOnlyList<string> Roles, bool AccountCreated);

public sealed record CompanyCodeResponse(
    string Code, string Hint, int Version);

public sealed record ResolveCompanyCodeRequest([param: Required] string Code);
public sealed record CompanyCodeSummaryResponse(string CompanyName, string CodeHint);

public sealed record CreateConnectionRequest([param: Required] string Code);
public sealed record ResolveConnectionRequest(Guid? DriverId, string? Reason = null);

public sealed record ConnectionRequestResponse(
    Guid Id, Guid CompanyId, string CompanyName, Guid AccountId,
    string AccountEmail, string AccountName, IReadOnlyList<string> RequestedRoles,
    string Status, Guid? DriverId, string? ResolutionReason,
    DateTimeOffset CreatedAt, DateTimeOffset? ResolvedAt);

public sealed record MembershipStatusRequest(
    [param: Required, RegularExpression("^(Active|Suspended|Revoked)$")] string Status);
