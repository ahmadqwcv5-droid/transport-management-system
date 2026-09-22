using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class TripNumberCounter : ITenantOwned
{
    private TripNumberCounter() { }
    public TripNumberCounter(Guid companyId, int year, long lastValue)
    {
        CompanyId = companyId;
        Year = year;
        LastValue = lastValue;
    }
    public Guid CompanyId { get; private set; }
    public int Year { get; private set; }
    public long LastValue { get; private set; }
}
