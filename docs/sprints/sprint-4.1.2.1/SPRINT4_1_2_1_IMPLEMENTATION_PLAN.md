# Sprint 4.1.2.1 Implementation Plan

## Baseline and initial state

- Started: `2026-09-25 15:07:06 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `6d7f0a9` (`feat(operations): add driver tracking workflow`), matching the prompt baseline and `origin/main`.
- Initial worktree: clean except for the user-provided untracked Sprint 4.1.2.1 prompt.
- Retained environment at start: `tms-smoke` API and PostgreSQL both healthy because the user had just resumed manual testing. `.env` is ignored and will not be changed.
- No commit, push, branch, or pull request is authorized by this sprint request.

## Confirmed root causes

- `DriverWorkflowService.DepartToPickupAsync` forwarded only the existing
  `CurrentRepositioningPlan` ID into manager-oriented dispatch. Outside the
  pickup radius, no plan therefore produced `REPOSITIONING_ROUTE_REQUIRED`, and
  the Driver had no route-preparation command.
- `DriverActions` considered only trip status, so it advertised departure even
  when telemetry was missing, offline, or too stale for the mutation.
- `DriverTripController` caught every action exception and returned `false`,
  discarding stable ProblemDetails codes before presentation.
- The departure button was rendered after a fixed 360px map and details card,
  leaving it below the fold on compact screens.
- assignment notification payloads contained only the trip number; the alert
  used a generic View label and navigation did not invalidate the workspace.
- every two-second Driver map update launched an unawaited annotation sync. Any
  photo, line, symbol, or camera error permanently replaced the map with an
  icon-only unavailable state, with no retry path.
- The prior browser harness called manager dispatch and therefore bypassed the
  Driver route-preparation behavior this repair must prove.

## Intended lifecycle and command boundary

The normal path remains `Assigned -> EnRouteToPickup -> AtPickup -> InTransit
-> AtDelivery -> Completed`. One Driver-owned Application command will resolve
the signed-in linked Driver/current assignment, validate trusted telemetry,
reuse or prepare a valid approach route without holding a database transaction
across provider I/O, revalidate assignment/position/version, start or reuse the
Driver–Truck session, and transition idempotently. Owner route preview remains
optional; manager override remains a reasoned audited exception.

## API and Flutter design checkpoints

- Add a server-owned Driver action/readiness projection with stable blocking
  codes while retaining `allowedActions` compatibility where required.
- Preserve stable ProblemDetails codes through Flutter and provide actionable
  English/Arabic recovery guidance.
- Put the primary departure panel before map/details on compact and desktop
  layouts with confirmation, loading, and duplicate-submit prevention.
- Make assignment alerts explicitly open and immediately refresh `/my-trip`.
- Keep Driver map operations serialized/latest-wins, preserve the last usable
  map on transient layer/photo failures, and expose loading/error/retry states.
- Keep two-second polling non-overlapping, scoped to the current auth session,
  and visibly stale after repeated transient failures.

## Tenant and authorization analysis

Driver commands derive company, Driver, trip, and truck from the signed token
and tenant-filtered assignment. The client submits no arbitrary operational IDs.
Route reuse must match tenant, trip, assigned truck, pickup/revision/profile,
source-position freshness/movement tolerance, and plan status. Driver APIs may
not expose another tenant's identifiers or invoke manager/simulator commands.

## Test and acceptance matrix

- Backend: missing/offline/stale telemetry; already-at-pickup; route generate,
  reuse, invalidation and provider failure; assignment race; idempotent/double
  departure; session/event uniqueness; tenant/role isolation; no-read simulator
  movement and tick budget.
- Flutter: actionable assignment alert/navigation; primary enabled/blocked and
  retry states; stable localized errors; immediate refresh; polling overlap and
  auth disposal; map pre-departure/loading/error/retry/latest-wins behavior;
  English LTR and Arabic RTL.
- Runtime/browser: disposable PostgreSQL/API and two independent browser storage
  contexts; Owner assigns through UI; Driver opens alert and departs through UI;
  no approach preview, manager override, direct departure API, or simulator step;
  prove persisted route/status/movement and continued movement without Owner
  polling.

## Retained-data safety strategy

Record non-sensitive retained tenant/user/resource/position/notification counts
before runtime work. Stop retained API after the snapshot to prevent simulator
writes, and use a distinct disposable Compose project and named volumes for
acceptance. Reject any resolved acceptance configuration that references
`tms-smoke_postgres_data` or `tms-smoke_truck_photo_data`. Do not migrate or
alter retained data. Restore the initial retained service state and compare
after-counts when validation ends.

## Task timing

Times are updated during execution. Unfinished rows are not estimates.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline, prompt, plan, and retained-data safety audit | 2026-09-25 15:07:06 +03:00 | 2026-09-25 15:08:48 +03:00 | 1m 42s | Complete |
| 2 | Trace root causes and finalize command/UI/test design | 2026-09-25 15:08:48 +03:00 | 2026-09-25 15:14:04 +03:00 | 5m 16s | Complete |
| 3 | Backend departure orchestration, readiness, and tests | 2026-09-25 15:14:04 +03:00 | 2026-09-25 15:26:29 +03:00 | 12m 25s | Complete |
| 4 | Flutter activation UX, navigation, map/polling repair, and tests | 2026-09-25 15:26:29 +03:00 | 2026-09-25 15:28:27 +03:00 | 1m 58s | Complete |
| 5 | Automated, migration, Docker, and real-browser acceptance | 2026-09-25 15:28:27 +03:00 | 2026-09-25 15:57:43 +03:00 | 29m 16s | Complete |
| 6 | Evidence, documentation, retained-data comparison, and final audit | 2026-09-25 15:57:43 +03:00 | 2026-09-25 16:03:22 +03:00 | 5m 39s | Complete |

**Total active sprint time:** 56m 16s.

## Final validation and unresolved limitations

Implemented one authoritative, idempotent Driver departure command with
telemetry/readiness validation, approach-route generation/reuse, concurrency
revalidation, session activation, and stable error codes. Flutter now presents
the primary confirmation before the map, preserves server error codes in
English/Arabic, opens and refreshes assignments explicitly from notifications,
keeps the last good projection during polling errors, and serializes map work
with latest-wins behavior.

Validation passed: solution build (0 warnings/errors), 66 integration tests, 11
architecture tests, EF pending-model check, Flutter analysis, 60 Flutter tests,
Flutter Web release build, isolated Docker startup, and the mandatory real
two-profile Firefox workflow. The browser path used Owner UI assignment and
Driver UI Open trip/departure, persisted an OSRM approach plan, reached
`EnRouteToPickup`, rendered the route in Driver and Owner maps, and increased
persisted trail points from 5 to 9 while the Owner profile was closed. It used
no Owner approach preview, manager override, direct departure API call, or
manual simulator step.

The retained stack was restored healthy. Business/notification/photo counts
match the before snapshot; 11 Demo Transport positions were added only after
the original retained simulator resumed. Android could not be built or run:
`ANDROID_HOME=/home/pc/Android/Sdk` points to a missing SDK directory and no
Android device/emulator exists. Evidence is under
`docs/evidence/sprint4_1_2_1/`.
