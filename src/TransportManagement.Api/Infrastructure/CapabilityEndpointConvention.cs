using Microsoft.AspNetCore.Mvc.ApplicationModels;
using TransportManagement.Application.Capabilities;

namespace TransportManagement.Api.Infrastructure;

[AttributeUsage(AttributeTargets.Method)]
public sealed class SimulatorCapabilityAttribute : Attribute;

public sealed class CapabilityEndpointConvention(ProductCapabilities capabilities)
    : IActionModelConvention
{
    public void Apply(ActionModel action)
    {
        if (capabilities.SimulatorEndpoints) return;
        if (action.Attributes.OfType<SimulatorCapabilityAttribute>().Any())
            action.Selectors.Clear();
    }
}
