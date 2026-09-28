# Sprint 4.3 Evidence

Recorded on 2026-09-27 in Europe/Istanbul. This evidence separates automated,
database, and real-browser proof; it does not treat API fixture setup as UI
proof.

## Automated proof

- .NET Release build: passed with 0 warnings and 0 errors.
- Complete backend suite: 87/87 passed, including six focused Sprint 4.3
  identity, membership, invitation/connection, QR/session, and handover tests.
- Flutter analyzer: clean.
- Complete Flutter suite: 84/84 passed, including six focused Sprint 4.3
  contract, Google configuration, QR-adapter, localization, and RTL tests.
- Flutter Web release build: passed.
- Architecture tests keep tenant-owned repositories scoped and explicitly
  allow only reviewed global identity stores.
- The fake external-identity verifier proves verified Google creation,
  subject/email collision handling, explicit linking, unlink-last-method
  protection, invalid tokens, and the unconfigured boundary. No live Google
  success is claimed.

## Isolated PostgreSQL and migration proof

A disposable Compose project named `tms-s43` used PostgreSQL 18 on host port
55433 and the API on host port 55080. It did not share the retained
`tms-smoke` database or volumes.

- All 13 migrations, including
  `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`, applied and
  both containers became healthy.
- `dotnet ef migrations has-pending-model-changes` reported no changes.
- A separate disposable legacy database was migrated only through Sprint
  4.2.2, populated with a legitimate legacy Driver login and refresh token,
  then upgraded. The account ID and password hash were byte-for-byte
  preserved; company, Driver link, role, locale, notification preference, and
  refresh-token account/membership mapping were preserved.
- The migrated legacy Driver authenticated successfully through the running
  API and returned the expected company, role, Driver ID/name, locale, and
  preference.
- Adding a second membership and attempting Down caused the documented
  rollback guard to refuse the lossy collapse. The Sprint 4.3 migration stayed
  applied.
- The new migration invents no company, account, Driver, truck, trip, or
  geography. Fresh-database development seeding created only the configured
  Owner account, Owner membership, and role.

## Real Firefox proof

Firefox and geckodriver were available. Each `flutter drive` invocation used
a newly created browser profile.

Passed real UI scenarios:

1. The isolated Owner logged in with local credentials, reached the dashboard,
   opened the account identity menu, logged out, and returned to login.
2. The Owner opened Access Management, created a Driver invitation through the
   UI, and received the one-time copy-link UI.
3. After logout, the public invitation screen previewed the invitation and
   accepted a new self-owned local account/password through the UI.
4. A second independent Firefox profile logged in as that invited Driver,
   reached the Driver workspace (including the honest not-yet-linked state),
   opened the account menu, and logged out.
5. Existing English/Arabic, RTL/LTR, workspace, membership, QR/manual fallback,
   handover modal, trip-preservation, map, and notification paths are covered
   by the complete widget and backend integration suites.

Not claimed as real-browser proof: the full three-party QR/handover scenario,
workspace switching, exact-code connection approval, default-truck assignment,
and physical-camera scan. Their domain/API and Flutter projections are
deterministically covered, but completing them through three simultaneously
open interactive browser profiles was outside this environment's completed
acceptance run.

The first browser run found an outdated logout test assumption because logout
moved into the account menu. The corrected test passed. The invitation run also
exposed authenticated pollers continuing after logout; dashboard,
notification, and Driver polling now stop when no session exists.

## Google, camera, Chrome, and Android limitations

- No Google OAuth project/client credentials were present, so live Google login
  and linking were unavailable and are not claimed.
- The Flutter client now uses the official `google_sign_in` integration:
  Google Identity Services renders the Web button, while native/Android uses
  the platform launcher. ID tokens are sent immediately to the backend; Google
  access/refresh tokens are not stored. Separate Web, Android, and server
  audience identifiers are configurable.
- No physical camera/device was available. Manual truck-code fallback and a
  deterministic scanner adapter were tested; physical scanning is unverified.
- Chrome was not installed. Firefox Web is the real-browser result.
- Flutter doctor reported no Android SDK at the configured location and no
  device/emulator, so Android build/run is unverified.

## Data-safety proof

The retained `tms-smoke` services remained healthy. Final retained counts
match baseline exactly: 3 companies, 8 users, 120 trucks, 140 Drivers, and 142
trips. Retained container identities at final comparison were
`tms-smoke-api-1:a6dd0bd90fea` and
`tms-smoke-postgres-1:393645e9042b`. Retained volumes remained
`tms-smoke_postgres_data` and `tms-smoke_truck_photo_data` at their original
mountpoints. The user's `.env` has no diff. No retained credentials were reset
and no retained volume was recreated.

The disposable `tms-s43` project and its volume are removed at final cleanup.
No commit or push is part of Sprint 4.3.
