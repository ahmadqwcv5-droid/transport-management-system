# Sprint 4.1 — Live Fleet, Geofence Events, and Driver Workflow

## Role

You are a senior product engineer extending an existing multi-tenant transport-management system with live operational behavior.

Act as:

- Senior ASP.NET Core engineer
- Senior Flutter engineer
- Fleet and dispatch domain designer
- Geospatial and telematics engineer
- Mobile workflow designer
- Security and multi-tenant SaaS reviewer
- QA and browser-acceptance engineer

This sprint must connect tracking data, trip lifecycle, notifications, truck identity, and user actions into one coherent live-operations workflow.

Do not treat this as a collection of unrelated visual improvements.

---

## Repository and Baseline

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Expected starting baseline:

`55d3c1e feat(sprint4): add customer and fleet operations`

Before editing:

1. Fetch the latest remote state.
2. Record the actual starting commit and branch.
3. Inspect the worktree and preserve unrelated user changes.
4. Read the README, architecture decisions, Sprint 3.5 and Sprint 4 plans/evidence, security review, and quality-gate workflow.
5. Verify the latest GitHub quality-gate result.
6. Run the repository-local quality gate before implementation.
7. Inspect the current trip state machine, dispatch service, tracking ingestion, simulator, route progress, dashboard polling, fleet-map camera logic, truck profile, identity/auth roles, and current event writers.

Do not assume paths or implementation details are unchanged. Adapt to the current repository while preserving the validated architecture.

---

## Confirmed Baseline Gaps

The current implementation already:

- Automatically evaluates arrival at pickup from tracking samples.
- Moves `EnRouteToPickup` to `AtPickup` and records system events.
- Computes `At delivery` as a route-progress phase.
- Uses a project-owned truck icon on MapLibre.
- Selects a truck and loads approach/cargo route details.
- Fits the full route automatically when a selected truck has a route.
- Keeps the map camera still during ordinary polling.

The current implementation does not yet:

- Persist and serve a primary truck photo.
- Use a truck photo/avatar as the live-map marker.
- Provide an explicit follow-selected-truck camera mode.
- Separate `Follow Truck` from `Show Full Route`.
- Persist an explicit `AtDelivery` trip state.
- Automatically transition to delivery arrival from trusted tracking.
- Persist user-visible in-app notifications.
- Give a linked driver a restricted `My Trip` workflow.
- Let the driver confirm loading/departure or delivery.
- Collapse the manager-facing `Start -> In Transit -> Delivered -> Complete` click chain into meaningful operational actions.

---

## Sprint Goal

Deliver this live operational workflow:

```text
Manager assigns and dispatches truck
        ↓
Truck travels to pickup
        ↓
Geofence confirms At Pickup automatically
        ↓
Manager receives arrival notification
        ↓
Driver confirms cargo loaded and departure
        ↓
Trip becomes In Transit
        ↓
Truck reaches delivery geofence
        ↓
Trip becomes At Delivery automatically
        ↓
Manager receives arrival notification
        ↓
Driver confirms cargo handoff
        ↓
Trip becomes Completed and resources are released
```

On the fleet map:

```text
Select truck
    -> close zoom on truck
    -> Follow Truck enabled

Manual map pan
    -> Follow paused
    -> Resume Follow button appears

Show Full Route
    -> fit current route once
    -> do not keep forcing camera bounds
```

If a truck has a primary photo, display a map-safe avatar marker. Otherwise retain the existing truck-icon fallback.

---

## Non-Negotiable Product Decisions

1. GPS arrival proves presence near a stop; it does not prove loading or cargo handoff.
2. Pickup arrival is automatic, but cargo departure requires a human confirmation.
3. Delivery arrival is automatic, but cargo handoff requires a human confirmation.
4. The commercial trip completes when cargo is handed over, not when the truck returns to its original base.
5. Empty return-to-base movement is not part of the completed customer trip.
6. A future paid return load is a separate trip or future explicit leg, not an indefinite active state.
7. The linked driver performs normal field confirmations.
8. Owner/Operations may perform an audited override when the driver cannot.
9. Truck operational status remains derived from the authoritative trip lifecycle.
10. Notifications are persisted event records; they are not inferred only from transient UI text.
11. In-app notification polling is sufficient for this sprint. SignalR and push notifications remain deferred.
12. The same Flutter application provides role-specific Manager and Driver experiences. Do not create a second app repository.

---

## Mandatory Plan and Timing

Before implementation, create:

`SPRINT4_1_IMPLEMENTATION_PLAN.md`

Place it in the established sprint documentation structure and update the sprint index.

It must include:

- Baseline commit, test counts, and CI status
- Existing state-machine analysis
- Target state machine and compatibility strategy
- Geofence algorithm and persistence decisions
- Notification design and deduplication strategy
- Driver identity/authorization model
- Truck photo storage and security model
- Fleet-map camera-state model
- Migration and rollback strategy
- Mutation-refresh matrix
- Automated and browser test plan
- Risks and known limitations
- Task start/end times and active elapsed time
- Final changed-file summary

Update it throughout the sprint. Do not reconstruct timing afterward.

---

# 1. Target Trip Lifecycle

## 1.1 Canonical lifecycle

The current authoritative lifecycle must evolve to:

```text
Draft
  -> Assigned
  -> EnRouteToPickup
  -> AtPickup
  -> InTransit
  -> AtDelivery
  -> Completed
```

Cancellation remains permitted only under reviewed existing rules.

Archive remains orthogonal to terminal status.

## 1.2 Meaning of each state

| State | Meaning | Normal actor |
|---|---|---|
| Draft | Planning is incomplete or not assigned | Manager |
| Assigned | Truck and driver reserved; not dispatched | Manager |
| EnRouteToPickup | Truck dispatched toward pickup | Manager dispatch action |
| AtPickup | Trusted tracking confirms arrival at pickup | System/geofence |
| InTransit | Cargo is loaded and commercial movement started | Linked driver |
| AtDelivery | Trusted tracking confirms arrival at delivery | System/geofence |
| Completed | Driver confirmed cargo handoff; resources released | Linked driver |
| Cancelled | Trip cancelled under existing rules | Manager |

## 1.3 Remove redundant user actions

The ordinary UI must no longer require four separate manager clicks for:

```text
Start -> Mark In Transit -> Deliver -> Complete
```

Replace them with two meaningful commands:

- `Confirm loaded and start trip`
- `Confirm delivery`

Normal command behavior:

### Confirm loaded and start trip

- Allowed only from `AtPickup`.
- Records authenticated actor, source, and UTC time.
- Produces the final visible status `InTransit` in one transaction.
- Preserves an actual cargo start timestamp.
- Starts the cargo tracking phase.

### Confirm delivery

- Allowed only from `AtDelivery` for a normal driver action.
- Records delivery and completion timestamps in one transaction.
- Produces the final visible status `Completed`.
- Releases truck and driver reservations atomically.
- Stops active simulator targeting for the trip.
- Preserves all immutable tracking history.

## 1.4 Backward compatibility

The existing persisted `Started` and `Delivered` values and API endpoints may exist in retained data and integrations.

Implement a reviewed compatibility strategy:

- Existing historical rows remain readable.
- Existing `Started` rows remain operable and may be normalized safely to the current visible lifecycle only when correctness is proven.
- Existing `Delivered` rows remain completable.
- Existing `/start`, `/mark-in-transit`, `/deliver`, and `/complete` API contracts must not be silently broken.
- They may delegate to compatibility use cases, return stable deprecation metadata, or remain manager-only legacy actions.
- New Flutter manager/driver workflows use the two meaningful commands.
- Do not rewrite historical event timestamps or invent confirmations.

Document which states remain persisted for compatibility and which are shown to users.

---

# 2. Automatic Pickup and Delivery Geofences

## 2.1 General requirements

Geofence evaluation must run from accepted, tenant-owned, trusted tracking samples.

Do not let Flutter assert arrival.

Do not use route percentage alone as proof of arrival.

Use direct distance to the authoritative stop coordinates plus configurable stability rules.

## 2.2 Stability against GPS jitter

The existing single-sample pickup transition must be hardened.

Use a deterministic policy with configurable values such as:

- Arrival radius
- Exit/hysteresis radius larger than arrival radius
- Minimum consecutive qualifying samples
- Minimum dwell time
- Maximum accepted sample age
- Maximum accepted accuracy when accuracy becomes available

Choose sensible defaults after inspecting current simulator/report intervals. Document them.

An acceptable initial policy might be:

```text
Arrival radius: 50 m
Exit radius: 80 m
Minimum samples: 2
Minimum dwell: 20–30 seconds
```

Do not hard-code policy values in domain methods.

## 2.3 Restart-safe evaluation

Arrival confirmation must survive API restarts and multiple API instances conceptually.

Do not rely only on an in-memory counter.

Either:

- Derive qualification from bounded persisted tracking samples, or
- Persist a small tenant-owned geofence observation state.

The chosen design must be:

- Idempotent
- Tenant-safe
- Concurrency-safe
- Bounded in query cost
- Testable without timing sleeps

## 2.4 Pickup arrival

When a trip is `EnRouteToPickup` and qualifying samples confirm the pickup geofence:

- Transition to `AtPickup` exactly once.
- Complete the active repositioning plan.
- Record system trip/truck events.
- Create one in-app notification.
- Refresh trip, truck, dashboard, map, and notification projections.
- Keep resources reserved.
- Keep the truck stationary or track it without beginning the cargo route.

## 2.5 Delivery arrival

When a trip is `InTransit` and qualifying samples confirm the delivery geofence:

- Transition to `AtDelivery` exactly once.
- Record `ArrivedAtDeliveryAt` or equivalent authoritative timestamp.
- Record system trip/truck events.
- Create one in-app notification.
- Refresh trip, truck, dashboard, map, and notification projections.
- Keep resources reserved until delivery confirmation.
- Do not automatically mark cargo delivered or completed.

## 2.6 Deduplication and races

Two concurrent samples or retries must not:

- Create duplicate transitions
- Create duplicate notifications
- Create duplicate events
- Complete the same repositioning plan twice

Use optimistic concurrency and/or database uniqueness/idempotency keys.

Add deterministic tests for simultaneous evaluation.

---

# 3. In-App Notifications

## 3.1 Notification entity

Add a tenant-owned persisted notification model.

Suggested shape:

```text
OperationNotification

Id
CompanyId
Type
Severity
TripId
TruckId
DriverId
EventKey
DataJson
CreatedAt
ReadAt
ReadByUserId
```

Use a bounded payload and stable event codes.

Do not store a localized sentence as the source of truth.

Suggested notification types:

- `TruckArrivedAtPickup`
- `TruckArrivedAtDelivery`
- `DriverConfirmedDeparture`
- `DriverConfirmedDelivery`
- `TruckOfflineDuringActiveTrip`
- `TripOffRoute`

Only pickup/delivery arrival and driver confirmations are mandatory in this sprint. Offline/off-route notifications may be included only if safely bounded and deduplicated.

## 3.2 Deduplication

Use a deterministic event key such as:

```text
type + tripId + lifecycleVersion/routePlanId
```

Enforce uniqueness per tenant where practical.

Repeated polling or repeated tracking samples must not generate repeated notifications.

## 3.3 APIs

Provide tenant-scoped endpoints for:

- Bounded/paginated notification list
- Unread count
- Mark one as read
- Mark all visible/current-user notifications as read
- Navigate to related trip/truck where authorized

Owner and Operations may view company operational notifications.

A linked Driver sees only notifications related to their own assigned trip when needed; do not expose the company-wide feed.

## 3.4 Flutter notification center

Add:

- Notification icon with unread badge
- Responsive notification panel/page
- Localized notification rendering from event type and payload
- Read/unread state
- Timestamp
- Trip/truck navigation
- Empty/loading/error states

Use existing dashboard polling or a focused configurable polling interval.

Do not add SignalR, Firebase Cloud Messaging, APNs, email, SMS, or browser push in this sprint.

---

# 4. Driver Identity and Authorization

## 4.1 Link User and Driver

Add an optional one-to-one association between a tenant user and a Driver record.

The exact ownership may be `Driver.UserId` or an equivalent reviewed model.

Rules:

- Both records must belong to the same tenant.
- One user may link to at most one driver.
- One driver may link to at most one user.
- Linking/unlinking is Owner-only unless current policy explicitly grants Operations.
- Linking a user does not assign a trip.
- Deactivating/archive behavior must not corrupt historical actor attribution.
- Do not enable public registration.

Add a dedicated `Driver` role or a focused permission policy only if this is the cleanest fit with the current auth model. Do not grant generic Employee users driver access by assumption.

## 4.2 Driver authorization boundary

A linked driver may access only:

- Their own current assigned trip
- The minimum pickup/delivery details required to perform it
- The assigned truck summary
- Their own allowed actions
- Their own recent confirmation result where useful

A driver must not access:

- Other drivers' trips
- Full client lists
- Full fleet lists
- Company-wide dashboard
- Company-wide tracking map
- Simulator controls
- Administrative mutation endpoints

Enforce this on the backend. Hiding navigation is not authorization.

## 4.3 Driver Mode in the same Flutter app

After login, linked drivers see a mobile-first experience:

```text
My Trip
  - Current phase
  - Truck
  - Pickup name/address/contact/instructions
  - Delivery name/address/contact/instructions
  - Route summary
  - Last known tracking status
  - One primary action when allowed
```

Primary actions:

- `Confirm loaded and start trip` at pickup
- `Confirm delivery` at delivery

The driver app does not produce GPS positions in this sprint; the hidden tracker/simulator remains the tracking source.

Build responsive Flutter Web/mobile layout even if Android cannot be compiled in the current environment.

---

# 5. Manager Override

Owner/Operations must retain an emergency/manual override.

Requirements:

- Override is visually secondary, not the normal primary action.
- A bounded reason is required.
- Actor, UTC time, reason, previous state, next state, and source `ManagerOverride` are audited.
- The UI warns that the driver should normally confirm the action.
- Override cannot cross arbitrary lifecycle states.
- Confirm departure override requires `AtPickup` unless an explicitly reviewed exceptional rule is added.
- Confirm delivery override normally requires `AtDelivery`; an emergency bypass of geofence requires a stronger reason and separate stable event code if implemented.
- Backend authorization and concurrency remain authoritative.

Do not add an unrestricted `SetTripStatus` endpoint.

---

# 6. Truck Primary Photo

## 6.1 Storage architecture

Add a storage abstraction such as:

`ITruckPhotoStorage`

Development may use a local durable mounted directory. The contract must permit later S3/MinIO/object-storage implementation without changing Domain/Application use cases.

Do not:

- Store Base64 image bytes in the truck row
- Store user-supplied filesystem paths
- Trust the original filename
- Expose an unauthenticated tenant-wide file directory

## 6.2 Photo metadata

Store reviewed metadata such as:

- Storage key
- Content type
- Original byte size
- Thumbnail byte size
- Width/height when known
- Version or ETag
- UploadedAt
- UploadedByUserId

Support one primary photo per truck in this sprint.

Do not build a gallery.

## 6.3 Upload security

Requirements:

- Tenant-authorized upload/read/delete
- Multipart upload
- Configurable size limit, with a safe default such as 5 MB
- Allow only reviewed JPEG, PNG, or WebP formats
- Verify actual file signature/content, not only extension or MIME header
- Reject SVG and executable/polyglot content
- Generate storage keys server-side
- Prevent path traversal
- Remove unnecessary metadata/EXIF where the chosen image pipeline supports it
- Create a small map thumbnail, approximately 128–256 px
- Bound decompressed image dimensions to prevent image bombs
- Replace/delete old physical files safely after the database update succeeds, with failure recovery

Select a compatible, maintained image library only after reviewing its license and project impact. Document the choice.

## 6.4 Photo APIs and caching

Provide:

- Upload/replace primary photo
- Fetch thumbnail
- Fetch detail-size photo if needed
- Remove photo

Use authenticated API access or appropriately scoped short-lived URLs.

Expose a stable photo version/ETag so Flutter can cache and refresh only when the image changes.

## 6.5 Flutter photo UI

Show the truck photo in:

- Truck list
- Truck details
- Assignment selector
- Selected-truck card
- Fleet panel
- Map marker when available

Fallback to the existing truck icon when no photo exists or loading fails.

Provide upload/replace/remove actions only to authorized roles, with progress and localized errors.

---

# 7. Photo-Based Map Markers

## 7.1 Marker design

When a truck has a photo, display a compact avatar marker inspired by live-location applications:

- Circular or rounded-circular thumbnail
- Status ring
- Selected-state emphasis
- Small direction indicator or separate heading cue
- Legible at normal fleet zoom levels

The status ring should continue to communicate:

- Moving/current
- Stationary/current
- Offline/stale
- Maintenance/out of service

Do not rotate a person's/truck's rectangular photo itself in a visually confusing way. Rotate a direction indicator instead.

## 7.2 MapLibre image lifecycle

Use a stable image identity such as:

```text
truck-photo:{truckId}:{photoVersion}
```

Requirements:

- Register each thumbnail once per active style generation/version.
- Do not fetch or decode every photo on every poll.
- Do not clear all symbols to update one photo.
- Re-register after a genuine style reload.
- Remove or bound obsolete cached image versions.
- Use authenticated bytes safely.
- Preserve latest-wins annotation synchronization.
- Fallback immediately to the existing icon on image failure.

The annotation coordinator must remain platform-neutral; provider/auth/image fetching belongs in an adapter or focused loader.

---

# 8. Fleet Map Camera Modes

## 8.1 Explicit modes

Replace implicit camera behavior with an explicit state machine:

- `Free`
- `FollowSelectedTruck`
- `RouteOverview`

Do not overload a generic selection/recenter request with conflicting meaning.

## 8.2 Selection behavior

When the user selects a truck:

- Select and emphasize the marker.
- Open the selected-truck card/panel.
- Move to a configurable close local zoom, approximately 14–15.
- Offset for the visible detail panel.
- Enter `FollowSelectedTruck` by default.
- Do not automatically fit the complete route.

## 8.3 Follow behavior

While Follow is active:

- Each accepted selected-truck position update keeps the truck in view.
- Camera movement is smooth and latest-wins.
- Do not queue obsolete animations.
- Do not move for unrelated truck updates.
- Preserve the chosen zoom unless the user explicitly changes it.
- Bearing may remain north-up initially; do not force heading-up unless intentionally implemented and user-controlled.

Revise the existing camera invariant to:

> Polling causes zero camera moves in Free and RouteOverview modes. Polling may move the camera only for the selected truck while FollowSelectedTruck is active.

## 8.4 Manual interaction

When the user manually pans, zooms, rotates, or pitches:

- Pause Follow and enter `Free` mode.
- Do not mistake programmatic camera animation for manual input.
- Show a visible `Resume follow` button.

Use a programmatic-camera token/guard if MapLibre callbacks do not distinguish gesture origin reliably.

## 8.5 Show full route

Add a side control:

- `Show full route`

Behavior:

- Fit the currently relevant geometry once.
- If heading to pickup, include the active approach route and optionally the cargo route with visually distinct semantics.
- If carrying cargo, prioritize the cargo route.
- Enter `RouteOverview`.
- Do not refit on every poll.
- Keep marker updates live.
- Offer `Resume follow` or `Back to truck`.

## 8.6 Other controls

Provide localized controls for:

- Follow truck / Resume follow
- Pause follow, if explicit control is useful
- Show full route
- Back to truck
- Clear selection

Support Arabic/RTL positioning and keyboard accessibility.

---

# 9. Automatic Refresh and Live Consistency

Reuse Sprint 4's mutation refresh coordinator and dashboard polling.

After automatic or driver-triggered lifecycle events, refresh affected projections without manual reload:

- Trip details and allowed actions
- Trip list and operational tabs
- Truck detail and operational state
- Client trip history
- Dashboard counters
- Fleet map marker/card/route
- Driver `My Trip`
- Notifications and unread count
- Assignment options after resources are released

Requirements:

- A trip arriving at pickup/delivery moves to the correct tab/state automatically.
- A completed trip disappears from Active and appears in Completed.
- The truck becomes Available immediately after confirmation.
- No stale response may restore an older state.
- Duplicate tracking events remain idempotent.
- Polling and mutation refresh must not create request storms.
- Preserve current filters, selection, and map mode where semantically valid.

---

# 10. Simulator Integration

Extend the Development/Testing simulator so the entire workflow can be demonstrated deterministically.

Requirements:

- Approach movement triggers the same pickup geofence path as real tracking ingestion.
- Simulator pauses at `AtPickup`; it must not begin the cargo route automatically.
- Driver or manager confirmation starts cargo movement.
- Cargo movement triggers the delivery geofence path.
- Simulator pauses at `AtDelivery`; it must not confirm delivery automatically.
- Driver or manager confirmation completes the trip.
- `10x` changes simulated progress rate but not reported physical speed.
- API restart restores the correct active leg without teleporting.
- Reset creates a new run and does not duplicate arrival notifications.
- Completed trips are no longer active simulator targets.

Do not create simulator-only lifecycle behavior separate from production application services.

---

# 11. Backend Architecture

Respect Sprint 3.5 and Sprint 4 boundaries.

Requirements:

- Do not recreate a catch-all service/store.
- Keep geofence evaluation in a focused Application service/policy.
- Keep tracking providers vendor-neutral.
- Keep trip transitions in the Domain aggregate.
- Keep image storage implementation in Infrastructure.
- Keep notification contracts/use cases focused.
- Keep controllers thin.
- Keep EF Core inside Infrastructure.
- Derive tenant identity from authentication.
- Use database constraints/idempotency for race-sensitive events.
- Keep driver permissions in named policies/handlers.
- Do not let map/UI concerns leak into Domain/Application.

Review any handwritten file that exceeds approximately 500 lines and explain remaining cohesion in the implementation plan.

---

# 12. Migration and Data Safety

One reviewed migration is expected for:

- `AtDelivery` status compatibility if persisted
- Arrival timestamp/state
- User/Driver link
- Truck photo metadata or entity
- Notifications
- Geofence observation state if chosen

Requirements:

- Preserve all existing trips, timestamps, routes, events, positions, users, drivers, and truck records.
- Do not invent driver confirmations.
- Do not invent delivery arrival timestamps.
- Do not attach users to drivers automatically.
- Do not invent truck photos.
- Existing `Started` and `Delivered` trips remain readable and actionable.
- Migration SQL is reviewed for enum/string values, unique indexes, partial indexes, and data loss.
- Existing resource-reservation indexes include any new reserving state such as `AtDelivery`.
- Apply migration to retained PostgreSQL without deleting the volume.
- Confirm no EF drift remains.
- Do not rewrite earlier migrations.

---

# 13. Localization and Accessibility

All new user-visible content must use ARB resources.

Verify English/LTR and Arabic/RTL for:

- Notifications
- Driver Mode
- Arrival states
- Driver confirmation dialogs
- Manager override and reason
- Photo upload/remove
- Follow/route camera controls
- Map selected-truck card
- Offline/error/fallback states
- Long client site names and addresses

Requirements:

- Controls have tooltips and accessible labels.
- Status is not communicated by color alone.
- Driver primary action is large and clear on narrow screens.
- Confirmation dialogs clearly state the irreversible operational meaning.
- Backend English messages are not displayed directly.

---

# 14. Backend Tests

Add tests covering at least:

## State machine

- AtPickup -> confirm loaded -> InTransit in one command
- InTransit -> AtDelivery only through system geofence evaluation
- AtDelivery -> confirm delivery -> Completed in one command
- Completion releases truck and driver atomically
- Invalid transitions return stable codes
- Legacy Started/Delivered records remain actionable
- Return-to-base is not required for completion

## Geofences

- One noisy sample does not trigger arrival
- Required consecutive samples/dwell triggers exactly once
- Exit/hysteresis prevents chatter
- Stale/offline/untrusted sample does not trigger
- Pickup uses pickup coordinates
- Delivery uses delivery coordinates
- Wrong truck/trip does not trigger
- API restart does not lose or duplicate qualification
- Concurrent evaluations produce one transition/event/notification
- Tenant isolation

## Notifications

- One pickup-arrival notification
- One delivery-arrival notification
- Driver confirmation notifications/events
- Deduplication under retries
- Read/unread operations
- Tenant isolation
- Driver cannot read company-wide notifications

## Driver authorization

- Link/unlink rules and uniqueness
- Driver sees only own assigned trip
- Driver cannot act on another trip
- Driver cannot confirm from wrong state
- Manager override requires permission and reason
- Actor/source/reason audit is correct

## Photos

- Valid upload/replace/remove
- Invalid MIME/signature rejection
- Size/dimension limit
- Tenant isolation
- Unauthorized read/write rejection
- Old file cleanup/failure recovery
- Photo version changes

## Map contracts

- Dashboard/truck projection returns photo version/thumbnail reference safely
- Operational state reflects AtPickup/InTransit/AtDelivery/Completed correctly

Keep every existing backend and architecture test passing.

---

# 15. Flutter and Map Tests

Add tests for:

- Truck list/detail photo and fallback icon
- Authenticated thumbnail loading and cache version
- Map photo marker registration once per style/version
- Photo failure falls back without removing the truck
- Selection enters FollowSelectedTruck at local zoom
- Route is not automatically fit on selection
- Selected truck updates move the camera only in Follow mode
- Unrelated truck updates do not move the camera
- Manual pan pauses Follow
- Programmatic camera movement does not falsely pause Follow
- Show Full Route fits once and enters RouteOverview
- Polling does not refit RouteOverview
- Resume Follow returns to selected truck
- Clear selection returns to Free mode
- Notification badge/list/read state
- Driver role navigation restrictions
- Driver My Trip state and actions
- Confirm loaded updates visible status
- Delivery arrival notification appears
- Confirm delivery moves trip to Completed and releases truck
- Manager override requires a reason
- Arabic/RTL and English/LTR

Update existing map telemetry assertions:

- Free mode polling camera moves = 0
- RouteOverview polling camera moves = 0
- Follow mode selected-truck updates may move camera
- Global symbol/line/circle clears remain 0 during normal polling

Do not weaken prior flicker, annotation, route, or manual-pan tests.

---

# 16. Mandatory Real Browser Acceptance

Use dedicated Development/Testing manager and linked-driver accounts with known smoke credentials.

Do not reset retained owner credentials or delete the PostgreSQL volume.

Run Firefox if Chrome is unavailable.

## Photo and map workflow

1. Login as manager in Arabic/RTL.
2. Open a truck with no photo and verify icon fallback.
3. Upload a valid primary photo.
4. Verify list, details, assignment selector, selected card, and map marker show the photo/avatar.
5. Select the truck on the fleet map.
6. Verify close local zoom rather than automatic full-route fit.
7. Run at least ten position updates and verify the truck remains in view.
8. Manually pan the map and verify Follow pauses.
9. Verify updates no longer move the camera.
10. Press Resume Follow and verify the camera returns to the truck.
11. Press Show Full Route and verify the relevant route fits once.
12. Run at least ten more polls and verify the route view is not repeatedly refit.
13. Press Back to Truck and verify Follow resumes.

## Pickup workflow

14. Create/assign/dispatch a trip with the photographed truck and linked driver.
15. Simulate approach to pickup.
16. Verify noisy/first qualifying sample alone does not transition if policy requires more evidence.
17. Verify confirmed geofence arrival transitions to AtPickup exactly once.
18. Verify one manager notification and correct truck/trip/map refresh.
19. Verify simulator does not begin cargo movement automatically.

## Driver workflow

20. Login as the linked driver.
21. Verify only My Trip/minimum allowed navigation is visible.
22. Confirm loaded and start trip.
23. Verify trip becomes InTransit and simulator begins cargo movement.
24. Verify the manager view refreshes without manual reload.

## Delivery workflow

25. Simulate movement to delivery.
26. Verify geofence arrival transitions to AtDelivery exactly once.
27. Verify one manager arrival notification.
28. Verify simulator pauses and the trip remains active awaiting confirmation.
29. Login as driver and confirm delivery.
30. Verify trip becomes Completed.
31. Verify truck and driver become available.
32. Verify the trip moves from Active to Completed without manual reload.
33. Verify tracking history remains and the truck's current location stays at delivery.

## Override and isolation

34. Run a disposable trip far enough to demonstrate manager override with a required reason.
35. Verify audit actor/source/reason.
36. Verify a second driver cannot view or act on the first driver's trip.
37. Switch manager UI to English/LTR and verify notification/map controls.
38. Logout.

Store screenshots, operation counts, notification facts, and machine-readable browser results under:

`docs/evidence/sprint4_1/`

Do not claim browser acceptance from widget tests, direct API calls, or screenshots fabricated from test widgets.

---

# 17. Quality Gates

Run:

- Repository local quality-gate script
- .NET Release build with zero warnings/errors
- Architecture tests
- Full backend integration tests
- EF migration apply and drift check
- Flutter format verification
- Flutter analyzer
- Full Flutter unit/widget tests
- Flutter Web production release build
- Flutter Web Development/Testing build
- Docker Compose health checks
- Retained PostgreSQL validation
- Real authenticated manager and driver Firefox workflows

Ensure GitHub Actions discovers and runs new tests after the user pushes.

Do not claim GitHub-hosted CI success until it actually runs.

Android:

- Build/run only if a valid Android SDK and device/emulator exist.
- Otherwise report the exact blocker.
- Responsive Web driver workflow remains mandatory even if Android is unavailable.

---

# 18. Documentation

Update:

- `README.md`
- `docs/architecture.md`
- Sprint index
- `SPRINT4_1_IMPLEMENTATION_PLAN.md`
- `docs/evidence/sprint4_1/README.md`

Document:

- Canonical trip lifecycle and responsibility table
- Compatibility handling for Started/Delivered
- Geofence policy, hysteresis, dwell, and restart behavior
- Notification event types and deduplication
- Driver link and authorization boundary
- Manager override semantics
- Truck photo storage/security/caching
- Map marker fallback
- Free/Follow/RouteOverview camera state machine
- Simulator pause/confirmation behavior
- Mutation refresh matrix
- Configuration values
- Known limitations

Add or supersede ADRs instead of leaving contradictory current state-machine decisions.

---

# 19. Explicitly Out of Scope

Do not implement:

- Finance, expenses, payments, or profitability
- Full proof-of-delivery signatures
- Customer signature capture
- Multiple truck photos/gallery
- Driver profile photos
- Phone GPS as the fleet tracking source
- Real GPS vendor integration
- Push notifications
- SMS, email, WhatsApp messaging
- SignalR
- Voice alerts
- Full maintenance or document modules
- Route optimization
- Automatic rerouting
- Traffic-aware routing
- Return-to-base workflow
- Multi-leg commercial trips
- Payroll or driver expenses
- Subscription billing

Do not expand the sprint beyond live fleet operations and driver confirmations.

---

# 20. Definition of Done

Sprint 4.1 is complete only when:

- A truck can have one secure primary photo and thumbnail.
- Photo upload/read/remove are tenant-authorized and validated.
- Truck photo appears in list, details, assignment UI, selected card, and map marker.
- Existing truck icon remains a reliable fallback.
- Map selection enters close Follow mode rather than full-route bounds.
- Follow keeps only the selected truck in view.
- Manual interaction pauses Follow.
- Show Full Route fits once and does not refit during polling.
- Pickup geofence is stable against jitter and restart-safe.
- Delivery geofence transitions to AtDelivery exactly once.
- Pickup and delivery arrivals create one persisted notification each.
- Driver identity is securely linked and tenant-isolated.
- Driver sees only their own My Trip workflow.
- Driver confirmation moves AtPickup to InTransit.
- Driver confirmation moves AtDelivery to Completed and releases resources.
- Manager override requires authorization, reason, and audit.
- Ordinary manager UI no longer requires Start/InTransit/Deliver/Complete click chaining.
- Commercial completion does not wait for return to base.
- Simulator pauses for both human confirmations.
- Trip/truck/dashboard/map/notification screens refresh without manual reload.
- Existing routes, trails, markers, and camera stability do not regress.
- Multi-tenant and concurrency tests pass.
- .NET build passes with zero warnings/errors.
- Architecture and integration tests pass.
- Flutter analyzer is clean.
- All Flutter tests pass.
- Web release builds pass.
- EF migration applies and no drift remains.
- Compose services are healthy.
- Full manager and driver Firefox workflows pass.
- Arabic/RTL and English/LTR evidence exists.
- Documentation and evidence are complete.

---

# 21. Git and Safety Constraints

- Do not commit.
- Do not push.
- Do not create or merge a pull request.
- Do not reset or discard unrelated changes.
- Do not overwrite `.env`.
- Do not reset retained credentials.
- Do not delete or recreate the retained PostgreSQL volume.
- Do not rewrite previous migrations.
- Do not expose uploaded files through an unauthenticated directory.
- Do not fabricate screenshots, CI results, notification evidence, or camera telemetry.
- Recreate only the minimum necessary containers if Compose repair is required.
- Leave Sprint 4.1 changes uncommitted for user review.

---

# 22. Required Final Report

Provide:

## Implemented

- Lifecycle changes and compatibility behavior
- Pickup/delivery geofence implementation
- Notifications
- Driver link, permissions, and My Trip UI
- Manager override
- Truck photo storage/security/UI
- Photo map markers
- Free/Follow/RouteOverview camera modes
- Simulator integration

## Operational evidence

Explicitly report:

- Pickup arrival transition count and notification count
- Delivery arrival transition count and notification count
- Driver departure confirmation result
- Driver delivery confirmation result
- Resource release result
- Cross-driver isolation result
- Manager override audit result
- Manual page reload required: the required answer is `No`

## Map evidence

Report across the required poll sequences:

- Photo image registrations
- Symbol additions/updates/removals
- Global annotation clears
- Free-mode polling camera moves
- Follow-mode selected-truck camera moves
- RouteOverview polling camera moves
- Manual-pan protection
- Route-fit count

## Validation

- .NET build
- Architecture test count
- Backend integration test count
- Flutter analyzer
- Flutter test count
- Web builds
- EF migration/drift
- PostgreSQL/Compose health
- Browser workflows
- GitHub CI only if actually run after push
- Android result or blocker

## Evidence and timing

- Evidence directory
- Implementation plan
- Task-level active elapsed times
- Total active elapsed time

## Git status

Confirm no commit, push, or PR was performed and summarize changed files.

If any mandatory lifecycle, authorization, geofence, photo-security, map-follow, refresh, or browser criterion fails, report Sprint 4.1 as incomplete rather than weakening the acceptance criteria.
