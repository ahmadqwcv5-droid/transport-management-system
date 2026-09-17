namespace TransportManagement.Domain.Common;

public abstract class Entity
{
    public Guid Id { get; protected set; }
    public DateTimeOffset CreatedAt { get; protected set; }
    public DateTimeOffset UpdatedAt { get; protected set; }

    protected Entity(Guid id, DateTimeOffset now)
    {
        Id = id;
        CreatedAt = now;
        UpdatedAt = now;
    }

    protected Entity() { }
}
