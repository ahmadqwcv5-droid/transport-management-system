using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Auth;

internal sealed class CompanyCodeService(IOptions<JwtOptions> jwtOptions)
    : ICompanyCodeService
{
    private readonly byte[] _key = Encoding.UTF8.GetBytes(jwtOptions.Value.SigningKey);

    public string Generate(Guid companyId, int version)
    {
        var payload = Encoding.UTF8.GetBytes(
            $"company-connection-code:{companyId:N}:{version}");
        var digest = HMACSHA256.HashData(_key, payload);
        return $"TMS-{Base64UrlEncoder.Encode(digest)[..20].ToUpperInvariant()}";
    }

    public string Hash(string code)
    {
        var normalized = code.Trim().ToUpperInvariant();
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalized)));
    }
}
