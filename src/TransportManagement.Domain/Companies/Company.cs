using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Companies;

public sealed class Company : Entity
{
    private Company() { }

    public Company(Guid id, string name, string slug, DateTimeOffset now) : base(id, now)
    {
        Name = name;
        Slug = slug;
        IsActive = true;
    }

    public string Name { get; private set; } = string.Empty;
    public string Slug { get; private set; } = string.Empty;
    public bool IsActive { get; private set; }
}
