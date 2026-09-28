namespace TransportManagement.Application.Abstractions;

public interface ICurrentUser
{
    bool IsAuthenticated { get; }
    Guid UserId { get; }
    Guid MembershipId { get; }
    Guid CompanyId { get; }
    string Role { get; }
    bool IsInRole(string role);
}
