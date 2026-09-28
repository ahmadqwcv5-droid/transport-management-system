# Sprint 4.3 Implementation Plan

## Baseline

- Started: `2026-09-27 17:40:29 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `32f1867` (`feat(tracking): complete sprint 4.2.2 reliability`).
- Remote verification: `origin/main` is also `32f1867`.
- Initial worktree: clean except for the user-provided untracked Sprint 4.3 prompt, now organized in this sprint folder.
- Baseline .NET: build passed with 0 warnings and 0 errors; 81/81 tests passed.
- Baseline Flutter: analyzer clean; 78/78 tests passed.
- Retained `tms-smoke` business counts: 3 companies, 8 users, 120 trucks,
  140 drivers, and 142 trips. Retained mounts are
  `tms-smoke_postgres_data:/var/lib/postgresql` and
  `tms-smoke_truck_photo_data:/data/truck-photos`.
- Safety boundary: do not modify `.env`, credentials, retained business data,
  or retained volumes. Migration and browser fixtures use a separate disposable
  Compose project. Do not commit or push.

## Current architecture audit

### Authentication and refresh tokens

- `User` is currently `ITenantOwned`, contains one `CompanyId`, one `Role`,
  the password hash, locale, notification preference, and active flag.
- Email already has a global unique index and login uses normalized lowercase
  email plus BCrypt. Refresh tokens store a hash, rotate on refresh, and are
  currently tied to both `UserId` and `CompanyId`.
- JWTs contain `user_id`, `company_id`, one role claim, email, and JTI.
  Refresh checks only the tenant-bound user active flag; no membership exists.
- `AppDbContext` automatically filters every `ITenantOwned` entity by the
  current company claim, and separately filters `Company`. Identity lookup
  currently uses narrowly placed `IgnoreQueryFilters` calls.
- Password change revokes tokens and preserves BCrypt, but Owner company-user
  creation/reset currently generates and returns a temporary password. Sprint
  4.3 must replace that manager-owned credential flow with invitations.

### Company users, memberships, and Drivers

- Company access is currently represented by the tenant-bound `User`; there is
  no membership, membership state, multi-role representation, invitation,
  external login, or connection request.
- `Driver` is correctly tenant-owned and may exist without login access, but
  links through `Driver.UserId` to the current tenant-bound user. The unique
  `UserId` index is global and would incorrectly prevent one account linking to
  one Driver record in multiple companies.
- Owner-only company-user screens merge credential identity, company access, and
  Driver linking into one ambiguous status.

### Default truck, session, assignment, and history

- `Truck.DefaultDriverId` already models a company-scoped persistent default
  and drives the working assignment recommendation/idle Driver map.
- `DriverTruckSession` has filtered unique indexes enforcing one active session
  per company/Driver and company/truck. It currently requires a starting trip,
  records only last trip/end reason, and lacks source, initiator, and approver.
- Trip assignment stores the current truck and Driver on `Trip`. Trip events
  preserve structured audit metadata, but there is no explicit historical
  Driver participation boundary for evaluation or handover.
- Existing tracking, route plans, current-position projection, notifications,
  maps, and trip workflow are stable and will be preserved.

### Development seeding

- Development seeding is opt-in, requires an externally supplied password, runs
  migrations, and creates one company plus one Owner user only if the configured
  email is absent. It must be updated to create the matching global account and
  active Owner membership without inventing other records.

## Architecture decisions

- Keep the existing `users` table and IDs as the global personal account to
  preserve every password hash, audit FK, and login. Remove tenant ownership
  from the domain model and migrate the legacy `CompanyId`/single role into an
  active `CompanyMembership`. Retain legacy columns only as a guarded
  transition if required by PostgreSQL migration ordering, then remove them once
  the backfill is proven.
- Model membership roles as normalized rows with a unique
  membership/role constraint. This supports Owner + Driver without comma strings
  and maps directly to multiple JWT role claims.
- Make refresh tokens account-scoped and optionally membership-scoped. A
  workspace-selection token has no company/role claims; normal operational
  tokens require an active membership. Login automatically selects exactly one
  active membership; multiple memberships require explicit switching.
- Keep global identity queries in a dedicated identity store. Never disable
  tenant filters in general-purpose business repositories.
- Add provider-neutral external login verification. Google configuration is
  optional; the fake verifier proves policy in tests. Do not store Google access
  or refresh tokens and never link solely by email.
- Store invitation and truck QR raw secrets only as SHA-256 hashes. Company
  connection codes are high-entropy, normalized, exact-match values with a
  server-side hash and rate-limited lookup.
- Extend sessions rather than overload default assignment. Sessions become
  trip-optional and record source, initiator, approver, and end reason.
- Add immutable `TripDriverParticipation` and explicit handover requests.
  Approval updates current assignment/session/participation in one transaction
  with optimistic concurrency while preserving the same Trip, route, tracking,
  progress, trail, and position data.
- Reuse stable event codes and structured notification/audit payloads. Do not put
  localized English text in domain state.

## Rejected alternatives

- Do not create a second account table and duplicate password hashes/FKs.
- Do not retain `CompanyId` as the authorization source on the global account.
- Do not encode multiple roles in one unvalidated string.
- Do not accept arbitrary client-supplied company IDs or Google email claims.
- Do not store raw invitation, connection, refresh, OAuth, or QR secrets.
- Do not make default truck assignment start a session or trip.
- Do not silently steal an occupied truck or overwrite trip Driver history.
- Do not add public company/Driver discovery, fake OTP, or fake live Google/QR
  camera evidence.

## Migration and data-safety strategy

1. Preflight normalized-email and Driver-link conflicts in the migration and
   fail with an actionable error rather than merge accounts.
2. Add memberships, roles, external logins, invitations, connection requests,
   identity audit, QR credentials, enhanced session fields, handover requests,
   and participation using additive nullable-safe steps.
3. Backfill one active membership and one membership-role row per legacy user,
   preserving account ID, password hash, active state, company, role, Driver
   link, refresh history, locale, and timestamps.
4. Convert refresh tokens to account/membership semantics and revoke only when a
   legacy token cannot be mapped safely.
5. Backfill participation for currently assigned trips from the existing
   Driver assignment without changing Trip IDs or operational state.
6. Add reviewed unique/filtered constraints only after conflict guards.
7. Apply first to isolated PostgreSQL, inspect Up/Down, test migrated local
   Owner/Driver login, and run EF pending-model checks.
8. A fully lossless Down after new multi-membership data is impossible; Down
   will be guarded and refuse collapse when an account has multiple memberships
   or roles instead of discarding access relationships.
9. Compare retained business counts and volume identities read-only. Never seed
   Sprint fixtures into `tms-smoke`; remove the isolated stack afterward.

## Task checklist and acceptance criteria

- [x] Complete baseline audit, conflict inventory, implementation plan, and test baseline.
- [x] Implement global accounts, memberships, multi-role authorization, active-workspace tokens, and safe migration.
- [x] Implement local-auth compatibility, provider-neutral Google verification/linking, and phone-provider extension boundary.
- [x] Implement secure invitations, exact company-code connections, membership lifecycle, audit, and notifications.
- [x] Formalize default truck assignment; implement secure truck QR credentials and transactional active sessions.
- [x] Implement approval-based active-trip handover with immutable Driver participation and authorization.
- [x] Implement responsive Flutter account/workspace/membership/invitation/connection/QR/handover UX in English and Arabic.
- [x] Add backend/Flutter regression coverage and pass full build, tests, EF migration/drift, and Web release.
- [x] Complete isolated Firefox acceptance, data-preservation proof, evidence, documentation, cleanup, and final audit.

## Testing matrix

| Area | Required proof | Result |
|---|---|---|
| Baseline | .NET build/tests and Flutter analyze/tests | Passed: .NET 81/81, Flutter 78/78 |
| Migration | conflict guards, legacy hashes/logins/roles/Driver links, isolated PostgreSQL, guarded Down, drift | Passed: 13 migrations; legacy hash/login/link preserved; guarded Down; no drift |
| Accounts/workspaces | one/multi/none, switch, refresh revalidation, suspended/revoked, tenant isolation | Passed in focused backend and Flutter tests |
| External auth | fake Google validation/link/unlink/conflicts/unconfigured; no live claim without credentials | Passed deterministically; official client wired; live credentials unavailable |
| Invitations/connections | full lifecycle, token hashing, exact code privacy, explicit Driver link | Passed automated; invitation also passed Firefox UI |
| QR/sessions | regeneration, cross-tenant protection, unique active sessions, default separation | Passed automated; physical camera unavailable |
| Handover | no pre-approval mutation, atomic approval, stale/idempotent/rejection, participation, permissions | Passed focused integration tests; full three-profile Firefox scenario not completed |
| Flutter | analyzer/full/focused, localization/RTL, workspace and operations workflows | Passed: analyzer clean, 84/84 tests |
| Web/browser | release build and independent Owner/Driver A/Driver B Firefox profiles | Release passed; Owner invite/accept and independent Driver profile passed; full Driver A/B handover not completed |
| Data safety | isolated cleanup, retained counts/volumes, `.env` unchanged | Passed: 3/8/120/140/142 unchanged; retained volumes intact; isolated removed |

## Task timing

Times are recorded at task boundaries. Active elapsed excludes explicit
user/environment pauses; concurrent work is not double-counted.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline audit, prompt organization, retained snapshot, baseline validation, and implementation plan | 2026-09-27 17:40:29 +03:00 | 2026-09-27 17:45:23 +03:00 | 4m 54s | Completed |
| 2 | Global identity/membership domain, persistence, authorization, and migration | 2026-09-27 17:45:23 +03:00 | 2026-09-27 18:32:23 +03:00 | 47m 00s | Completed |
| 3 | Authentication, workspace switching, Google abstraction, invitation, and connection APIs | 2026-09-27 18:32:23 +03:00 | 2026-09-27 18:48:00 +03:00 | 15m 37s | Completed |
| 4 | Default assignment, QR/session switching, handover, participation, audit, and notifications | 2026-09-27 18:48:00 +03:00 | 2026-09-27 18:54:03 +03:00 | 6m 03s | Completed |
| 5 | Flutter multi-workspace, account, membership, QR, handover, localization, and Google GIS UX | 2026-09-27 18:54:03 +03:00 | 2026-09-27 19:48:00 +03:00 | 53m 57s | Completed |
| 6 | Focused and full automated validation, migration apply, drift, and Web release | 2026-09-27 19:48:00 +03:00 | 2026-09-27 19:57:00 +03:00 | 9m 00s | Completed |
| 7 | Isolated Firefox acceptance and regression evidence | 2026-09-27 19:57:00 +03:00 | 2026-09-27 20:15:00 +03:00 | 18m 00s | Completed with explicit scope limitation |
| 8 | Documentation, isolated cleanup, retained-data comparison, and final audit | 2026-09-27 20:15:00 +03:00 | 2026-09-27 20:26:03 +03:00 | 11m 03s | Completed |

## Final result and deferred work

Implementation completed at `2026-09-27 20:26:03 +03:00`; total active elapsed was `2h 45m 34s`. Backend build and 87/87 tests, Flutter analyzer and 84/84 tests, Web release, isolated migration/legacy compatibility/guarded Down, Firefox Owner invitation/acceptance and independent Driver login, retained-data comparison, and isolated cleanup passed. The full three-profile QR/handover workflow was not completed in Firefox and remains explicitly evidenced through deterministic integration/widget coverage rather than claimed as browser proof. Live Google, physical camera, Chrome, and Android were unavailable in this environment.

Phone/SMS OTP, public company or Driver search, driver
marketplace/load board, ratings, Sprint 4.4 onboarding, finance, maintenance,
documents, real GPS integration, SignalR redesign, and Android background
location remain deferred.
