namespace TransportManagement.Application.Common;

public sealed class NotFoundException(string message, string code = "RESOURCE_NOT_FOUND") : Exception(message)
{
    public string Code { get; } = code;
}
