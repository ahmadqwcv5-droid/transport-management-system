using TransportManagement.Domain.Identity;

namespace TransportManagement.Application.Abstractions;

public sealed record GeneratedRefreshToken(string PlainText, string Hash, DateTimeOffset ExpiresAt);

public interface ITokenService
{
    (string Token, DateTimeOffset ExpiresAt) CreateAccessToken(
        User account, CompanyMembership? membership,
        IReadOnlyCollection<string> roles);
    GeneratedRefreshToken CreateRefreshToken(DateTimeOffset now);
    string HashRefreshToken(string plainTextToken);
}
