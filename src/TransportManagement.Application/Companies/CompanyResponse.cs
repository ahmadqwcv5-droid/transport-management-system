namespace TransportManagement.Application.Companies;

public sealed record CompanyResponse(Guid Id, string Name, string Slug, bool IsActive);
