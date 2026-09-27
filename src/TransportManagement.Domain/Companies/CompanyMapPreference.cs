using System.Text.RegularExpressions;
using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Companies;

/// <summary>Optional, tenant-owned map viewport selected explicitly by an Owner.</summary>
public sealed partial class CompanyMapPreference : Entity, ITenantOwned
{
    private CompanyMapPreference() { }

    public CompanyMapPreference(Guid companyId, string countryCode, string label,
        decimal south, decimal west, decimal north, decimal east,
        decimal? centerLatitude, decimal? centerLongitude, decimal? preferredZoom,
        Guid updatedByUserId, DateTimeOffset now) : base(companyId, now)
    {
        CompanyId = companyId;
        Update(countryCode, label, south, west, north, east, centerLatitude,
            centerLongitude, preferredZoom, updatedByUserId, now);
    }

    public Guid CompanyId { get; private set; }
    public string CountryCode { get; private set; } = string.Empty;
    public string Label { get; private set; } = string.Empty;
    public decimal South { get; private set; }
    public decimal West { get; private set; }
    public decimal North { get; private set; }
    public decimal East { get; private set; }
    public decimal? CenterLatitude { get; private set; }
    public decimal? CenterLongitude { get; private set; }
    public decimal? PreferredZoom { get; private set; }
    public Guid UpdatedByUserId { get; private set; }

    public void Update(string countryCode, string label, decimal south, decimal west,
        decimal north, decimal east, decimal? centerLatitude, decimal? centerLongitude,
        decimal? preferredZoom, Guid updatedByUserId, DateTimeOffset now)
    {
        countryCode = countryCode.Trim().ToUpperInvariant();
        label = label.Trim();
        if (!CountryCodePattern().IsMatch(countryCode))
            throw new DomainRuleException("Country code must be an ISO alpha-2 code.", "INVALID_MAP_COUNTRY_CODE");
        if (label.Length is < 1 or > 200)
            throw new DomainRuleException("Operational area label is required and cannot exceed 200 characters.", "INVALID_MAP_AREA_LABEL");
        if (south is < -90 or > 90 || north is < -90 or > 90 || south >= north
            || west is < -180 or > 180 || east is < -180 or > 180 || west >= east)
            throw new DomainRuleException("Operational area bounds are invalid. Dateline-crossing areas are not supported yet.", "INVALID_MAP_AREA_BOUNDS");
        if (centerLatitude.HasValue != centerLongitude.HasValue
            || centerLatitude is < -90 or > 90 || centerLongitude is < -180 or > 180)
            throw new DomainRuleException("Operational area center is invalid.", "INVALID_MAP_AREA_CENTER");
        if (preferredZoom is < 0 or > 22)
            throw new DomainRuleException("Preferred map zoom must be between 0 and 22.", "INVALID_MAP_AREA_ZOOM");

        CountryCode = countryCode;
        Label = label;
        South = south;
        West = west;
        North = north;
        East = east;
        CenterLatitude = centerLatitude;
        CenterLongitude = centerLongitude;
        PreferredZoom = preferredZoom;
        UpdatedByUserId = updatedByUserId;
        Touch(now);
    }

    [GeneratedRegex("^[A-Z]{2}$", RegexOptions.CultureInvariant)]
    private static partial Regex CountryCodePattern();
}
