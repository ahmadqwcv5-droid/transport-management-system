using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Auth;

internal sealed class PasswordHasher : IPasswordHasher
{
    public string Hash(string password) => BCrypt.Net.BCrypt.EnhancedHashPassword(password, 12);
    public bool Verify(string password, string passwordHash) =>
        BCrypt.Net.BCrypt.EnhancedVerify(password, passwordHash);
}
