namespace TransportManagement.Application.Common;

public sealed class ConflictException(
    string message,
    string code = "OPERATION_CONFLICT",
    Exception? innerException = null) : Exception(message, innerException)
{
    public string Code { get; } = code;
}
