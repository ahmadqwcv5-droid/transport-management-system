namespace TransportManagement.Domain.Identity;

public static class AppRoles
{
    public const string Owner = "Owner";
    public const string Operations = "Operations";
    public const string Accountant = "Accountant";
    public const string Employee = "Employee";

    public static readonly IReadOnlySet<string> All =
        new HashSet<string>(StringComparer.Ordinal) { Owner, Operations, Accountant, Employee };
}
