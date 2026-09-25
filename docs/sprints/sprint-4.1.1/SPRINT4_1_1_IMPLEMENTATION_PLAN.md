# Sprint 4.1.1 Implementation Plan

## Baseline and safety status

- Started: `2026-09-25T02:08:49+03:00` (Europe/Istanbul).
- Baseline: `3f741a5e41800666d1cd1a5217887c24c049e705` (`feat(operations): add live fleet driver workflow`).
- Initial worktree: clean except for the user-provided untracked Sprint 4.1.1 prompt.
- Safety gate: complete. The retained database was inspected read-only; no schema, row, container, or volume mutation occurred. Feature migrations and acceptance will target a separate disposable environment.
- Source prompt will be moved into this sprint directory after its contents are preserved.

## Existing implementation findings

The baseline already has tenant-scoped identity, drivers, trips, tracking, notifications, authenticated truck photos, manager map camera modes, and a role-aware Flutter shell. Manual acceptance exposed missing owner-driven account onboarding, ambiguous driver-workspace states, raw rectangular MapLibre photo symbols, gesture/follow races, hidden saved-site states, and no shell-level audible alerts.

The active stack is Compose project `tms-smoke`, API environment `Development`, PostgreSQL container `tms-smoke-postgres-1`, and mounted volume `tms-smoke_postgres_data` at `/var/lib/postgresql`. Three owner tenants exist in that database. `Demo Transport` retains 11 trucks, 5 clients, 9 drivers, and 28 trips; `Sprint 3.2.2 Smoke Tenant` contains 104 trucks, 83 clients, 127 drivers, and 95 trips; `Sprint321Smoke` contains 4 of each resource. The apparent data switch is tenant identity confusion, not row deletion: the original-looking fleet remains under `owner@demo.local`, while test fleets are visible under the smoke owners. No live Flutter/browser process was available from which to recover an active browser token, so there was no current authenticated browser session to identify. A second unmounted volume, `transport-management-system_postgres_data`, exists and is left untouched.

## Architectural decisions

Repository inspection confirmed the implementation seams. Company-user lifecycle belongs to a focused Application service and tenant-filtered Infrastructure store; the scoped `AppDbContext` is the transaction boundary for create-and-link. The existing unique nullable `Driver.UserId` index remains the database backstop. Driver workspace is composed server-side from the linked identity, current trip, fleet, photo, and tracking ports. Notification records remain the authority; Flutter overlays/audio react only to newly observed persisted IDs. Map photo bytes are transformed client-side into deterministic circular PNG symbols so the authenticated raw thumbnail endpoint remains unchanged.

## Database and migration design

One forward-only, default-safe Sprint 4.1.1 migration will be used if required. Planned candidates are temporary-credential state, notification-sound preference, audit records, and a database-enforced unique Driver-to-User link. Legacy rows will remain valid; links and preference history will not be fabricated.

## API changes

Planned surfaces:

- Owner-only tenant company-user list/create/activate/deactivate/reset operations.
- Transactional Driver/User create-and-link, link, replace, and unlink operations.
- Assignment projections exposing app-account state.
- Driver-scoped workspace projection with explicit state codes and no fleet-wide data.
- Per-user notification preference operations.
- Read-only environment/Compose diagnostic script without secret output.

## Flutter changes

Planned surfaces:

- Company Users and Driver account-link management.
- Assignment account-status badges and deliberate warnings.
- Driver workspace with scoped MapLibre map and explicit empty/offline states.
- Deterministic circular map-marker image pipeline and versioned cache.
- Input-first pause behavior for follow mode and explicit resume.
- Always-visible saved-site loading/empty/error/populated states.
- Shell-level queued notification overlay, injectable audio, and Settings controls.
- Account/company/role/non-production identity surface.
- Complete English/Arabic localization and responsive RTL/LTR layouts.

## Security and tenant isolation

- Every user/driver/trip/truck/position/preference query must be company scoped.
- Only Owners may manage company users and links.
- Password hashes and credentials are never returned or written to evidence.
- Generated temporary credentials may be returned once; reset/deactivation revokes refresh tokens.
- Driver endpoints expose only the linked Driver identity and assigned work.
- Acceptance must fail closed unless it uses a disposable Testing database/volume.

## Browser audio constraints

Notification history hydration is silent. Only unseen persisted notification IDs received later may enqueue an alert or request one rate-limited sound. Audio initialization requires a genuine user gesture; blocked playback produces an honest localized enable-sound action. Logout and mute disable playback immediately. A testable audio abstraction will support headless verification.

## Test matrix

- Backend: owner authorization, tenant isolation, duplicate/concurrent linking rules, refresh-token revocation, driver workspace states and scoping, preference isolation, notification deduplication, migration compatibility.
- Flutter: marker image shapes/fallback/cache, pointer and wheel follow pause, polling camera stability, saved-site states and immediate marker, workspace states, alert hydration/deduplication/mute, Arabic/English rendering.
- Builds: warning-clean .NET build, architecture/integration tests, EF migration and pending-model check, Flutter localization/format/analyze/tests, development and production Web builds.
- Runtime: healthy disposable Compose stack, real map style, two independent browser contexts, genuine pan/wheel across three polls, one alert/sound request per new event, retained counts unchanged.

## Acceptance workflow

The real-browser workflow will create the Driver record, Driver account, and link only through product UI in an explicitly disposable acceptance environment. It will cover assignment, saved sites, circular non-square photo marker, independent manager/driver sessions, driver-scoped map, real pointer/wheel input, follow resume, operational alert/sound deduplication, lifecycle completion, and English/Arabic rendering. It will compare retained-database counts before and after.

## Risks and deferred work

- Retained data may exist under another tenant or Docker volume; discovery must stop before any remount/recovery mutation.
- Browser autoplay and headless audio-device availability may limit acoustic verification, but instrumented play requests must still be proven.
- MapLibre browser automation can be timing-sensitive and requires real rendered input.
- Android depends on local SDK/device availability.
- Explicitly deferred: public registration, email/SMS invitations, background/browser/native push, SignalR, real GPS, finance, maintenance, multi-vehicle optimization, driver profile photos, proof-of-delivery uploads, and return-to-base.
- Forced first-login password change was not added to the current token contract. A
  server-generated policy-compliant temporary password is returned only from the
  immediate create/reset response, stored only as a hash, and reset/deactivation
  revokes refresh tokens. Adding a restricted password-change-only token state is
  deferred rather than weakening the existing authorization path.
- The real Firefox acceptance did not complete. The isolated API/UI workflow was
  exercised in parts, but two independent browser contexts, screenshots, rendered
  map gestures across three polls, full bilingual browser coverage, and physical
  audio remain unproven. Exact results are in `docs/evidence/sprint4_1_1/`.

## Task timing

Times below are recorded as work occurs; unfinished rows are not estimates.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline, plan, and non-destructive tenant/volume safety audit | 2026-09-25 02:08:49 +03:00 | 2026-09-25 02:11:40 +03:00 | 2m 51s | Complete |
| 2 | Architecture/current implementation inspection and final design | 2026-09-25 02:11:40 +03:00 | 2026-09-25 02:20:39 +03:00 | 8m 59s | Complete |
| 3 | Backend, schema, isolation, and diagnostic implementation | 2026-09-25 02:20:39 +03:00 | 2026-09-25 02:30:00 +03:00 | 9m 21s | Complete |
| 4 | Flutter UX, map, saved-site, alert/audio, and localization implementation | 2026-09-25 02:30:00 +03:00 | 2026-09-25 02:39:58 +03:00 | 9m 58s | Complete |
| 5 | Automated tests and disposable acceptance environment | 2026-09-25 02:39:58 +03:00 | 2026-09-25 03:32:30 +03:00 | 52m 32s | Complete with documented browser limitation |
| 6 | Full build, migration, Docker, browser, data-preservation, and platform validation | 2026-09-25 03:32:30 +03:00 | 2026-09-25 03:36:15 +03:00 | 3m 45s | Complete with documented browser/Android/audio limitations |
| 7 | Evidence, documentation, and final audit | 2026-09-25 03:36:15 +03:00 | 2026-09-25 03:39:13 +03:00 | 2m 58s | Complete |

**Total active sprint time:** 1h 30m 24s.

## Final validation summary

- .NET restore and warning-clean build passed with 0 warnings and 0 errors.
- Architecture tests passed 11/11; integration tests passed 59/59.
- The disposable PostgreSQL database applied the Sprint 4.1.1 migration and the
  EF pending-model check reported no drift.
- Flutter localization generation and formatting passed, analysis reported no
  issues, and Flutter tests passed 52/52.
- Development and production Web release builds passed. Their optional Wasm
  dry run reported the existing `flutter_secure_storage_web` incompatibility;
  the JavaScript builds completed successfully.
- Disposable API and PostgreSQL health checks passed. Its database volume is
  distinct from the retained `tms-smoke_postgres_data` volume.
- Retained truck/client/driver/trip counts exactly matched the before-test
  baseline for all three owner tenants.
- Firefox acceptance remains partial/failed as described in the evidence. No
  screenshot, two-context, real-map-gesture, or physical-audio pass is claimed.
- Android could not be built or run: no Android SDK platform/toolchain and no
  Android device/emulator are installed in this environment.
