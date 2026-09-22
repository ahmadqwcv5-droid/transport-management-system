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
        decimal? latitude,
        decimal? longitude,
        DateTimeOffset? plannedArrivalAt,
        int? plannedServiceDurationMinutes,
        DateTimeOffset now) : base(id, now)
    {
        if (sequence < 0)
            throw new DomainRuleException("Stop sequence cannot be negative.", "INVALID_STOP_SEQUENCE");
        if (string.IsNullOrWhiteSpace(name))
            throw new DomainRuleException("Stop name is required.", "STOP_NAME_REQUIRED");
        if (latitude.HasValue != longitude.HasValue)
            throw new DomainRuleException("Both coordinates must be provided together.", "INVALID_COORDINATES");
        if (latitude.HasValue) ValidateCoordinates(latitude.Value, longitude!.Value);
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

    internal bool UpdateFrom(TripStop value, DateTimeOffset now)
    {
        if (value.CompanyId != CompanyId || value.TripId != TripId
            || value.Sequence != Sequence || value.Type != Type)
            throw new DomainRuleException("The stop identity cannot be changed.", "INVALID_TRIP_STOPS");
        if (Name == value.Name && Address == value.Address
            && Latitude == value.Latitude && Longitude == value.Longitude
            && PlannedArrivalAt == value.PlannedArrivalAt
            && PlannedServiceDurationMinutes == value.PlannedServiceDurationMinutes)
            return false;
        Name = value.Name;
        Address = value.Address;
        Latitude = value.Latitude;
        Longitude = value.Longitude;
        PlannedArrivalAt = value.PlannedArrivalAt;
        PlannedServiceDurationMinutes = value.PlannedServiceDurationMinutes;
        Touch(now);
        return true;
    }

    public static void ValidateCoordinates(decimal latitude, decimal longitude)
    {
        if (latitude is < -90 or > 90)
            throw new DomainRuleException("Latitude must be between -90 and 90.", "INVALID_COORDINATES");
        if (longitude is < -180 or > 180)
            throw new DomainRuleException("Longitude must be between -180 and 180.", "INVALID_COORDINATES");
    }
}
