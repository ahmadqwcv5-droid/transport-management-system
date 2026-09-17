using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Persistence;

public sealed class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__Database")
            ?? "Host=localhost;Port=5432;Database=transport_management;Username=transport_app";
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(connectionString)
            .Options;
        return new AppDbContext(options, new DesignTimeCurrentUser());
    }

    private sealed class DesignTimeCurrentUser : ICurrentUser
    {
        public bool IsAuthenticated => false;
        public Guid UserId => Guid.Empty;
        public Guid CompanyId => Guid.Empty;
        public string Role => string.Empty;
    }
}
