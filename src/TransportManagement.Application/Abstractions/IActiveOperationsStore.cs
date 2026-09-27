using TransportManagement.Application.Dashboard;

namespace TransportManagement.Application.Abstractions;

public interface IActiveOperationsStore
{
    Task<(IReadOnlyList<ActiveOperationSource> Items, int TotalCount)> QueryAsync(
        ActiveOperationsQuery query, int candidateLimit,
        CancellationToken cancellationToken);
}
