namespace TransportManagement.Application.Abstractions;

public sealed record VerifiedExternalIdentity(
    string Provider,
    string Subject,
    string Email,
    bool EmailVerified,
    string? DisplayName);

public interface IExternalIdentityVerifier
{
    bool IsConfigured(string provider);

    Task<VerifiedExternalIdentity> VerifyAsync(
        string provider,
        string idToken,
        string? nonce,
        CancellationToken cancellationToken);
}
