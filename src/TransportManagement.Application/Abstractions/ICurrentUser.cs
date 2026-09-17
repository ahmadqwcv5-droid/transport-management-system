namespace TransportManagement.Application.Abstractions;

public interface ICurrentUser
{
    bool IsAuthenticated { get; }
    Guid UserId { get; }
    Guid CompanyId { get; }
    string Role { get; }
}
