using TransportManagement.Application.Capabilities;

namespace TransportManagement.ArchitectureTests;

public sealed class ProductCapabilitiesTests
{
    [Theory]
    [InlineData("Development", true, true, true)]
    [InlineData("Testing", true, true, true)]
    [InlineData("Pilot", false, false, false)]
    [InlineData("Production", false, false, false)]
    public void EnvironmentProfilesEnforceSimulatorAndSeedBoundaries(
        string environment, bool endpoints, bool worker, bool seed)
    {
        var capabilities = ProductCapabilities.Resolve(environment, null);

        Assert.Equal(endpoints, capabilities.SimulatorEndpoints);
        Assert.Equal(worker, capabilities.SimulatorWorker);
        Assert.Equal(seed, capabilities.DemoSeed);
    }

    [Fact]
    public void DemoRequiresExplicitSimulatorAndSeedOptIn()
    {
        var restricted = ProductCapabilities.Resolve("Demo", null);
        var enabled = ProductCapabilities.Resolve("Demo", null, true, true);

        Assert.False(restricted.SimulatorEndpoints);
        Assert.False(restricted.DemoSeed);
        Assert.True(enabled.SimulatorEndpoints);
        Assert.True(enabled.SimulatorWorker);
        Assert.True(enabled.DemoSeed);
    }

    [Theory]
    [InlineData("Pilot")]
    [InlineData("Production")]
    public void DeploymentProfilesCannotBeOverriddenByDemoFlags(string profile)
    {
        var capabilities = ProductCapabilities.Resolve(
            "Development", profile, true, true);

        Assert.False(capabilities.SimulatorEndpoints);
        Assert.False(capabilities.SimulatorWorker);
        Assert.False(capabilities.DemoSeed);
        Assert.True(capabilities.RequiresRealTracking);
    }
}
