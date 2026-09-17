namespace TransportManagement.Application.Common;

public sealed class ConflictException(string message, Exception? innerException = null)
    : Exception(message, innerException);
