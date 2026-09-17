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

namespace TransportManagement.IntegrationTests;

public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string _databaseName = $"tms-tests-{Guid.NewGuid()}";
    public static readonly Guid CompanyAId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    public static readonly Guid CompanyBId = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    public const string Password = "DemoPassword!123";

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
            }));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<AppDbContext>>();
            services.RemoveAll<AppDbContext>();
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
        db.Users.AddRange(
            new User(Guid.NewGuid(), CompanyAId, "owner-a@example.test", "Owner A", hasher.Hash(Password), AppRoles.Owner, now),
            new User(Guid.NewGuid(), CompanyBId, "owner-b@example.test", "Owner B", hasher.Hash(Password), AppRoles.Owner, now));
        await db.SaveChangesAsync();
    }

    public new async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
    }
}
