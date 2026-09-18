namespace TransportManagement.Application.Common;

public sealed class ProviderException(
    string message,
    string code,
    Exception? innerException = null) : Exception(message, innerException)
{
    public string Code { get; } = code;
}
