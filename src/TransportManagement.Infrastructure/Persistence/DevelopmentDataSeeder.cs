using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Infrastructure.Persistence;

public static class DevelopmentDataSeeder
{
    public static async Task SeedAsync(
        IServiceProvider services,
        IConfiguration configuration,
        CancellationToken cancellationToken)
    {
        if (!configuration.GetValue<bool>("DevelopmentSeed:Enabled")) return;

        var password = configuration["DevelopmentSeed:OwnerPassword"];
        if (string.IsNullOrWhiteSpace(password) || password.Length < 12)
            throw new InvalidOperationException(
                "DevelopmentSeed:OwnerPassword must be supplied externally and contain at least 12 characters.");

        await using var scope = services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var passwordHasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        await dbContext.Database.MigrateAsync(cancellationToken);

        var email = configuration["DevelopmentSeed:OwnerEmail"] ?? "owner@demo.local";
        if (await dbContext.Users.IgnoreQueryFilters().AnyAsync(x => x.Email == email, cancellationToken)) return;

        var now = DateTimeOffset.UtcNow;
        var company = new Company(
            Guid.NewGuid(),
            configuration["DevelopmentSeed:CompanyName"] ?? "Demo Transport",
            configuration["DevelopmentSeed:CompanySlug"] ?? "demo-transport",
            now);
        var owner = new User(
            Guid.NewGuid(), email, "Demo Owner", passwordHasher.Hash(password), now);
        var membership = new CompanyMembership(Guid.NewGuid(), company.Id, owner.Id,
            MembershipStatus.Active, owner.Id, now);
        dbContext.Companies.Add(company);
        dbContext.Users.Add(owner);
        dbContext.CompanyMemberships.Add(membership);
        dbContext.CompanyMembershipRoles.Add(
            new CompanyMembershipRole(company.Id, membership.Id, AppRoles.Owner));
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
