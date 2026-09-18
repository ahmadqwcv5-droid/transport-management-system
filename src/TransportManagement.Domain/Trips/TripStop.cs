using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class TripStop : Entity, ITenantOwned
{
    private TripStop() { }

    public TripStop(
        Guid id,
        Guid companyId,
        Guid tripId,
        int sequence,
        TripStopType type,
        string name,
        string? address,
        decimal latitude,
        decimal longitude,
        DateTimeOffset? plannedArrivalAt,
        int? plannedServiceDurationMinutes,
        DateTimeOffset now) : base(id, now)
    {
        if (sequence < 0)
            throw new DomainRuleException("Stop sequence cannot be negative.", "INVALID_STOP_SEQUENCE");
        if (string.IsNullOrWhiteSpace(name))
            throw new DomainRuleException("Stop name is required.", "STOP_NAME_REQUIRED");
        ValidateCoordinates(latitude, longitude);
        if (plannedServiceDurationMinutes is < 0)
            throw new DomainRuleException("Service duration cannot be negative.", "INVALID_SERVICE_DURATION");

        CompanyId = companyId;
        TripId = tripId;
        Sequence = sequence;
        Type = type;
        Name = name.Trim();
        Address = string.IsNullOrWhiteSpace(address) ? null : address.Trim();
        Latitude = latitude;
        Longitude = longitude;
        PlannedArrivalAt = plannedArrivalAt;
        PlannedServiceDurationMinutes = plannedServiceDurationMinutes;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public int Sequence { get; private set; }
    public TripStopType Type { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? Address { get; private set; }
    public decimal? Latitude { get; private set; }
    public decimal? Longitude { get; private set; }
    public DateTimeOffset? PlannedArrivalAt { get; private set; }
    public int? PlannedServiceDurationMinutes { get; private set; }
    public bool HasCoordinates => Latitude.HasValue && Longitude.HasValue;

    public static void ValidateCoordinates(decimal latitude, decimal longitude)
    {
        if (latitude is < -90 or > 90)
            throw new DomainRuleException("Latitude must be between -90 and 90.", "INVALID_COORDINATES");
        if (longitude is < -180 or > 180)
            throw new DomainRuleException("Longitude must be between -180 and 180.", "INVALID_COORDINATES");
    }
}
