namespace TransportManagement.Application.Abstractions;

public interface ICompanyExecutionContext
{
    Guid? CompanyId { get; }
    IDisposable Enter(Guid companyId);
}
