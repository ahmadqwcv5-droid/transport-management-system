using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Auth;

internal sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
