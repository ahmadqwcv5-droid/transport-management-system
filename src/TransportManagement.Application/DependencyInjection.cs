using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Companies;

namespace TransportManagement.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services) => services
        .AddScoped<AuthService>()
        .AddScoped<CompanyService>();
}
