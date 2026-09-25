using Microsoft.Extensions.Hosting;
using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure;

internal sealed class RuntimeEnvironment(IHostEnvironment hostEnvironment) : IRuntimeEnvironment
{
    public string Name => hostEnvironment.EnvironmentName;
}
