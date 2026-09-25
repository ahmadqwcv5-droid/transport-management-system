using TransportManagement.Application.Abstractions;

namespace TransportManagement.Infrastructure.Auth;

internal sealed class CompanyExecutionContext : ICompanyExecutionContext
{
    private Guid? _companyId;
    public Guid? CompanyId => _companyId;

    public IDisposable Enter(Guid companyId)
    {
        if (_companyId.HasValue)
            throw new InvalidOperationException("A company execution scope is already active.");
        _companyId = companyId;
        return new Scope(this);
    }

    private sealed class Scope(CompanyExecutionContext owner) : IDisposable
    {
        private bool _disposed;
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            owner._companyId = null;
        }
    }
}
