using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options, ICurrentUser currentUser) : DbContext(options)
{
    public Guid CurrentCompanyId => currentUser.CompanyId;
    public DbSet<Company> Companies => Set<Company>();
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Client> Clients => Set<Client>();
    public DbSet<Truck> Trucks => Set<Truck>();
    public DbSet<Driver> Drivers => Set<Driver>();
    public DbSet<Trip> Trips => Set<Trip>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        foreach (var entityType in modelBuilder.Model.GetEntityTypes()
                     .Where(type => typeof(ITenantOwned).IsAssignableFrom(type.ClrType)))
        {
            var parameter = Expression.Parameter(entityType.ClrType, "entity");
            var companyId = Expression.Call(
                typeof(EF), nameof(EF.Property), [typeof(Guid)], parameter, Expression.Constant(nameof(ITenantOwned.CompanyId)));
            var currentCompanyId = Expression.Property(Expression.Constant(this), nameof(CurrentCompanyId));
            var predicate = Expression.Lambda(Expression.Equal(companyId, currentCompanyId), parameter);
            entityType.SetQueryFilter(predicate);
        }

        modelBuilder.Entity<Company>().HasQueryFilter(company => company.Id == CurrentCompanyId);
    }
}
