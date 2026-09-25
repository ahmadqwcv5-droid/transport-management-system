# Sprint 4.1.2 — Driver Operations and Tracking Responsiveness

## Role

Act as a senior product engineer, logistics-domain analyst, solution architect, ASP.NET Core engineer, Flutter/MapLibre engineer, security reviewer, and end-to-end test engineer.

Work directly in the existing repository. Read all repository instructions and inspect the current code before making changes. Pay special attention to the Sprint 4.1 and Sprint 4.1.1 implementation plans, validation reports, evidence boundaries, lifecycle code, tracking simulator, geofence evaluation, notification delivery, Driver Workspace, MapLibre adapters, authentication, tenant isolation, and retained-data safeguards.

This sprint must close one complete operational loop. Do not expand it into unrelated modules.

---

# Repository and Baseline

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected baseline:

```text
5ec2d98 feat(operations): add driver onboarding and live alerts
```

Confirm the actual checked-out commit and working-tree state before implementation. Preserve unrelated user changes. Never reset, discard, overwrite, or reformat unrelated work.

The latest GitHub Quality Gate passed, but Sprint 4.1.1 documentation explicitly records that its real Firefox workflow was only partially completed and did not prove the full two-session manager/driver workflow. Treat the manual user findings below as real acceptance failures, not optional enhancements.

---

# Manual Acceptance Findings

The following issues were reproduced by the user after Sprint 4.1.1:

1. The Driver account view is materially weaker than the Owner view. It lacks practical vehicle-follow controls and does not present route phase, location, remaining time, and live movement as clearly or responsively as the manager map.
2. The Driver truck position refresh is slow.
3. Arrival alerts may appear approximately 30–60 seconds after the truck reaches pickup or delivery.
4. Assigning a trip currently allows the manager-side dispatch action to start movement. Assignment must not mean departure. The Driver must explicitly confirm departure toward pickup.
5. At pickup, the Driver must explicitly confirm loading and departure toward delivery.
6. After completing delivery, the Driver loses the map because Completed trips are excluded from the current-trip query.
7. The Driver cannot change their own password.
8. Circular truck photos look correct, but during movement the image can disappear briefly, exposing the dark status/selection circle before the photo returns.

---

# Product Goal

At the end of Sprint 4.1.2, the system must support this exact real workflow:

```text
Manager assigns trip
        ↓
Driver sees Assigned task
        ↓
Driver confirms “Depart to pickup”
        ↓
EnRouteToPickup + live approach tracking
        ↓
Automatic stable pickup arrival
        ↓
Driver confirms “Loaded and depart to delivery”
        ↓
InTransit + live cargo-route tracking
        ↓
Automatic stable delivery arrival
        ↓
Driver confirms delivery
        ↓
Trip Completed
        ↓
Driver still sees the current truck on a post-trip home map
```

Manager and Driver views must update from the same backend-owned tracking pipeline. Opening or closing the manager dashboard must not control whether the simulator advances.

---

# Mandatory Plan and Time Record

Before implementation, create:

```text
docs/sprints/sprint-4.1.2/SPRINT4_1_2_IMPLEMENTATION_PLAN.md
```

It must include:

- Baseline commit and dirty-worktree assessment.
- Current behavior and root-cause findings.
- Tracking ingestion design.
- Simulator scheduling design.
- Trip lifecycle decision table.
- Driver–truck post-trip association design.
- Geofence/notification latency budget.
- Map component/refactor design.
- Marker flicker investigation and chosen solution.
- Password security design.
- API and migration changes.
- Tenant and authorization analysis.
- Test and real-browser acceptance matrix.
- Data-safety and disposable-environment plan.
- Risks and deferred work.
- Actual start, end, and active elapsed time per task.
- Total active sprint time.

Update the plan while working. Do not reconstruct fictional timings at the end.

---

# Non-Negotiable Rules

- Preserve Clean Architecture boundaries and tenant query filters.
- Keep business transitions in Domain/Application layers.
- Keep controllers thin.
- Use stable error/event/action codes.
- Localize all user-facing text through English and Arabic ARB files.
- Preserve correct RTL/LTR behavior.
- Do not expose fleet-wide tracking to Driver accounts.
- Do not let UI polling be the authoritative generator of tracking data.
- Do not let the manager dashboard determine whether the simulator moves.
- Do not weaken stable geofence rules merely to make the demo look fast.
- Do not use the Completed trip as an active commercial trip merely to keep a map visible.
- Do not duplicate manager and driver map logic when a shared component is appropriate.
- Do not clear and recreate all MapLibre annotations on each update.
- Do not switch to SignalR/WebSockets in this sprint.
- Do not write acceptance data to the retained user database.
- Do not delete or recreate retained PostgreSQL or photo volumes.
- Do not run `docker compose down -v` against retained environments.
- Do not overwrite `.env` or retained credentials.
- Do not claim end-to-end success when the real browser workflow is incomplete.
- Do not commit, push, create a branch, or open a pull request.

---

# Workstream 0 — Retained Data and Acceptance Isolation

Preserve the Sprint 4.1.1 safeguards.

Before any migration or runtime validation:

- Identify the retained Compose project.
- Identify the exact retained PostgreSQL volume.
- Record redacted company/user/resource counts.
- Confirm the active tenant/account.
- Confirm no acceptance container mounts the retained volume.

All browser acceptance work must use the disposable acceptance environment introduced in Sprint 4.1.1 or a demonstrably equivalent isolated environment.

Requirements:

- No test row enters the retained database.
- No test photo enters retained photo storage.
- Retained aggregate counts are identical before and after acceptance.
- Teardown targets only explicitly identified disposable resources.
- If a migration must be applied to the retained development database for manual testing, take a timestamped `pg_dump` first and document the result without committing the dump.

---

# Workstream 1 — Backend-Owned Tracking Ingestion

## 1.1 Root cause

The current simulator advances when `ITrackingProvider.GetCurrent(...)` is invoked through tracking endpoints. Driver Workspace polling reads the latest persisted position but does not itself produce a new simulator sample. Consequently, live movement can depend on whether another screen—especially the manager dashboard—is polling fleet positions.

This coupling must be removed.

## 1.2 Canonical ingestion path

Create one canonical application-level ingestion pipeline for tracking samples:

```text
Tracking source
    ↓
Validate + normalize sample
    ↓
Persist when meaningful/heartbeat-required
    ↓
Evaluate geofences
    ↓
Evaluate tracking health
    ↓
Persist operation notifications
    ↓
Manager/Driver read projections
```

Every source must eventually use this path:

- Development simulator.
- Future external GPS webhook/poller.
- Explicit Testing provider.

Do not duplicate persistence/geofence logic across controllers, the hosted simulator, and Driver Workspace.

## 1.3 Development/Testing simulator scheduler

Run the simulator from a backend-owned scheduler in Development/Testing only.

Requirements:

- It advances independently of any browser being open.
- It processes all active simulator companies safely.
- It never runs when the simulator provider is disabled.
- It never runs in Production unless a future explicit provider design enables it.
- It uses a configurable tick interval.
- Recommended default tick: `2 seconds`.
- It does not overlap ticks if one execution is still running.
- Cancellation and shutdown are clean.
- Per-company failures do not terminate the process.
- Tenant/company context is explicit; do not fabricate an HTTP `ICurrentUser` in a background thread.
- It uses scoped services correctly.
- It preserves deterministic Testing support.

Add configuration such as:

```text
Tracking:SimulatorTickSeconds = 2
```

Clamp unsafe values and document them.

## 1.4 Persistence volume control

Fast sampling must not create uncontrolled row growth.

Preserve meaningful-change persistence rules:

- Coordinate movement above tolerance.
- Speed change above tolerance.
- Heading change above tolerance.
- Online/offline transition.
- Trip/route/run/phase association change.
- Bounded heartbeat for unchanged stationary vehicles.

Document expected maximum moving and stationary rows per truck/hour at default settings.

UI read polling must not insert duplicate position rows.

## 1.5 Read projections

Manager Dashboard and Driver Workspace become read projections over the same persisted latest state.

- Opening the manager page must not make the driver map faster.
- Closing the manager page must not freeze the simulator.
- Opening two clients must not double simulator speed.
- The simulator speed multiplier affects movement progress, not physical reported speed or operational ETA.

---

# Workstream 2 — Responsiveness and Arrival Latency Budget

## 2.1 Configurable client refresh

Use one documented live-operations polling configuration instead of hard-coded independent five-second timers.

Recommended defaults for this small fleet:

```text
Live map position refresh: 2 seconds
Driver Workspace refresh: 2 seconds
Notification feed refresh: 2 seconds
Non-live list refresh: slower as appropriate
```

Use compile-time/environment configuration consistently. Prevent overlapping HTTP requests and use latest-wins semantics.

Polling failures must retain the last good state and display stale/offline age accurately.

## 2.2 Geofence latency

Keep protection against GPS noise:

- Arrival radius.
- Exit radius/hysteresis.
- Consecutive evidence.
- Maximum sample age.
- Idempotent event key.
- Restart-safe persisted observation.

Tune the default policy to achieve a documented target under normal simulator conditions:

```text
Arrival qualification and visible alert within 10–15 seconds
```

A reasonable starting point is:

```text
Minimum samples: 2
Minimum dwell: 8–10 seconds
Simulator tick: 2 seconds
Notification poll: 2 seconds
```

Choose final values based on deterministic tests. Do not set dwell to zero and do not accept a single noisy point.

## 2.3 Latency instrumentation

Record these timestamps in acceptance evidence:

```text
first qualifying in-radius sample
geofence transition persisted
operation notification persisted
manager alert rendered
driver alert rendered when applicable
```

Report each latency segment and end-to-end latency. Do not estimate it by eye.

---

# Workstream 3 — Driver-Controlled Trip Start

## 3.1 Canonical lifecycle

Use the existing statuses wherever possible:

| Status | Meaning | Transition authority |
|---|---|---|
| Draft | Trip is being prepared | Manager |
| Assigned | Truck and Driver assigned; waiting for Driver departure | Manager assigns, Driver starts |
| EnRouteToPickup | Driver confirmed departure toward pickup | Driver, or manager override |
| AtPickup | Stable automatic arrival at pickup | System geofence |
| InTransit | Driver confirmed loaded and departure toward delivery | Driver, or manager override |
| AtDelivery | Stable automatic arrival at delivery | System geofence |
| Completed | Driver confirmed delivery | Driver, or manager override |
| Cancelled | Trip cancelled with reason | Authorized manager |

Do not treat assignment as departure.

The legacy `Started` and `Delivered` states/endpoints may remain for compatibility, but the normal new workflow must not require them. Document compatibility behavior and prevent ambiguous duplicate paths.

## 3.2 Manager responsibility

The manager may:

- Create route and approach preview.
- Assign truck and Driver.
- See that the trip is waiting for Driver departure.
- Notify the Driver of assignment.
- Override a Driver action only with a required audited reason.

The normal manager UI must not present `Dispatch to pickup` as if the Driver has already departed.

If a manager needs an emergency override, use a distinct action such as:

```text
Start toward pickup on Driver's behalf
```

Require a localized warning and reason.

## 3.3 Driver departure to pickup

Add a Driver action and endpoint conceptually equivalent to:

```text
POST /api/driver/my-trip/depart-to-pickup
```

Behavior:

- Allowed only for the linked Driver of the Assigned trip.
- Validate assigned truck and Driver.
- Validate trusted current truck position.
- Validate a current repositioning/approach plan when the truck is outside pickup radius.
- If the plan is stale because the truck moved, return an actionable stable error code and allow manager/driver refresh of the approach preview.
- Transition `Assigned -> EnRouteToPickup`.
- Activate the approach route.
- Start or continue the Driver–Truck operational session.
- Persist audit event and operation notification.
- Remain idempotent for safe duplicate taps.

Suggested stable action/event codes:

```text
DEPART_TO_PICKUP
DriverDepartedToPickup
APPROACH_ROUTE_REQUIRED
APPROACH_ROUTE_STALE
TRUCK_POSITION_REQUIRED
TRUCK_POSITION_STALE
TRUCK_OFFLINE
```

Button label:

```text
EN: Depart to pickup
AR: الانطلاق إلى موقع التحميل
```

## 3.4 Pickup to delivery

At `AtPickup`, the Driver action must clearly mean both operational facts:

```text
Loaded and departing to delivery
```

It transitions:

```text
AtPickup -> InTransit
```

Do not label it only `Start`.

Persist confirmation timestamp, actor, source, audit event, and notifications.

## 3.5 Delivery completion

At `AtDelivery`, the Driver confirms delivery:

```text
AtDelivery -> Completed
```

Commercial trip resources are released according to existing rules. Completion does not automatically erase the Driver's current-vehicle map context.

## 3.6 Allowed actions

The backend is authoritative for allowed actions. Flutter must render actions returned by the backend rather than duplicating status logic inconsistently.

At minimum support stable action codes:

```text
DEPART_TO_PICKUP
CONFIRM_LOADED_AND_DEPART
CONFIRM_DELIVERY
END_VEHICLE_SESSION
```

---

# Workstream 4 — Driver–Truck Operational Session

## 4.1 Why this is separate from a Trip

A commercial trip ends when the cargo is delivered. The Driver may still be physically inside the truck and must continue seeing its position. Keeping a Completed trip active would corrupt trip status, availability, reporting, and reservation semantics.

Introduce a lightweight Driver–Truck operational association, conceptually:

```text
DriverTruckSession
  Id
  CompanyId
  DriverId
  TruckId
  StartedAt
  EndedAt
  StartedFromTripId
  LastTripId
  EndReason
  Version
```

Choose names consistent with the repository.

## 4.2 Rules

- At most one active session per Driver.
- At most one active session per Truck.
- Start the session when the Driver confirms departure to pickup.
- Reuse the same session for consecutive trips using the same Driver/truck pair.
- Trip completion updates `LastTripId` but does not end the session.
- The Driver may explicitly end the vehicle session when no active trip reserves the pair.
- Manager may end/handoff the session with an audited reason.
- Assigning the truck to a different Driver must not leak its location to the previous Driver.
- A deliberate reassignment/handoff safely closes the previous informational session.
- Session state must not create a second conflicting reservation system. Existing active-trip resource reservation remains authoritative.

Add appropriate tenant-scoped unique/partial indexes and concurrency handling.

## 4.3 Post-trip Driver home map

Driver Workspace states must include an explicit post-trip state, for example:

```text
NO_ACTIVE_TRIP_NO_VEHICLE
NO_ACTIVE_TRIP_WITH_VEHICLE
ACTIVE_TRIP_READY
```

When the trip is Completed but the session remains active, show:

- Current truck location.
- Truck plate/fleet code/photo.
- Online/stale/offline state.
- Last update age.
- Last completed trip summary.
- “No active trip” message.
- End Vehicle Session action where allowed.

Do not show a completed cargo route as though it is still active. The map remains a current-location map.

If the truck is handed to another Driver, the previous Driver must immediately lose access after the next refresh/token-authorized request.

---

# Workstream 5 — Driver Map Operational Parity

## 5.1 Shared map foundation

Refactor reusable map behavior rather than maintaining an independent simplified `DriverWorkspaceMap` that diverges from the manager fleet map.

Create or extract a shared single-vehicle live-map component that supports:

- Circular photo/fallback marker.
- Stable incremental position updates.
- Free camera mode.
- Follow Vehicle mode.
- Resume Follow button.
- Recenter action.
- Show Full Route action.
- Route Overview mode that fits once.
- Approach route.
- Cargo route.
- Pickup/delivery markers.
- Optional recent trail.
- Manual pan/zoom protection.
- Loading, provider failure, no telemetry, stale, and offline states.

The manager fleet map may keep multi-vehicle-specific panels, but single-vehicle behavior should share the same core controller/adapter logic where practical.

## 5.2 Driver screen information hierarchy

The Driver screen must prominently show:

- Trip number and lifecycle phase.
- Truck plate/fleet code/photo.
- Current/next destination.
- Remaining distance.
- Stable ETA.
- Current speed.
- Last position update age.
- Online/current/stale/offline badge.
- Current allowed action.

Do not expose internal GUIDs as primary labels.

## 5.3 ETA behavior

Do not make ETA disappear merely because one instantaneous sample reports speed zero.

Implement a documented strategy using available route data, for example:

- Remaining geometry distance.
- Smoothed recent moving speed when enough valid samples exist.
- Provider planned duration or configured nominal speed as a fallback.
- Mark ETA as estimated when fallback speed is used.

Avoid wild ETA jumps caused by a single sample. Use consistent calculations for manager and Driver projections.

## 5.4 Camera behavior

- Selecting/entering an active Driver trip may start in Follow Vehicle mode at a practical local zoom.
- Real mouse/touch/trackpad interaction pauses follow immediately.
- Polls continue updating markers/routes without moving the camera in Free mode.
- Follow resumes only after explicit user action.
- Full Route fits once and does not refit on later polls.
- Post-trip home map may follow the current truck but must still respect manual interaction.

---

# Workstream 6 — Self-Service Password Change

Add a secure authenticated endpoint such as:

```text
PUT /api/auth/me/password
```

Request:

```text
currentPassword
newPassword
newPasswordConfirmation
```

Requirements:

- Available to all authenticated roles, including Driver.
- Verify current password.
- Enforce the repository's password policy.
- Reject confirmation mismatch.
- Reject reusing the current password.
- Hash server-side using the existing password hasher.
- Record a security/audit event.
- Revoke all existing refresh tokens after change.
- Define clearly whether the current session is immediately logged out; prefer requiring a fresh login after success.
- Never log or return passwords.
- Rate-limit or otherwise protect repeated failed change attempts if compatible with current infrastructure.

Stable error codes:

```text
CURRENT_PASSWORD_INCORRECT
NEW_PASSWORD_CONFIRMATION_MISMATCH
NEW_PASSWORD_SAME_AS_CURRENT
PASSWORD_POLICY_FAILED
```

Add a localized Change Password section in Settings with obscured fields, show/hide controls, validation, success confirmation, logout/re-login behavior, Arabic RTL, and English LTR.

Owner temporary-password reset remains available but is not a substitute for self-service change.

---

# Workstream 7 — Faster Visible and Audible Alerts

Preserve the persisted notification center, visible overlay, sound preference, sound unlock behavior, initial silent hydration, ID-based deduplication, and tenant/Driver scoping from Sprint 4.1.1.

Improve delivery latency without creating duplicates:

- Use the shared configurable live notification interval, recommended default two seconds.
- Trigger geofence evaluation from the canonical ingestion pipeline.
- Do not wait for a dashboard request to create an arrival event.
- Enqueue only persisted unseen notification IDs.
- Never replay historical unread sounds at login.
- Never play the same event twice across overlapping polls.
- Keep sound burst rate limiting.
- Preserve browser autoplay-blocked messaging.

Add visible notifications for:

- Trip assigned to Driver.
- Driver departed toward pickup.
- Truck arrived at pickup.
- Driver loaded and departed toward delivery.
- Truck arrived at delivery.
- Driver completed delivery.
- Vehicle session ended/handoff.
- Truck offline/stale during active work.

Localize all titles and messages with trip number and truck plate where relevant.

---

# Workstream 8 — Eliminate Truck Photo Marker Flicker

## 8.1 Root cause investigation

The circular marker bytes are correctly generated and cached, but repeated MapLibre annotation updates can briefly hide/rebuild the photo symbol while the status/selection circle remains visible.

Instrument the actual update path and determine whether flicker is caused by symbol annotation replacement, temporary fallback assignment, async image-registration race, layer ordering, style reload, or rebuilding the map widget.

Do not guess and do not repeatedly reload authenticated photo bytes.

## 8.2 Preferred stable rendering

Prefer stable MapLibre style sources/layers for moving vehicle markers:

```text
GeoJSON source with vehicle features
Symbol layer using registered circular image
Circle layer for status/selection
Separate heading layer/indicator
```

Update feature coordinates/properties rather than recreating symbol annotations.

If retaining annotation managers, prove that:

- The registered photo image name never changes for the same photo version.
- A position update never assigns the fallback between photo frames.
- Symbol objects are not removed/re-added for coordinate-only updates.
- No global annotation clear occurs.

Apply the stable approach to both manager and Driver maps when feasible. Preserve upright photos and rotate only the heading indicator.

## 8.3 Acceptance criterion

Across at least 30 consecutive moving updates:

- Photo marker remains visible.
- Fallback marker frames: `0` after the photo is initially loaded.
- Symbol remove/re-add operations for coordinate-only updates: `0`.
- Global annotation clears: `0`.
- Style reloads: `0`.

Because flicker is visual, include a short recorded sequence or automated frame evidence if the environment supports it. Do not represent operation counters alone as visual proof.

---

# Backend/API Requirements

Expected changes may include:

- Canonical tracking sample ingestion service.
- Development/Testing simulator hosted scheduler.
- Explicit company-scoped background processing.
- Configurable live timing policies.
- Driver departure-to-pickup action.
- Renamed/clarified confirm-loaded-and-depart action.
- Driver–Truck operational session domain/application/infrastructure support.
- Driver Workspace active-trip and post-trip projections.
- Shared ETA/progress calculation service.
- Self-service password change.
- New operation notifications and audit events.
- Manager override parity with required reasons.

All mutations must be authorized, tenant-scoped, concurrency-safe, and idempotent where retries are expected.

---

# Migration Requirements

Use one safe forward migration for Sprint 4.1.2 if schema changes are necessary.

Requirements:

- Preserve all existing users, companies, drivers, trucks, trips, positions, notifications, photos, and preferences.
- Do not invent active Driver–Truck sessions for legacy rows unless the relationship is unambiguous and documented.
- Prefer no fabricated historical sessions.
- Use nullable/default-safe additions.
- Add tenant-scoped indexes and one-active-session constraints.
- Verify migration on a copy/disposable database containing legacy Sprint 4.1.1 data.
- Verify no pending EF model changes.
- Never modify migration history manually.

---

# Flutter Requirements

Required surfaces:

- Driver task card with Assigned/waiting state.
- Depart to Pickup action.
- Loaded and Depart action.
- Confirm Delivery action.
- Driver active live map with follow/free/overview controls.
- Driver post-trip home map.
- End Vehicle Session action.
- Clear current/stale/offline and last-update indicators.
- Stable ETA and remaining distance.
- Self-service Change Password UI.
- Faster visible/audible alerts.
- Stable non-flickering circular photo marker.

Every new string must be added to:

```text
app_en.arb
app_ar.arb
```

Verify layout at desktop and practical mobile widths, in English/LTR and Arabic/RTL.

---

# Backend Test Requirements

Add deterministic tests for at least:

1. Simulator advances without any manager/driver page request.
2. Opening two clients does not double simulator progress.
3. Background ticks do not overlap.
4. Disabled simulator produces no background samples.
5. Canonical ingestion persists meaningful change exactly once.
6. Stationary heartbeat remains bounded.
7. Geofence evaluation runs from ingestion, not UI reads.
8. Arrival notification is persisted once.
9. Normal default arrival latency meets the documented deterministic budget.
10. Assigned trip does not move to EnRouteToPickup until Driver action.
11. Wrong Driver cannot start another Driver's trip.
12. Depart-to-pickup validates position and approach plan.
13. Duplicate departure tap is safe.
14. Pickup arrival remains system-controlled.
15. Loaded-and-depart transitions AtPickup to InTransit.
16. Delivery arrival remains system-controlled.
17. Confirm delivery completes the commercial trip.
18. Manager overrides require a reason and are audited.
19. Driver–Truck session uniqueness and tenant isolation.
20. Completed trip leaves valid session/home-map access.
21. Reassignment/handoff revokes previous Driver access.
22. Ending session is rejected while an active trip requires it.
23. Driver Workspace never exposes another truck or Driver.
24. ETA remains available with stationary instantaneous sample when fallback data exists.
25. Correct current password changes password.
26. Incorrect current password is rejected.
27. Confirmation mismatch and same-password reuse are rejected.
28. Refresh tokens are revoked after password change.
29. Notification deduplication survives fast polling.
30. Tenant filters and architecture tests continue passing.

---

# Flutter Test Requirements

Add unit/widget tests for at least:

- Driver lifecycle action rendering from backend allowed actions.
- Assigned state shows Depart to Pickup.
- AtPickup shows Loaded and Depart.
- AtDelivery shows Confirm Delivery.
- Completed/no-active-trip with session shows home map.
- No session shows intentional empty state.
- Shared map Follow/Free/RouteOverview behavior.
- Real pointer signal pauses follow at widget boundary.
- Poll updates do not move Free-mode camera.
- Driver route overview fits once.
- ETA formatting and fallback-estimate label.
- Last-update age and stale/offline transitions.
- Password form validation and forced logout behavior.
- Notification two-second polling does not overlap.
- Notification IDs never enqueue twice.
- Marker source/layer update keeps the same image identity.
- Thirty coordinate updates produce zero symbol removals/re-additions or fallback frames after initial load.
- Arabic RTL and English LTR for every new workflow.

Use injectable clocks, scheduler/timer abstractions, audio interfaces, and map adapters where necessary for deterministic tests.

---

# Mandatory Real-Browser Acceptance

This sprint is not complete unless a real browser workflow passes from beginning to end. A partial or failed workflow must be reported as incomplete.

Use a disposable PostgreSQL/API environment, real Flutter Web build, real MapLibre style, and two independent browser profiles/contexts: one Manager and one Driver.

The workflow must prove:

1. Manager logs in.
2. Driver account exists and is linked through UI-supported flows.
3. Manager creates/chooses client, saved sites, truck, and Driver.
4. Manager creates route and assigns trip.
5. Manager does not start departure.
6. Driver receives visible/audible assignment alert.
7. Driver sees status Assigned and the Depart to Pickup button.
8. Keep both manager and Driver dashboards open.
9. Before Driver confirmation, wait through multiple simulator ticks and prove trip remains Assigned and route movement has not started.
10. Driver presses Depart to Pickup.
11. Both screens transition to EnRouteToPickup without manual refresh.
12. Driver and manager maps update at the expected cadence independently.
13. Close or navigate away from the manager dashboard and prove Driver movement continues.
14. Reopen manager dashboard and prove no speed/progress jump caused by a second client.
15. Perform real drag and wheel/zoom on Driver map.
16. Across at least three live updates, prove camera does not snap back.
17. Press Resume Follow and prove follow resumes.
18. Press Show Full Route and prove it fits once.
19. Reach pickup.
20. Record geofence and manager/Driver alert latency; meet the documented target or fail acceptance.
21. Driver presses Loaded and Depart to Delivery.
22. Both screens transition to InTransit.
23. Reach delivery and record alert latency.
24. Driver confirms delivery.
25. Trip becomes Completed and resources follow documented release rules.
26. Driver remains on a live current-truck home map through the active Driver–Truck session.
27. Truck location continues updating after trip completion.
28. Driver ends vehicle session.
29. Driver loses truck location and sees the correct no-active-task state.
30. Driver changes their own password using the old password.
31. Existing session/refresh behavior follows the documented security decision.
32. Old password no longer works; new password works.
33. Across at least 30 moving marker updates, no visible rectangular/fallback flash occurs after initial photo load.
34. Repeat critical lifecycle/UI checks in Arabic/RTL and English/LTR.
35. Confirm retained database and photo counts are unchanged.

Do not replace real browser gestures by directly invoking Flutter callbacks.

If WebDriver or the Flutter test binding fails, diagnose and fix the harness or report the sprint incomplete. Do not downgrade the required workflow silently.

---

# Performance and Operation Evidence

Store evidence under:

```text
docs/evidence/sprint4_1_2/
```

Include:

- Redacted environment/volume isolation proof.
- Retained before/after counts.
- Simulator ticks while no browser is open.
- Same progress with one versus two clients.
- Manager and Driver independent-session evidence.
- Lifecycle state/timestamp table.
- Tracking update cadence measurements.
- Pickup and delivery notification latency breakdowns.
- Driver Follow/Free/RouteOverview evidence.
- Driver post-trip home map.
- End Vehicle Session result.
- Password change security result without passwords/tokens.
- Marker operation counts.
- Marker visual sequence/video/frame evidence if supported.
- Notification IDs and deduplication counts.
- English/LTR and Arabic/RTL screenshots.
- Machine-readable browser assertions with a clear pass/fail result.

Never store credentials, temporary passwords, JWTs, refresh tokens, database dumps, connection secrets, or private headers in evidence.

---

# Required Validation

## Backend

```text
dotnet restore
dotnet build with repository warning policy
architecture tests
integration tests
EF migration applied to disposable legacy database
EF pending-model-change check
```

## Flutter

```text
flutter pub get
flutter gen-l10n
dart format verification
flutter analyze
all Flutter tests
development Web release build
production Web release build with simulator mutation UI excluded
```

## Runtime

```text
retained API/PostgreSQL remain healthy
disposable acceptance API/PostgreSQL healthy
backend simulator advances without browser polling
manager and Driver sessions both pass
real map style loads
notification latency target measured
post-trip Driver map passes
password change passes
marker stability passes
retained counts remain unchanged
```

Android may be reported as blocked only if the SDK/device is genuinely unavailable and all Web requirements pass. Android limitation does not excuse an incomplete Web workflow.

---

# Documentation Updates

Update:

```text
README.md
docs/architecture.md
docs/sprints/README.md
```

Document:

- Backend-owned tracking ingestion.
- Development simulator scheduler and configuration.
- Position persistence/heartbeat bounds.
- Live polling settings.
- Geofence latency policy and expected alert budget.
- Driver-controlled lifecycle.
- Manager override behavior.
- Driver–Truck operational session versus commercial trip.
- Driver active and post-trip map behavior.
- Shared map camera modes.
- ETA strategy.
- Self-service password security behavior.
- Notification delivery/deduplication.
- Marker rendering strategy and flicker fix.
- Disposable acceptance environment.
- Known limitations and deferred work.

---

# Explicitly Out of Scope

Do not add:

- Finance, payments, expenses, or profitability.
- Maintenance workflows.
- Real external GPS provider integration.
- SignalR/WebSockets.
- Browser/native push notifications.
- Email/SMS delivery.
- Proof-of-delivery signatures or document uploads.
- Driver phone GPS collection.
- Route optimization.
- Multi-stop route planning beyond the current model.
- A separate Driver application codebase.
- Driver profile photos.
- Full work-shift/timekeeping management.
- Return-to-base as part of the commercial trip status.

The Driver–Truck session is only the minimal association required to retain safe current-vehicle context after trip completion.

---

# Definition of Done

Sprint 4.1.2 is complete only when:

- Simulator movement is backend-owned and continues with no browser open.
- Manager Dashboard no longer controls Driver tracking freshness.
- Two clients do not double simulator movement.
- Driver and manager maps update at the configured live cadence.
- Arrival alert latency is measured and meets the documented safe target.
- Assignment remains Assigned until the Driver confirms departure.
- Driver controls departure to pickup.
- System controls stable pickup arrival.
- Driver controls loaded/departure to delivery.
- System controls stable delivery arrival.
- Driver controls delivery completion.
- Manager overrides remain available only with audited reasons.
- Driver active map has follow, free, resume, recenter, and route-overview behavior.
- ETA remains useful and does not disappear solely because one speed sample is zero.
- Completed trip is commercially closed.
- Driver retains a secure current-truck home map through an active Driver–Truck session.
- Reassignment/handoff prevents old Driver access.
- Driver can securely change their own password.
- Visible/audible notifications remain deduplicated and arrive faster.
- Circular photo marker does not visibly flash to fallback/dark-circle state during movement after initial load.
- Real browser acceptance passes end to end with two independent sessions.
- English/LTR and Arabic/RTL pass.
- Retained user data and volumes are untouched by acceptance.
- Backend build/tests pass with zero warnings/errors under repository policy.
- Flutter analysis/tests pass.
- EF model drift is absent.
- Web builds pass.
- Documentation and evidence are accurate.
- No unrelated files are changed.
- No commit or push is performed.

---

# Final Report Format

Return a concise final report with:

## Implemented

- Backend-owned tracking ingestion and simulator scheduling.
- Timing/geofence responsiveness.
- Driver-controlled lifecycle.
- Driver–Truck operational session.
- Driver map parity and ETA.
- Self-service password change.
- Faster alerts.
- Marker flicker fix.

## Validation

- Backend build and test counts.
- Flutter analysis and test counts.
- Migration status.
- Web build status.
- Docker health.
- Simulator-without-browser result.
- One-client versus two-client movement result.
- Pickup/delivery latency measurements.
- Two-session browser result.
- Password-change result.
- Marker stability result.
- Arabic/English result.
- Retained-data before/after result.

## Evidence

- Exact evidence directory.
- Important machine-readable files and screenshots/video.

## Limitations

- Only genuine remaining limitations.
- If real browser acceptance is incomplete, state that the sprint is incomplete.

## Timing

- Per-task active elapsed time.
- Total active elapsed time.

## Git Status

Explicitly confirm that changes remain uncommitted and unpushed.
