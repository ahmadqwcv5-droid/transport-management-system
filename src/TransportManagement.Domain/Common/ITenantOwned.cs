namespace TransportManagement.Domain.Common;

public interface ITenantOwned
{
    Guid CompanyId { get; }
}
