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
using TransportManagement.Infrastructure.Routing;

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
        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<ITokenService, JwtTokenService>();
        services.AddScoped<IIdentityStore, IdentityStore>();
        services.AddScoped<ICompanyReader, CompanyReader>();
        services.AddScoped<IOperationsStore, OperationsStore>();
        services.AddScoped<ITrackingStore, TrackingStore>();
        services.AddSingleton(new RouteProgressPolicy(
            Math.Max(10, configuration.GetValue<decimal>("Routing:OffRouteThresholdMeters", 150)),
            Math.Max(5, configuration.GetValue<decimal>("Routing:ArrivalThresholdMeters", 30))));

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
        services.AddSingleton(
            new TrackingPolicy(
                TimeSpan.FromSeconds(offlineThresholdSeconds),
                TimeSpan.FromSeconds(historyHeartbeatSeconds)));
        var simulatorEnabled = configuration.GetValue<bool>("Tracking:SimulatorEnabled")
            && (environment.IsDevelopment() || environment.IsEnvironment("Testing"))
            && configuration["Tracking:Provider"]?.Equals("Simulator", StringComparison.OrdinalIgnoreCase) == true;
        if (simulatorEnabled)
            services.AddSingleton<ITrackingProvider, SimulatedTrackingProvider>();
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
                }
            };
        });
        services.AddAuthorizationBuilder()
            .AddPolicy("companies.read", policy => policy.RequireAuthenticatedUser())
            .AddPolicy("companies.manage", policy => policy.RequireRole("Owner"))
            .AddPolicy("operations.read", policy => policy.RequireRole("Owner", "Operations", "Accountant"))
            .AddPolicy("operations.manage", policy => policy.RequireRole("Owner", "Operations"));

        return services;
    }
}
