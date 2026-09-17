namespace TransportManagement.Domain.Common;

public sealed class DomainRuleException(string message, string code = "BUSINESS_RULE_VIOLATION") : Exception(message)
{
    public string Code { get; } = code;
}
