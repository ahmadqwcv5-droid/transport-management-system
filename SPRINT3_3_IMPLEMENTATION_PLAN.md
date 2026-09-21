# Sprint 3.3 Implementation Plan

## Objective

Eliminate assignment-induced position teleportation and add an explicit,
auditable empty repositioning workflow from a truck's latest trustworthy
position to the cargo pickup. Keep repositioning metrics, geometry, progress,
tracking, and map layers separate from the immutable commercial cargo route.

## Baseline Architecture Findings

- Baseline is `main` at `133134a`; `origin/main` matches after fetch.
- The only pre-existing unrelated change is the untracked
  `transport_management_sprint3_1_codex_prompt.md`; it will remain untouched.
- `Trip` currently follows `Draft -> Assigned -> Started -> InTransit ->
  Delivered -> Completed`, with Assigned/Started/InTransit/Delivered reserving
  resources.
- Assignment itself only changes domain assignment fields, but
  `TrackingService.BuildTargets` immediately supplies the assigned trip's cargo
  geometry to the simulator.
- `SimulatedTrackingProvider.GetCurrent` emits a sample for every target with a
  route, even when `CanMove` is false. A new state begins at distance zero, so
  the next poll persists the pickup as the truck's current location.
- Cargo `TripRoutePlan` is immutable after assignment and already drives cargo
  progress. Repositioning must not be prepended to or stored as that route.
- Simulator execution anchors are process-local; a provider/API restart creates
  state at distance zero and can therefore reset active movement.
- Sprint 3.2.1/3.2.2 provide stable incremental annotations, event-only camera
  movement, trip/run-aware history, and segmented trails. Sprint 3.3 will extend
  those contracts rather than replace them.

## Reproducible Teleport Regression

Given a truck with a persisted position at Trip A's delivery, completing Trip A
and assigning the same truck to distant Trip B makes Trip B's cargo route the
active tracking target. The simulator creates a new target state at distance
zero. Although Assigned is non-moving, `GetCurrent` still returns the
interpolated distance-zero sample, and the application persists Trip B's pickup
as the latest position. A focused integration test will assert that assignment
plus repeated polling preserves the prior coordinates; it must fail before the
fix and pass afterward.

## Lifecycle and State Machine

```text
Draft
  -> Assigned
  -> EnRouteToPickup
  -> AtPickup
  -> Started
  -> InTransit
  -> Delivered
  -> Completed
```

- Assigned reserves resources but causes no movement.
- EnRouteToPickup means empty/deadhead execution and makes resources
  operationally busy.
- AtPickup means geographically arrived and waiting for loading/readiness.
- Started is an explicit operator confirmation that cargo execution may begin.
- InTransit remains the existing post-start cargo state.
- Cancellation remains allowed through InTransit and releases resources when
  they had been marked busy.

## Repositioning Data Model

Add tenant-owned `TripRepositioningPlan` with trip/truck identity, immutable
origin/destination coordinates, optional source position ID and timestamp,
GeoJSON/version/provider/profile metadata, planned distance/duration,
Proposed/Active/Completed/Expired status, calculation/dispatch/arrival times,
and audit timestamps. A trip may retain historical proposals, with at most one
Proposed/Active plan enforced by application rules and indexed tenant/trip/truck
lookups. Activation freezes the snapshot; stale proposals are expired and
regenerated rather than mutated.

Add nullable `MovementPhase` to `TruckPosition` for legacy compatibility. New
writes use `CurrentLocation`, `Repositioning`, or `Cargo`; repositioning plan ID
is a separate nullable foreign key and cargo `RoutePlanId` is never overloaded.

## Position Trust and Policies

Typed dispatch policy will bound:

- maximum current-position age;
- pickup arrival radius;
- proposal origin movement tolerance;
- simulator route-restoration projection tolerance.

Proposal/activation validates tenant-filtered truck ownership, valid coordinates,
online state, freshness, and matching assignment. Stable ProblemDetails codes
cover missing/stale/offline position, missing/stale approach route, distant
cargo start, and invalid transitions.

## API Design

- `POST /api/trips/{id}/repositioning/preview`: calculate server-side from the
  latest trusted position, persist a Proposed snapshot, or return
  `alreadyAtPickup` without meaningless geometry.
- `POST /api/trips/{id}/dispatch-to-pickup`: revalidate the proposal/current
  position, activate it and enter EnRouteToPickup; if already within the radius,
  enter AtPickup directly.
- `POST /api/trips/{id}/arrive-pickup`: idempotently evaluate proximity and enter
  AtPickup. The same backend evaluator is invoked after telemetry persistence.
- Existing `POST /api/trips/{id}/start`: allowed only from AtPickup and rechecks
  proximity.
- Trip responses expose the active/latest approach snapshot and separate planned
  deadhead distance/duration. Approach progress is separate from cargo progress.

## Simulator Continuity Design

- Assigned targets have no active movement geometry, so the simulator emits no
  synthetic route-zero sample.
- EnRouteToPickup targets use approach geometry and Repositioning phase; cargo
  states use cargo geometry and Cargo phase.
- Tracking targets include the latest persisted restore coordinate. When an
  in-memory state is absent or its leg changes, the simulator projects that
  coordinate onto the active immutable geometry and restores distance only when
  within the configured tolerance. Otherwise it preserves the known coordinate
  rather than teleporting.
- AtPickup has no moving leg and remains at the latest persisted pickup
  coordinate. Cargo begins from the same pickup within tolerance.
- A Development-only `seed-position` simulator command persists a deterministic
  current coordinate for otherwise untracked trucks; it remains behind the
  existing simulator/Owner gates.
- Real tracking providers remain vendor-neutral and may ignore route-restoration
  hints; arrival evaluation remains in the backend application layer.

## Migration and Compatibility

- Add the repositioning table and nullable position phase/approach association.
- Preserve all existing trips, cargo routes, and tracking records without
  invented plans or coordinates.
- Extend status strings and rebuild partial unique reservation indexes to include
  EnRouteToPickup and AtPickup.
- Use restrictive deletes for approach plans and their tracking references.
- Apply against the preserved PostgreSQL volume and verify zero EF drift.

## Ordered Tasks

1. Record baseline, architecture trace, plan, and failing teleport regression.
2. Implement lifecycle, repositioning model, position phase, policies, stores,
   migration, and API contracts.
3. Implement trust checks, preview/activation/arrival/start enforcement and
   independent progress.
4. Refactor tracking targets/simulator for active-leg selection, no assignment
   samples, deterministic seed position, arrival evaluation, and restart restore.
5. Update Flutter lifecycle actions, localized errors/statuses, approach progress,
   stable dashed amber map layer, and English/Arabic legend.
6. Add backend/Flutter coverage for lifecycle, isolation, trust failures,
   continuity, resource/cancellation rules, and map stability.
7. Update README/architecture, generate/apply/review migration, run all suites,
   Compose/API/PostgreSQL checks, Web build, and real Firefox evidence workflow.

## Test and Browser Strategy

- Backend tests cover the original teleport, every transition, position trust
  failure, proposal staleness, tenant isolation, provider failure, independent
  route/progress metrics, movement phases, arrival idempotency, cancellation,
  multiplier semantics, and restart restoration.
- Flutter tests cover contextual actions/endpoints, approach/cargo annotation
  identity, hidden cargo progress, localized errors/statuses/legend, stale layer
  cleanup, ten-poll zero clears, and zero poll camera moves.
- A dedicated smoke tenant runs Trip A to completion, reuses its truck for distant
  Trip B, proves Assigned stability/start rejection, previews/activates approach,
  restarts the API mid-leg without touching the volume, arrives, explicitly starts
  cargo, verifies 10x physical speed, manual pan, and English/Arabic real MapLibre.

## Risks and Explicit Decisions

- Public OSRM/OpenFreeMap availability can affect live evidence; deterministic
  provider/application tests remain authoritative for domain behavior.
- Arrival evaluation is called by the current polling ingestion path for
  Development. It is backend-owned so a future GPS ingestion worker can call the
  same service without Flutter or MapLibre.
- Proposed routes are auditable snapshots, not mutable caches. A changed origin
  expires the proposal.
- Planned approach distance/duration are retained for future profitability, but
  finance is out of scope.
- Cargo ETA remains operational real-world ETA; simulator acceleration changes
  demonstration progress only.

## Acceptance Checklist

- [x] Assignment and Assigned polling never change coordinates.
- [x] Repositioning model, metrics, progress, and tracking phase remain separate from cargo.
- [x] Position ownership/freshness/online/validity and proposal freshness are enforced.
- [x] Explicit dispatch, geographic arrival, AtPickup wait, and explicit cargo start work.
- [x] Simulator follows the active leg and restores after API restart without jumping.
- [x] Resource reservation, busy status, cancellation, and concurrency rules include new states.
- [x] Flutter actions, map layers, statuses, errors, and legends are localized and stable.
- [x] Backend/Flutter/EF/Web/Compose/browser validations pass with retained evidence.
- [x] Android is validated or its exact environment limitation is recorded.
- [x] No commit or push is performed.

## Elapsed Time

| Task | Started (UTC) | Finished (UTC) | Elapsed | Status | Result |
|---|---:|---:|---:|---|---|
| Baseline fetch, architecture trace, and implementation plan | 2026-09-21 08:13:41 | 2026-09-21 08:16:20 | 00:02:39 | Completed | Confirmed the route-zero sample path and recorded the separate-leg design |
| Teleport regression and detailed design | 2026-09-21 08:16:20 | 2026-09-21 08:19:00 | 00:02:40 | Completed | Reproduced 41.000 versus persisted 40.000, then passed after Assigned targets stopped emitting route-zero samples |
| Backend domain, persistence, API, and simulator | 2026-09-21 08:19:00 | 2026-09-21 09:32:00 | 01:13:00 | Completed | Implemented lifecycle, independent plans, trust policy, active-leg telemetry, arrival evaluation, and restart projection |
| Flutter workflow and map | 2026-09-21 09:32:00 | 2026-09-21 10:18:00 | 00:46:00 | Completed | Implemented contextual workflow, separate progress, dashed amber approach, localization, and stable annotation diffing |
| Automated tests and migration | 2026-09-21 10:18:00 | 2026-09-21 10:46:00 | 00:28:00 | Completed | Passed the initial 33 backend and 29 Flutter tests, analyzer, build, generated migration, and zero EF drift |
| PostgreSQL, browser, restart, integration fixes, and evidence | 2026-09-21 10:46:00 | 2026-09-21 11:52:02 | 01:06:02 | Completed | Applied retained-volume migration, rebuilt Compose, corrected the OSRM endpoint, passed real Firefox and API-restart workflows, and retained seven screenshots |
| Documentation and final validation | 2026-09-21 11:52:02 | 2026-09-21 12:04:57 | 00:12:55 | Completed | Finalized README, ADR, and evidence; added provider-failure regression; passed 34 backend tests, 29 Flutter tests, web release, EF drift, service health, and environment checks |

Total active sprint time: **03:51:16**.

## Final Validation Notes

- .NET solution build: succeeded with 0 warnings and 0 errors.
- Backend integration suite: 34 passed, 0 failed.
- Flutter analyzer: no issues; Flutter suite: 29 passed, 0 failed.
- EF Core: no pending model changes after applying
  `20260921083330_Sprint33DispatchToPickup` to retained PostgreSQL.
- Flutter Web release build: succeeded. The Wasm dry run reports the existing
  `flutter_secure_storage_web` JavaScript interop incompatibility; the requested
  JavaScript web release is valid.
- Docker API and PostgreSQL services are healthy; `/health` returned `Healthy`.
- Real Firefox/MapLibre workflow passed with seven screenshots and the
  machine-readable result under `docs/evidence/sprint3_3/`.
- Android could not be built or run: `flutter doctor -v` reports
  `ANDROID_HOME=/home/pc/Android/Sdk`, but that directory and SDK are absent.

## Git Safety

Sprint 3.3 work, its prompt, plan, migration, tests, and evidence will remain
uncommitted and unpushed. The unrelated untracked Sprint 3.1 prompt is preserved.
