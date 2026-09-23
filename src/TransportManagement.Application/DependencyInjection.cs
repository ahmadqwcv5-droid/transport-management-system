using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Clients;
using TransportManagement.Application.Companies;
using TransportManagement.Application.Fleet;
using TransportManagement.Application.Trips;
using TransportManagement.Application.Tracking;
using TransportManagement.Application.Dashboard;
using TransportManagement.Application.Routing;

namespace TransportManagement.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services) => services
        .AddScoped<AuthService>()
        .AddScoped<CompanyService>()
        .AddScoped<ClientService>()
        .AddScoped<TruckService>()
        .AddScoped<DriverService>()
        .AddScoped<TripEntityResolver>()
        .AddScoped<TripEventWriter>()
        .AddScoped<TripDraftService>()
        .AddScoped<TripRoutingService>()
        .AddScoped<TripAssignmentService>()
        .AddScoped<TripDispatchService>()
        .AddScoped<TripLifecycleService>()
        .AddScoped<TripQueryService>()
        .AddSingleton<RoutePlanningService>()
        .AddScoped<LocationService>()
        .AddScoped<RouteProgressService>()
        .AddScoped<TrackingService>()
        .AddScoped<DashboardService>();
}
