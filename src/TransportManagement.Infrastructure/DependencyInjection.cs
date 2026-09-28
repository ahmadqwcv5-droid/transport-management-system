using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using TransportManagement.Application.Abstractions;
using TransportManagement.Infrastructure.Auth;
using TransportManagement.Infrastructure.Persistence;
using TransportManagement.Infrastructure.Tracking;
using TransportManagement.Application.Tracking;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Trips;
using TransportManagement.Application.Fleet;
using TransportManagement.Infrastructure.Routing;
using TransportManagement.Infrastructure.Photos;

namespace TransportManagement.Infrastructure;

public static class DependencyInjection
{
    private static readonly Action<ILogger, string, Exception?> LogJwtValidationFailure =
        LoggerMessage.Define<string>(
            LogLevel.Warning,
            new EventId(4010, "JwtValidationFailure"),
            "JWT validation failed: {Reason}");

    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration configuration, IHostEnvironment environment)
    {
        services.AddOptions<JwtOptions>()
            .Bind(configuration.GetSection(JwtOptions.SectionName))
            .Validate(options => !string.IsNullOrWhiteSpace(options.Issuer), "Jwt:Issuer is required.")
            .Validate(options => !string.IsNullOrWhiteSpace(options.Audience), "Jwt:Audience is required.")
            .Validate(options => Encoding.UTF8.GetByteCount(options.SigningKey) >= 32,
                "Jwt:SigningKey must be at least 32 bytes.")
            .ValidateOnStart();
        services.AddOptions<ExternalIdentityOptions>()
            .Bind(configuration.GetSection(ExternalIdentityOptions.SectionName));
        services.AddHttpClient<IExternalIdentityVerifier, GoogleExternalIdentityVerifier>();
        services.AddHttpContextAccessor();
        services.AddScoped<ICompanyExecutionContext, CompanyExecutionContext>();
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<IRuntimeEnvironment, RuntimeEnvironment>();
        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<ITokenService, JwtTokenService>();
        services.AddScoped<IIdentityStore, IdentityStore>();
        services.AddScoped<IMembershipWorkflowStore, MembershipWorkflowStore>();
        services.AddScoped<IQrHandoverStore, QrHandoverStore>();
        services.AddSingleton<ICompanyCodeService, CompanyCodeService>();
        services.AddScoped<ICompanyUserStore, CompanyUserStore>();
        services.AddScoped<ICompanyReader, CompanyReader>();
        services.AddScoped<ICompanyMapPreferenceStore, CompanyMapPreferenceStore>();
        services.AddScoped<OperationsStore>();
        services.AddScoped<IClientStore>(provider => provider.GetRequiredService<OperationsStore>());
        services.AddScoped<IFleetStore>(provider => provider.GetRequiredService<OperationsStore>());
        services.AddScoped<ITripStore>(provider => provider.GetRequiredService<OperationsStore>());
        services.AddScoped<ITripQueryStore>(provider => provider.GetRequiredService<OperationsStore>());
        services.AddScoped<IActiveOperationsStore>(provider => provider.GetRequiredService<OperationsStore>());
        services.AddScoped<ITrackingStore, TrackingStore>();
        services.AddScoped<ITruckPhotoStore, TruckPhotoStore>();
        services.AddSingleton<ITruckPhotoProcessor, SkiaTruckPhotoProcessor>();
        services.AddOptions<TruckPhotoStorageOptions>()
            .Bind(configuration.GetSection(TruckPhotoStorageOptions.SectionName));
        services.AddSingleton<ITruckPhotoStorage, LocalTruckPhotoStorage>();
        var photoMaximumBytes = Math.Clamp(configuration.GetValue<int>(
            "TruckPhotos:MaximumBytes", 5 * 1024 * 1024), 1024, 20 * 1024 * 1024);
        var photoMaximumPixels = Math.Clamp(configuration.GetValue<int>(
            "TruckPhotos:MaximumPixels", 40_000_000), 1_000_000, 100_000_000);
        services.AddSingleton(new TruckPhotoPolicy(photoMaximumBytes, photoMaximumPixels));
        services.AddScoped<LiveOperationsStore>();
        services.AddScoped<IGeofenceStore>(provider => provider.GetRequiredService<LiveOperationsStore>());
        services.AddScoped<INotificationStore>(provider => provider.GetRequiredService<LiveOperationsStore>());
        services.AddScoped<IDriverIdentityStore>(provider => provider.GetRequiredService<LiveOperationsStore>());
        services.AddSingleton(new RouteProgressPolicy(
            Math.Max(10, configuration.GetValue<decimal>("Routing:OffRouteThresholdMeters", 150)),
            Math.Max(5, configuration.GetValue<decimal>("Routing:ArrivalThresholdMeters", 30))));
        var maximumPositionAgeSeconds = Math.Max(30,
            configuration.GetValue<int>("Dispatch:MaximumPositionAgeSeconds", 300));
        services.AddSingleton(new DispatchPolicy(
            TimeSpan.FromSeconds(maximumPositionAgeSeconds),
            Math.Max(5, configuration.GetValue<decimal>("Dispatch:PickupArrivalRadiusMeters", 50)),
            Math.Max(5, configuration.GetValue<decimal>("Dispatch:ProposalOriginMovementToleranceMeters", 100)),
            Math.Max(10, configuration.GetValue<decimal>("Dispatch:SimulatorRestoreProjectionToleranceMeters", 500))));
        services.AddSingleton(new GeofencePolicy(
            Math.Max(5, configuration.GetValue<decimal>("Geofence:ArrivalRadiusMeters", 50)),
            Math.Max(10, configuration.GetValue<decimal>("Geofence:ExitRadiusMeters", 80)),
            Math.Max(2, configuration.GetValue<int>("Geofence:MinimumSamples", 2)),
            TimeSpan.FromSeconds(Math.Max(5, configuration.GetValue<int>("Geofence:MinimumDwellSeconds", 8))),
            TimeSpan.FromSeconds(Math.Max(10, configuration.GetValue<int>("Geofence:MaximumSampleAgeSeconds", 60)))));

        if (environment.IsEnvironment("Testing"))
        {
            services.AddSingleton<IRoutingProvider, DeterministicRoutingProvider>();
            services.AddSingleton<IGeocodingProvider, DeterministicGeocodingProvider>();
        }
        else
        {
            var routingProvider = configuration["Routing:Provider"];
            if (string.Equals(routingProvider, "Osrm", StringComparison.OrdinalIgnoreCase))
            {
                services.AddHttpClient<OsrmRoutingProvider>(client =>
                    client.DefaultRequestHeaders.UserAgent.ParseAdd(
                        configuration["Routing:UserAgent"]
                        ?? "TransportManagementDevelopment/0.1"));
                services.AddSingleton<IRoutingProvider>(provider => provider.GetRequiredService<OsrmRoutingProvider>());
            }
            else services.AddSingleton<IRoutingProvider, UnconfiguredRoutingProvider>();

            var geocodingProvider = configuration["Geocoding:Provider"];
            if (string.Equals(geocodingProvider, "Nominatim", StringComparison.OrdinalIgnoreCase))
            {
                services.AddHttpClient<NominatimGeocodingProvider>();
                services.AddSingleton<IGeocodingProvider>(provider => provider.GetRequiredService<NominatimGeocodingProvider>());
            }
            else services.AddSingleton<IGeocodingProvider, UnconfiguredGeocodingProvider>();
        }
        var offlineThresholdSeconds = Math.Max(
            1, configuration.GetValue<int>("Tracking:OfflineThresholdSeconds", 30));
        var historyHeartbeatSeconds = Math.Max(
            offlineThresholdSeconds,
            configuration.GetValue<int>("Tracking:HistoryHeartbeatSeconds", 300));
        var simulatorHeartbeatSeconds = Math.Clamp(
            configuration.GetValue<int>("Tracking:SimulatorHeartbeatSeconds", 60),
            1, Math.Max(1, Math.Min(
                offlineThresholdSeconds / 2, maximumPositionAgeSeconds / 2)));
        services.AddSingleton(
            new TrackingPolicy(
                TimeSpan.FromSeconds(offlineThresholdSeconds),
                TimeSpan.FromSeconds(historyHeartbeatSeconds),
                TimeSpan.FromSeconds(Math.Max(30,
                    configuration.GetValue<int>("Tracking:TrailGapThresholdSeconds", 300))),
                Math.Max(100, configuration.GetValue<decimal>(
                    "Tracking:TrailJumpThresholdMeters", 5000)),
                Math.Clamp(configuration.GetValue<int>(
                    "Tracking:MaxTripHistoryPoints", 500), 10, 2000),
                Math.Max(10, configuration.GetValue<decimal>(
                    "Dispatch:SimulatorRestoreProjectionToleranceMeters", 500)),
                TimeSpan.FromSeconds(simulatorHeartbeatSeconds)));
        var simulatorEnabled = configuration.GetValue<bool>("Tracking:SimulatorEnabled")
            && (environment.IsDevelopment() || environment.IsEnvironment("Testing"))
            && configuration["Tracking:Provider"]?.Equals("Simulator", StringComparison.OrdinalIgnoreCase) == true;
        if (simulatorEnabled)
        {
            services.AddSingleton<ITrackingProvider, SimulatedTrackingProvider>();
            services.AddSingleton(new TrackingSchedulerOptions(TimeSpan.FromSeconds(Math.Clamp(
                configuration.GetValue<int>("Tracking:SimulatorTickSeconds", 2), 1, 30))));
            services.AddHostedService<TrackingIngestionWorker>();
        }
        else
            services.AddSingleton<ITrackingProvider, UnconfiguredTrackingProvider>();
        services.AddDbContext<AppDbContext>((serviceProvider, options) =>
        {
            var connectionString = serviceProvider.GetRequiredService<IConfiguration>()
                .GetConnectionString("Database");
            if (string.IsNullOrWhiteSpace(connectionString))
                throw new InvalidOperationException("ConnectionStrings:Database is required.");
            options.UseNpgsql(connectionString);
        });

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>>((options, configuredJwt) =>
        {
            var jwt = configuredJwt.Value;
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = jwt.Issuer,
                ValidateAudience = true,
                ValidAudience = jwt.Audience,
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromSeconds(30)
            };
            options.Events = new JwtBearerEvents
            {
                OnAuthenticationFailed = context =>
                {
                    var logger = context.HttpContext.RequestServices
                        .GetRequiredService<ILoggerFactory>()
                        .CreateLogger("TransportManagement.JwtBearer");
                    LogJwtValidationFailure(logger, context.Exception.Message, context.Exception);
                    return Task.CompletedTask;
                },
                OnTokenValidated = async context =>
                {
                    var principal = context.Principal;
                    var membershipText = principal?.FindFirst(CustomClaims.MembershipId)?.Value;
                    if (string.IsNullOrWhiteSpace(membershipText)) return;
                    if (!Guid.TryParse(membershipText, out var membershipId)
                        || !Guid.TryParse(principal?.FindFirst(CustomClaims.UserId)?.Value, out var accountId)
                        || !Guid.TryParse(principal?.FindFirst(CustomClaims.CompanyId)?.Value, out var companyId))
                    {
                        context.Fail("The workspace claims are invalid.");
                        return;
                    }

                    var db = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
                    var membership = await db.CompanyMemberships.IgnoreQueryFilters()
                        .AsNoTracking().SingleOrDefaultAsync(x => x.Id == membershipId
                            && x.AccountId == accountId && x.CompanyId == companyId,
                            context.HttpContext.RequestAborted);
                    if (membership is null || membership.Status != Domain.Identity.MembershipStatus.Active)
                    {
                        context.Fail("The workspace membership is not active.");
                        return;
                    }

                    var currentRoles = await db.CompanyMembershipRoles.IgnoreQueryFilters()
                        .Where(x => x.MembershipId == membershipId)
                        .Select(x => x.Role).OrderBy(x => x)
                        .ToListAsync(context.HttpContext.RequestAborted);
                    var claimedRoles = principal!.FindAll(System.Security.Claims.ClaimTypes.Role)
                        .Select(x => x.Value).Distinct(StringComparer.Ordinal).OrderBy(x => x).ToList();
                    if (!currentRoles.SequenceEqual(claimedRoles, StringComparer.Ordinal))
                        context.Fail("The workspace roles have changed.");
                }
            };
        });
        services.AddAuthorizationBuilder()
            .AddPolicy("companies.read", policy => policy.RequireAuthenticatedUser()
                .RequireClaim(CustomClaims.MembershipId))
            .AddPolicy("companies.manage", policy => policy.RequireClaim(CustomClaims.MembershipId).RequireRole("Owner"))
            .AddPolicy("operations.read", policy => policy.RequireClaim(CustomClaims.MembershipId).RequireRole("Owner", "Operations", "Accountant"))
            .AddPolicy("operations.manage", policy => policy.RequireClaim(CustomClaims.MembershipId).RequireRole("Owner", "Operations"));
        services.AddAuthorizationBuilder()
            .AddPolicy("driver.workflow", policy => policy.RequireClaim(CustomClaims.MembershipId).RequireRole("Driver"))
            .AddPolicy("notifications.read", policy => policy.RequireClaim(CustomClaims.MembershipId).RequireRole("Owner", "Operations", "Driver"))
            .AddPolicy("owner", policy => policy.RequireClaim(CustomClaims.MembershipId).RequireRole("Owner"));

        return services;
    }
}
