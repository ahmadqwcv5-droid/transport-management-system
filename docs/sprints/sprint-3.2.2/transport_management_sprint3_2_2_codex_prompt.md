# Sprint 3.2.2 — Tracking Correctness and Simulation Semantics

## Role

Act as a senior product engineer and technical lead working inside the existing **Transport Management System** repository.

You are responsible for diagnosing the current implementation, designing the smallest correct solution, implementing it end to end, testing it, documenting it, and providing concrete browser evidence.

Do not merely write a plan or recommend changes. Complete the implementation.

---

## Repository

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Work from the current repository state, which already contains Sprint 3.2.1. Inspect the actual code, migrations, conventions, tests, and documentation before changing anything. Do not assume that file names or APIs are exactly as described below if the repository has evolved.

Preserve all correct Sprint 3.2 and Sprint 3.2.1 behavior, especially:

- English and Arabic localization and RTL/LTR behavior.
- OpenFreeMap/MapLibre basemap and attribution.
- Route planning and OSRM integration.
- Pickup/delivery stops and immutable route snapshots.
- Directional truck image markers and selection styling.
- Incremental annotation synchronization.
- No global annotation clearing during polling.
- Latest-wins serialized map synchronization.
- Manual-pan protection and explicit recenter/fit-route behavior.
- Tenant isolation.
- Vendor-neutral tracking provider design.
- Development-only tracking simulator.

Do not replace the current map architecture, routing provider, or working truck marker implementation.

---

## Problem Statement

Sprint 3.2.1 improved the map visually and eliminated most annotation flicker. However, two data correctness problems remain.

### Problem 1 — The travelled trail can connect unrelated positions

The green line represents the truck's travelled trail. It can currently point to unrelated locations because the frontend requests recent history by `TruckId`, while persisted `TruckPosition` records are not associated with the trip whose movement produced them.

As a result, one rendered line may connect:

- positions from a previous trip;
- positions from the current trip;
- positions produced before and after a simulator reset;
- positions generated against different route revisions;
- discontinuous positions separated by a large time or distance gap.

The existing history query also returns newest-first records. A renderable path must be returned or normalized oldest-to-newest.

This is a data-model and query correctness issue. Do not hide it with a frontend-only workaround.

### Problem 2 — Simulation speed is shown as physical vehicle speed

At a simulator multiplier of `10x`, a truck whose physical simulated speed is `65 km/h` can be displayed as travelling at `650 km/h`.

The simulation multiplier must accelerate simulated time and route progress only. It must not change the reported physical vehicle speed.

The following concepts must remain separate:

- **Physical speed:** what the vehicle telemetry reports and what the UI displays, for example `65 km/h`.
- **Simulation multiplier:** how quickly the demonstration advances relative to wall-clock time, for example `10x`.
- **Route progress:** distance advanced along the geometry as simulated time passes.
- **Operational ETA:** derived using physical/operational assumptions, not an impossible displayed speed created by the demo multiplier.

---

## Sprint Goal

Make tracking history trip-aware and discontinuity-safe, and make simulator timing semantically correct.

After this sprint:

1. Selecting a trip must show only the trail belonging to that trip and its applicable route/session.
2. Starting another trip with the same truck must never display points from the previous trip.
3. Resetting the simulator must never draw a straight connector from the pre-reset location to the reset location.
4. Trail coordinates must be rendered chronologically.
5. Suspicious gaps must create separate trail segments rather than false connecting lines.
6. A `10x` simulation must advance faster while still displaying a realistic physical truck speed.
7. Existing fleet map stability and annotation guarantees must remain intact.

---

## Mandatory Working Process

Before implementation:

1. Inspect the repository status and preserve unrelated user changes.
2. Read the current architecture and README documentation.
3. Trace the complete path from:
   - `TrackingTarget`;
   - tracking provider samples;
   - `TrackingService` persistence;
   - `TruckPosition` storage;
   - tracking history endpoints;
   - Flutter dashboard repository;
   - selected-trip trail state;
   - MapLibre line rendering.
4. Reproduce or demonstrate the current cross-trip/reset trail failure with a focused test before fixing it.
5. Create `docs/sprints/sprint-3.2.2/SPRINT3_2_2_IMPLEMENTATION_PLAN.md` before material implementation.

The implementation plan must contain:

- baseline findings;
- root cause;
- proposed data model;
- migration and compatibility strategy;
- ordered tasks;
- acceptance criteria;
- test strategy;
- risks and decisions;
- an elapsed-time table with actual time recorded per task and total sprint time.

Update the plan throughout the work. Do not fill all elapsed times retrospectively with estimates.

---

## Functional Requirements

### 1. Trip-aware persisted tracking positions

Persist enough context with every newly stored truck position to determine which operational movement produced it.

At minimum, new records must support:

- tenant/company association;
- truck association;
- nullable trip association;
- applicable route revision or route snapshot identifier when a route exists;
- a tracking run/session discriminator, or an equivalent robust mechanism that prevents reset discontinuities from becoming one line;
- recorded timestamp;
- coordinates, speed, heading, online status, and source.

Use the existing domain identifiers and conventions.

The tracking provider should remain vendor-neutral. Prefer enriching raw telemetry with the active trip context in the application layer instead of forcing future GPS vendors to understand transport-domain trip entities. If another approach is chosen, document why it preserves provider independence.

Positions recorded while no trip is active may keep a null trip association. They must remain usable for the current fleet location, but they must not appear in a trip trail.

### 2. Safe database migration

Create a new EF Core migration for Sprint 3.2.2.

Requirements:

- Existing position rows must remain valid.
- Do not invent historical trip associations.
- Existing rows should use null for associations that cannot be proven.
- Add appropriate tenant-safe and query-efficient indexes for the new trip-history query.
- Review the generated migration manually.
- Verify that there is no model/migration drift after applying it.

Do not delete existing tracking data merely to make the test pass.

### 3. Trip-scoped history API

Add or update an API that returns the tracking history for a specific trip. Use a REST shape consistent with the existing controllers.

It must:

- validate that the trip belongs to the current tenant;
- validate the truck/trip relationship through authoritative domain data;
- return only positions associated with the requested trip;
- select the applicable current session/run and route revision deliberately;
- return points in oldest-to-newest order, or return explicitly ordered segments;
- enforce a safe configurable or bounded result limit;
- never expose another tenant's tracking records;
- use stable ProblemDetails `errorCode` values for failures;
- preserve the generic truck-history endpoint if it is still useful, but do not use it to render a selected trip trail.

Do not infer a historical trip merely because the truck is currently assigned to it.

### 4. Discontinuity-safe trail segmentation

Represent the travelled trail as one or more ordered segments.

Start a new segment when appropriate, including at least:

- a tracking session/run change;
- a route revision change when the previous geometry is no longer applicable;
- a simulator reset;
- a timestamp gap beyond a configurable/documented threshold;
- an implausible geographic jump beyond a configurable/documented threshold.

Do not render a straight line across a detected discontinuity.

Choose whether segmentation is produced by the backend or a shared deterministic client/domain utility. Prefer a design that can be tested without MapLibre and reused by future clients. Document the decision.

Use a proper geographic distance calculation for jump detection. Do not compare raw latitude/longitude deltas as if they were meters.

### 5. Correct simulator timing semantics

Refactor the simulator so the multiplier affects elapsed simulated time or distance advanced, not reported physical speed.

Required behavior:

- At `1x`, a truck configured at `65 km/h` reports approximately `65 km/h` while moving.
- At `10x`, it still reports approximately `65 km/h` while moving.
- At `10x`, route progress over the same wall-clock interval is approximately ten times the `1x` progress, subject to route end and deterministic stepping behavior.
- Paused and stopped trucks report the correct stationary behavior.
- Resume must not create a false time leap.
- Reset must create a fresh tracking run/session or otherwise guarantee a clean trail boundary.
- Changing the multiplier must not teleport the truck or create a false trail connector.
- Offline behavior must remain correct.

Review ETA calculations. Ensure no ETA or remaining-time display derives from a multiplier-inflated physical speed. Clearly document whether displayed ETA represents operational real-world ETA or accelerated demo completion time. Prefer operational real-world ETA for the product UI.

### 6. Flutter data flow and map behavior

Update Flutter so the selected trip uses the trip-scoped tracking history.

Requirements:

- Render every returned segment independently.
- Keep the planned route visually distinct from travelled history.
- Recommended semantics:
  - blue: planned route;
  - green: valid travelled trail;
  - red: off-route status or off-route portion only when supported by the existing semantics.
- Do not connect separate segments.
- Do not refit or move the camera during normal polling.
- Preserve manual pan/zoom.
- Preserve incremental annotation updates and stable annotation identifiers.
- Do not globally clear line, symbol, or circle annotations.
- Clear selected-trip trail state correctly when selection changes or no applicable history exists.
- Keep Arabic RTL and English LTR correct.
- Add a localized compact legend or clear explanatory labels for planned route and travelled trail.
- Add a localized control to show/hide the travelled trail if it fits the existing map controls without clutter.

Avoid rebuilding the entire map widget on every polling update.

### 7. Legacy and unassigned data behavior

Define and test behavior for:

- legacy `TruckPosition` rows with null `TripId`;
- positions recorded with no active trip;
- completed trips;
- a truck reused across multiple trips;
- a route regenerated before a trip starts;
- a route revision changed after some positions exist, if the domain permits it;
- simulator reset during a trip;
- selected trip with no tracking history.

Legacy/unassigned positions may supply the truck's latest fleet location if that remains consistent with current behavior, but must not be drawn as part of a selected trip's travelled trail.

---

## Data Integrity and Multi-Tenancy Requirements

Tenant isolation is non-negotiable.

Add integration tests proving that:

- Tenant A cannot request Tenant B's trip history.
- A trip-scoped query cannot leak positions from a same-ID-like or unrelated truck context.
- Positions for the same truck but another trip are excluded.
- Null-trip legacy positions are excluded from trip history.
- The active trip association is captured when a new position is persisted.
- Database query filters and explicit validation work together rather than relying only on the frontend.

Never accept `CompanyId` from the client as authoritative.

---

## Required Automated Tests

Add focused tests at the appropriate layers. At minimum cover:

### Backend domain/application/integration tests

1. A truck has positions from Trip A and Trip B; requesting Trip B returns only Trip B.
2. Returned positions/segments are chronological.
3. Legacy null-trip positions are not included.
4. A reset or session change creates separate segments.
5. A large time gap creates separate segments.
6. An implausible distance jump creates separate segments.
7. Tenant isolation for trip history.
8. Current fleet position remains available when no trip is active.
9. New persisted positions receive the correct trip and route context.
10. Route revision changes do not create a false connecting line.
11. At `1x` and `10x`, reported physical speed is the same.
12. At `10x`, progress advances faster than at `1x` for equal wall-clock time.
13. Pause/resume does not create a time-leap teleport.
14. Reset creates a clean trail boundary.

### Flutter tests

1. The dashboard requests trip-scoped history for the selected trip.
2. Two history segments produce two independent line annotations.
3. Segment identifiers remain stable during polling updates.
4. Updating the trail does not cause global annotation clearing.
5. Updating the trail does not trigger an automatic camera movement.
6. Changing the selected trip removes stale trail segments and loads the new trip history.
7. No-history state renders safely without a false line.
8. Legend and optional trail visibility control are localized in English and Arabic.
9. The displayed truck speed remains realistic when the simulator is set to `10x`.

Avoid tests that merely assert mocked methods were called if an observable state or returned data assertion is possible.

---

## Browser Validation Workflow

Perform a real Flutter Web browser smoke test against the running API and PostgreSQL stack.

The workflow must prove all of the following:

1. Log in to a dedicated smoke-test tenant without overwriting existing user data or credentials.
2. Create or use one truck and at least two different trips for that same truck.
3. Generate valid routes for both trips.
4. Run Trip A long enough to persist several positions.
5. Complete or release Trip A as required by the domain workflow.
6. Assign the same truck to Trip B and start it.
7. Select Trip B on the fleet map.
8. Confirm that Trip A's trail does not appear and no connector points toward Trip A.
9. Reset the simulator during Trip B and continue it.
10. Confirm that the trail is split cleanly and no straight reset connector is drawn.
11. Run the simulator at `10x`.
12. Confirm visually and through API data that the truck advances quickly but displays the configured physical speed, not `650 km/h` or another multiplier-inflated value.
13. Pan the map manually and allow at least ten polling updates.
14. Confirm that the camera does not snap back, markers do not flicker, and no global annotation clearing occurs.
15. Switch between Arabic RTL and English LTR and verify the legend, trail control, selected truck details, speed, and map panel.

Retain evidence screenshots and concise machine-readable or textual evidence under:

`docs/evidence/sprint3_2_2/`

Evidence must include:

- Trip A and Trip B identifiers using the same truck;
- the history API result proving isolation;
- ordered segment summaries with point counts and timestamps;
- simulator `1x` versus `10x` speed/progress comparison;
- annotation operation counts across at least ten polling updates;
- screenshots showing the valid trail, post-reset segmentation, `10x` realistic speed, and Arabic RTL.

Do not claim browser verification if only widget tests or a tile-independent fallback were tested.

---

## Non-Functional Requirements

- Preserve clean architecture and existing project conventions.
- Do not couple the domain to OSRM, OpenFreeMap, or MapLibre.
- Do not make future real GPS providers depend on simulator-only concepts.
- Keep thresholds configurable through typed options where appropriate.
- Avoid unbounded tracking-history queries.
- Add indexes that support the actual tenant/trip/time query.
- Avoid N+1 queries.
- Avoid global map annotation recreation.
- Preserve API error-code localization behavior.
- Keep all new user-facing strings in ARB resources.
- Do not introduce secrets or API keys into source control.
- Do not use arbitrary delays in tests to hide synchronization problems.

---

## Explicitly Out of Scope

Do not expand this sprint into unrelated features.

The following are out of scope:

- real GPS vendor integration;
- SignalR/WebSocket migration;
- driver profile photo uploads or driver-avatar map markers;
- finance, expenses, payments, or profitability;
- maintenance management;
- route optimization across multiple vehicles;
- geofencing and alert delivery;
- full telemetry retention/archival platform;
- redesigning the entire dashboard;
- replacing the current truck marker asset;
- changing the selected basemap provider when it is working.

Keep the truck as the primary map entity. Driver avatars can be considered later in selected-truck cards or as a small optional badge, but they are not part of this sprint.

---

## Required Validation Commands and Checks

Run the repository's correct equivalents of all applicable checks:

- .NET restore/build with zero warnings and zero errors where the repository currently enforces that standard.
- All backend tests.
- New focused tracking and simulator tests.
- EF Core migration application against PostgreSQL.
- EF Core migration/model drift check.
- Flutter dependency resolution.
- Flutter analyzer.
- All Flutter tests.
- Focused map/trail tests.
- Flutter Web release build with required dart-defines.
- Browser smoke test using an available supported browser.
- Docker Compose health verification.
- Live API verification against PostgreSQL.

If Android cannot be validated because the SDK/device is unavailable, report the exact limitation. Do not represent Android as passed.

Do not weaken tests, remove assertions, suppress warnings, or skip failing checks to obtain a green report.

---

## Acceptance Criteria

Sprint 3.2.2 is complete only when all of these are true:

- [ ] New tracking positions are associated with the correct tenant, truck, and active trip context.
- [ ] Historical rows with unknown associations remain null rather than receiving invented data.
- [ ] The selected trip uses a trip-scoped history API.
- [ ] Reusing one truck across multiple trips never merges their trails.
- [ ] History is chronological and represented as safe independent segments.
- [ ] Reset, time gap, route revision change, and geographic jump cannot produce false connector lines.
- [ ] The simulator multiplier accelerates progress but does not inflate reported physical speed.
- [ ] `10x` no longer displays values such as `650 km/h` for a `65 km/h` truck.
- [ ] ETA semantics are correct and documented.
- [ ] Normal polling causes zero global symbol/line/circle clears.
- [ ] Normal polling causes zero automatic camera moves.
- [ ] Manual pan remains stable across at least ten polling updates.
- [ ] Planned route and travelled trail remain visually distinct and explained.
- [ ] English, Arabic, LTR, and RTL are verified.
- [ ] Tenant-isolation tests pass.
- [ ] Backend and Flutter test suites pass.
- [ ] EF migration drift is absent.
- [ ] Flutter Web release build succeeds.
- [ ] A real browser workflow proves the two core fixes.
- [ ] README and architecture documentation are updated.
- [ ] Evidence is stored under `docs/evidence/sprint3_2_2/`.
- [ ] `docs/sprints/sprint-3.2.2/SPRINT3_2_2_IMPLEMENTATION_PLAN.md` contains actual elapsed times and final results.

---

## Documentation Requirements

Update at least:

- `README.md` with any new configuration, migration, API, simulator behavior, and validation steps.
- `docs/architecture.md` with the trip-aware tracking model, provider/application responsibility boundary, trail segmentation, session/reset semantics, and ETA meaning.
- API documentation or endpoint examples where the repository currently documents endpoints.
- `docs/sprints/sprint-3.2.2/SPRINT3_2_2_IMPLEMENTATION_PLAN.md` with final decisions, validation results, limitations, and actual elapsed time.

Include a small data-flow explanation showing:

`Provider telemetry -> application trip correlation -> persisted position context -> trip-scoped history -> ordered segments -> Flutter map annotations`

---

## Git and Safety Constraints

- Do not commit.
- Do not push.
- Do not rewrite history.
- Do not discard or overwrite unrelated local changes.
- Do not delete existing database volumes or user data.
- Do not change preserved owner credentials.
- A dedicated smoke-test tenant may be created and must be documented.
- Keep all Sprint 3.2.2 changes uncommitted for review.

---

## Final Report Format

At completion, provide a concise but evidence-based report containing:

1. Root cause confirmed.
2. Data model and migration changes.
3. API and tenant-isolation changes.
4. Trail segmentation behavior.
5. Simulator speed and ETA semantics.
6. Flutter/map changes.
7. Automated test counts and results.
8. Browser workflow result.
9. Evidence paths.
10. Environment limitations.
11. Actual elapsed time per task and total.
12. Exact `git status --short` summary.

Explicitly state whether any commit or push was performed. The expected answer is that neither was performed.

Do not describe Sprint 3.2.2 as complete if the browser still draws a cross-trip/reset connector or if the displayed speed remains multiplier-inflated.
