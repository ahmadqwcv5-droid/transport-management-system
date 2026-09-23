# Sprint 3.5 Security and Observability Review

## Tenant and authorization boundaries

- All persisted operational entities still implement `ITenantOwned`; executable
  architecture tests verify global company filters and tenant-leading indexes,
  with explicit identity exceptions.
- Controllers accept resource IDs, never a company scope. Focused stores remain
  behind the authenticated `ICurrentUser`-derived `AppDbContext` filter.
- `IgnoreQueryFilters` in production remains limited to `IdentityStore` and
  `DevelopmentDataSeeder`, where a tenant claim does not yet exist. Test-only
  verification bypasses do not ship in the API.
- Assignment, dispatch, route freshness, status transitions, and resource
  reservation checks remain server authoritative. PostgreSQL partial unique
  indexes retain the concurrent double-booking backstop.
- Simulator mutation remains Development/Testing-gated and Owner-authorized.

## Secrets and diagnostics

- `.env` is ignored and untracked. No credential, access/refresh token, private
  key, or retained database data was added to the diff or browser evidence.
- CI uses disposable, explicit CI-only values and uploads only test reports on
  failure. It does not package environment files, build configuration secrets,
  or database volumes.
- Stable Problem Details codes and trace IDs remain the safe client-facing
  diagnostic contract. Serilog structured console logging remains the baseline;
  no new token/password/provider-secret logging was introduced.
- Trip events retain actor, UTC time, stable event code, source, and bounded
  metadata. The refactor keeps event writes in focused Application collaborators.

No new security or cross-tenant defect was found during source review,
architecture enforcement, integration tests, or the authenticated browser run.
