using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Companies;

namespace TransportManagement.Application.Companies;

public sealed record CompanyMapPreferenceRequest(
    string CountryCode, string Label, decimal South, decimal West,
    decimal North, decimal East, decimal? CenterLatitude,
    decimal? CenterLongitude, decimal? PreferredZoom);

public sealed record CompanyMapPreferenceResponse(
    string CountryCode, string Label, decimal South, decimal West,
    decimal North, decimal East, decimal? CenterLatitude,
    decimal? CenterLongitude, decimal? PreferredZoom,
    DateTimeOffset UpdatedAt);

public sealed class CompanyMapPreferenceService(
    ICompanyMapPreferenceStore store, ICurrentUser currentUser, IClock clock)
{
    public async Task<CompanyMapPreferenceResponse?> GetAsync(CancellationToken cancellationToken) =>
        Map(await store.GetAsync(cancellationToken));

    public async Task<CompanyMapPreferenceResponse> SetAsync(
        CompanyMapPreferenceRequest request, CancellationToken cancellationToken)
    {
        if (currentUser.CompanyId == Guid.Empty || currentUser.UserId == Guid.Empty)
            throw new InvalidOperationException("An authenticated tenant Owner context is required.");
        var preference = await store.GetAsync(cancellationToken);
        if (preference is null)
        {
            preference = new CompanyMapPreference(currentUser.CompanyId,
                request.CountryCode, request.Label, request.South, request.West,
                request.North, request.East, request.CenterLatitude,
                request.CenterLongitude, request.PreferredZoom,
                currentUser.UserId, clock.UtcNow);
            store.Add(preference);
        }
        else
            preference.Update(request.CountryCode, request.Label, request.South,
                request.West, request.North, request.East, request.CenterLatitude,
                request.CenterLongitude, request.PreferredZoom,
                currentUser.UserId, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(preference)!;
    }

    public async Task ClearAsync(CancellationToken cancellationToken)
    {
        var preference = await store.GetAsync(cancellationToken);
        if (preference is null) return;
        store.Remove(preference);
        await store.SaveChangesAsync(cancellationToken);
    }

    private static CompanyMapPreferenceResponse? Map(CompanyMapPreference? preference) =>
        preference is null ? null : new(preference.CountryCode, preference.Label,
            preference.South, preference.West, preference.North, preference.East,
            preference.CenterLatitude, preference.CenterLongitude,
            preference.PreferredZoom, preference.UpdatedAt);
}
