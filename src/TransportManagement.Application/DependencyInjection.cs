using Microsoft.Extensions.DependencyInjection;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Clients;
using TransportManagement.Application.Companies;
using TransportManagement.Application.Fleet;
using TransportManagement.Application.Trips;
using TransportManagement.Application.Tracking;
using TransportManagement.Application.Dashboard;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Notifications;
using TransportManagement.Application.Drivers;
using TransportManagement.Application.CompanyUsers;

namespace TransportManagement.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services) => services
        .AddScoped<AuthService>()
        .AddScoped<CompanyService>()
        .AddScoped<ClientService>()
        .AddScoped<TruckService>()
        .AddScoped<DriverService>()
        .AddScoped<TruckPhotoService>()
        .AddScoped<TripEntityResolver>()
        .AddScoped<TripEventWriter>()
        .AddScoped<ResourceEventWriter>()
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
        .AddScoped<GeofenceEvaluationService>()
        .AddScoped<NotificationService>()
        .AddScoped<DriverWorkflowService>()
        .AddScoped<CompanyUserService>()
        .AddScoped<DashboardService>();
}
