using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Identity;

namespace TransportManagement.Infrastructure.Auth;

internal sealed class JwtTokenService(IOptions<JwtOptions> options, IClock clock) : ITokenService
{
    private readonly JwtOptions _options = options.Value;

    public (string Token, DateTimeOffset ExpiresAt) CreateAccessToken(User user)
    {
        var now = clock.UtcNow;
        var expiresAt = now.AddMinutes(_options.AccessTokenMinutes);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(CustomClaims.UserId, user.Id.ToString()),
            new Claim(CustomClaims.CompanyId, user.CompanyId.ToString()),
            new Claim(ClaimTypes.Role, user.Role),
            new Claim(JwtRegisteredClaimNames.Email, user.Email),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey)),
            SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            _options.Issuer, _options.Audience, claims, now.UtcDateTime, expiresAt.UtcDateTime, credentials);
        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }

    public GeneratedRefreshToken CreateRefreshToken(DateTimeOffset now)
    {
        var bytes = RandomNumberGenerator.GetBytes(64);
        var plainText = Base64UrlEncoder.Encode(bytes);
        return new(plainText, HashRefreshToken(plainText), now.AddDays(_options.RefreshTokenDays));
    }

    public string HashRefreshToken(string plainTextToken) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(plainTextToken)));
}
