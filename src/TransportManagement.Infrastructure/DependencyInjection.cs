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
        var offlineThresholdSeconds = Math.Max(
            1, configuration.GetValue<int>("Tracking:OfflineThresholdSeconds", 30));
        services.AddSingleton(
            new TrackingPolicy(TimeSpan.FromSeconds(offlineThresholdSeconds)));
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
