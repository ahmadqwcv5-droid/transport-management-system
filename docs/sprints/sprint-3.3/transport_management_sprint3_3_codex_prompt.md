# Sprint 3.3 — Dispatch to Pickup, Repositioning Route, and Arrival Workflow

## Role

Act as a senior product engineer, logistics-domain architect, and technical lead working inside the existing **Transport Management System** repository.

Your responsibility is to inspect the current implementation, design the smallest correct domain extension, implement it end to end, validate it with real browser evidence, and document every important decision.

Do not only produce a plan or code review. Complete the implementation.

---

## Repository and Baseline

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Start from the current `main` branch, which includes Sprint 3.2.2 and commit `133134a` or a later reviewed commit.

Before changing anything:

1. Fetch the current repository state.
2. Inspect `git status` and preserve all unrelated user changes.
3. Read `README.md`, `docs/architecture.md`, and the Sprint 3.2–3.2.2 implementation plans.
4. Trace the current trip lifecycle, route planning, tracking persistence, route progress, dashboard, MapLibre annotations, simulator state, and tenant filters.
5. Confirm the teleport regression described below with a focused failing test.

Preserve all correct existing behavior, including:

- multi-tenant isolation;
- English/Arabic localization and RTL/LTR;
- OpenFreeMap/MapLibre rendering and attribution;
- OSRM/configurable routing providers;
- immutable cargo route snapshots;
- trip-scoped tracking history;
- tracking-run and route-aware trail segmentation;
- physical simulator speed semantics at `1x` and `10x`;
- incremental annotations, no global clears, and no polling camera moves;
- directional truck image markers;
- planned route, travelled trail, stop markers, fleet filters, and selection behavior.

Do not replace the map, routing provider, truck icon, or tracking architecture with a new unrelated implementation.

---

## Confirmed Product Defect

When a truck finishes one trip at a location far from the next trip's pickup, assigning the truck to the next trip can make the simulator place it immediately at the new pickup.

The current behavior is caused by the following design:

- the active tracking target changes to the newly assigned trip's cargo route;
- that route begins at the pickup;
- a new simulator state starts at distance zero;
- a sample is still produced for a route-aware assigned trip even when it cannot move;
- distance zero is persisted as the truck's new current position.

This is an invalid teleport. Assignment must never change a vehicle's geographic position.

The system is also missing the real operational stage in which the truck travels empty from its current position to the pickup location. This is commonly called repositioning, empty movement, or deadhead movement. In the product UI, use user-friendly wording such as **Heading to pickup** / **التوجه إلى موقع التحميل**.

---

## Sprint Goal

Implement an explicit, auditable pre-trip dispatch workflow:

```text
Draft
  -> Assigned
  -> En Route to Pickup
  -> At Pickup
  -> Started
  -> In Transit
  -> Delivered
  -> Completed
```

The exact enum names may follow repository conventions, but the user-visible and domain semantics must remain unambiguous.

After this sprint:

1. Assignment never changes the truck's current location.
2. The system uses the truck's latest trustworthy position to determine whether it is already near the pickup.
3. If the truck is far away, the system proposes and persists a separate repositioning route from the current location to the pickup.
4. The manager can dispatch the truck along that route.
5. The simulator follows the repositioning route without jumping.
6. Arrival at the pickup is detected using a configurable radius.
7. Arrival does not silently imply that loading is complete; the user explicitly starts the cargo trip.
8. The cargo route remains separate and starts continuously from the pickup.
9. Repositioning distance/time remains available for future profitability calculations.
10. Restarting the API does not send a simulated truck back to the beginning of a route.

---

## Non-Negotiable Product Semantics

### Assignment is not movement

Assigning a truck and driver reserves them for the trip. It must not:

- move the truck;
- create a synthetic pickup position;
- start the repositioning leg;
- start the cargo trip;
- change cargo progress.

Immediately after assignment, the truck must remain at the last persisted current position.

### Repositioning and cargo movement are different operational legs

Keep these concepts separate:

| Leg | Origin | Destination | Commercial meaning |
|---|---|---|---|
| Repositioning | Truck's current position | First pickup | Normally empty/non-billable movement |
| Cargo | First pickup | Final delivery through configured stops | Customer trip movement |

Do not prepend the truck's current location to the existing cargo `TripRoutePlan`. That would corrupt quoted cargo distance, cargo ETA, route progress, and future profitability.

### Arrival is not cargo departure

GPS arrival at the pickup must transition the operation to **At Pickup** and notify the user. It must not automatically mark loading complete or depart with cargo.

The existing Start action must be allowed only after the truck is at the pickup. The user explicitly starts the trip after operational readiness/loading confirmation.

### Backend enforcement

All important rules must be enforced by the backend. Flutter must not be the only guard.

---

## Mandatory Working Process

Create `docs/sprints/sprint-3.3/SPRINT3_3_IMPLEMENTATION_PLAN.md` before material implementation.

The plan must contain:

- baseline architecture findings;
- a reproducible explanation of the teleport;
- proposed lifecycle/state machine;
- proposed repositioning data model;
- simulator continuity design;
- migration and backward-compatibility strategy;
- API design;
- ordered implementation tasks;
- test and browser-validation strategy;
- risks and explicit decisions;
- actual start/end timestamps and elapsed time for each task;
- total active sprint time.

Update the plan during implementation rather than inventing all timing retrospectively.

Add a regression test that fails because assignment currently teleports the truck before implementing the fix.

---

## Domain and Persistence Requirements

### 1. Extend the trip lifecycle

Add explicit lifecycle support for:

- En Route to Pickup;
- At Pickup.

Preserve existing stored trips and handle existing statuses safely. Update every place that depends on trip status, including:

- domain transition rules;
- allowed actions;
- resource reservation logic;
- filtered unique indexes or database predicates;
- dashboard active-trip counts;
- truck and driver status synchronization;
- cancellation and resource release;
- API contracts;
- Flutter parsing and status chips;
- English and Arabic localization;
- integration tests and seeded/demo data.

Recommended compatible lifecycle:

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

Allow an Assigned trip to move directly to AtPickup when the latest valid position is already inside the arrival radius.

Document the semantic distinction between `AtPickup`, `Started`, and `InTransit`. Do not leave the UI with three labels that appear to mean the same thing.

### 2. Repositioning route snapshot

Persist a route snapshot separate from the cargo route. Use a clear domain name such as `TripRepositioningPlan`, `TripApproachPlan`, or an equivalent repository-consistent name.

At minimum store:

- `Id`;
- `CompanyId`;
- `TripId`;
- `TruckId`;
- origin latitude/longitude;
- destination pickup latitude/longitude;
- the source `TruckPositionId` when available;
- source position timestamp;
- GeoJSON route geometry and geometry version;
- distance meters;
- estimated duration seconds;
- provider name and provider route ID;
- route profile;
- calculation timestamp;
- lifecycle/status such as Proposed, Active, Completed, Expired or an equivalent robust model;
- timestamps for dispatch start and pickup arrival where appropriate.

The repositioning route must be tenant-owned and immutable after activation. If the origin becomes stale before activation, explicitly expire/regenerate it instead of mutating an accepted route silently.

Use restrictive and intentional delete behavior. Add indexes supporting tenant/trip/truck/status lookups.

### 3. Safe migration

Create a Sprint 3.3 EF Core migration.

Requirements:

- preserve all existing trips, routes, and tracking data;
- do not invent historical repositioning plans;
- do not rewrite old coordinates;
- update status-related filtered indexes safely;
- review generated SQL/model snapshot;
- apply the migration to PostgreSQL;
- verify zero model/migration drift.

### 4. Movement-leg identity in tracking

New tracking positions must distinguish at least:

- Unassigned/current-location movement;
- Repositioning to pickup;
- Cargo-trip movement.

Use an enum/value object or an equivalent strongly validated representation. If a leg/entity identifier is introduced, persist and tenant-protect it.

The current trip, route plan, and tracking-run association must remain correct. Do not overload the cargo `RoutePlanId` with a repositioning plan ID that points to a different table or has ambiguous meaning.

Legacy positions must remain valid with null/unknown movement phase where necessary.

Repositioning tracking must remain independently queryable and must not corrupt cargo route progress.

### 5. Preserve deadhead metrics

Expose at least planned repositioning distance and duration in the trip/API response. Preserve enough data to calculate actual repositioning distance later or calculate it now if it is straightforward from tracking history.

Do not implement finance in this sprint, but do not discard the non-billable distance information that Sprint 4 profitability will need.

---

## Trustworthy Current-Position Rules

Route proposal must use the latest persisted position for the assigned truck within the current tenant.

Before using it, validate:

- position exists;
- coordinates are valid;
- position is online when required by policy;
- position age is below a configurable maximum;
- the position belongs to the assigned truck and current tenant.

Add typed/configurable policies, including sensible bounded defaults, for:

- maximum acceptable position age for dispatch planning;
- pickup arrival radius;
- maximum allowed origin movement before an unaccepted proposal becomes stale;
- optional projection tolerance used when restoring simulator state.

Use stable ProblemDetails error codes, including repository-consistent equivalents of:

- `TRUCK_POSITION_REQUIRED`;
- `TRUCK_POSITION_STALE`;
- `TRUCK_OFFLINE`;
- `REPOSITIONING_ROUTE_REQUIRED`;
- `REPOSITIONING_ROUTE_STALE`;
- `TRUCK_NOT_AT_PICKUP`;
- `INVALID_TRIP_TRANSITION`.

Localize them through the existing Flutter error-code mapping.

If the truck has never reported a location, do not fabricate the pickup as its current position. For development/simulator testing, provide a deterministic, development-only way to seed/set a truck's current coordinate, or reuse a documented simulator seed mechanism. This control must not be exposed in production builds.

---

## Routing and Dispatch API Requirements

Design REST endpoints consistent with the existing controllers. Exact paths may follow repository conventions, but the capabilities must be clear.

Required capabilities:

### Preview/propose route to pickup

- Valid only for an assigned trip with truck and pickup coordinates.
- Uses the latest trustworthy truck position as origin.
- Uses the first pickup stop as destination.
- If already inside the arrival radius, return a clear `alreadyAtPickup` result and do not create a meaningless road route.
- Calculates route server-side through the configured routing abstraction.
- Returns origin position age, planned distance, duration, and geometry.
- Must not accept client-supplied geometry as authoritative.

### Activate dispatch to pickup

- Revalidate assignment, tenant, latest position, and proposal freshness.
- Persist/activate the repositioning snapshot.
- Transition the trip to En Route to Pickup.
- Update truck/driver operational status consistently.
- Ensure resources remain reserved.
- Be concurrency-safe and reject duplicate activation.

### Mark/detect arrival at pickup

- Use proper geographic distance calculation.
- Transition to At Pickup when inside the configured radius.
- Be idempotent.
- Record `ArrivedPickupAt` or equivalent.
- Never mark cargo delivery or completion.

### Start cargo trip

- Allow only from At Pickup.
- Recheck current proximity at the backend.
- Reject a distant truck with `TRUCK_NOT_AT_PICKUP`.
- Record the existing cargo start time only here.
- Preserve continuity between the last repositioning coordinate and the first cargo coordinate.

### Progress responses

Expose separate operational progress:

- distance and ETA to pickup while repositioning;
- At Pickup state while waiting;
- cargo route progress only after cargo execution starts;
- no fake cargo progress during repositioning.

Do not combine repositioning distance with the customer's cargo route distance or cargo completion percentage.

---

## Simulator Requirements

The simulator must support the new workflow without product-specific shortcuts that future real GPS providers would require.

### No sample-at-route-zero teleport

An Assigned trip awaiting dispatch must not cause the provider to emit the cargo route's first coordinate as the truck's current location.

If the target is not allowed to move and has no applicable active movement leg, preserve the last known position and do not synthesize a new coordinate.

### Follow the active movement leg

- During En Route to Pickup, follow the repositioning route.
- At Pickup, remain at the pickup without advancing cargo progress.
- During Started/In Transit, follow the cargo route according to the documented current semantics.
- Keep physical speed independent from the simulation multiplier.
- Preserve tracking-run boundaries and movement-phase association.

### Route transition continuity

The end of repositioning and beginning of the cargo route should resolve to the same pickup within tolerance. Switching legs must not create a visible jump or false connecting segment.

### Restart continuity

The simulator currently stores operational progress in memory. Fix restart behavior so an API/container restart does not reset an active truck to distance zero.

Use a robust approach such as:

- restoring progress by projecting the last persisted position onto the active immutable route; or
- persisting explicit simulator execution state;
- or another documented design with equivalent correctness.

Provider abstraction must remain vendor-neutral. Real GPS providers must not be forced to simulate routes.

### Multiplier semantics

Retain Sprint 3.2.2 behavior:

- `10x` accelerates distance/progress;
- physical speed remains realistic;
- operational ETA remains real-world ETA;
- changing the multiplier does not jump the truck;
- pause/resume does not create elapsed-time teleportation.

---

## Resource and Cancellation Semantics

Define and test truck/driver behavior for every new state.

Recommended behavior:

- Assigned: resources are reserved even if their fleet status still appears available.
- En Route to Pickup and later active execution states: resources are operationally busy; use existing `OnTrip` or introduce a clearer compatible status only if justified.
- Cancellation from Assigned, En Route to Pickup, At Pickup, Started, or In Transit releases resources consistently where business rules permit cancellation.
- Completed and Cancelled trips never remain selected as an active movement target.

Update reservation queries and filtered database indexes to include all new reserving statuses.

Do not allow two active/repositioning trips to control the same truck or driver.

---

## Flutter and Map Requirements

### Trip details/actions

Show contextual actions, not a generic Start button in every assigned state.

Examples:

- Assigned and far away: **Preview route to pickup**.
- Valid proposal: **Dispatch to pickup**.
- En Route to Pickup: progress and ETA to pickup.
- At Pickup: **Start trip**.
- Started: existing next valid action.

Display clear localized states in English and Arabic.

### Map semantics

Use distinct layers and a localized legend:

- planned repositioning route: dashed orange/amber;
- planned cargo route: solid blue;
- actual travelled trail: green;
- off-route warning: red using the existing semantics;
- pickup and delivery markers: visually distinct;
- directional truck icon: preserve the existing asset and heading behavior.

While repositioning, selecting the truck must show:

- Heading to pickup;
- pickup name;
- remaining distance to pickup;
- ETA to pickup;
- physical speed;
- last update;
- relevant offline/stale warning.

At pickup, show a clear arrived/waiting state and Start Trip action where appropriate.

### Stability

- Keep stable annotation IDs.
- Update annotations incrementally.
- Do not globally clear symbols, lines, or circles.
- Do not move/refit the camera during polling.
- Preserve manual pan/zoom.
- Fit/recenter only after explicit user action or a documented one-time selection event.
- Avoid rebuilding the map widget on every poll.

### Responsive and localized UI

- Verify English/LTR and Arabic/RTL.
- Keep controls usable at the current desktop/web layout.
- Do not add hard-coded strings.
- Do not show raw enum names or IDs to users.

---

## Arrival Detection and Side-Effect Boundary

Arrival detection must be deterministic, idempotent, and testable independently of MapLibre.

The current development simulator may advance when tracking is polled, but document the architecture boundary clearly:

- simulator polling is acceptable for development;
- real GPS ingestion and arrival evaluation must eventually run independently of whether a dashboard browser is open.

Do not attempt a full production GPS ingestion pipeline or SignalR migration in this sprint. However, do not bury arrival business logic inside a Flutter widget or MapLibre callback. Keep it in backend application/domain services so it can later be called by real telemetry ingestion.

---

## Required Automated Tests

Add focused tests at the appropriate domain, application, integration, and Flutter layers.

### Backend regression and lifecycle tests

1. Completing Trip A leaves the truck at Trip A's final persisted position.
2. Assigning the same truck to distant Trip B does not change that position.
3. Polling immediately after assignment does not create a synthetic pickup position.
4. Starting Trip B while far from pickup is rejected by the backend.
5. A repositioning preview uses the latest trustworthy position and first pickup.
6. The cargo route snapshot remains unchanged after repositioning preview/activation.
7. Activating dispatch transitions to En Route to Pickup and reserves/busies resources correctly.
8. Repositioning progress does not change cargo progress.
9. Entering the arrival radius transitions idempotently to At Pickup.
10. Arrival does not automatically start cargo movement.
11. Start succeeds from At Pickup and cargo movement begins continuously.
12. A truck already within the arrival radius skips the road approach route safely.
13. Missing, stale, invalid, or offline positions return stable error codes.
14. A proposal becomes stale when the truck moves beyond the configured threshold before activation.
15. API restart/restoration resumes near the latest persisted position rather than route distance zero.
16. Repositioning and cargo tracking positions have correct movement-leg identity.
17. Cancelling in every new allowed state releases resources correctly.
18. Another trip cannot reserve or control the same truck/driver.
19. Tenant A cannot read, activate, or mutate Tenant B's repositioning plan.
20. Routing-provider failure does not change trip state or truck location.

### Simulator tests

1. Assigned-but-not-dispatched target emits no teleporting sample.
2. Repositioning follows the approach geometry.
3. At Pickup remains stationary.
4. Cargo starts from the pickup without a jump.
5. `1x` and `10x` preserve the same physical speed.
6. Pause/resume and multiplier changes do not create jumps.
7. Reset creates a new run boundary without moving to an unrelated route origin.
8. Recreated provider/API state restores from persisted position.

### Flutter tests

1. Correct action is shown for each lifecycle state.
2. Repositioning preview and activation use the correct endpoints.
3. Planned approach and cargo routes use independent stable annotations.
4. Cargo progress is hidden/not started during repositioning.
5. At Pickup UI exposes Start Trip.
6. Stale/offline/missing-location errors are localized.
7. Ten polling updates produce no global annotation clears.
8. Ten polling updates produce no automatic camera moves.
9. Switching between approach and cargo legs removes stale approach state without clearing unrelated fleet annotations.
10. English/LTR and Arabic/RTL labels, status chips, map legend, and actions are correct.

Prefer observable behavior assertions over tests that only verify mocked method calls.

---

## Mandatory Browser Workflow

Run a real Flutter Web workflow against the real API and PostgreSQL database using a dedicated smoke-test tenant. Do not overwrite preserved owner data or credentials.

The workflow must demonstrate:

1. Create/use one truck, one driver, and two trips in geographically different areas.
2. Complete Trip A so its truck ends at Trip A's delivery point.
3. Record Trip A's final truck coordinates.
4. Create and assign the same truck to distant Trip B.
5. Poll multiple times while Trip B is only Assigned.
6. Prove the coordinates remain at Trip A's destination and do not jump to Trip B's pickup.
7. Attempt to start Trip B while distant and prove it is rejected.
8. Preview a repositioning route from the actual truck position to Trip B pickup.
9. Display the orange/dashed approach route separately from the blue cargo route.
10. Activate dispatch and run the simulator along the approach route.
11. Show approach remaining distance and ETA while cargo progress has not started.
12. Restart the API/container mid-approach without deleting the PostgreSQL volume.
13. Prove the truck resumes near its last persisted position rather than returning to route start.
14. Reach the configured pickup radius and prove the state becomes At Pickup.
15. Prove the cargo trip does not start automatically.
16. Explicitly start the trip and prove the truck continues onto the cargo route without a jump.
17. Run at `10x` and prove physical speed remains realistic.
18. Manually pan the map and observe at least ten polling updates with no refit/flicker/global clears.
19. Verify English/LTR and Arabic/RTL on the real MapLibre map.

Retain evidence under:

`docs/evidence/sprint3_3/`

Evidence must include:

- screenshots for Assigned/no teleport, proposed route, active approach, At Pickup, and cargo start;
- before/after coordinates proving no assignment teleport;
- API response showing distant Start rejection;
- approach/cargo route IDs and independent distances;
- position/phase records from PostgreSQL;
- restart-continuity evidence;
- annotation operation counts over at least ten polls;
- English and Arabic screenshots;
- a concise machine-readable browser workflow result.

Do not claim browser validation if only widget tests or the fallback map were used.

---

## Documentation Requirements

Update at least:

- `README.md`;
- `docs/architecture.md`;
- API/configuration documentation used by the repository;
- `docs/sprints/sprint-3.3/SPRINT3_3_IMPLEMENTATION_PLAN.md`.

Document:

- the revised lifecycle;
- the distinction between repositioning and cargo movement;
- why assignment cannot create coordinates;
- position freshness/arrival policies;
- repositioning snapshot schema;
- tracking movement-phase semantics;
- simulator restart restoration;
- resource reservation and cancellation behavior;
- map color/legend semantics;
- how planned deadhead metrics will feed future profitability;
- the future boundary between development polling and real GPS ingestion.

Include a concise data flow:

```text
Latest trusted truck position
  -> route proposal to pickup
  -> activate repositioning leg
  -> telemetry and arrival detection
  -> At Pickup
  -> explicit cargo start
  -> cargo route execution
```

---

## Validation Requirements

Run the repository's correct equivalents of:

- .NET restore and build;
- backend integration tests;
- new focused lifecycle/repositioning/simulator tests;
- EF migration application against PostgreSQL;
- EF model/migration drift check;
- Flutter dependency resolution;
- Flutter analyzer;
- all Flutter tests;
- focused map annotation tests;
- Flutter Web release build with required dart-defines;
- real Firefox or Chrome browser workflow;
- Docker Compose service and health verification;
- live API and PostgreSQL verification.

Report exact pass/fail counts. Do not weaken tests, suppress warnings, delete assertions, or skip failing checks to obtain a green result.

If Android cannot be built because the SDK/device is unavailable, report the exact limitation and do not claim Android passed.

---

## Acceptance Criteria

Sprint 3.3 is complete only when every applicable item is true:

- [ ] Assignment never changes the truck's coordinates.
- [ ] Assigned polling cannot emit a pickup-origin teleport.
- [ ] Repositioning is modeled separately from the cargo route.
- [ ] Latest position freshness, online state, ownership, and validity are enforced.
- [ ] A far-away truck receives a server-calculated route proposal to pickup.
- [ ] An already-near truck can safely proceed to At Pickup without a meaningless route.
- [ ] Dispatch activation is explicit, tenant-safe, concurrency-safe, and auditable.
- [ ] Repositioning distance and duration remain separate from cargo distance and duration.
- [ ] Cargo progress does not begin while heading to pickup.
- [ ] Arrival detection is geographic, configurable, idempotent, and backend-owned.
- [ ] Arrival produces At Pickup and does not automatically start cargo movement.
- [ ] Start is backend-rejected unless the truck is at pickup.
- [ ] Cargo movement begins continuously from the pickup without a jump.
- [ ] Tracking identifies repositioning versus cargo movement.
- [ ] An API restart cannot reset an active simulated truck to distance zero.
- [ ] `10x` still reports realistic physical speed and operational ETA.
- [ ] New statuses participate correctly in reservation, dashboard, cancellation, and resource synchronization.
- [ ] No cross-tenant repositioning data access is possible.
- [ ] Planned approach, cargo route, and travelled trail are visually distinct and localized.
- [ ] Polling causes zero global annotation clears.
- [ ] Polling causes zero automatic camera moves.
- [ ] English/LTR and Arabic/RTL pass on the real map.
- [ ] Backend and Flutter suites pass.
- [ ] EF migration drift is absent.
- [ ] Flutter Web release build succeeds.
- [ ] Real browser evidence proves the full Trip A -> Trip B workflow.
- [ ] Documentation and actual elapsed-time records are complete.

Do not describe the sprint as complete if assignment still moves the truck, Start can succeed while far from pickup, or restart resets route progress.

---

## Explicitly Out of Scope

Do not expand this sprint into:

- finance, payments, expenses, or profitability UI;
- real GPS vendor integration;
- SignalR/WebSocket migration;
- full background telemetry ingestion platform;
- driver photo uploads or avatar markers;
- maintenance and document management;
- multi-vehicle route optimization;
- customer billing based on deadhead distance;
- advanced geofence alert delivery;
- redesigning the entire dashboard;
- replacing OpenFreeMap, MapLibre, OSRM, or the current truck marker asset.

Preserve data needed by future finance and GPS work, but do not implement those later sprints here.

---

## Git and Data Safety

- Do not commit.
- Do not push.
- Do not rewrite Git history.
- Do not discard unrelated local changes.
- Do not delete PostgreSQL volumes.
- Do not overwrite existing owner credentials or tenant data.
- Use a dedicated smoke tenant and document it.
- Recreating only stopped application containers is acceptable when required; preserve database volumes.
- Leave Sprint 3.3 changes uncommitted for review.

---

## Final Report Format

Return a concise, evidence-based completion report containing:

1. Confirmed teleport root cause.
2. Lifecycle/state-machine changes.
3. Repositioning data model and migration.
4. Position trust/staleness rules.
5. API endpoints and backend enforcement.
6. Simulator no-teleport and restart-continuity design.
7. Tracking movement-phase changes.
8. Flutter/map UX changes.
9. Resource reservation/cancellation behavior.
10. Automated test counts and results.
11. Browser workflow results with exact coordinates/distances.
12. Evidence paths.
13. Environment limitations.
14. Actual elapsed time per task and total.
15. Exact `git status --short` summary.

Explicitly state whether any commit or push was performed. The expected answer is that neither was performed.
