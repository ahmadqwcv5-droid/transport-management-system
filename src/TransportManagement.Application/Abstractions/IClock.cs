namespace TransportManagement.Application.Abstractions;

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}
