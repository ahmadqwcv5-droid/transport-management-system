using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface IMembershipWorkflowStore
{
    Task<IReadOnlyList<CompanyInvitation>> ListInvitationsAsync(
        CancellationToken cancellationToken);
    Task<CompanyInvitation?> FindInvitationByHashAsync(
        string tokenHash, CancellationToken cancellationToken);
    Task<CompanyInvitation?> FindInvitationAsync(
        Guid invitationId, CancellationToken cancellationToken);
    Task<Company?> FindCompanyByCodeHashAsync(
        string codeHash, CancellationToken cancellationToken);
    Task<IReadOnlyList<CompanyConnectionRequest>> ListCompanyRequestsAsync(
        CancellationToken cancellationToken);
    Task<IReadOnlyList<CompanyConnectionRequest>> ListAccountRequestsAsync(
        Guid accountId, CancellationToken cancellationToken);
    Task<CompanyConnectionRequest?> FindCompanyRequestAsync(
        Guid requestId, CancellationToken cancellationToken);
    Task<CompanyConnectionRequest?> FindAccountRequestAsync(
        Guid requestId, Guid accountId, CancellationToken cancellationToken);
    Task<CompanyMembership?> FindMembershipAsync(
        Guid companyId, Guid accountId, CancellationToken cancellationToken);
    Task<CompanyMembership?> FindCompanyMembershipAsync(
        Guid membershipId, CancellationToken cancellationToken);
    Task<Driver?> FindDriverAsync(Guid driverId, Guid companyId, CancellationToken cancellationToken);
    void AddInvitation(CompanyInvitation invitation);
    void AddConnectionRequest(CompanyConnectionRequest request);
    void AddNotification(OperationNotification notification);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}

public interface ICompanyCodeService
{
    string Generate(Guid companyId, int version);
    string Hash(string code);
}
