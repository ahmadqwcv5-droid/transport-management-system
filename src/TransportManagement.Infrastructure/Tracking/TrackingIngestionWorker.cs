using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Tracking;

namespace TransportManagement.Infrastructure.Tracking;

internal sealed class TrackingIngestionWorker(
    IServiceScopeFactory scopeFactory,
    TrackingSchedulerOptions options,
    ILogger<TrackingIngestionWorker> logger) : BackgroundService
{
    private static readonly Action<ILogger, Exception?> LogCycleFailure =
        LoggerMessage.Define(LogLevel.Error, new EventId(4201, "TrackingCycleFailure"),
            "Tracking ingestion cycle failed.");
    private static readonly Action<ILogger, Guid, Exception?> LogCompanyFailure =
        LoggerMessage.Define<Guid>(LogLevel.Error,
            new EventId(4202, "TrackingCompanyFailure"),
            "Tracking ingestion failed for company {CompanyId}.");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(options.Interval);
        do
        {
            try { await TickAllCompaniesAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception exception)
            {
                LogCycleFailure(logger, exception);
            }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task TickAllCompaniesAsync(CancellationToken cancellationToken)
    {
        IReadOnlyList<Guid> companyIds;
        using (var discovery = scopeFactory.CreateScope())
            companyIds = await discovery.ServiceProvider.GetRequiredService<IIdentityStore>()
                .ListActiveCompanyIdsAsync(cancellationToken);

        foreach (var companyId in companyIds)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<ICompanyExecutionContext>();
                using var companyScope = context.Enter(companyId);
                await scope.ServiceProvider.GetRequiredService<TrackingIngestionService>()
                    .TickAsync(cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
            catch (Exception exception)
            {
                LogCompanyFailure(logger, companyId, exception);
            }
        }
    }
}

internal sealed record TrackingSchedulerOptions(TimeSpan Interval);
