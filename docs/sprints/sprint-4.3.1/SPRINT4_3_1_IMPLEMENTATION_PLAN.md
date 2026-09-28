# Sprint 4.3.1 Implementation Plan

## Baseline

- Started: `2026-09-28 14:34:57 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `3ff880a` (`feat(identity): complete sprint 4.3 accounts and handover`).
- Initial worktree: the user-provided Sprint 4.3.1 prompt plus two unrelated SQL backups under the Flutter app. The backups remain untouched and untracked; the prompt is organized in this sprint folder.
- Retained Compose project: `tms-smoke`.
- Retained containers: API `2e84950232346f72577976bb136b08d7eae632a3ad931993700457a4b2c88967`; PostgreSQL `a44107485fb7c3a311ef8524a85f439b501356638f1840fc88d8b15b90ba6ace`; both healthy.
- Retained volumes: `tms-smoke_postgres_data` and `tms-smoke_truck_photo_data`.
- Retained business counts: 3 companies, 9 accounts, 120 trucks, 140 Drivers, and 144 trips.
- Latest retained migration: `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`.
- `.env` integrity baseline recorded without reading or copying its values. It must remain unchanged.

## Safety boundary

- Preserve the retained database, photo data, credentials, Owner password, OAuth configuration, and `.env`.
- Never run Compose with `down -v`; never recreate retained named volumes.
- Use isolated data for destructive fixtures and acceptance setup.
- Avoid a schema migration unless the audited model genuinely requires one.
- Do not commit or push unless the user explicitly requests it.

## Architecture audit

- User is a global personal account. CompanyMembership grants tenant access,
  and normalized CompanyMembershipRole rows carry one or more roles.
- JWTs select exactly one membership/company. Every authenticated request reloads
  the active membership and sorted roles; stale access tokens fail immediately
  after a role or membership change. Membership refresh tokens are revoked on
  role/lifecycle changes.
- The authorization matrix is:
  - Owner: view members; invite any role; edit roles; suspend/reactivate/revoke;
    link/unlink Driver profiles; manage truck QR credentials.
  - Operations: view members; invite non-Owner roles; link/unlink eligible Driver
    profiles; manage truck QR credentials. Operations cannot grant Owner or
    change membership roles/lifecycle.
  - Driver/Accountant/Employee: no company access-management mutation.
- Driver linking is an explicit post-acceptance relationship. A link is
  tenant-scoped and one-to-one, is idempotent when repeated, never steals an
  existing link, and cannot be removed during an active trip, active
  Driver-truck session, or pending handover.
- TruckQrCredential stores only a hash and hint. The status endpoint exposes
  metadata only; generation returns the raw secret once. Regeneration revokes
  the prior credential and PostgreSQL retains one filtered active credential.
- Invitation URLs come from validated Frontend:PublicBaseUrl, never request
  Host headers. Flutter hash routing uses the accept-invitation hash route.
- Google ID tokens remain verified server-side for issuer, signature, lifetime,
  verified email, configured audience, and optional nonce. UI availability now
  requires both the platform client identifier and backend provider readiness.
- Problem Details preserves stable errorCode and traceId; Flutter maps the
  affected role/link/QR/invitation/Google codes in English and Arabic.

## State model

    Global User
      -> CompanyMembership (tenant access and lifecycle)
          -> CompanyMembershipRole[] (authorization)
          -> optional tenant Driver link (operational identity)
              -> optional active DriverTruckSession
              -> optional reserved Trip assignment/participation

    Truck
      -> optional default Driver (planning preference)
      -> optional active DriverTruckSession (current operation)
      -> optional active hashed TruckQrCredential (access handoff)

These relationships are deliberately independent: editing roles does not change
a Driver link; linking a Driver does not assign a trip; scanning a free truck QR
changes only the active session; approving a handover changes participation and
the active trip Driver without changing the truck, route, or history.

## Risks and rollback

- Authorization changes can strand a tenant without an Owner or leave stale JWT permissions; enforce rules transactionally and retain request-time membership/role validation.
- Driver linking can corrupt operational ownership if it steals an existing link or ignores active work; reject unsafe mutations with stable errors.
- QR regeneration destroys usability of the previous raw secret by design; retain one active hashed credential and warn before regeneration.
- Invitation and OAuth flows carry bearer-like secrets; never log or persist raw invitation, QR, Google ID, JWT, cookie, or authorization-code values.
- UI changes must preserve English/Arabic, LTR/RTL, responsive layouts, and existing operational workflows.
- Application rollback is by reverting code. No migration is planned; if one becomes necessary, an isolated upgrade/Down proof will be added before retained activation.

## Task checklist

- [x] 1. Baseline audit, state model, retained snapshot, and baseline validation.
- [x] 2. Safe membership-role management and authorization invariants.
- [x] 3. Post-acceptance account-to-Driver linking and unlink safety.
- [x] 4. Complete QR status/generation/download/manual-code lifecycle.
- [x] 5. Complete invitation URLs and reliable hash deep links.
- [x] 6. Google login/link/invitation flows and honest availability.
- [x] 7. Actionable localized error handling and safe diagnostics.
- [x] 8. Complete backend and Flutter automated coverage.
- [ ] 9. Independent-profile Firefox acceptance and sanitized evidence (local
  auth and configured Google control passed; live Google account selection and
  consent remain a human acceptance step).
- [x] 10. Regression, retained-data comparison, documentation, activation commands, and final audit.

## Task timing

Times use Europe/Istanbul. Active elapsed excludes explicit user/environment pauses; concurrent validation is not double-counted.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline audit, state model, retained snapshot, and baseline validation | 2026-09-28 14:34:57 +03:00 | 2026-09-28 14:39:19 +03:00 | 4m 22s | Completed |
| 2 | Safe membership-role management and authorization invariants | 2026-09-28 14:39:19 +03:00 | 2026-09-28 14:53:10 +03:00 | 13m 51s | Completed |
| 3 | Post-acceptance account-to-Driver linking and unlink safety | 2026-09-28 14:53:10 +03:00 | 2026-09-28 14:57:40 +03:00 | 4m 30s | Completed |
| 4 | QR status/generation/download/manual-code lifecycle | 2026-09-28 15:01:20 +03:00 | 2026-09-28 15:08:50 +03:00 | 7m 30s | Completed |
| 5 | Complete invitation URLs and reliable hash deep links | 2026-09-28 14:57:40 +03:00 | 2026-09-28 15:01:20 +03:00 | 3m 40s | Completed |
| 6 | Google login/link/invitation flows | 2026-09-28 15:08:50 +03:00 | 2026-09-28 15:13:40 +03:00 | 4m 50s | Completed |
| 7 | Actionable localized error handling | 2026-09-28 15:13:40 +03:00 | 2026-09-28 15:17:10 +03:00 | 3m 30s | Completed |
| 8 | Complete automated coverage | 2026-09-28 15:17:10 +03:00 | 2026-09-28 15:24:10 +03:00 | 7m 00s | Completed |
| 9 | Real Firefox acceptance and sanitized evidence | 2026-09-28 15:24:10 +03:00 | 2026-09-28 15:45:39 +03:00 | 21m 29s | Browser readiness passed; human Google consent pending |
| 10 | Regression, safety comparison, documentation, activation, and final audit | 2026-09-28 15:45:39 +03:00 | 2026-09-28 15:58:19 +03:00 | 12m 40s | Completed |
| **Total** | **Sprint 4.3.1 active work** | **2026-09-28 14:34:57 +03:00** | **2026-09-28 15:58:19 +03:00** | **1h 23m 22s** | **Implementation complete; one human OAuth acceptance step remains** |

## Validation matrix

| Area | Required proof | Result |
|---|---|---|
| Baseline | Release build, backend tests, Flutter analyze/tests | Passed: baseline .NET 87/87; Flutter 84/84; analyzer clean |
| Roles/linking | authorization, invariants, tenant isolation, refresh behavior | Passed focused API coverage: escalation denied, self/last-Owner guards, stale token rejected, non-stealing/idempotent links, active-session unlink blocked |
| QR | status, one-time secret, PNG, regeneration/concurrency, manual entry | Passed API/model/UI coverage; status omits secret, full payload resolves, one active row; PostgreSQL concurrency maps to stable conflict |
| Invitations | complete URL, direct clean-profile open, single use | Passed deterministic API coverage for complete hash URL, mismatch non-consumption, acceptance, replay denial |
| Google | deterministic security tests plus real configured Firefox acceptance | Deterministic verifier/flow tests passed; configured backend and GIS Web control passed in fresh Firefox; final human Google account consent remains |
| Localization/UI | English/Arabic, LTR/RTL, desktop/mobile | Analyzer clean; Flutter 85/85; new stable errors generated for English/Arabic |
| Regression | full suites, Web builds, EF drift, health | Passed: .NET 91/91, Flutter 85/85, Release build, Web build, no EF drift, retained API healthy |
| Data safety | .env, counts, IDs, volumes, isolated cleanup | .env hash unchanged; counts remain 3/9/120/140/144; PostgreSQL ID and named volumes preserved |
