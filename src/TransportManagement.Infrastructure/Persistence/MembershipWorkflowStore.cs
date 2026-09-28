using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class MembershipWorkflowStore(AppDbContext dbContext)
    : IMembershipWorkflowStore
{
    public async Task<IReadOnlyList<CompanyInvitation>> ListInvitationsAsync(
        CancellationToken cancellationToken) => await dbContext.CompanyInvitations
        .AsNoTracking().OrderByDescending(x => x.CreatedAt).ToListAsync(cancellationToken);

    public Task<CompanyInvitation?> FindInvitationByHashAsync(
        string tokenHash, CancellationToken cancellationToken) =>
        dbContext.CompanyInvitations.IgnoreQueryFilters().SingleOrDefaultAsync(
            x => x.TokenHash == tokenHash, cancellationToken);

    public Task<CompanyInvitation?> FindInvitationAsync(
        Guid invitationId, CancellationToken cancellationToken) =>
        dbContext.CompanyInvitations.SingleOrDefaultAsync(
            x => x.Id == invitationId, cancellationToken);

    public Task<Company?> FindCompanyByCodeHashAsync(
        string codeHash, CancellationToken cancellationToken) =>
        dbContext.Companies.IgnoreQueryFilters().AsNoTracking().SingleOrDefaultAsync(
            x => x.ConnectionCodeHash == codeHash && x.IsActive, cancellationToken);

    public async Task<IReadOnlyList<CompanyConnectionRequest>> ListCompanyRequestsAsync(
        CancellationToken cancellationToken) => await dbContext.CompanyConnectionRequests
        .AsNoTracking().OrderByDescending(x => x.CreatedAt).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<CompanyConnectionRequest>> ListAccountRequestsAsync(
        Guid accountId, CancellationToken cancellationToken) =>
        await dbContext.CompanyConnectionRequests.IgnoreQueryFilters().AsNoTracking()
            .Where(x => x.AccountId == accountId)
            .OrderByDescending(x => x.CreatedAt).ToListAsync(cancellationToken);

    public Task<CompanyConnectionRequest?> FindCompanyRequestAsync(
        Guid requestId, CancellationToken cancellationToken) =>
        dbContext.CompanyConnectionRequests.SingleOrDefaultAsync(
            x => x.Id == requestId, cancellationToken);

    public Task<CompanyConnectionRequest?> FindAccountRequestAsync(
        Guid requestId, Guid accountId, CancellationToken cancellationToken) =>
        dbContext.CompanyConnectionRequests.IgnoreQueryFilters().SingleOrDefaultAsync(
            x => x.Id == requestId && x.AccountId == accountId, cancellationToken);

    public Task<CompanyMembership?> FindMembershipAsync(
        Guid companyId, Guid accountId, CancellationToken cancellationToken) =>
        dbContext.CompanyMemberships.IgnoreQueryFilters().SingleOrDefaultAsync(
            x => x.CompanyId == companyId && x.AccountId == accountId, cancellationToken);

    public Task<CompanyMembership?> FindCompanyMembershipAsync(
        Guid membershipId, CancellationToken cancellationToken) =>
        dbContext.CompanyMemberships.SingleOrDefaultAsync(
            x => x.Id == membershipId, cancellationToken);

    public Task<Driver?> FindDriverAsync(Guid driverId, Guid companyId,
        CancellationToken cancellationToken) => dbContext.Drivers.IgnoreQueryFilters()
        .SingleOrDefaultAsync(x => x.Id == driverId && x.CompanyId == companyId,
            cancellationToken);

    public void AddInvitation(CompanyInvitation invitation) =>
        dbContext.CompanyInvitations.Add(invitation);

    public void AddConnectionRequest(CompanyConnectionRequest request) =>
        dbContext.CompanyConnectionRequests.Add(request);

    public void AddNotification(OperationNotification notification) =>
        dbContext.OperationNotifications.Add(notification);

    public Task SaveChangesAsync(CancellationToken cancellationToken) =>
        dbContext.SaveChangesAsync(cancellationToken);
}
