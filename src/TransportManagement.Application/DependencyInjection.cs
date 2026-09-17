using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Clients;
using TransportManagement.Application.Companies;
using TransportManagement.Application.Fleet;
using TransportManagement.Application.Trips;

namespace TransportManagement.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services) => services
        .AddScoped<AuthService>()
        .AddScoped<CompanyService>()
        .AddScoped<ClientService>()
        .AddScoped<TruckService>()
        .AddScoped<DriverService>()
        .AddScoped<TripService>();
}
