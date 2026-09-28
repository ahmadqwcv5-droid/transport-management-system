using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Identity;
using TransportManagement.Infrastructure.Persistence;
using TransportManagement.Infrastructure.Routing;
using TransportManagement.Infrastructure.Tracking;
using TransportManagement.Application.Tracking;

namespace TransportManagement.IntegrationTests;

public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string _databaseName = $"tms-tests-{Guid.NewGuid()}";
    private readonly string _photoRoot = Path.Combine(Path.GetTempPath(),
        $"tms-photo-tests-{Guid.NewGuid():N}");
    private readonly bool _useFailingRoutingProvider;
    private readonly bool _simulatorEnabled = true;
    public static readonly Guid CompanyAId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    public static readonly Guid CompanyBId = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    public const string Password = "DemoPassword!123";

    public ApiFactory()
    {
    }

    internal ApiFactory(bool useFailingRoutingProvider, bool simulatorEnabled = true)
    {
        _useFailingRoutingProvider = useFailingRoutingProvider;
        _simulatorEnabled = simulatorEnabled;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ConnectionStrings:Database"] = "Host=unused;Database=unused;Username=unused;Password=unused",
                ["Jwt:Issuer"] = "IntegrationTests",
                ["Jwt:Audience"] = "IntegrationTests",
                ["Jwt:SigningKey"] = "integration-test-signing-key-at-least-32-bytes-long",
                ["Jwt:AccessTokenMinutes"] = "15",
                ["Jwt:RefreshTokenDays"] = "14"
                , ["Tracking:Provider"] = "Simulator"
                , ["Tracking:SimulatorEnabled"] = _simulatorEnabled.ToString()
                , ["Tracking:SimulatorStepDistanceMeters"] = "100000"
                , ["Geofence:MinimumDwellSeconds"] = "0"
                , ["Geofence:MinimumSamples"] = "2"
                , ["TruckPhotos:RootPath"] = _photoRoot
            }));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<AppDbContext>>();
            services.RemoveAll<AppDbContext>();
            services.RemoveAll<ITrackingProvider>();
            services.RemoveAll<IExternalIdentityVerifier>();
            services.AddSingleton<IExternalIdentityVerifier, FakeExternalIdentityVerifier>();
            services.RemoveAll<GeofencePolicy>();
            services.AddSingleton(new GeofencePolicy(50, 80, 2,
                TimeSpan.Zero, TimeSpan.FromSeconds(60)));
            if (_simulatorEnabled)
                services.AddSingleton<ITrackingProvider, SimulatedTrackingProvider>();
            else
                services.AddSingleton<ITrackingProvider, DisabledTrackingProvider>();
            if (_useFailingRoutingProvider)
            {
                services.RemoveAll<IRoutingProvider>();
                services.AddSingleton<IRoutingProvider, FailingRoutingProvider>();
            }
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase(_databaseName));
        });
    }

    public async ValueTask InitializeAsync()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        var now = DateTimeOffset.UtcNow;

        db.Companies.AddRange(
            new Company(CompanyAId, "Company A", "company-a", now),
            new Company(CompanyBId, "Company B", "company-b", now));
        var ownerA = new User(Guid.NewGuid(), "owner-a@example.test",
            "Owner A", hasher.Hash(Password), now);
        var ownerB = new User(Guid.NewGuid(), "owner-b@example.test",
            "Owner B", hasher.Hash(Password), now);
        var membershipA = new CompanyMembership(Guid.NewGuid(), CompanyAId,
            ownerA.Id, MembershipStatus.Active, ownerA.Id, now);
        var membershipB = new CompanyMembership(Guid.NewGuid(), CompanyBId,
            ownerB.Id, MembershipStatus.Active, ownerB.Id, now);
        db.Users.AddRange(ownerA, ownerB);
        db.CompanyMemberships.AddRange(membershipA, membershipB);
        db.CompanyMembershipRoles.AddRange(
            new CompanyMembershipRole(CompanyAId, membershipA.Id, AppRoles.Owner),
            new CompanyMembershipRole(CompanyBId, membershipB.Id, AppRoles.Owner));
        await db.SaveChangesAsync();
    }

    public new async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
    }
}

internal sealed class DisabledTrackingProvider : ITrackingProvider
{
    public bool IsSimulator => false;
    public IReadOnlyList<TrackingSample> GetCurrent(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets, DateTimeOffset now) => [];
    public SimulatorState Control(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets,
        SimulatorCommand command, DateTimeOffset now) => new(false, false, 1, 0);
}

internal sealed class FailingRoutingProvider : IRoutingProvider
{
    private readonly DeterministicRoutingProvider _inner = new();

    public bool IsConfigured => true;

    public Task<RoutingProviderResult> CalculateAsync(
        RoutingProviderRequest request, CancellationToken cancellationToken)
    {
        if (request.Stops[^1].Latitude < 40)
            throw new TransportManagement.Application.Common.ProviderException(
                "The routing provider failed.", "ROUTING_PROVIDER_FAILURE");
        return _inner.CalculateAsync(request, cancellationToken);
    }
}

internal sealed class FakeExternalIdentityVerifier : IExternalIdentityVerifier
{
    public bool IsConfigured(string provider) =>
        provider.Equals("google", StringComparison.OrdinalIgnoreCase);

    public Task<VerifiedExternalIdentity> VerifyAsync(
        string provider, string idToken, string? nonce,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured(provider))
            throw new TransportManagement.Domain.Common.DomainRuleException(
                "The provider is not configured.", "EXTERNAL_PROVIDER_UNAVAILABLE");
        var parts = idToken.Split('|');
        if (parts.Length != 4 || parts[0] != "verified")
            throw new TransportManagement.Domain.Common.DomainRuleException(
                "The Google identity token is invalid.", "EXTERNAL_TOKEN_INVALID");
        return Task.FromResult(new VerifiedExternalIdentity(
            "google", parts[1], parts[2], parts[3] == "true", parts[2]));
    }
}
