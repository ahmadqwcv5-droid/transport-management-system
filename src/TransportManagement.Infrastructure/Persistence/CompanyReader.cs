using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Companies;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class CompanyReader(AppDbContext dbContext, ICurrentUser currentUser) : ICompanyReader
{
    public Task<Company?> GetCurrentAsync(CancellationToken cancellationToken) =>
        dbContext.Companies.SingleOrDefaultAsync(x => x.Id == currentUser.CompanyId, cancellationToken);

    public Task<Company?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Companies.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);
}
