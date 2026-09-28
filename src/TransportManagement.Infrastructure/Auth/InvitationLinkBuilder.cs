using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Auth;

public sealed class FrontendOptions
{
    public const string SectionName = "Frontend";
    public string PublicBaseUrl { get; init; } = "http://localhost:3000";
}

internal sealed class InvitationLinkBuilder(
    IOptions<FrontendOptions> options,
    IHostEnvironment environment) : IInvitationLinkBuilder
{
    public string BuildAcceptanceUrl(string token)
    {
        if (!Uri.TryCreate(options.Value.PublicBaseUrl, UriKind.Absolute, out var baseUri)
            || baseUri.Scheme is not ("http" or "https")
            || !string.IsNullOrEmpty(baseUri.Query)
            || !string.IsNullOrEmpty(baseUri.Fragment))
            throw new InvalidOperationException(
                "Frontend:PublicBaseUrl must be an absolute HTTP(S) URL without query or fragment.");
        if (environment.IsProduction() && baseUri.IsLoopback)
            throw new InvalidOperationException(
                "Frontend:PublicBaseUrl cannot be loopback in Production.");
        var publicBase = baseUri.GetLeftPart(UriPartial.Path).TrimEnd('/');
        return $"{publicBase}/#/accept-invitation?token={Uri.EscapeDataString(token)}";
    }
}
