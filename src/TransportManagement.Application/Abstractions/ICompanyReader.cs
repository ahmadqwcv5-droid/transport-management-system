using TransportManagement.Domain.Companies;

namespace TransportManagement.Application.Abstractions;

public interface ICompanyReader
{
    Task<Company?> GetCurrentAsync(CancellationToken cancellationToken);
    Task<Company?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
}
