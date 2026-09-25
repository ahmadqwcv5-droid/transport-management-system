# Sprint 4.1.2 Implementation Plan

## Baseline and worktree

- Started: `2026-09-25 11:36:25 +03:00` (Europe/Istanbul).
- Baseline: `5ec2d98ca9c2aa815fd6a727f773cfc9a892e74d`
  (`feat(operations): add driver onboarding and live alerts`).
- Initial worktree: clean except for the user-provided untracked Sprint 4.1.2
  prompt. No unrelated user changes were present.
- The prompt will be preserved under this sprint directory. No commit, push,
  branch, or pull request is authorized by the sprint prompt.

## Current behavior and root-cause hypotheses

Sprint 4.1.1 evidence already records incomplete two-browser acceptance. Manual
testing now proves that simulator progress is indirectly driven by manager
Dashboard reads: the provider advances when queried, while Driver Workspace is
a persisted read projection. Shared browser storage can also replace an Owner
token with a Driver token, after which manager polling returns 401/403 and the
simulator stops producing samples. The current trip lookup excludes Completed
trips, so the Driver loses vehicle context after delivery. Driver map behavior
is implemented separately from the manager map. Marker bytes are cached, but
annotation updates may expose the underlying status circle during symbol
updates. Auth supports owner-issued resets but no authenticated self-change.

These hypotheses will be confirmed against code and deterministic tests before
the design is finalized.

## Tracking ingestion design

Introduce one company-explicit Application ingestion use case that accepts
provider samples, validates and normalizes them, applies meaningful-change and
bounded-heartbeat persistence, evaluates persisted geofence evidence, evaluates
tracking health, and persists idempotent notifications. HTTP reads and the
hosted simulator call the same use case; reads no longer generate movement.
Future GPS adapters can call this boundary without duplicating business rules.

## Simulator scheduling design

A scoped hosted service will run only for Development/Testing when the
Simulator provider is enabled. It will enumerate eligible companies through a
tenant-safe system store, execute one non-overlapping tick per configured
interval, isolate per-company failures, and honor cancellation. Default tick is
2 seconds with a safe clamp. Testing will use an injectable tick/clock seam.

## Trip lifecycle decision table

| Current | Authority/action | Next | Rule |
|---|---|---|---|
| Draft | Manager assigns | Assigned | Assignment never implies movement |
| Assigned | Driver `DEPART_TO_PICKUP` | EnRouteToPickup | Trusted position and current approach plan required when outside pickup |
| Assigned | Manager override with reason | EnRouteToPickup | Audited exception only |
| EnRouteToPickup | Ingestion/geofence | AtPickup | Stable persisted evidence only |
| AtPickup | Driver `CONFIRM_LOADED_AND_DEPART` | InTransit | Driver identity and assignment enforced |
| AtPickup | Manager override with reason | InTransit | Audited exception only |
| InTransit | Ingestion/geofence | AtDelivery | Stable persisted evidence only |
| AtDelivery | Driver `CONFIRM_DELIVERY` | Completed | Releases commercial reservations, retains vehicle session |
| AtDelivery | Manager override with reason | Completed | Audited exception only |

Legacy action aliases will remain only where compatibility requires them and
will map to one canonical transition without creating duplicate paths.

## Driver–Truck post-trip association

Add tenant-owned `DriverTruckSession` state with start/end timestamps, starting
and last trip references, end reason, and optimistic version. Partial unique
indexes enforce at most one active session per Driver and Truck. Driver
departure starts/reuses the association; completion updates `LastTripId` but
does not keep the commercial trip active. Explicit Driver end is allowed only
without an active reserving trip. Handoff closes the prior informational
session so previous Drivers immediately lose scoped location access.

## Geofence and notification latency budget

Target normal simulator end-to-visible alert latency is 10–15 seconds:

- provider tick: 2 seconds;
- stable evidence: at least 2 in-radius samples and 8 seconds dwell;
- ingestion-to-notification persistence: same transaction/use-case execution;
- manager/Driver live polling: 2 seconds;
- expected worst normal scheduling alignment: approximately 12 seconds plus
  request/render time.

Arrival radius, exit hysteresis, sample freshness, persisted observation, and
event-key uniqueness remain mandatory. Deterministic tests and browser evidence
will record actual segment timestamps instead of visual estimates.

## Map component and marker design

Extract a reusable single-vehicle controller/view contract from manager/Driver
behavior: Follow, Free, and RouteOverview camera modes; input-first follow
pause; one-shot route fit; stable marker image identity; route/stop/trail
updates; and current/stale/offline/provider states. Prefer persistent style
source/layer or stable annotation identity with coordinate/property updates.
Instrument 30 coordinate updates and require zero image fallback frames,
symbol remove/re-add operations, global clears, and style reloads after initial
load.

## Marker flicker investigation

Trace MapLibre image registration, symbol identity, async photo loading, widget
rebuilds, and style reload callbacks. The chosen correction will keep the same
registered `truckId + photoVersion + marker-format-version` image throughout
coordinate-only updates and must not temporarily assign the fallback asset.
Visual browser/frame evidence is required where the environment supports it;
operation counters alone will be labelled deterministic structural evidence.

## Password security design

Add authenticated `PUT /api/auth/me/password` for every role. Verify current
password; require confirmation, policy compliance, and a value different from
the current password; hash server-side; record an audit/security event; revoke
all refresh tokens; and require a fresh login after success. Apply endpoint
rate limiting if it fits the current middleware without weakening tests. No
password value may be logged, returned, or stored in evidence.

## API and migration changes

Expected additions are canonical tracking ingestion/scheduling ports and use
cases, Driver departure and vehicle-session actions, post-trip Driver Workspace
projection, password change, notification/audit events, timing configuration,
and one forward-only default-safe Sprint 4.1.2 migration for session storage and
constraints. Existing tenant data will not be backfilled with fabricated
sessions.

## Tenant and authorization analysis

Background processing must carry an explicit company ID and may not fabricate
an HTTP user. All session, trip, truck, position, notification, and user access
remains company scoped. Driver actions resolve the linked Driver from the JWT
identity and cannot accept an arbitrary Driver/company selector. The workspace
may expose only the active session truck and assigned/last trip summary.
Manager overrides require an authorized role, reason, and audit record.

## Test and browser acceptance matrix

- Backend: scheduler independence/non-overlap/disablement; ingestion
  idempotency/heartbeat; geofence latency; lifecycle authority/idempotency;
  session uniqueness/handoff/isolation; post-trip workspace; ETA fallback;
  password error codes/token revocation; fast notification deduplication;
  architecture rules.
- Flutter: backend-projected allowed actions; active/post-trip/empty workspace;
  shared camera behavior; real pointer boundary; ETA/age/status rendering;
  password validation/logout; two-second non-overlapping polling; notification
  dedupe; stable 30-update marker identity; English/Arabic layouts.
- Browser: disposable two-profile Owner/Driver workflow from assignment through
  end session and password change, with real gestures, map style, geofence
  timestamps, 30 moving frames, and retained before/after counts.

## Data safety and disposable environment

Before migration/runtime work, record the exact retained Compose project,
PostgreSQL/photo volumes, active tenant/account, and company resource counts.
Acceptance will use a new Sprint 4.1.2 disposable Compose project/volumes (or a
verified extension of the existing fail-closed pattern) and must reject the
retained volume. No retained migration will be applied for acceptance. If a
retained migration later becomes necessary for user manual testing, create a
timestamped untracked `pg_dump` first and document it.

## Risks and deferred work

- Flutter WebDriver/Firefox previously failed before end-to-end completion;
  harness failures must be diagnosed, not hidden.
- MapLibre visual flicker proof may require non-headless frame recording.
- Browser autoplay may prevent physical sound; instrumented invocation remains
  valid only when clearly labelled.
- High-frequency position storage must retain movement/heartbeat bounds.
- Android depends on the missing local Android SDK/device and does not replace
  Web acceptance.
- SignalR, push, real GPS, finance, maintenance, proof of delivery, route
  optimization, and full shift management remain deferred.

## Task timing

Times are updated while work occurs; unfinished rows are not estimates.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Plan, baseline, and retained/disposable safety audit | 2026-09-25 11:36:25 +03:00 | 2026-09-25 11:38:52 +03:00 | 2m 27s | Complete |
| 2 | Architecture inspection and final technical design | 2026-09-25 11:38:52 +03:00 | 2026-09-25 11:54:06 +03:00 | 15m 14s | Complete |
| 3 | Backend, migration, lifecycle, scheduler, session, auth, and tests | 2026-09-25 11:54:06 +03:00 | 2026-09-25 12:17:49 +03:00 | 23m 43s | Complete |
| 4 | Flutter map/workspace/auth/alert responsiveness and tests | 2026-09-25 12:17:49 +03:00 | 2026-09-25 12:19:43 +03:00 | 1m 54s | Complete |
| 5 | Full automated, Docker, browser, latency, marker, and data validation | 2026-09-25 12:19:43 +03:00 | 2026-09-25 12:23:24 +03:00 | 3m 41s | Complete; mandatory browser workflow failed |
| 6 | Evidence, documentation, timing, and final audit | 2026-09-25 12:23:24 +03:00 | 2026-09-25 12:25:52 +03:00 | 2m 28s | Complete |

**Total active sprint time:** 49m 27s.

## Implementation outcome

- Tracking reads are side-effect free. The Development/Testing hosted worker
  advances the simulator through one company-explicit ingestion path and
  continues when no browser is open.
- Driver departure is authoritative for the normal Assigned-to-approach
  transition. Pickup/delivery arrivals remain system-controlled; manager
  equivalents require an audited reason.
- Tenant-owned Driver–Truck sessions retain only the assigned truck projection
  after completion and enforce unique active Driver/Truck ownership.
- Driver Workspace supports active and post-trip maps, shared camera semantics,
  server-projected actions, ETA fallback, explicit session end, and two-second
  non-overlapping polling.
- Authenticated password change verifies current credentials and policy, writes
  an audit event, revokes all refresh tokens, and logs the client out.
- Shared versioned marker identity and in-place updates passed 30 consecutive
  movement updates without structural fallback or symbol recreation.

## Final validation and acceptance status

- Solution build: passed with zero warnings/errors.
- Architecture tests: 11/11 passed.
- Backend integration tests: 60/60 passed.
- Flutter analyzer: no issues; Flutter tests: 52/52 passed.
- Flutter Web build and isolated Docker API health: passed.
- Migration `20260925084826_Sprint412DriverOperationsTracking` applied to the
  disposable database only.
- With no browser running, disposable position rows increased from 361 to 369
  over ten seconds. Measured pickup dwell was 8.002–10.001 seconds and
  notification persistence followed confirmation by 10–16 milliseconds.
- Retained tenant counts match the before snapshot exactly; disposable
  containers are stopped with their volumes preserved and retained PostgreSQL
  is restored.
- Android build/run is unavailable because there is no installed Android SDK
  platform/build tools or device/emulator.
- The mandatory two-independent-browser workflow **did not pass**. Firefox and
  Flutter Web reached the isolated backend and created the scenario, but the
  legacy Flutter Drive harness ended with six aggregated client exceptions.
  Therefore Sprint 4.1.2 is incomplete under its real-browser Definition of
  Done, despite the passing implementation and automated/runtime validation.

Evidence is stored in `docs/evidence/sprint4_1_2/`. Changes remain uncommitted
and unpushed as required by the Sprint prompt.
