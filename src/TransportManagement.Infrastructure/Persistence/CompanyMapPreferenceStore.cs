using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Companies;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class CompanyMapPreferenceStore(
    AppDbContext dbContext, ICurrentUser currentUser) : ICompanyMapPreferenceStore
{
    public Task<CompanyMapPreference?> GetAsync(CancellationToken cancellationToken) =>
        dbContext.CompanyMapPreferences.SingleOrDefaultAsync(
            x => x.CompanyId == currentUser.CompanyId, cancellationToken);

    public void Add(CompanyMapPreference preference)
    {
        if (preference.CompanyId != currentUser.CompanyId)
            throw new InvalidOperationException("Cannot add another tenant's map preference.");
        dbContext.CompanyMapPreferences.Add(preference);
    }

    public void Remove(CompanyMapPreference preference)
    {
        if (preference.CompanyId != currentUser.CompanyId)
            throw new InvalidOperationException("Cannot remove another tenant's map preference.");
        dbContext.CompanyMapPreferences.Remove(preference);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken) =>
        dbContext.SaveChangesAsync(cancellationToken);
}
