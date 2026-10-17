namespace TransportManagement.Application.Capabilities;

public enum ProductProfile
{
    Development,
    Demo,
    Pilot,
    Production
}

public sealed record ProductCapabilities(
    ProductProfile Profile,
    bool SimulatorEndpoints,
    bool SimulatorWorker,
    bool DemoSeed,
    bool DiagnosticEvidence,
    bool RequiresRealTracking)
{
    public static ProductCapabilities Resolve(
        string environmentName,
        string? configuredProfile,
        bool demoSimulatorEnabled = false,
        bool demoSeedEnabled = false)
    {
        var profile = Parse(configuredProfile) ?? environmentName.ToLowerInvariant() switch
        {
            "development" or "testing" => ProductProfile.Development,
            "demo" => ProductProfile.Demo,
            "pilot" => ProductProfile.Pilot,
            _ => ProductProfile.Production
        };

        return profile switch
        {
            ProductProfile.Development => new(profile, true, true, true, true, false),
            ProductProfile.Demo => new(profile, demoSimulatorEnabled,
                demoSimulatorEnabled, demoSeedEnabled, false, false),
            ProductProfile.Pilot => new(profile, false, false, false, false, true),
            _ => new(profile, false, false, false, false, true)
        };
    }

    private static ProductProfile? Parse(string? value) =>
        Enum.TryParse<ProductProfile>(value, true, out var profile) ? profile : null;
}
