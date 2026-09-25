# Sprint 4.1.2.1 — Driver Assignment Activation and End-to-End Acceptance Repair

## Role

Act as a senior product engineer and technical lead working inside the existing Transport Management System repository.

You are responsible for product behavior, backend correctness, Flutter Web UX, MapLibre stability, automated testing, tenant isolation, safe data handling, documentation, and honest acceptance evidence.

Do not treat this task as a superficial UI patch. Trace and repair the complete operational path from assignment to actual simulator movement.

---

## Repository and baseline

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected starting point at the time this prompt was written:

```text
6d7f0a9 feat(operations): add driver tracking workflow
```

Before changing anything:

1. Inspect the current branch, HEAD, worktree, and recent commits.
2. Treat the repository state you actually find as authoritative.
3. Preserve all unrelated user changes.
4. Do not reset, discard, overwrite, or clean user work.
5. Do not modify `.env`.
6. Do not delete or recreate retained PostgreSQL volumes.
7. Do not replace existing users, tenants, trucks, drivers, trips, photos, or credentials.
8. Do not commit, push, create a branch, or open a pull request unless explicitly requested later.

If the baseline differs from the commit above, document the difference and continue from the current repository state.

---

## Mandatory sprint plan

Create and continuously maintain:

```text
docs/sprints/sprint-4.1.2.1/SPRINT4_1_2_1_IMPLEMENTATION_PLAN.md
```

The plan must contain:

- baseline commit and initial worktree state;
- confirmed root causes, not only hypotheses;
- final lifecycle and command design;
- API and Flutter changes;
- tenant and authorization analysis;
- test matrix;
- browser acceptance design;
- retained-data safety strategy;
- actual start/end timestamps and active elapsed time for every task;
- final validation results and unresolved limitations.

Update the plan while working. Do not reconstruct timings from memory at the end.

---

## Background

Sprint 4.1.2 added significant backend and driver-workspace functionality:

- a browser-independent simulator ingestion worker;
- Driver Workspace polling;
- a Driver departure endpoint;
- Driver/Truck post-trip sessions;
- arrival geofences and operational notifications;
- a Driver map and post-trip location view;
- authenticated password change;
- a two-second live refresh target.

However, the real user workflow is currently not usable end to end.

The owner manually tested this scenario:

1. The owner created a trip.
2. The owner assigned a truck and a Driver who has an application account.
3. The Driver account received a trip-assignment notification.
4. The Driver did not get a clear, actionable departure experience.
5. The Driver map did not become reliably usable.
6. The truck did not move because the trip remained `Assigned`.
7. The Driver could not clearly confirm departure and activate the simulator workflow.

The current repository evidence also states that the mandatory independent Owner/Driver browser acceptance workflow did not pass. The legacy browser harness ended with multiple exceptions. Therefore Sprint 4.1.2 must not be treated as end-to-end accepted.

---

## Confirmed design gaps to investigate and repair

Verify each item against the current code before implementation and document the exact findings.

### 1. Hidden approach-route prerequisite

The Driver departure command currently requires:

- a current truck position;
- an online truck;
- a position fresh enough for dispatch;
- and, when outside the pickup radius, a valid current repositioning/approach route.

Assignment does not guarantee that the approach route exists. The Driver cannot prepare it from the Driver Workspace. This creates a dead end where departure depends on a prior manager action that is not communicated to the Driver.

### 2. Action availability is too shallow

The current Driver action projection is primarily based on trip status. It can claim that `depart-to-pickup` is available even when the command will fail because telemetry or route prerequisites are missing.

### 3. Flutter swallows actionable errors

Driver actions catch failures and often reduce them to a generic error message. Stable backend error codes must be preserved and translated into actionable Arabic and English messages.

### 4. The departure action is not prominent

The Driver primary action appears after the map and information card. On smaller displays it can be below the fold, and the assignment notification does not clearly tell the Driver that a confirmation is required.

### 5. Assignment notification navigation is not a proven workflow

The Driver must be able to press a clear notification action and arrive at a refreshed `/my-trip` workspace. The application must not require guessing, manual page refreshes, or navigating between screens until the trip appears.

Do not force automatic navigation while the Driver is doing something else. Use an explicit, highly visible action such as `Open trip` / `فتح الرحلة`.

### 6. Driver map synchronization is fragile

Inspect the Driver map update path carefully. Poll-driven map operations must not overlap. A transient annotation or image error must not permanently replace the map with an unavailable placeholder. The map requires a retry path and useful loading/error states.

### 7. Previous browser evidence bypassed the behavior under test

The previous browser flow used a manager override/API dispatch before Driver verification. It did not prove:

```text
Assignment notification
→ Driver opens My Trip
→ Driver confirms departure
→ approach route is prepared
→ trip becomes EnRouteToPickup
→ background simulator starts moving the truck
```

This sprint must prove that exact path without bypassing it.

---

## Product outcome

After this sprint, a normal Driver must be able to perform the following without manager intervention after assignment:

```text
Owner assigns ready trip
        ↓
Driver receives visible assignment alert
        ↓
Driver presses Open Trip
        ↓
My Trip displays truck, pickup, map, status, and primary action
        ↓
Driver presses Confirm Departure to Pickup
        ↓
Backend validates trusted truck telemetry
        ↓
Backend reuses or generates the approach route when needed
        ↓
Trip transitions to EnRouteToPickup
        ↓
Background simulator starts advancing the truck
        ↓
Driver and Owner views update without manual refresh
```

The owner must not need to manually preview the approach route merely to make the Driver departure command possible.

Manager route preview may remain available as an optional planning/inspection tool, but it must not be a hidden prerequisite of the normal Driver workflow.

---

## Scope

This is a focused repair sprint. Implement only what is required to make assignment activation reliable and verifiably complete.

### In scope

- Driver assignment-to-departure workflow;
- automatic approach-route preparation at Driver departure;
- explicit Driver action readiness/blocking information;
- assignment-alert navigation and immediate workspace refresh;
- prominent Driver primary action UX;
- translated actionable errors;
- robust Driver map loading, retry, and serialized synchronization;
- simulator activation immediately after successful departure;
- a real two-profile Owner/Driver browser acceptance workflow;
- regression tests and evidence;
- documentation and timing.

### Out of scope

- finance;
- maintenance;
- real GPS vendor integration;
- SignalR;
- proof-of-delivery photos or signatures;
- route optimization across several trips;
- dispatch scheduling/optimization;
- full Driver shift management;
- redesigning unrelated CRUD screens;
- unrelated architecture rewrites.

---

## Required backend behavior

### 1. Introduce one authoritative Driver departure use case

Implement one application-level operation for normal Driver departure. A suitable conceptual name is:

```text
PrepareAndDepartToPickup
```

The exact code name may follow existing conventions, but the behavior must be cohesive.

It must:

1. Resolve the signed-in user to the tenant-scoped linked Driver.
2. Resolve that Driver's current assigned trip.
3. Verify that the trip is still `Assigned` and belongs to the same tenant.
4. Verify that the same Driver and truck are still assigned.
5. Load the latest trusted position for the assigned truck.
6. Reject missing, offline, or stale telemetry with stable error codes.
7. Resolve the pickup coordinates from the trip snapshot.
8. If the truck is already within the configured pickup-arrival radius, perform the existing direct dispatch-for-pickup-confirmation behavior without inventing a route.
9. If the truck is outside the pickup radius:
   - reuse a valid current proposed approach route when safe;
   - otherwise calculate a new route through the existing vendor-neutral routing abstraction;
   - persist an immutable repositioning/approach route snapshot;
   - revalidate the assignment, trip version/state, and truck movement tolerance before transition;
   - activate the correct route and transition the trip to `EnRouteToPickup`.
10. Start or reuse the Driver/Truck session using the existing rules.
11. Set operational Driver/Truck states consistently.
12. append auditable trip/resource events;
13. persist once in a consistent final state;
14. return the updated Driver Workspace or sufficient data for an immediate workspace refresh.

Do not require the Driver to submit arbitrary Driver IDs, truck IDs, tenant IDs, coordinates, or route IDs.

### 2. Concurrency and external routing

Do not keep a database transaction open unnecessarily while waiting for an external routing provider.

Use a safe pattern:

1. read and validate a departure proposal;
2. calculate the route if needed;
3. reload/revalidate the trip, assignment, version, position freshness, and movement tolerance;
4. persist the route snapshot and state transition safely.

Handle double-clicks and repeated submissions predictably. They must not create duplicate active approach routes, duplicate Driver/Truck sessions, or duplicate events.

If an identical departure is already active, return an idempotent success/current workspace where safe. Otherwise return a stable conflict code.

### 3. Approach-route validity

Centralize the validity policy. At minimum, validity must consider:

- tenant;
- trip;
- currently assigned truck;
- pickup destination;
- route profile;
- route/assignment revision;
- source position age;
- movement from the proposal origin against the configured tolerance;
- route status.

Do not reuse a route from a previous truck, previous assignment, previous pickup, or expired plan.

### 4. Stable error codes

Use or add stable ProblemDetails `errorCode` values for at least:

```text
DRIVER_LINK_REQUIRED
DRIVER_TRIP_NOT_FOUND
TRIP_NOT_ASSIGNED
DRIVER_ASSIGNMENT_CHANGED
TRUCK_POSITION_REQUIRED
TRUCK_POSITION_STALE
TRUCK_OFFLINE
PICKUP_COORDINATES_REQUIRED
ROUTING_PROVIDER_UNAVAILABLE
ROUTE_CALCULATION_FAILED
DEPARTURE_ALREADY_IN_PROGRESS
INVALID_TRIP_TRANSITION
```

Reuse existing codes where their meaning is already correct. Do not create duplicate synonyms.

Do not expose provider exception text, secrets, request headers, or internal stack traces to Flutter.

### 5. Action/readiness projection

Replace the status-only Driver action decision with a server-owned readiness projection.

A suitable contract is conceptually:

```json
{
  "code": "DEPART_TO_PICKUP",
  "visible": true,
  "enabled": true,
  "blockingReason": null,
  "requiresConfirmation": true
}
```

When blocked, keep the relevant action visible but disabled and return a stable reason, for example:

```json
{
  "code": "DEPART_TO_PICKUP",
  "visible": true,
  "enabled": false,
  "blockingReason": "TRUCK_POSITION_REQUIRED",
  "requiresConfirmation": true
}
```

Maintain backward compatibility for the existing `allowedActions` array if needed, but Flutter must use the richer contract for the primary Driver experience.

Do not block departure merely because an approach route is absent; the departure command is responsible for generating it. Missing/offline/stale telemetry may block the action because routing cannot safely begin.

### 6. Simulator activation

The background simulator worker must begin route progress after the successful transition to `EnRouteToPickup` without requiring:

- an Owner Dashboard request;
- a tracking positions GET request;
- a manual simulator step;
- an open manager browser;
- an open Driver browser.

With the normal development configuration, persisted movement should become observable within no more than two simulator ticks plus normal scheduling tolerance.

Reads must remain side-effect free.

---

## Required Flutter behavior

### 1. Assignment alert

For `TripAssignedToDriver`, show a clear visible alert containing:

- assignment title;
- trip number;
- truck identity when available;
- a concise message that Driver confirmation is required before movement begins;
- an explicit `Open trip` / `فتح الرحلة` action.

When pressed:

1. mark the notification read safely;
2. navigate to `/my-trip`;
3. invalidate/refresh Driver Workspace immediately;
4. display loading state until the current assignment is resolved.

Do not automatically hijack navigation when the notification arrives.

### 2. Driver primary action panel

The current required Driver action must be immediately discoverable.

For an assigned trip, show a prominent primary panel before the long details content, or as a safe sticky action area on compact layouts:

```text
Trip assigned
The truck will not start moving until you confirm departure.
[ Confirm departure to pickup ]
```

Arabic equivalent:

```text
تم إسناد الرحلة إليك
لن تبدأ الشاحنة بالحركة قبل تأكيد انطلاقك.
[ تأكيد الانطلاق إلى موقع الاستلام ]
```

Requirements:

- visible without needing to discover an action below a 360-pixel map;
- responsive on desktop and mobile widths;
- confirmation dialog before mutation;
- loading/progress state while route preparation occurs;
- double-submit prevention;
- immediate refreshed status after success;
- translated, actionable failure messages;
- no generic-error-only handling for known operational failures.

### 3. Blocked states and recovery guidance

Render the primary action even when blocked, with the correct reason and recovery guidance.

Examples:

| Blocking reason | Driver message | Suggested recovery |
|---|---|---|
| `TRUCK_POSITION_REQUIRED` | Truck location has not been received yet. | Ask the manager to set/refresh the simulator location or wait for GPS. |
| `TRUCK_POSITION_STALE` | Truck location is too old to start safely. | Refresh telemetry and retry. |
| `TRUCK_OFFLINE` | Truck tracking is offline. | Bring tracking online and retry. |
| routing provider failure | The route to pickup could not be prepared. | Retry without losing the assignment. |

Provide complete English and Arabic localization. Verify RTL layout.

### 4. Driver map

The map must be useful before departure and during movement.

When the trip is Assigned:

- show the truck's current location when available;
- show the pickup marker;
- show the delivery marker when useful;
- show an existing approach preview if one exists;
- otherwise do not pretend that a route already exists;
- keep the map available even when movement has not started.

After successful departure:

- render the generated approach route;
- show the moving truck/photo marker;
- show remaining distance and ETA;
- update without manual refresh;
- retain Follow, Free, and Route Overview behavior.

### 5. Map synchronization repair

Do not start overlapping annotation mutations from repeated two-second polls.

Use serialized, latest-wins synchronization or reuse/extract the already proven fleet map coordination mechanism.

Requirements:

- at most one annotation synchronization operation in flight;
- pending updates collapse to the latest workspace state;
- no global annotation clears during polling;
- no symbol remove/re-add for coordinate-only changes;
- no style reload during polling;
- no fallback-image frame during normal coordinate updates;
- no polling camera movement while the Driver is in Free mode;
- only actual style initialization failure should mark the map unavailable;
- photo/annotation/route update failures must not permanently destroy the entire map;
- provide localized loading, error, Retry, and unavailable states;
- successful retry must restore the map without reloading the entire application.

Avoid maintaining two divergent map implementations if a shared single-vehicle map component can safely serve both Owner and Driver views.

### 6. Workspace polling and visibility

- Keep non-overlapping live polling.
- Refresh immediately after assignment notification navigation.
- Refresh immediately after successful Driver actions.
- Preserve the last valid workspace only for transient poll failures.
- Expose a non-intrusive connection/update warning when polls repeatedly fail; do not silently display an obsolete `No active trip` state forever.
- Cancel timers correctly on disposal/logout.
- Ensure one account cannot leak polling state into another account after logout/login.

---

## Authentication and two-session testing rule

Owner and Driver sessions must be tested in separate browser storage contexts.

Two normal tabs from the same browser profile are not independent because local authentication storage can be shared and one login can overwrite the other.

Use one of:

- two isolated Firefox profiles;
- Firefox plus another supported browser;
- two genuinely isolated WebDriver/browser contexts with separate storage;
- equivalent independently verified session containers.

Document the exact isolation method used.

---

## Backend test requirements

Add deterministic tests for at least the following.

### Departure orchestration

1. Far truck, no approach plan:
   - Driver departure calculates and persists a route;
   - trip becomes `EnRouteToPickup`;
   - the route is associated with the correct tenant/trip/truck;
   - the Driver/Truck session begins.
2. Far truck, valid current approach plan:
   - plan is reused;
   - no duplicate plan is created.
3. Far truck, stale/invalid plan:
   - old plan is expired;
   - a new plan is generated safely.
4. Truck already inside pickup radius:
   - departure succeeds without invented approach geometry.
5. Missing position returns `TRUCK_POSITION_REQUIRED`.
6. Offline position returns `TRUCK_OFFLINE`.
7. Stale position returns `TRUCK_POSITION_STALE`.
8. Routing provider failure:
   - trip remains `Assigned`;
   - assignment remains intact;
   - no active corrupt route/session is created;
   - stable error code is returned.
9. Assignment changes while routing is being calculated:
   - transition is rejected safely;
   - no route from the prior assignment becomes active.
10. Two simultaneous departure requests:
    - no duplicate active plan;
    - no duplicate active session;
    - no duplicate lifecycle event;
    - deterministic response behavior.

### Authorization and tenant isolation

1. A Driver cannot depart another Driver's trip.
2. A Driver cannot submit arbitrary tenant/truck/trip IDs.
3. A Driver from another company cannot observe the workspace, route, truck photo, position, or errors containing protected identifiers.
4. Owner-only simulator mutations remain protected and Development/Testing-only.
5. A Driver cannot use manager override endpoints.

### Simulator behavior

1. `Assigned` does not move.
2. Successful Driver departure causes background movement without HTTP reads.
3. The first persisted movement occurs within the configured tick budget.
4. Physical speed and operational ETA remain unaffected by simulator speed multiplier semantics.
5. Repeated reads do not advance position.

---

## Flutter test requirements

Add widget/controller/model tests covering:

- assignment alert displays a clear Driver-required-action message;
- `Open trip` navigates to `/my-trip` and requests immediate refresh;
- assigned trip shows the primary departure panel without scrolling to the bottom;
- primary action loading and double-click prevention;
- enabled departure action;
- disabled departure action with each telemetry blocking reason;
- translated ProblemDetails mappings for all new/reused error codes;
- success changes the visible trip phase;
- failure preserves the assignment and permits retry;
- map loading/error/retry states;
- map remains available with pickup coordinates but no movement yet;
- non-overlapping latest-wins map synchronization;
- transient photo/annotation errors do not permanently replace the map;
- Driver polling does not overlap;
- repeated poll failures show stale/connectivity feedback rather than a false empty state;
- logout/login disposes old Driver polling state;
- English LTR and Arabic RTL layouts.

Do not count only model parsing tests as UI acceptance.

---

## Mandatory real-browser acceptance

This is the sprint's blocking Definition of Done.

Automated unit/integration tests are necessary but not sufficient.

Use a real Flutter Web build, real MapLibre/OpenFreeMap style, real API, real PostgreSQL database, and two isolated Owner/Driver browser sessions.

### Required scenario

1. Start from a disposable test tenant or carefully isolated disposable records.
2. Create or use a Driver application account through supported product/API setup.
3. Create an active truck.
4. Seed/set a fresh online truck position that is clearly away from pickup, preferably several kilometers away.
5. Create a trip with valid pickup and delivery points.
6. Calculate the commercial pickup-to-delivery route.
7. Assign the truck and linked Driver through the Owner UI.
8. Do not calculate the approach route manually from the Owner UI.
9. Do not call manager dispatch/override.
10. Do not call the Driver departure endpoint directly from test code.
11. In the independent Driver browser, observe the new assignment alert.
12. Press `Open trip` in the UI.
13. Verify the correct trip, truck, map, current truck location, pickup, and primary action.
14. Press `Confirm departure to pickup` in the Driver UI.
15. Confirm the warning dialog in the Driver UI.
16. Observe loading while the route is prepared.
17. Verify the UI changes to `En route to pickup`.
18. Verify an approach route appears on both Driver and Owner maps.
19. Verify the truck position advances without manager Dashboard reads or manual simulator steps.
20. Close or stop polling from the Owner browser and prove that persisted positions continue advancing.
21. Verify Driver remaining distance and ETA update.
22. Verify the map remains responsive and can switch between Follow, Free, and Route Overview.
23. Verify Arabic RTL for the assignment/departure experience.

Continue through pickup/loading/delivery confirmation if practical to prove no regression in the complete lifecycle. At minimum, the assignment-to-moving-truck path above must pass continuously without bypasses.

### Acceptance assertions

Record and verify:

- notification received time;
- Driver workspace visible time;
- departure click time;
- approach route persisted time;
- status transition time;
- first changed position time;
- initial and changed coordinates;
- trip ID, truck ID, and Driver ID only for disposable evidence records;
- no manager override event;
- no direct departure API call from the harness;
- route provider result and geometry presence;
- zero duplicate active routes/sessions/events;
- independent authentication storage contexts.

### Browser harness rule

The existing legacy Flutter Drive harness previously failed. Diagnose it, repair it, or replace it with a more reliable real-browser acceptance mechanism already compatible with the project environment.

Do not hide browser exceptions with a global error handler. Do not publish screenshots from a partial run as proof of success.

If the mandatory browser scenario does not pass, the sprint status is **incomplete**, regardless of unit-test counts.

---

## Evidence requirements

Store evidence under:

```text
docs/evidence/sprint4_1_2_1/
```

Include:

- `README.md` with an honest overall result;
- automated validation summary;
- browser acceptance narrative;
- machine-readable browser result JSON;
- timestamps/latency metrics JSON;
- screenshots from Owner and Driver sessions;
- English and Arabic Driver workspace screenshots;
- database/API evidence for route creation, status transition, and position movement;
- confirmation that no manager override was used;
- map operation counts or equivalent structural stability evidence;
- retained-data before/after checks.

Never store:

- real passwords;
- access or refresh tokens;
- private request headers;
- connection strings;
- `.env` contents;
- production database dumps;
- personal customer data.

Use disposable credentials and records for evidence.

---

## Data safety

Before migrations or runtime acceptance:

1. Identify the retained Compose project, database volume, photo volume, tenant, and active account.
2. Record non-sensitive before-counts for tenants, users, clients, trucks, drivers, trips, positions, and notifications.
3. Prefer a separate disposable Compose project and volumes for destructive acceptance tests.
4. Fail closed if the supposed disposable test environment points to the retained database/volume.
5. Do not alter preserved credentials merely to make automation easier.
6. Do not create unexplained demo records in the user's tenant.
7. After validation, record equivalent after-counts and explain every deliberate disposable change.

If a migration is required:

- make it forward-only and default-safe;
- do not invent operational data during backfill;
- verify EF model drift is zero;
- document rollback limitations;
- do not apply it to retained data merely for convenience.

---

## Architecture constraints

Preserve the existing architectural direction:

- Domain owns lifecycle invariants.
- Application owns orchestration and readiness policy.
- Infrastructure owns EF/provider implementation.
- API exposes stable contracts and ProblemDetails codes.
- Flutter consumes server-owned capabilities and localizes presentation.
- tracking remains vendor-neutral;
- routing remains provider-neutral;
- tenant filters remain mandatory;
- simulator mutations remain excluded from production behavior.

Do not move business rules into Flutter.

Do not make route generation depend directly on OSRM-specific DTOs in Domain/Application contracts. Use the existing routing abstraction.

Do not make read endpoints create routes, transition trips, or move trucks.

---

## Configuration

Reuse existing configuration where possible:

- tracking ingestion tick;
- position freshness threshold;
- offline threshold;
- pickup arrival radius;
- reposition proposal movement tolerance;
- routing provider and User-Agent;
- MapLibre/OpenFreeMap style URL;
- Flutter polling interval.

Add configuration only when necessary. Provide safe defaults and validation/clamping. Update `.env.example`, README, and architecture documentation without changing `.env`.

---

## Documentation updates

Update at least:

```text
README.md
docs/architecture.md
docs/sprints/README.md
docs/sprints/sprint-4.1.2.1/SPRINT4_1_2_1_IMPLEMENTATION_PLAN.md
```

Document the final normal workflow clearly:

```text
Owner assigns
→ Driver opens assignment
→ Driver confirms departure
→ backend prepares approach route
→ simulator/GPS movement begins
→ geofence confirms arrival
```

Clarify that Owner route preview is optional and that Owner override is an audited exception, not the normal path.

Document how to run two independent browser sessions for manual testing.

---

## Validation commands and quality gates

Run the repository's actual supported commands. At minimum validate:

### Backend

```text
dotnet build
dotnet test
```

Requirements:

- zero build errors;
- zero warnings unless an unavoidable pre-existing warning is documented precisely;
- all architecture tests pass;
- all backend integration tests pass;
- EF migration drift check passes.

### Flutter

```text
flutter analyze
flutter test
flutter build web --release ...
```

Use the required existing `--dart-define` values without exposing secrets.

Requirements:

- analyzer clean;
- all Flutter tests pass;
- release Web build succeeds;
- simulator mutation code remains absent/disabled in the production build according to existing safeguards;
- real-browser workflow passes.

### Android

Attempt Android validation only if a valid SDK and device/emulator exist. If unavailable, report the exact environmental limitation. Do not substitute Android for the mandatory Web acceptance, and do not claim Android success without running it.

---

## Definition of Done

Sprint 4.1.2.1 is complete only if all of the following are true:

- [ ] Assignment alone does not move the truck.
- [ ] Driver receives a visible actionable assignment alert.
- [ ] Pressing `Open trip` opens and refreshes the correct Driver workspace.
- [ ] The map reliably appears before departure when valid pickup coordinates exist.
- [ ] The primary departure action is immediately discoverable.
- [ ] Missing/offline/stale telemetry produces explicit localized guidance.
- [ ] Absence of a precomputed approach route does not require manager intervention.
- [ ] Driver departure generates/reuses the route safely and transitions the trip.
- [ ] Simulator movement begins through the background worker.
- [ ] Movement continues without browser/dashboard reads.
- [ ] Owner and Driver views update from the same persisted state.
- [ ] Known API failures are localized instead of becoming generic errors.
- [ ] Map polling updates are serialized and do not permanently fail on transient annotation errors.
- [ ] Tenant isolation and Driver authorization tests pass.
- [ ] Concurrency/idempotency tests pass.
- [ ] Real Owner/Driver sessions use isolated browser storage.
- [ ] Browser acceptance uses no manager override and no direct departure API bypass.
- [ ] English/LTR and Arabic/RTL are verified.
- [ ] Builds, tests, analyzer, migration drift, and Web release pass.
- [ ] Retained user data and credentials remain unchanged.
- [ ] Evidence and actual elapsed-time records are complete.

If any blocking item fails, report the sprint as incomplete.

---

## Final response format

At completion, provide:

1. concise implementation summary;
2. confirmed root causes;
3. files/components changed;
4. final lifecycle behavior;
5. automated validation totals;
6. real-browser result with explicit pass/fail;
7. measured assignment-to-first-movement timing;
8. map stability result;
9. data-safety result;
10. Android status;
11. actual elapsed-time table and total;
12. remaining limitations;
13. exact git status;
14. explicit confirmation that no commit or push was performed.

Do not describe the sprint as complete if the two-profile Driver departure browser workflow did not pass from assignment through visible truck movement.
