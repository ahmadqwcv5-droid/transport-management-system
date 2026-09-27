using TransportManagement.Domain.Companies;

namespace TransportManagement.Application.Abstractions;

public interface ICompanyMapPreferenceStore
{
    Task<CompanyMapPreference?> GetAsync(CancellationToken cancellationToken);
    void Add(CompanyMapPreference preference);
    void Remove(CompanyMapPreference preference);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
