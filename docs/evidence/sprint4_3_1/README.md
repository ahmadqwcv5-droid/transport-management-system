# Sprint 4.3.1 Evidence

Recorded on 2026-09-28 in Europe/Istanbul. This record separates automated,
retained-runtime, and browser evidence. It contains no passwords, raw QR or
invitation values, access tokens, OAuth identifiers, or personal screenshots.

## Automated proof

- .NET Release build: passed with 0 warnings and 0 errors.
- Complete backend suite: 91/91 passed.
- Focused Sprint 4.3.1 backend suite: 4/4 passed.
- Flutter analyzer: clean.
- Complete Flutter suite: 85/85 passed.
- Flutter Web JavaScript release build: passed.
- EF Core reported no pending model changes; this stabilization needed no new
  migration.

Focused coverage proves complete invitation hash URLs, mismatch
non-consumption and replay rejection; Operations escalation denial;
self/last-Owner protection; immediate rejection of stale access; idempotent,
non-stealing Driver links; active-session unlink protection; secret-free QR
status; full QR-payload resolution; one active credential; and cross-tenant
not-found behavior.

## Retained runtime proof

The retained `tms-smoke` PostgreSQL container and the named volumes
`tms-smoke_postgres_data` and `tms-smoke_truck_photo_data` were preserved. The
API image/container was rebuilt as expected and both services became healthy.
No retained volume was deleted or recreated.

Read-only business counts matched before and after activation:

| Entity | Before | After |
|---|---:|---:|
| Companies | 3 | 3 |
| Accounts | 9 | 9 |
| Trucks | 120 | 120 |
| Drivers | 140 | 140 |
| Trips | 144 | 144 |

The retained Owner authenticated, `/api/auth/me` returned the expected Owner
membership, company-user projection loaded, and the backend reported the
configured Google provider as available. The `.env` content hash remained
unchanged.

## Real Firefox proof

Fresh-profile, headless Firefox tests passed against the rebuilt retained API
and Flutter Web application on the configured `http://localhost:3000` origin:

1. Local Owner login reached the authenticated application, exercised current
   user/session behavior, logged out, and returned to login.
2. The application queried the live backend's external-provider readiness and
   rendered the real Google Identity Services Web control when both sides were
   configured.

The Google readiness run is genuine browser evidence of configuration and UI
availability; it is not represented as a completed Google account login. The
remaining acceptance step requires a person to select the existing Google
account, complete Google's consent UI if shown, and verify the callback/login
or invitation acceptance in that visible Firefox profile. This is a human
interaction boundary, not a missing client configuration.

No useful personal-data screenshot was retained. Physical camera scanning and
Android execution are not claimed; Web deliberately offers manual truck-code
entry while camera support remains unavailable.

## Security and data-safety proof

- QR status exposes only metadata and a hint; raw material is returned once on
  generation and never re-exposed.
- Invitation URLs are built from validated configuration rather than an
  untrusted request Host header.
- Refresh tokens are revoked after role changes and request-time membership
  revalidation rejects stale authorization immediately.
- Driver-link conflicts are audited and rejected instead of stealing an
  existing link.
- Stable error codes are localized in English and Arabic.
- The two pre-existing SQL backup files remain untouched and untracked.
- No commit or push is part of this task unless separately requested.
