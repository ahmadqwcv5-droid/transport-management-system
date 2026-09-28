using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Common;

namespace TransportManagement.Infrastructure.Auth;

public sealed class ExternalIdentityOptions
{
    public const string SectionName = "ExternalIdentity";
    public GoogleIdentityOptions Google { get; init; } = new();
}

public sealed class GoogleIdentityOptions
{
    public string ClientId { get; init; } = string.Empty;
    public string WebClientId { get; init; } = string.Empty;
    public string AndroidClientId { get; init; } = string.Empty;
    public string JwksUrl { get; init; } = "https://www.googleapis.com/oauth2/v3/certs";
}

internal sealed class GoogleExternalIdentityVerifier(
    HttpClient httpClient,
    IOptions<ExternalIdentityOptions> options) : IExternalIdentityVerifier
{
    private readonly GoogleIdentityOptions _google = options.Value.Google;

    public bool IsConfigured(string provider) =>
        provider.Equals("google", StringComparison.OrdinalIgnoreCase)
        && Audiences().Length > 0;

    public async Task<VerifiedExternalIdentity> VerifyAsync(
        string provider, string idToken, string? nonce, CancellationToken cancellationToken)
    {
        if (!provider.Equals("google", StringComparison.OrdinalIgnoreCase))
            throw new DomainRuleException("The external identity provider is not supported.",
                "EXTERNAL_PROVIDER_UNSUPPORTED");
        if (!IsConfigured(provider))
            throw new DomainRuleException("Google Sign-In is not configured.",
                "EXTERNAL_PROVIDER_UNAVAILABLE");
        if (string.IsNullOrWhiteSpace(idToken))
            throw new DomainRuleException("The Google identity token is required.",
                "EXTERNAL_TOKEN_INVALID");

        try
        {
            var jwksJson = await httpClient.GetStringAsync(_google.JwksUrl, cancellationToken);
            var signingKeys = new JsonWebKeySet(jwksJson).GetSigningKeys();
            var parameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuers = ["https://accounts.google.com", "accounts.google.com"],
                ValidateAudience = true,
                ValidAudiences = Audiences(),
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = signingKeys,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(2)
            };
            var principal = new JwtSecurityTokenHandler().ValidateToken(
                idToken, parameters, out _);
            var subject = principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
                ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = principal.FindFirstValue(JwtRegisteredClaimNames.Email)
                ?? principal.FindFirstValue(ClaimTypes.Email);
            var verifiedText = principal.FindFirstValue("email_verified");
            var verified = bool.TryParse(verifiedText, out var parsed) && parsed;
            var tokenNonce = principal.FindFirstValue("nonce");
            if (!string.IsNullOrWhiteSpace(nonce)
                && !string.Equals(nonce, tokenNonce, StringComparison.Ordinal))
                throw new SecurityTokenValidationException("The nonce does not match.");
            if (string.IsNullOrWhiteSpace(subject) || string.IsNullOrWhiteSpace(email))
                throw new SecurityTokenValidationException("Required Google claims are missing.");
            return new("google", subject, email.Trim().ToLowerInvariant(), verified,
                principal.FindFirstValue("name"));
        }
        catch (DomainRuleException)
        {
            throw;
        }
        catch (Exception exception) when (exception is SecurityTokenException
            or HttpRequestException or JsonException)
        {
            throw new DomainRuleException("The Google identity token could not be verified.",
                "EXTERNAL_TOKEN_INVALID");
        }
    }

    private string[] Audiences() =>
        new[] { _google.ClientId, _google.WebClientId, _google.AndroidClientId }
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value.Trim())
            .Distinct(StringComparer.Ordinal)
            .ToArray();
}
