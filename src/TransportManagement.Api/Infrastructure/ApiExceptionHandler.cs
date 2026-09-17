using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Auth;

namespace TransportManagement.Api.Infrastructure;

internal sealed class ApiExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    private static readonly Action<ILogger, string, string, Exception?> LogUnhandledException =
        LoggerMessage.Define<string, string>(
            LogLevel.Error,
            new EventId(5000, nameof(ApiExceptionHandler)),
            "Unhandled exception while processing {Method} {Path}");

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var status = exception is AuthenticationException
            ? StatusCodes.Status401Unauthorized
            : StatusCodes.Status500InternalServerError;
        if (status == StatusCodes.Status500InternalServerError)
            LogUnhandledException(logger, httpContext.Request.Method, httpContext.Request.Path, exception);

        httpContext.Response.StatusCode = status;
        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails
            {
                Status = status,
                Title = status == 401 ? "Authentication failed" : "An unexpected error occurred",
                Detail = status == 401 ? exception.Message : "Contact support with the trace identifier.",
                Instance = httpContext.Request.Path
            }
        });
    }
}
