using System.Globalization;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Scalar.AspNetCore;
using Serilog;
using TransportManagement.Api.Infrastructure;
using TransportManagement.Application;
using TransportManagement.Infrastructure;
using TransportManagement.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, configuration) => configuration
    .ReadFrom.Configuration(context.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console(formatProvider: CultureInfo.InvariantCulture));

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment);
builder.Services.AddControllers().AddJsonOptions(options =>
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
    context.ProblemDetails.Extensions["traceId"] = context.HttpContext.TraceIdentifier);
builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddRateLimiter(options => options.AddPolicy("geocoding", context =>
    RateLimitPartition.GetFixedWindowLimiter(
        context.User.Identity?.Name ?? context.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 30,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        })));
builder.Services.AddHealthChecks().AddDbContextCheck<AppDbContext>("postgresql");
builder.Services.AddCors(options => options.AddPolicy("frontend", policy => policy
    .WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

app.UseSerilogRequestLogging();
app.UseExceptionHandler();
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options => options.WithTitle("Transport Management API"));
    await DevelopmentDataSeeder.SeedAsync(app.Services, app.Configuration, app.Lifetime.ApplicationStopping);
}
else if (app.Environment.IsEnvironment("Testing")
    && app.Configuration.GetValue<bool>("AcceptanceEnvironment:Enabled"))
{
    await DevelopmentDataSeeder.SeedAsync(app.Services, app.Configuration, app.Lifetime.ApplicationStopping);
}

app.UseHttpsRedirection();
app.UseCors("frontend");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health", new HealthCheckOptions());

app.Run();

public partial class Program;
