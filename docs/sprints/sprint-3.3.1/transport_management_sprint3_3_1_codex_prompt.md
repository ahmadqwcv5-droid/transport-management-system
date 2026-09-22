# Sprint 3.3.1 — Simulator Location Setup and GPS Heartbeat Usability

## Role

Act as a senior product engineer and technical lead working inside the existing **Transport Management System** repository.

Implement this sprint end to end. Do not merely provide recommendations or a plan. Inspect the current implementation, reproduce the user-facing failures, implement the smallest complete correction, validate it through the actual Flutter UI, and document the result.

---

## Repository and Current Baseline

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Start from the current `main` branch, which includes Sprint 3.3 and commit `3460546` or a later reviewed commit.

Before changing code:

1. Fetch the latest repository state.
2. Inspect `git status` and preserve all unrelated user changes.
3. Read `README.md`, `docs/architecture.md`, `docs/sprints/sprint-3.3/SPRINT3_3_IMPLEMENTATION_PLAN.md`, and the Sprint 3.3 evidence.
4. Trace the existing simulator controls, `seed-position` backend command, current-position persistence, online/offline calculation, dispatch freshness policy, trip-details error handling, dashboard data flow, and Flutter compile-time simulator gate.
5. Reproduce both user-facing failures described below before implementing the fix.

Preserve all correct Sprint 3.3 behavior, including:

- assignment never teleports a truck;
- separate repositioning and cargo routes;
- `EnRouteToPickup` and `AtPickup` lifecycle states;
- backend proximity enforcement before cargo start;
- route restoration after API restart;
- trip/run/leg-aware tracking history;
- physical speed semantics at accelerated simulation rates;
- OpenFreeMap/MapLibre rendering;
- incremental stable annotations;
- no global annotation clears and no polling camera moves;
- English/Arabic localization and RTL/LTR;
- tenant isolation.

Do not redesign the trip module in this sprint. Trip CRUD and operations UX will be handled separately in Sprint 3.4.

---

## Confirmed Usability Failures

### Failure 1 — A newly created truck has no position

A truck record does not inherently have GPS coordinates. In production, its first location will come from a GPS device. In Development, the simulator already supports the backend command:

```text
seed-position
```

However, that command is currently exercised only through tests/direct API calls. There is no usable Flutter workflow for a developer or product tester to select a new truck and place it on the map.

The current simulator truck selector is built from tracked positions, so a truck with no position may not appear in the selector at all. This creates a circular usability failure:

```text
The truck needs a position to appear in the simulator list,
but the user needs the simulator list to assign its first position.
```

The user sees the localized equivalent of:

> Record the truck's current position before dispatch.

The backend validation is correct, but the Development UI does not provide a way to satisfy it.

### Failure 2 — A stationary simulated location becomes stale

Dispatch preview correctly rejects a position older than `Dispatch__MaximumPositionAgeSeconds`, currently defaulting to 300 seconds.

Real GPS devices normally continue sending heartbeat/location messages while a vehicle is stationary. The simulator does not currently emulate that behavior for an idle or seeded truck. Therefore, after approximately five minutes, a previously valid simulated position becomes stale and repositioning preview fails.

Do not solve this by disabling freshness checks or by assigning a very large Development timeout. The simulator must behave more like a GPS source.

---

## Sprint Goal

Make Sprint 3.3 fully testable from the Flutter UI without Postman, database edits, or custom API calls.

After this sprint:

1. Every active truck appears in the Development simulator panel, including trucks with no tracking history.
2. A user can set a simulated truck position from a real map, location search, or manual coordinates.
3. The position is immediately visible on the fleet map and usable for route-to-pickup preview.
4. A stationary online simulated truck emits a bounded GPS-like heartbeat so its location remains fresh.
5. Pause stops movement but does not make the GPS device stale or offline.
6. Stop/offline behavior still makes the truck offline and must not be hidden by heartbeats.
7. Missing, stale, and offline states have clear actions rather than dead-end error messages.
8. Production builds do not expose simulator position controls.

---

## Mandatory Working Process

Create `docs/sprints/sprint-3.3.1/SPRINT3_3_1_IMPLEMENTATION_PLAN.md` before material implementation.

The plan must include:

- baseline findings;
- reproduction of both failures;
- chosen heartbeat ownership and persistence design;
- UI flow for first position and stale-position refresh;
- Development/production security boundary;
- ordered tasks;
- test plan;
- browser workflow;
- risks and decisions;
- actual start/end timestamps and elapsed time per task;
- total active sprint time.

Update timing during the work rather than filling it entirely from estimates afterward.

Add focused regression tests that demonstrate the current failures before fixing them.

---

## Product Behavior

### Truck location states

The Development simulator UI must classify every active truck into one of these clear states:

| State | Meaning | Primary action |
|---|---|---|
| No location | No persisted tracking position exists | Set simulated location |
| Current | Position is online and within the freshness threshold | View or update location |
| Stale | Position exists but is older than the dispatch threshold | Refresh/update location |
| Offline | Latest position explicitly reports offline | Set online or update location as appropriate |

Use existing backend policies as the authoritative source wherever possible. Avoid duplicating a hard-coded 300-second rule in Flutter. If the frontend needs freshness metadata, return an explicit status/age/policy value from the API.

### Setting a first simulated location

The user flow must be:

1. Open Development simulator controls.
2. Select any active truck, even if it has no position.
3. Choose **Set simulated location**.
4. Open a location picker.
5. Select a coordinate using one of:
   - clicking/tapping the real configured MapLibre map;
   - searching for a place using the existing geocoding abstraction;
   - entering valid latitude/longitude manually.
6. Show a marker and human-readable coordinate/location preview.
7. Confirm explicitly.
8. Call the existing simulator control endpoint using `seed-position` or a more accurately named compatible command.
9. Refresh dashboard and operations state.
10. Show the truck immediately on the fleet map.

Do not default the new truck to:

- the trip pickup;
- `(0, 0)`;
- a random coordinate;
- another truck's position;
- a hard-coded demo city without explicit user action.

### Updating or refreshing an existing position

For a current or stale position, support:

- **Refresh at same coordinate**: create/record a current online simulator report without geographic movement;
- **Move simulated truck**: select a different coordinate through the same location picker.

Make these actions clearly distinct. Refreshing must not look like movement and must not create a false travelled trail for a trip.

### Contextual recovery from trip details

When route-to-pickup preview fails because the assigned truck has no location or a stale simulated location:

- In a Development build with simulator controls explicitly enabled, show an actionable localized recovery dialog or button:
  - Set truck location;
  - Refresh simulated location;
  - Open simulator location picker.
- After successful correction, let the user retry preview without navigating through unrelated screens.
- Do not automatically retry an external routing request repeatedly.
- In production, retain the correct localized error and do not expose simulator actions.

For an offline truck, do not silently make it online. Require the user to explicitly choose the appropriate simulator action.

---

## Development-Only Security Boundary

Simulator location mutation must remain unavailable in production.

Enforce the boundary at multiple layers:

- backend environment/provider configuration;
- existing simulator-enabled gate;
- authorization policy, limited to the appropriate Owner/operations role according to current conventions;
- Flutter `ENABLE_SIMULATOR_CONTROLS` compile-time gate;
- no hidden production route that can mutate truck GPS coordinates merely by knowing an ID.

Do not rely only on hiding a Flutter button.

Return stable ProblemDetails error codes for disabled/unauthorized/invalid simulator commands.

Tenant isolation is non-negotiable: a user must never seed, refresh, or view another tenant's truck position.

---

## Simulator Truck List Requirements

The simulator selector must be sourced from the tenant's active truck inventory, not only from the current tracking-position list.

For every truck show enough context to identify it safely:

- plate number;
- current location state;
- last update age/time when a position exists;
- online/offline state;
- current trip/phase when applicable.

The selector and state must update when:

- a truck is created;
- a location is seeded;
- a heartbeat arrives;
- the truck is set offline/online;
- a trip assignment or movement phase changes.

Avoid creating a second inconsistent source of truth for truck inventory.

---

## Reusable Location Picker

Do not duplicate the trip planner's map/location-selection logic in an unmaintainable way.

Extract or reuse a component/service for:

- map selection;
- geocoding search results;
- manual coordinate validation;
- selected marker;
- configured-map fallback behavior;
- loading/error states;
- English/Arabic labels and RTL/LTR layout.

Requirements:

- Use the configured MapLibre/OpenFreeMap style.
- Preserve attribution.
- Validate latitude `[-90, 90]` and longitude `[-180, 180]`.
- Work when geocoding is unavailable by allowing map/manual selection.
- Work when the map style is unavailable by allowing manual coordinates.
- Do not expose raw provider exceptions directly to users.
- Do not introduce API keys or secrets.

If extracting a reusable picker would create unreasonable risk to the working trip planner, implement a focused shared abstraction with tests and preserve all existing trip-planner behavior.

### Immediate map markers in trip creation/editing

Fix the existing trip planner's map-selection feedback as part of the shared location-picker work.

Currently, choosing **Select on map** and clicking a coordinate updates the form fields, but the user may not see a marker at the clicked point until a route is calculated. This makes it unclear whether the click was accepted or which exact location was selected.

Required behavior:

- When the user selects Pickup and clicks the map, show a pickup marker immediately at the exact clicked coordinate.
- When the user selects Delivery and clicks the map, show a delivery marker immediately at the exact clicked coordinate.
- Display markers before route calculation; route geometry is not required for marker feedback.
- Use visually distinct, localized semantics for pickup and delivery, such as green pickup and red delivery markers or existing design-system equivalents.
- Keep the first marker visible while selecting the second stop.
- Clicking again for the same stop moves/replaces that stop's marker instead of creating duplicate markers.
- Keep marker coordinates and latitude/longitude form fields synchronized in both directions.
- If manual coordinates or a geocoding result changes a stop, update its marker consistently.
- When editing a Draft trip, initialize the map with its existing pickup and delivery markers.
- After both locations are selected, keep both markers visible while calculating and displaying the route.
- Recalculating or clearing route geometry must not accidentally remove valid selected-stop markers.
- Do not refit the camera repeatedly because of unrelated form rebuilds. A one-time explicit fit-to-selected-stops action or a deliberate initial fit is acceptable.
- Preserve MapLibre attribution, map fallback behavior, English/LTR, and Arabic/RTL.

Use stable annotation identifiers or deterministic update logic. Do not clear and recreate every map annotation for a single marker move if the MapLibre API supports an incremental update.

---

## GPS-Like Heartbeat Requirements

### Correct semantics

An online simulated GPS device should continue reporting while the vehicle is stationary.

Required behavior:

- A seeded online truck remains fresh while the simulator environment is active.
- Pausing movement does not stop the device heartbeat.
- Reaching the end of a route does not immediately make the position stale.
- At Pickup waiting does not become stale merely because the truck is stationary.
- Setting a truck offline stops online heartbeats and preserves offline state.
- The Stop command's documented offline semantics remain intact.
- Setting the truck online resumes heartbeat without moving it.
- Heartbeat does not change latitude, longitude, heading, trip phase, route progress, or travelled distance.
- Heartbeat never moves an unlocated truck to a fabricated coordinate.

### Bounded persistence

Do not insert a database row on every dashboard poll.

Add a configurable simulator heartbeat interval with a sensible Development default that is safely shorter than the dispatch maximum position age. Validate or clamp invalid combinations so the default configuration cannot make an online simulated truck stale.

For example, use a dedicated setting equivalent to:

```text
Tracking__SimulatorHeartbeatSeconds
```

The exact design may use append-only heartbeat samples, a latest-position projection, or another architecture-consistent method, but it must satisfy all of the following:

- no row per 3–5 second poll;
- dispatch freshness remains correct;
- restart behavior remains correct;
- trip trail does not gain false movement;
- historical data is not rewritten misleadingly;
- online/offline transitions remain auditable;
- seven idle trucks can run through a long demo without uncontrolled history growth.

Document the expected maximum heartbeat rows per truck per hour under default configuration.

### Ownership and architecture

Keep GPS heartbeat behavior in the backend/provider/application layer, not in a Flutter timer that sends fake coordinates. Closing the browser must not conceptually define whether a GPS unit is online.

The current simulator may still be sampled through the existing Development polling architecture, but the heartbeat logic must be centralized and reusable by backend tests. Document that real GPS ingestion will eventually be independent of dashboard polling.

Do not weaken production `TRUCK_POSITION_STALE` enforcement.

---

## Backend/API Requirements

Inspect and extend existing contracts rather than adding redundant endpoints without reason.

At minimum support:

### Inventory plus tracking-state data

Flutter must be able to render all active trucks and their optional latest-position metadata.

Use either:

- a dedicated Development simulator inventory response; or
- a clean composition of the existing truck list and position list.

Avoid an N+1 request per truck.

### Seed/set position

Support tenant-safe validation for:

- truck exists in current tenant;
- truck is active;
- valid coordinates;
- simulator is enabled and configured;
- caller is authorized;
- source and movement phase clearly indicate a simulator current-location seed/update;
- no unrelated trip/cargo route association is fabricated.

### Refresh same position

Provide an explicit, semantically clear operation. Do not require the frontend to copy private/internal tracking fields blindly.

Refreshing a location must:

- keep the coordinate unchanged;
- retain or deliberately reset online state according to the explicit action;
- not add cargo/repositioning progress;
- not create an artificial route/trail segment;
- create at most the bounded necessary persistence event.

### State metadata

Return enough information for the UI to distinguish no-location/current/stale/offline without reproducing backend policy inconsistently.

Use stable error codes and update centralized localization mappings.

---

## Flutter UX Requirements

### Simulator panel

Improve the Development simulator panel without redesigning the production dashboard.

Required controls:

- active-truck selector including trucks with no position;
- state badge: No location / Current / Stale / Offline;
- last update timestamp and/or age;
- Set simulated location;
- Refresh location;
- Move simulated truck;
- Set online;
- Set offline;
- existing Start/Pause/Resume/Stop/Reset/Step/speed controls.

Disable or hide actions that do not make sense for the selected state, and explain why with localized helper text/tooltips where useful.

### Location dialog

The dialog must:

- identify the selected truck by plate number;
- display the real map when configured;
- allow search/map/manual coordinate selection;
- show the selected coordinate before confirmation;
- require explicit confirmation;
- have loading and error states;
- support English/LTR and Arabic/RTL;
- be keyboard-usable on Web;
- avoid overflow at common desktop sizes.

### Trip recovery action

From an Assigned trip with missing/stale simulator location, provide an obvious Development-only route to correct the location and then return to the trip workflow.

Do not make users infer that they must call a hidden API command.

---

## Data Correctness Requirements

- Setting a first location creates `MovementPhase.CurrentLocation` or the repository's equivalent.
- It must not attach the position to the assigned trip merely because the truck is reserved.
- It must not attach cargo `RoutePlanId` or repositioning plan ID.
- Refreshing a stationary position must not increase route progress.
- Heartbeat rows must not appear as travelled distance.
- Trip history must continue excluding unrelated current-location samples.
- Assignment must continue producing zero geographic movement.
- New coordinates must remain tenant-isolated.
- Concurrent seed/refresh/online/offline actions must produce deterministic final state.

---

## Required Automated Tests

Add focused tests at appropriate layers.

### Backend/integration tests

1. A newly created active truck with no position appears in simulator inventory/state as No location.
2. A tenant can seed a valid coordinate for its truck.
3. Tenant A cannot seed or refresh Tenant B's truck.
4. Seed is rejected when the simulator is disabled or outside Development policy.
5. Invalid latitude/longitude is rejected with a stable error code.
6. Seeding creates a current-location phase without trip/route/repositioning associations.
7. The new current position becomes immediately available through dashboard/current-position APIs.
8. An online stationary seeded truck remains fresh beyond the dispatch maximum-age window when heartbeat sampling is exercised.
9. Heartbeat does not change coordinates, heading, route progress, or movement phase.
10. Heartbeat persistence is bounded and does not create one row per poll.
11. Pause preserves online heartbeat while stopping movement.
12. Offline/Stop prevents online heartbeats from falsely restoring online status.
13. Set online resumes heartbeat without moving the truck.
14. Refresh same coordinate does not create a false trip trail segment.
15. A fresh seeded/refreshed position allows repositioning preview.
16. A genuinely stale position is still rejected when heartbeat is not applicable.
17. Assignment continues to cause no teleport.
18. API/provider restart preserves the latest simulated coordinate and freshness behavior.

### Flutter tests

1. All active trucks appear in the simulator selector, including no-location trucks.
2. Correct state badge and last-update information are displayed.
3. No-location truck enables Set simulated location.
4. Map selection sends the selected coordinates for the correct truck.
5. Search selection and manual coordinates work.
6. Invalid coordinates block confirmation.
7. Refresh sends the explicit refresh operation and preserves coordinates.
8. Stale and missing-location trip errors expose a Development-only recovery action.
9. Successful location setup returns to/reloads the trip workflow.
10. Production/disabled simulator configuration hides every location-mutation control.
11. English and Arabic strings render correctly in LTR/RTL.
12. Existing trip planner map/location selection still works after any component extraction.
13. Simulator heartbeat/dashboard refresh produces no global map annotation clears.
14. Polling produces no automatic camera movement.
15. Clicking the trip-planner map for Pickup immediately displays a pickup marker at the clicked coordinate before route calculation.
16. Clicking the trip-planner map for Delivery immediately displays a distinct delivery marker while preserving the pickup marker.
17. Re-selecting either stop moves its existing marker without creating duplicates.
18. Manual-coordinate and geocoding changes keep form fields and stop markers synchronized.
19. Editing an existing Draft initializes both stop markers correctly.

Prefer observable state/data assertions over tests that only verify mocks were called.

---

## Mandatory Browser Workflow

Run a real Flutter Web workflow against the real API and PostgreSQL database using a dedicated smoke-test tenant. Do not overwrite existing credentials or tenant data.

The workflow must be performed through visible Flutter UI controls for location setup. Direct API seeding may be used only for lower-level automated tests, not as a substitute for the browser acceptance path.

Prove all of the following:

1. Log in with simulator controls enabled.
2. Create a new active truck that has never reported a position.
3. Open the simulator and confirm the truck appears with No location.
4. Create/assign a trip to that truck.
5. Attempt route-to-pickup preview and observe the localized missing-location recovery UI.
6. Open the location picker from the UI.
7. Select a point far from pickup using the real map.
8. Confirm the location and see the truck marker appear at the selected point.
9. Return to the trip and successfully preview the repositioning route.
10. Verify the orange approach route starts at the chosen truck coordinate.
11. Leave the truck stationary online for longer than the configured dispatch freshness limit, using a shortened test-specific safe configuration if needed to keep the test practical.
12. Prove bounded heartbeat reports keep the position Current and preview remains available.
13. Prove coordinates and cargo/repositioning progress do not change during stationary heartbeat.
14. Pause and prove heartbeat/freshness continues without movement.
15. Set offline and prove the UI reports Offline and preview is rejected.
16. Explicitly set online and prove freshness resumes without a position jump.
17. Manually move the simulated truck through the UI to another chosen coordinate and verify the fleet marker updates only after confirmation.
18. Pan the fleet map and observe at least ten polling updates with zero camera refits and no marker flicker/global clears.
19. Verify the location picker, simulator panel, recovery message, and map in English/LTR and Arabic/RTL.
20. Open New Trip, choose Pickup selection, click the real map, and prove the pickup marker appears immediately before route calculation.
21. Choose Delivery selection, click a second location, and prove both distinct markers remain visible before calculating the cargo route.
22. Move one selected stop and prove its marker updates without duplicating or removing the other stop.

Retain evidence under:

`docs/evidence/sprint3_3_1/`

Evidence must include:

- screenshot of new truck in No location state;
- screenshot of real-map location picker;
- screenshot of marker at confirmed coordinate;
- screenshot of successful route-to-pickup preview;
- screenshot/state after the heartbeat freshness window;
- offline and online recovery evidence;
- English and Arabic screenshots;
- API/PostgreSQL evidence that heartbeat persistence is bounded;
- before/after coordinates proving refresh does not move the truck;
- annotation-operation counts across at least ten polls;
- screenshots showing immediate pickup and delivery markers before route calculation;
- concise machine-readable browser-workflow output.

Do not claim browser success if location was seeded directly through an API call instead of the Flutter UI.

---

## Documentation Requirements

Update at least:

- `README.md`;
- `docs/architecture.md`;
- relevant API/configuration documentation;
- `docs/sprints/sprint-3.3.1/SPRINT3_3_1_IMPLEMENTATION_PLAN.md`.

Document:

- how a new truck receives its first Development simulated location;
- differences between Set, Move, Refresh, Online, Offline, Pause, and Stop;
- heartbeat interval and maximum-position-age relationship;
- expected maximum heartbeat row rate per truck;
- why freshness validation remains enabled;
- Development/production security boundaries;
- behavior when map/geocoding is unavailable;
- the future distinction between simulator polling and real GPS ingestion.

---

## Validation Requirements

Run the repository's correct equivalents of:

- .NET restore and build;
- all backend integration tests;
- focused simulator location/heartbeat/security tests;
- EF migration/drift checks if the model changes;
- Flutter dependency resolution;
- Flutter analyzer;
- all Flutter tests;
- focused location-picker and simulator-panel tests;
- Flutter Web release build with simulator controls enabled for the Development artifact;
- a release/production-oriented build or test proving simulator controls are absent when disabled;
- real Firefox or Chrome browser workflow;
- Docker Compose API/PostgreSQL health checks;
- live API and PostgreSQL bounded-heartbeat verification.

Report exact pass/fail counts. Do not suppress warnings, weaken assertions, skip failures, or increase freshness timeouts simply to make validation pass.

If Android cannot be built because no SDK/device exists, report the exact limitation and do not claim it passed.

---

## Acceptance Criteria

Sprint 3.3.1 is complete only when all applicable conditions are true:

- [ ] Every active tenant truck appears in Development simulator controls.
- [ ] A truck with no history is visibly labeled No location.
- [ ] The first simulated position can be set entirely through Flutter UI.
- [ ] The picker supports real map selection, search, and manual coordinates.
- [ ] Trip creation/editing shows pickup and delivery markers immediately when the map is clicked, before route calculation.
- [ ] Pickup and delivery markers remain synchronized with map clicks, search results, and manual coordinates without duplicates.
- [ ] No automatic or fabricated default coordinate is used.
- [ ] Seed/set/refresh operations are authorized, tenant-safe, and Development-only.
- [ ] A confirmed coordinate appears immediately on the fleet map.
- [ ] A fresh coordinate enables route-to-pickup preview.
- [ ] Missing/stale position errors provide a Development-only recovery action.
- [ ] An online stationary simulated GPS remains fresh through bounded heartbeats.
- [ ] Heartbeat does not move the truck or change route progress.
- [ ] Heartbeat does not write a row on every poll.
- [ ] Pause preserves heartbeat while stopping movement.
- [ ] Offline/Stop is not undone by heartbeat.
- [ ] Set online resumes reporting without a jump.
- [ ] Genuine stale-location validation remains enforced.
- [ ] Assignment remains teleport-free.
- [ ] Trip/repositioning/cargo tracking isolation remains correct.
- [ ] Production builds expose no simulator coordinate mutation.
- [ ] English/LTR and Arabic/RTL are verified.
- [ ] Polling causes zero global annotation clears.
- [ ] Polling causes zero automatic camera moves.
- [ ] Backend and Flutter test suites pass.
- [ ] Flutter Web release build succeeds.
- [ ] Real browser evidence uses the visible Flutter location picker, not direct API seeding.
- [ ] Documentation and actual elapsed-time records are complete.

Do not describe the sprint as complete if a tester still needs Postman, SQL, or a hidden API call to give a new truck its first position.

---

## Explicitly Out of Scope

Do not expand this sprint into:

- trip list redesign;
- trip creation wizard;
- trip deletion, archiving, reassignment, or audit timeline;
- finance, expenses, payments, or profitability;
- real GPS vendor integration;
- SignalR/WebSocket migration;
- production background telemetry ingestion;
- driver photos or avatar markers;
- maintenance/documents;
- multi-stop trip UX;
- route optimization;
- dashboard visual redesign;
- changing OpenFreeMap, MapLibre, OSRM, or the truck icon.

Those belong to later sprints. This sprint must remain focused on making the existing Sprint 3.3 workflow usable and testable.

---

## Git and Data Safety

- Do not commit.
- Do not push.
- Do not rewrite Git history.
- Do not discard unrelated local changes.
- Do not delete PostgreSQL volumes.
- Do not overwrite existing owner credentials or tenant data.
- Use a dedicated smoke-test tenant and document it.
- Preserve the existing database volume during container recreation.
- Leave Sprint 3.3.1 changes uncommitted for review.

---

## Final Report Format

Return a concise, evidence-based report containing:

1. Confirmed root cause of the missing-location workflow failure.
2. Confirmed root cause of stationary-location staleness.
3. Simulator inventory and location-picker changes.
4. Heartbeat design, interval, and bounded persistence rate.
5. Backend security and tenant-isolation enforcement.
6. Missing/stale/offline recovery UX.
7. Map and localization changes.
8. Automated test counts and results.
9. Real browser workflow results.
10. Evidence paths.
11. Environment limitations.
12. Actual elapsed time per task and total.
13. Exact `git status --short` summary.

Explicitly state whether any commit or push was performed. The expected answer is that neither was performed.
