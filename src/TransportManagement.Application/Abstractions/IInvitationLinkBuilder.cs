namespace TransportManagement.Application.Abstractions;

public interface IInvitationLinkBuilder
{
    string BuildAcceptanceUrl(string token);
}
