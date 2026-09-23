using System.Reflection;
using Microsoft.EntityFrameworkCore;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Common;
using TransportManagement.Infrastructure.Persistence;

namespace TransportManagement.ArchitectureTests;

public sealed class ArchitectureRulesTests
{
    private static readonly string Root = FindRepositoryRoot();

    [Fact]
    public void DomainHasNoOutwardProjectReference()
    {
        var references = ProjectReferences("src/TransportManagement.Domain/TransportManagement.Domain.csproj");
        Assert.Empty(references);
    }

    [Fact]
    public void ApplicationReferencesOnlyDomain()
    {
        var references = ProjectReferences("src/TransportManagement.Application/TransportManagement.Application.csproj");
        Assert.Equal(["../TransportManagement.Domain/TransportManagement.Domain.csproj"], references);
    }

    [Fact]
    public void ControllersDoNotReferenceEfOrAppDbContext()
    {
        var content = ReadTree("src/TransportManagement.Api/Controllers", "*.cs");
        Assert.DoesNotContain("AppDbContext", content, StringComparison.Ordinal);
        Assert.DoesNotContain("Microsoft.EntityFrameworkCore", content, StringComparison.Ordinal);
    }

    [Fact]
    public void DomainAssemblyHasNoForbiddenFrameworkOrProviderReference()
    {
        var references = typeof(ITenantOwned).Assembly.GetReferencedAssemblies()
            .Select(reference => reference.Name ?? string.Empty)
            .ToArray();
        var forbidden = new[]
        {
            "TransportManagement.Application", "TransportManagement.Infrastructure",
            "TransportManagement.Api", "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore",
            "Dio", "Flutter", "MapLibre"
        };
        Assert.DoesNotContain(references, reference => forbidden.Any(value =>
            reference.Contains(value, StringComparison.OrdinalIgnoreCase)));
    }

    [Fact]
    public void ApplicationPublicContractsDoNotLeakInfrastructureTypes()
    {
        var application = typeof(ICurrentUser).Assembly;
        var exposed = application.ExportedTypes
            .SelectMany(type => type.GetMembers(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
            .SelectMany(MemberTypes)
            .Where(type => type.Assembly.GetName().Name == "TransportManagement.Infrastructure")
            .ToArray();
        Assert.Empty(exposed);
    }

    [Fact]
    public void EveryDomainTypeWithCompanyIdIsTenantOwned()
    {
        var offenders = typeof(ITenantOwned).Assembly.GetTypes()
            .Where(type => type.IsClass && !type.IsAbstract)
            .Where(type => type.GetProperty(nameof(ITenantOwned.CompanyId))?.PropertyType == typeof(Guid))
            .Where(type => !typeof(ITenantOwned).IsAssignableFrom(type))
            .Select(type => type.FullName)
            .ToArray();
        Assert.Empty(offenders);
    }

    [Fact]
    public void PersistedTenantEntitiesHaveFiltersAndCompanyIndexes()
    {
        var approvedIdentityLookupIndexes = new HashSet<Type>
        {
            typeof(TransportManagement.Domain.Identity.User),
            typeof(TransportManagement.Domain.Identity.RefreshToken)
        };
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"architecture-{Guid.NewGuid()}").Options;
        using var db = new AppDbContext(options, new ArchitectureCurrentUser());
        var offenders = db.Model.GetEntityTypes()
            .Where(entity => typeof(ITenantOwned).IsAssignableFrom(entity.ClrType))
            .Where(entity => entity.GetDeclaredQueryFilters().Count == 0 ||
                (!approvedIdentityLookupIndexes.Contains(entity.ClrType) &&
                 !entity.GetIndexes().Any(index => index.Properties.Any(property =>
                     property.Name == nameof(ITenantOwned.CompanyId))) &&
                 !(entity.FindPrimaryKey()?.Properties.Any(property =>
                     property.Name == nameof(ITenantOwned.CompanyId)) ?? false)))
            .Select(entity => entity.ClrType.FullName)
            .ToArray();
        Assert.Empty(offenders);
    }

    [Fact]
    public void IgnoreQueryFiltersIsLimitedToReviewedIdentityBootstrapFiles()
    {
        var approved = new HashSet<string>(StringComparer.Ordinal)
        {
            "src/TransportManagement.Infrastructure/Persistence/IdentityStore.cs",
            "src/TransportManagement.Infrastructure/Persistence/DevelopmentDataSeeder.cs"
        };
        var offenders = Directory.EnumerateFiles(Path.Combine(Root, "src"), "*.cs", SearchOption.AllDirectories)
            .Where(path => File.ReadAllText(path).Contains("IgnoreQueryFilters", StringComparison.Ordinal))
            .Select(Relative)
            .Where(path => !approved.Contains(path))
            .ToArray();
        Assert.Empty(offenders);
    }

    [Fact]
    public void FlutterPresentationDoesNotImportDioOrConcreteApiClient()
    {
        var offenders = Directory.EnumerateFiles(
                Path.Combine(Root, "apps/transport_management_app/lib"), "*.dart",
                SearchOption.AllDirectories)
            .Where(path => path.Replace('\\', '/').Contains("/presentation/", StringComparison.Ordinal))
            .Select(path => (Path: Relative(path), Content: File.ReadAllText(path)))
            .Where(file => file.Content.Contains("extends StatelessWidget", StringComparison.Ordinal) ||
                           file.Content.Contains("extends StatefulWidget", StringComparison.Ordinal) ||
                           file.Content.Contains("extends ConsumerWidget", StringComparison.Ordinal) ||
                           file.Content.Contains("extends ConsumerStatefulWidget", StringComparison.Ordinal))
            .Where(file => file.Content.Contains("package:dio/", StringComparison.Ordinal) ||
                           file.Content.Contains("core/network/api_client.dart", StringComparison.Ordinal))
            .Select(file => file.Path)
            .ToArray();
        Assert.Empty(offenders);
    }

    [Fact]
    public void FlutterUsesRiverpodAsItsOnlyStateManagementFramework()
    {
        var pubspec = File.ReadAllText(Path.Combine(Root, "apps/transport_management_app/pubspec.yaml"));
        Assert.Contains("flutter_riverpod:", pubspec, StringComparison.Ordinal);
        foreach (var forbidden in new[] { "provider:", "bloc:", "flutter_bloc:", "get:", "mobx:", "redux:" })
            Assert.DoesNotContain($"\n  {forbidden}", pubspec, StringComparison.Ordinal);
    }

    [Fact]
    public void CatchAllOperationsStoreHasBeenRemoved()
    {
        Assert.False(File.Exists(Path.Combine(Root,
            "src/TransportManagement.Application/Abstractions/IOperationsStore.cs")));
    }

    private static string[] ProjectReferences(string relativePath)
    {
        var document = System.Xml.Linq.XDocument.Load(Path.Combine(Root, relativePath));
        return document.Descendants("ProjectReference")
            .Select(element => element.Attribute("Include")?.Value)
            .Where(value => value is not null)
            .Cast<string>()
            .Order(StringComparer.Ordinal)
            .ToArray();
    }

    private static IEnumerable<Type> MemberTypes(MemberInfo member) => member switch
    {
        MethodInfo method => method.GetParameters().Select(parameter => parameter.ParameterType)
            .Append(method.ReturnType),
        PropertyInfo property => [property.PropertyType],
        FieldInfo field => [field.FieldType],
        EventInfo eventInfo => eventInfo.EventHandlerType is null ? [] : [eventInfo.EventHandlerType],
        _ => []
    };

    private static string ReadTree(string relativePath, string pattern,
        Func<string, bool>? predicate = null) => string.Join('\n',
        Directory.EnumerateFiles(Path.Combine(Root, relativePath), pattern, SearchOption.AllDirectories)
            .Where(path => predicate?.Invoke(path.Replace('\\', '/')) ?? true)
            .Select(File.ReadAllText));

    private static string Relative(string path) => Path.GetRelativePath(Root, path).Replace('\\', '/');

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "TransportManagement.slnx")))
            directory = directory.Parent;
        return directory?.FullName ?? throw new InvalidOperationException("Repository root was not found.");
    }

    private sealed class ArchitectureCurrentUser : ICurrentUser
    {
        public Guid UserId => Guid.Parse("11111111-1111-1111-1111-111111111111");
        public Guid CompanyId => Guid.Parse("22222222-2222-2222-2222-222222222222");
        public string Role => "Owner";
        public bool IsAuthenticated => true;
    }
}
