using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using TransportManagement.Application.Auth;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Common;

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
        var status = exception switch
        {
            AuthenticationException => StatusCodes.Status401Unauthorized,
            NotFoundException => StatusCodes.Status404NotFound,
            ConflictException => StatusCodes.Status409Conflict,
            DomainRuleException => StatusCodes.Status400BadRequest,
            _ => StatusCodes.Status500InternalServerError
        };
        if (status == StatusCodes.Status500InternalServerError)
            LogUnhandledException(logger, httpContext.Request.Method, httpContext.Request.Path, exception);

        httpContext.Response.StatusCode = status;
        var code = exception switch
        {
            ConflictException conflict => conflict.Code,
            NotFoundException notFound => notFound.Code,
            DomainRuleException domain => domain.Code,
            AuthenticationException => "AUTHENTICATION_FAILED",
            _ => "UNEXPECTED_ERROR"
        };
        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails
            {
                Status = status,
                Title = status switch
                {
                    400 => "Business rule validation failed",
                    401 => "Authentication failed",
                    404 => "Resource not found",
                    409 => "Operation conflict",
                    _ => "An unexpected error occurred"
                },
                Detail = status < 500 ? exception.Message : "Contact support with the trace identifier.",
                Instance = httpContext.Request.Path,
                Extensions = { ["errorCode"] = code }
            }
        });
    }
}
