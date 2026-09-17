namespace TransportManagement.Domain.Common;

public sealed class DomainRuleException(string message) : Exception(message);
