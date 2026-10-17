using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace TransportManagement.IntegrationTests;

public sealed class Sprint44CapabilityProfileTests
{
    [Theory]
    [InlineData("Pilot")]
    [InlineData("Production")]
    public async Task RestrictedProfilesDoNotMapSimulatorOrRunWorker(string profile)
    {
        await using var factory = new ApiFactory(false, true, profile, profile);
        await factory.InitializeAsync();
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");

        var control = await owner.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "pause"
        });
        var trucks = await owner.GetAsync(
            "/api/tracking/simulator/trucks",
            TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.NotFound, control.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, trucks.StatusCode);
        var hosted = factory.Services.GetServices<IHostedService>();
        Assert.DoesNotContain(hosted, item =>
            item.GetType().Name == "TrackingIngestionWorker");
    }

    [Fact]
    public async Task DevelopmentKeepsSimulatorEndpointAndWorker()
    {
        await using var factory = new ApiFactory(false, true, "Development", "Development");
        await factory.InitializeAsync();
        using var owner = await OperationsTestClient.AuthenticatedClientAsync(
            factory, "owner-a@example.test");

        var control = await owner.PostJsonAsync("/api/tracking/simulator/control", new
        {
            action = "pause"
        });

        Assert.Equal(HttpStatusCode.OK, control.StatusCode);
        Assert.Contains(factory.Services.GetServices<IHostedService>(), item =>
            item.GetType().Name == "TrackingIngestionWorker");
    }
}
