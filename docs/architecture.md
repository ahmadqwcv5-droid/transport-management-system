# Architecture Decisions

## ADR-001: Modular monolith with Clean Architecture

**Status:** Accepted

The first customer is small, while the product may grow into multi-tenant SaaS. A single deployable ASP.NET Core API minimizes operational cost. Domain/Application/Infrastructure/API dependency boundaries preserve modularity and keep future feature modules independently understandable. Microservices and event sourcing add no value at this stage.

Future modules should be vertical slices inside the monolith and may share only explicitly owned contracts. Domain never references EF Core or HTTP types.

## ADR-002: Tenant derived from authentication and enforced by EF Core

**Status:** Accepted

`CompanyId` is a signed JWT claim produced from the stored user. `ICurrentUser` exposes it to infrastructure. `AppDbContext` adds a global query filter to all `ITenantOwned` entities and to `Company`, so ordinary queries cannot accidentally cross company boundaries. An unauthenticated context resolves to `Guid.Empty` and therefore sees no tenant data.

Authentication must locate a user before a tenant is authenticated, and refresh must locate a hashed bearer credential. Those two store operations use `IgnoreQueryFilters` inside Infrastructure only. They never accept a frontend-provided company ID. All other business reads retain the global filter.

Every future tenant-owned entity must:

1. implement `ITenantOwned`;
2. have a required `CompanyId` foreign key and index;
3. receive `CompanyId` from `ICurrentUser` on creation;
4. include an integration test attempting a foreign-company ID.

Defense in depth can later add PostgreSQL row-level security if operational requirements justify its connection/session complexity.

## ADR-003: JWT access token and rotating refresh credential

**Status:** Accepted

Access tokens expire after 15 minutes and contain user, company, role, email, and unique token claims. Refresh credentials contain 512 random bits, are returned only once, are SHA-256 hashed in the database, expire after 14 days, and are rotated on every use. Logout revokes the supplied token or all current-user tokens when none is supplied.

Passwords use BCrypt with work factor 12. Signing secrets and seed passwords come from external configuration.

## ADR-004: Roles now, named policies as the permission seam

**Status:** Accepted

The initial roles are Owner, Operations, Accountant, and Employee. Controllers refer to named authorization policies instead of scattering role comparisons. Later, policy handlers can evaluate permissions without changing endpoints or business use cases.

## ADR-005: Riverpod and feature-first Flutter

**Status:** Accepted

Riverpod is the only state-management system. Code is grouped into `core`, `features`, and `shared`; each feature separates data, domain, and presentation where needed. Dio is centralized and performs authorization attachment, one-at-a-time refresh, a single retry, and common error mapping. GoRouter owns navigation and auth redirects.

The access token is memory-only. The refresh token uses platform secure storage. Web clients cannot fully protect browser-accessible secrets against XSS, so CSP, dependency hygiene, HTTPS, and a future HTTP-only cookie option remain important production controls.

## ADR-006: Explicit production migrations

**Status:** Accepted

Development seeding, when explicitly enabled, applies migrations for an easy local Compose startup. Non-Development environments never migrate at process startup. Deployment automation must run `dotnet ef database update` (or reviewed idempotent migration scripts) as a controlled release step.

## Future GPS integration

Fleet is not implemented in Sprint 1. When introduced, location ingestion will depend on an application-facing tracking contract (for example, `ITrackingProvider`) and vendor adapters will live in Infrastructure. Domain truck models will not reference Traccar, Wialon, or another provider SDK.
