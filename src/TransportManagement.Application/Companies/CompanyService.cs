using TransportManagement.Application.Abstractions;

namespace TransportManagement.Application.Companies;

public sealed class CompanyService(ICompanyReader companyReader)
{
    public async Task<CompanyResponse?> GetCurrentAsync(CancellationToken cancellationToken)
    {
        var company = await companyReader.GetCurrentAsync(cancellationToken);
        return company is null ? null : new(company.Id, company.Name, company.Slug, company.IsActive);
    }

    public async Task<CompanyResponse?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        var company = await companyReader.GetByIdAsync(id, cancellationToken);
        return company is null ? null : new(company.Id, company.Name, company.Slug, company.IsActive);
    }
}
