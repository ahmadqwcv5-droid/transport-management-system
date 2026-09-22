# Sprint 3.3.1 Implementation Plan

## Objective

Make the Sprint 3.3 dispatch workflow usable entirely through the Development
Flutter UI: inventory every active truck, explicitly set or refresh its simulated
location, keep stationary online simulator reports fresh with bounded GPS-like
heartbeats, and show trip-planner stop markers immediately before route calculation.

## Baseline Findings and Failure Reproduction

- Baseline is `main` at `3460546`; `origin/main` matched after fetch.
- The pre-existing untracked `transport_management_sprint3_1_codex_prompt.md`
  is unrelated and will remain untouched. The Sprint 3.3.1 prompt is task input.
- The simulator panel receives only `DashboardResponse.Positions`. That response
  is an inner join between latest positions and active trucks, so a newly created
  truck with no `TruckPosition` cannot appear in the selector. Although the
  backend accepts `seed-position`, Flutter exposes no coordinate input or picker.
  This reproduces the circular No-location failure directly from the current
  data flow.
- `SimulatedTrackingProvider.GetCurrent` emits only for a route-aware moving
  target. Seeded, paused, AtPickup, completed, and otherwise stationary trucks
  emit nothing. `TrackingService` therefore cannot append a new report, while
  dispatch rejects the unchanged persisted row after the configured 300-second
  maximum age. This reproduces the stationary-staleness failure.
- Existing `TrackingPolicy.HistoryHeartbeat` bounds duplicate writes, but it is
  not a device heartbeat: no stationary sample reaches `ShouldPersist`.
- Per-truck online/offline controls currently construct provider state only for
  route-aware targets, so an idle seeded truck cannot reliably be toggled.
- Trip planner map taps update form text but `_RoutePreview` draws stop circles
  only when a calculated route exists. Manual/search changes likewise have no
  immediate marker feedback.
- Backend simulator registration already requires Development/Testing,
  `Tracking:SimulatorEnabled=true`, and provider `Simulator`; the control API is
  Owner-only. Flutter additionally has the compile-time
  `ENABLE_SIMULATOR_CONTROLS` gate.

## Heartbeat Ownership and Persistence Design

- The simulator provider will own stationary report generation. It will retain
  online/offline state for every active-truck target, not only trucks with an
  executable route, and emit a same-coordinate sample only when a persisted
  simulator coordinate exists.
- Application persistence remains event-aware. A dedicated configurable
  `Tracking:SimulatorHeartbeatSeconds` interval will be clamped below the
  dispatch maximum-position age and used only for simulator heartbeat samples.
  Coordinate, heading, movement phase, trip/route/repositioning association, and
  route distance remain unchanged.
- Default heartbeat interval: 15 seconds, clamped below both the online/offline
  threshold and dispatch freshness threshold. Expected upper bound while polled
  is 240 stationary rows per truck per hour, rather than one row per dashboard poll.
- Explicit refresh writes one current, online, same-coordinate report with no
  trip or route association. It is rejected for an explicitly offline position;
  the user must choose Set online first.
- Stop/offline suppresses online heartbeats. Online resumes at the persisted
  coordinate. A truck without a position never receives a fabricated sample.
- Real GPS ingestion remains outside this polling-driven Development provider;
  dispatch freshness enforcement stays unchanged for production data.

## UI Flow

1. Load an Owner-only simulator inventory that left-joins active trucks with
   optional latest position and backend-derived No location / Current / Stale /
   Offline state, age, freshness threshold, trip, and movement phase.
2. Select any active truck. Show state badge, last update, contextual helper,
   and valid actions.
3. Set or Move opens one reusable location picker with configured MapLibre map,
   backend geocoding search, manual latitude/longitude validation, selected
   marker, fallback/manual operation, explicit confirmation, and RTL support.
4. Refresh records the same coordinate without movement. Offline requires an
   explicit Online action.
5. A missing/stale dispatch-preview error in Development exposes the same picker
   or refresh action, reloads the trip data, and leaves retry under user control.
6. Trip planning reuses deterministic marker-update behavior so pickup/delivery
   markers appear immediately and remain synchronized across map, search, manual,
   and Draft-edit initialization.

## Security Boundary

- Backend mutation remains impossible unless the simulator provider was
  registered by the Development/Testing environment plus configuration gate.
- Simulator inventory and mutation endpoints remain authenticated, tenant
  filtered, and Owner-only under existing conventions.
- Truck existence/activity and coordinate validity are checked server-side;
  stable ProblemDetails codes cover disabled, unauthorized, invalid, missing,
  stale, and offline cases.
- Flutter compiles all simulator mutation affordances out of the visible UI
  unless `ENABLE_SIMULATOR_CONTROLS=true`; disabled-build widget coverage will
  prove the boundary.

## Ordered Tasks

1. Record baseline and focused failing regressions for inventory omission,
   stationary staleness, and missing immediate stop markers.
2. Add simulator inventory/state contracts, explicit seed/refresh semantics,
   all-truck control state, and bounded stationary heartbeat behavior.
3. Add configuration defaults and backend tests for tenant isolation, disabled
   provider, coordinates, associations, freshness, bounded writes, pause,
   offline/online, preview recovery, and restart behavior.
4. Build the reusable Flutter picker and simulator inventory panel with state
   badges and contextual controls.
5. Add trip-details recovery and immediate incremental pickup/delivery markers.
6. Add English/Arabic localization and Flutter behavior/security/map tests.
7. Update README/architecture, run all builds/tests/drift checks, restore the
   retained Compose stack, and execute the real Firefox/PostgreSQL workflow.

## Automated and Browser Test Plan

- Backend tests will assert No-location inventory, valid and invalid seed,
  cross-tenant denial, disabled simulator, association isolation, bounded
  heartbeat persistence beyond the dispatch window, unchanged coordinates and
  progress, pause/offline/online semantics, refresh isolation, genuine stale
  rejection, preview recovery, assignment stability, and provider recreation.
- Flutter tests will assert inventory parsing, state/action behavior, picker map
  and manual selection, validation, explicit refresh, production hiding,
  recovery actions, localization, immediate stable stop markers, and unchanged
  annotation/camera guarantees.
- The real browser workflow will use visible UI controls to create an unlocated
  truck, recover from the missing-position preview error, select a real-map
  coordinate, observe bounded heartbeats beyond a shortened safe freshness
  window, exercise pause/offline/online/move, verify map stability and EN/AR,
  and prove immediate pickup/delivery marker updates before route calculation.

## Risks and Decisions

- Browser-driven Development polling currently samples the simulator; heartbeat
  ownership is nevertheless centralized in the backend provider/application and
  not a Flutter timer. A future ingestion worker can invoke the same boundary.
- Public OpenFreeMap/OSRM/geocoding availability can affect live evidence;
  manual coordinates and deterministic automated tests remain supported.
- Heartbeat persistence intentionally appends auditable rows at a bounded rate;
  rewriting historical timestamps would misrepresent received GPS reports.
- Stationary heartbeats preserve the previous movement context so they never
  create a leg transition or false distance. Explicit Set/Move/Refresh creates a
  current-location report with no trip association.
- No EF migration is expected because existing `TruckPosition` persistence is
  sufficient; model-drift verification remains mandatory.

## Acceptance Checklist

- [x] Every active truck appears with an authoritative location state.
- [x] Visible Flutter controls set/move/refresh the first simulated coordinate.
- [x] Picker supports map, search, manual input, fallback, EN/AR, and validation.
- [x] Missing/stale trip errors provide Development-only recovery.
- [x] Stationary online heartbeat stays fresh with bounded persistence.
- [x] Pause, Stop, Offline, Online, assignment, progress, and restart semantics remain correct.
- [x] Production/disabled UI and backend cannot mutate simulated coordinates.
- [x] Trip pickup/delivery markers appear immediately and update without duplicates.
- [x] Backend, Flutter, EF, Web, Compose, PostgreSQL, and real-browser validation pass.
- [x] Android is validated or its exact environment limitation is recorded.
- [x] No commit, push, volume deletion, credential overwrite, or unrelated-file change occurs.

## Elapsed Time

| Task | Started (UTC) | Finished (UTC) | Elapsed | Status | Result |
|---|---:|---:|---:|---|---|
| Baseline fetch, architecture trace, failure reproduction, and plan | 2026-09-21 16:07:01 | 2026-09-21 16:08:18 | 00:01:17 | Completed | Confirmed both failures from executable data flow and recorded the corrective design |
| Backend inventory, location controls, and heartbeat | 2026-09-21 16:08:18 | 2026-09-21 16:32:30 | 00:24:12 | Completed | Added tenant-safe all-truck inventory, Set/Refresh, provider state restoration, and bounded stationary heartbeat |
| Flutter picker, recovery, simulator panel, and stop markers | 2026-09-21 16:32:30 | 2026-09-21 16:50:12 | 00:17:42 | Completed | Added shared picker, location-state actions, recovery UX, immediate incremental stop markers, and EN/AR strings |
| Automated tests and documentation | 2026-09-21 16:50:12 | 2026-09-21 17:07:30 | 00:17:18 | Completed | Backend 38/38 and Flutter 36/36 pass; analyzer, build, EF drift, README, and architecture completed |
| Compose, PostgreSQL, browser evidence, and final validation | 2026-09-21 17:07:30 | 2026-09-21 18:11:26 | 01:03:56 | Completed | Retained-volume stack healthy and normal configuration restored; Firefox workflow passed; 14 screenshots, JSON, and PostgreSQL evidence retained; Android SDK absent |

Total active sprint time: **02:04:25**.

## Git and Data Safety

All Sprint 3.3.1 changes will remain uncommitted and unpushed. The unrelated
Sprint 3.1 prompt, `.env`, owner credentials, and retained PostgreSQL volume will
not be modified or deleted.
