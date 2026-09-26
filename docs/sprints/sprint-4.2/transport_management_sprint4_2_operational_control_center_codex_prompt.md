# Sprint 4.2 — Operational Control Center and Lifecycle Synchronization

## Role

Act as a senior product engineer, solution architect, and QA lead working inside the existing Transport Management System repository.

Own the complete result across:

- ASP.NET Core backend behavior;
- domain lifecycle correctness;
- EF Core persistence and tenant isolation;
- Flutter Web user experience;
- operational polling and cross-session synchronization;
- bilingual English/Arabic localization and RTL;
- automated tests;
- real-browser acceptance;
- data safety, evidence, and documentation.

This sprint is not a collection of unrelated cosmetic changes. Its single product objective is:

> Give the company owner an accurate, continuously updated operational picture of who is signed in, which trips are active, how close they are to their next milestone, what needs attention, and when a trip has actually completed.

---

## Repository and expected baseline

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected baseline when this prompt was written:

```text
958bd5d feat(driver): repair assignment activation workflow
```

Before modifying anything:

1. Inspect the current branch, HEAD, status, remotes, and recent history.
2. Treat the repository state you actually find as authoritative.
3. Record the baseline commit and initial worktree status.
4. Preserve every unrelated user change.
5. Do not reset, discard, clean, or overwrite user work.
6. Do not modify `.env`.
7. Do not delete or recreate retained PostgreSQL or truck-photo volumes.
8. Do not overwrite existing users, tenants, credentials, trucks, drivers, trips, photos, or operational history.
9. Do not commit, push, create a branch, or open a pull request unless explicitly requested later.

If the current baseline differs, document the difference and adapt safely.

---

## Mandatory implementation plan

Create and continuously update:

```text
docs/sprints/sprint-4.2/SPRINT4_2_IMPLEMENTATION_PLAN.md
```

It must include:

- baseline commit and worktree state;
- confirmed root causes rather than assumptions;
- lifecycle and cross-session refresh design;
- operational overview/read-model design;
- progress semantics;
- identity/profile design;
- notification data contract;
- default Driver selection rules;
- API and Flutter changes;
- tenant/security analysis;
- test and browser-acceptance matrix;
- data-safety plan;
- actual start/end timestamps and active elapsed time for each task;
- final validation results and unresolved limitations.

Update timings while work occurs. Do not invent or reconstruct them at the end.

---

## Current product context

The system already supports:

- multi-tenant authentication and roles;
- clients, trucks, Drivers, trips, and structured route stops;
- truck photos and default Driver metadata;
- commercial routes and approach/repositioning routes;
- Driver assignment notifications;
- Driver-controlled departure;
- browser-independent simulator ingestion;
- arrival geofences;
- Driver loading and delivery confirmations;
- operational notifications with sound;
- owner and Driver maps;
- remaining-distance and ETA calculations for selected tracked trips;
- Arabic/English and RTL/LTR;
- post-trip Driver/Truck vehicle sessions.

Sprint 4.1.2.1 successfully proved the following real-browser path:

```text
Owner assigns trip
→ Driver opens notification
→ Driver confirms departure
→ backend generates approach route
→ trip becomes EnRouteToPickup
→ simulator moves independently of browser reads
```

This sprint must build on that behavior without regressing it.

---

## User-observed problems and requested improvements

### 1. Completed trip remains visibly active

After the Driver completes a trip, the Owner can continue seeing the trip as active in an already-open trip list or detail page.

Current code appears to transition `AtDelivery → Completed` correctly and active backend queries appear to exclude `Completed`. Verify this against the current repository and runtime data. The likely gap is stale Owner-side state because:

- Dashboard polling and Trips polling are inconsistent;
- an Owner trip list can remain cached;
- a trip detail page does not necessarily refresh after an action performed in another authenticated session;
- Driver-side mutation invalidation does not cross browser sessions.

Do not assume this is only a UI problem. Prove where persisted state and presentation diverge.

### 2. Signed-in identity is unclear

The shell does not make it sufficiently obvious whether the current page belongs to:

- the company Owner/manager;
- an operations user;
- or a specific Driver.

This is especially confusing during two-account testing.

### 3. Notifications lack operational context

Arrival notifications are too generic. A notification must identify:

- which truck arrived;
- which trip it belongs to;
- whether it reached pickup or delivery;
- and the meaningful stop/location name.

### 4. Owner lacks an at-a-glance active trip overview

The Owner should not need to select trucks one by one on the map merely to understand current operations.

The product needs a compact Dashboard overview plus a complete Active Trips list showing phase, next milestone, route progress, remaining distance, ETA, health, and attention state.

### 5. Truck-to-default-Driver behavior is not sufficiently explicit

The codebase already appears to support `DefaultDriverId` on a truck and attempts to select that Driver during assignment. Verify the exact current behavior.

The UX must make this relationship clear and safe. It must never silently select an arbitrary first available Driver when the selected truck has no valid default Driver.

---

## Sprint product outcome

After Sprint 4.2:

1. A Driver completes a trip.
2. The backend persists `Completed` exactly once and releases commercial resource reservations.
3. An already-open Owner Dashboard, Active Trips list, and trip detail converge to the completed state without manual page reload.
4. The trip disappears from Active Trips and appears in Completed Trips.
5. The Owner sees a contextual notification naming the truck, trip, and delivery location.
6. Every application page clearly identifies the signed-in user, localized role, and company.
7. The Dashboard shows the most important active trips at a glance.
8. The Active Trips tab shows the complete operational fleet without requiring map interaction.
9. Selecting a truck during assignment safely preselects its eligible default Driver and explains the choice.

---

## Scope

### In scope

- completion lifecycle verification and idempotency;
- cross-session Owner synchronization;
- lightweight active-operation polling;
- signed-in user/profile presentation;
- enriched structured operational notifications;
- Dashboard active-trip overview;
- enhanced Active Trips list;
- server-owned active trip operational projection;
- honest phase/progress/remaining-distance/ETA semantics;
- default Driver auto-selection and fallback behavior;
- English/Arabic localization and RTL;
- automated and real-browser acceptance;
- documentation, evidence, and timing.

### Out of scope

- finance;
- maintenance management;
- real GPS vendor integration;
- SignalR or a new push infrastructure;
- proof-of-delivery photos/signatures;
- payroll or Driver shifts;
- route optimization across multiple trips;
- automated Driver reassignment;
- customer portal;
- a separate new operations module/page when Dashboard plus Trips can serve the current seven-truck fleet;
- unrelated UI redesigns.

---

# Workstream 1 — Lifecycle completion and cross-session synchronization

## 1.1 Prove the source of stale completion

Reproduce the issue with two isolated sessions:

```text
Owner keeps Active Trips or trip detail open
Driver confirms delivery in another session
Owner screen still shows the old status
```

Compare at the same moment:

- database trip status and `CompletedAt`;
- `GET /api/trips/{id}`;
- active trip query response;
- Dashboard response;
- Owner Flutter provider state;
- Driver Workspace state.

Document whether the defect is persistence, query classification, client caching, polling, invalidation, or more than one layer.

## 1.2 Preserve the lifecycle authority

The intended normal lifecycle remains:

```text
Assigned
→ EnRouteToPickup
→ AtPickup
→ InTransit
→ AtDelivery
→ Completed
```

Rules:

- geofence arrival at delivery produces `AtDelivery`, not automatic completion;
- the Driver confirms delivery and produces `Completed`;
- an authorized manager override remains an audited exception with a reason;
- completion writes `CompletedAt` once;
- duplicate confirmation is idempotent or returns one stable, documented conflict without duplicating events;
- Driver becomes Available;
- the truck is no longer commercially reserved by the completed trip;
- post-trip vehicle-session behavior from Sprint 4.1.2 remains intact;
- exactly one completion event and exactly one completion notification exist.

Verify every invariant and repair only what is incorrect.

## 1.3 Add focused operational refresh

For the current fleet size, use lightweight polling rather than introducing SignalR.

Do not poll the entire CRUD/reference dataset every two seconds.

Recommended behavior:

- Dashboard operational summary: existing configurable 2–5 second polling;
- Active Trips operational projection: default 3 seconds, configurable and safely clamped;
- an open active trip detail: default 3 seconds while the trip is operational;
- Completed/Cancelled/Archived trip detail: stop live polling and use manual refresh;
- planned/completed/cancelled/archive tabs: refresh on entry, explicit refresh, and relevant local mutation rather than continuous high-frequency polling.

Requirements:

- non-overlapping requests;
- latest-generation result wins;
- timer cancellation on disposal/logout/role change;
- no stale response may overwrite a newer state;
- transient failures preserve the last good state and show a subtle stale/connectivity indicator after repeated failures;
- successful response clears the warning;
- do not reset filters, selected tab, page, scroll, or map camera during refresh;
- polling reads remain side-effect free.

## 1.4 Automatic classification transition

When the Owner is viewing Active Trips and a trip becomes `Completed`:

- remove it from the active projection without manual reload;
- update active/completed counts;
- do not leave an empty phantom card;
- optionally show a small localized non-blocking message that the trip completed;
- make it discoverable in the Completed tab immediately;
- refresh truck/Driver availability where displayed.

If the Owner is viewing that trip's detail page:

- update the status chip and completion timestamp;
- disable operational actions that no longer apply;
- display the completed state without navigating away unexpectedly;
- stop high-frequency detail polling after completion.

---

# Workstream 2 — Signed-in identity and role clarity

## 2.1 Global account identity control

Use the existing authenticated user information where possible:

- display name;
- localized role;
- company name;
- email where appropriate;
- Driver identity when the signed-in user is linked to a Driver.

Add a responsive account control in the application shell.

Desktop/wide layout should show a compact identity area such as:

```text
[AM]  Ahmad Mohammad
      Driver · Demo Transport
```

Owner example:

```text
[AO]  Ahmad
      Owner · Demo Transport
```

Compact/mobile layout may show only the avatar/initials. Pressing it opens a menu or sheet containing:

- display name;
- localized role;
- company name;
- email;
- Settings;
- Change password;
- Sign out.

Do not duplicate the existing notification or logout behavior awkwardly. Consolidate shell actions cleanly.

## 2.2 Role and Driver naming rules

- Localize `Owner`, `Operations`, and `Driver` labels.
- Do not expose raw role codes in Arabic UI.
- For a Driver account, prefer the linked Driver's operational full name when it differs from the generic account display name, provided it can be obtained safely without leaking another Driver.
- If extending `/api/auth/me`, keep it tenant-safe and backward-compatible.
- Do not make every page issue a separate Driver lookup merely to render the shell.
- If the linked Driver identity is temporarily unavailable, show the authenticated account display name and role rather than breaking the shell.

## 2.3 Page-level context

The shell is the global source of identity. Additionally:

- Driver My Trip may show `Driver: <name>` in its workspace header;
- manager pages may show a localized management context label only when useful;
- avoid large repeated banners that waste screen space.

---

# Workstream 3 — Context-rich operational notifications

## 3.1 Structured snapshot data

Operational notification payloads must contain stable structured snapshot data sufficient for display even if a truck or stop is renamed later.

For pickup/delivery arrival notifications, include at least:

```text
tripNumber
truckPlateNumber
truckFleetCode (nullable)
driverName (nullable)
stopType
stopName
stopAddress (nullable)
reachedAt
distanceMeters (when useful)
```

For assignment notifications, retain or add:

```text
tripNumber
truckPlateNumber
truckFleetCode (nullable)
driverName
pickupName
confirmationRequired
```

For Driver confirmation/completion notifications, include the same relevant trip/truck/Driver context.

Store language-neutral structured values. Do not store a pre-rendered English or Arabic sentence as the canonical notification body.

## 3.2 Localized rendering

Flutter must render natural localized sentences.

Arabic examples:

```text
الشاحنة 34-ABC-123 وصلت إلى موقع الاستلام: مستودع الشركة – المنطقة الصناعية.
```

```text
الشاحنة 34-ABC-123 وصلت إلى موقع التسليم: مستودع العميل – حلب.
```

English examples:

```text
Truck 34-ABC-123 arrived at pickup: Company Warehouse — Industrial Area.
```

```text
Truck 34-ABC-123 arrived at delivery: Client Warehouse — Aleppo.
```

Requirements:

- graceful fallback when an optional field is missing;
- no `null`, empty separators, raw JSON, GUIDs, or raw enum codes;
- correct Arabic word order and RTL;
- concise overlay text and a more detailed notification-list subtitle when needed;
- trip/truck identity visible without opening the item;
- sound behavior remains deduplicated;
- existing read/unread behavior remains correct.

## 3.3 Navigation

On notification action/tap:

- Owner/Operations users go to the relevant trip detail when `tripId` exists;
- Driver users go to refreshed My Trip when it is their scoped operational notification;
- a truck-only alert may open truck detail for authorized management users;
- mark-as-read behavior must not block navigation if its request fails transiently;
- do not allow a Driver to navigate into manager-only routes.

## 3.4 Event correctness

Ensure notification creation is:

- tenant-scoped;
- idempotent through a deterministic event key;
- exactly once per meaningful lifecycle event;
- persisted in the same consistent application operation as the state/event where appropriate;
- not recreated on every tracking poll.

---

# Workstream 4 — Active Trips operational overview

## 4.1 Product placement

Do not create a separate top-level page in this sprint.

Implement the overview in two layers:

### Dashboard summary

Show the most important active trips, ideally 5–8 depending on layout, ordered by attention and ETA.

Include a clear `View all active trips` action.

### Trips → Active tab

Show the complete operational list with richer information, filters, and live refresh.

This is appropriate for the current small fleet and avoids navigation sprawl.

## 4.2 Server-owned operational projection

Create or extend a tenant-scoped query/read model that returns one efficient projection for all active trips.

A conceptual response item may include:

```json
{
  "tripId": "...",
  "tripNumber": "TRP-2026-000123",
  "clientId": "...",
  "clientName": "Factory A",
  "truckId": "...",
  "truckPlateNumber": "34-ABC-123",
  "truckFleetCode": "T-07",
  "truckPhotoVersion": "...",
  "truckPhotoThumbnailUrl": "...",
  "driverId": "...",
  "driverName": "Ahmad",
  "status": "InTransit",
  "operationalPhase": "ToDelivery",
  "nextMilestone": "Delivery",
  "nextStopName": "Client Warehouse",
  "progressPercent": 72.4,
  "remainingDistanceMeters": 46000,
  "estimatedArrivalAt": "...",
  "lastPositionAt": "...",
  "trackingHealth": "Current",
  "isOnline": true,
  "isOffRoute": false,
  "attentionCode": null
}
```

The exact contract should follow repository conventions.

Avoid N+1 database queries and avoid one route-history API request per trip. Build an efficient tenant-scoped query/application projection using latest positions and already stored route snapshots.

## 4.3 Honest progress semantics

Do not invent one misleading overall percentage that mixes driving, waiting, loading, and confirmation time.

Represent lifecycle progress with explicit milestones:

```text
Assigned
To pickup
At pickup / awaiting load confirmation
To delivery
At delivery / awaiting delivery confirmation
Completed
```

For moving phases:

- `EnRouteToPickup`: progress applies to the active approach route;
- `InTransit`: progress applies to the cargo route;
- use geometry projection and persisted route distance;
- clamp progress to `0..100`;
- expose remaining distance and ETA;
- identify off-route state;
- never advance from HTTP reads.

For waiting phases:

- `Assigned`: show `Awaiting Driver departure`;
- `AtPickup`: show `Awaiting loading confirmation`;
- `AtDelivery`: show `Awaiting delivery confirmation`;
- do not show an arbitrary moving percentage;
- show how long the trip has been waiting when practical.

For missing/stale/offline telemetry:

- keep the lifecycle phase visible;
- show `No telemetry`, `Stale`, or `Offline` clearly;
- do not display a fabricated ETA or `0 km remaining`;
- preserve the last known update timestamp.

## 4.4 Attention and sorting

Define server-owned or consistently derived attention codes, for example:

```text
AWAITING_DRIVER_DEPARTURE
AWAITING_LOADING_CONFIRMATION
AWAITING_DELIVERY_CONFIRMATION
TRACKING_OFFLINE
TRACKING_STALE
OFF_ROUTE
ETA_OVERDUE
NONE
```

Prioritize Dashboard items approximately as:

1. off-route/offline/stale/overdue;
2. waiting for human confirmation;
3. nearest ETA;
4. other active trips.

Do not let Flutter and backend implement contradictory priority rules.

## 4.5 Dashboard presentation

Add an operational card/section that remains usable in Arabic and English.

Each row/card should show at minimum:

- trip number and client;
- truck plate/photo thumbnail where available;
- Driver;
- phase/status chip;
- next stop/milestone;
- segment progress bar only when meaningful;
- remaining distance;
- ETA;
- tracking health/last update;
- attention indicator;
- tap action to open trip details.

The map remains available but must no longer be the only way to understand progress.

## 4.6 Active Trips tab presentation

Enhance the existing Active Trips group rather than replacing all trip CRUD screens.

Use responsive UI:

- data-table/list style on wide displays when readable;
- cards on compact layouts;
- preserve search and filters;
- support filters for truck, Driver, client, phase, and attention when reasonable;
- retain paging if needed;
- do not lose filter state on a poll refresh.

When a trip completes during polling, remove it cleanly from the active result and update counts without a full-screen loading flash.

---

# Workstream 5 — Safe default Driver selection

## 5.1 Preserve the correct domain meaning

Treat the truck relationship as:

```text
Preferred/default Driver
```

not a permanent exclusive binding.

A manager may select a different eligible Driver for an individual trip without changing the truck's stored default Driver.

Changing the default Driver must remain an explicit truck edit, not an accidental side effect of trip assignment.

## 5.2 Assignment behavior

When the manager selects a truck:

### Valid default Driver

If the truck's default Driver is active, available, unreserved, and otherwise eligible:

- automatically select that Driver;
- display a localized explanation such as:

```text
Ahmad was selected because he is the default Driver for this truck.
```

- allow an explicit manual override for this trip.

### Default Driver unavailable

If the default Driver is inactive, on another trip, reserved, or otherwise unavailable:

- do not silently select another Driver;
- leave Driver selection empty unless a previously explicit valid choice should be preserved;
- display the localized reason;
- require the manager to choose another eligible Driver.

### No default Driver

If the truck has no default Driver:

- do not auto-select the first eligible Driver;
- leave Driver selection empty;
- require deliberate selection.

### Explicit manager choice

Once the manager manually chooses a Driver:

- preserve that explicit choice while it remains eligible;
- changing unrelated fields must not overwrite it;
- changing to another truck must clearly indicate whether the explicit Driver remains selected or whether the new truck default is being proposed;
- avoid surprising silent replacements.

Choose and document one deterministic rule for the last case, then test it.

## 5.3 Assignment review

The Review step must visibly show:

- selected truck;
- selected Driver;
- whether the Driver came from the truck default or manual selection;
- linked application-account state;
- any eligibility warning before confirmation.

No trip may be assigned with an ineligible or missing Driver.

## 5.4 Truck form

Keep default Driver selection in truck create/edit.

Improve clarity where necessary:

- label it `Default Driver` / `السائق الافتراضي`;
- explain that it can be overridden per trip;
- allow clearing the default Driver;
- prevent cross-tenant Driver IDs;
- handle inactive/deleted/archived Driver references safely;
- preserve database referential behavior.

---

## API and application design requirements

### 1. Prefer a focused operational endpoint

Do not repeatedly reload all clients, trucks, Drivers, and historical trips merely to update current operations.

Introduce or extend a focused endpoint such as:

```text
GET /api/dashboard/active-trips
```

or:

```text
GET /api/operations/active-trips
```

Use the naming that best matches the existing architecture.

Support only justified query options, such as:

- limit/page;
- search;
- client ID;
- truck ID;
- Driver ID;
- phase;
- attention only.

Validate limits and remain tenant-scoped.

### 2. Consistent status grouping

Centralize or reuse one definition for operational groups so Dashboard, Trips, client counts, resource reservations, and tests do not drift.

At minimum:

- planned: `Draft`, `Assigned`;
- operational/active: `EnRouteToPickup`, `AtPickup`, `Started` if still supported, `InTransit`, `AtDelivery`, and any deliberately retained intermediate state;
- completed: `Completed`;
- cancelled: `Cancelled`;
- archived: archived completed/cancelled records.

Decide deliberately whether `Assigned` is displayed in Active Operations as `Awaiting Driver departure` while remaining in the planned business grouping. The same trip must not be double-counted in totals. Document the distinction between lifecycle grouping and operational attention grouping.

### 3. Completion consistency

When completion is persisted, all read models must converge:

- trip detail status;
- Active Trips projection;
- Completed Trips query;
- Dashboard active/completed counts;
- client active/completed counts;
- truck operational reservation;
- Driver availability;
- current trip lookup for Driver;
- notification history.

Add consistency tests spanning these projections.

### 4. Backward compatibility

Keep existing API contracts working unless a safe additive migration is possible. Prefer additive fields/new projections over breaking existing clients.

Use stable ProblemDetails error codes for new failure modes.

---

## Performance and reliability requirements

The expected current fleet is small, but implement sound query behavior.

Targets for a normal local development dataset:

- one operational overview request, not one request per trip;
- bounded payload size;
- no route geometry in list payloads unless truly needed for the list;
- no full position history in the overview;
- no N+1 truck/Driver/client/photo lookups;
- non-overlapping polling;
- no full-screen flicker on silent refresh;
- preserve the previous good projection during one transient failure;
- visible stale indicator after repeated failures;
- cancellation tokens honored;
- database query remains tenant-filtered and read-only where appropriate.

If adding indexes is necessary, create a forward-only migration and justify each index with the query pattern.

---

## Backend test requirements

Add deterministic tests for at least the following.

### Completion and consistency

1. Driver confirmation transitions `AtDelivery → Completed`.
2. `CompletedAt` is written.
3. Driver becomes Available.
4. truck is no longer reserved by the completed trip.
5. Driver current-trip lookup no longer returns the completed trip.
6. post-trip vehicle session remains available until explicitly ended.
7. active query excludes the trip.
8. completed query includes the trip.
9. Dashboard active count decreases and completed-today count increases.
10. client active/completed counts converge.
11. exactly one lifecycle event and notification are created.
12. duplicate confirmation cannot create duplicates or corrupt timestamps.
13. another tenant cannot observe the completed trip or notification.

### Operational projection

Cover each important phase:

- Assigned/awaiting departure;
- EnRouteToPickup with approach progress;
- AtPickup/awaiting loading confirmation;
- InTransit with cargo progress;
- AtDelivery/awaiting delivery confirmation;
- offline tracking;
- stale tracking;
- missing telemetry;
- off-route;
- completed trip disappearing from active results.

Verify:

- next milestone;
- progress semantics;
- remaining distance;
- ETA nullability;
- last update;
- attention code;
- sorting priority;
- tenant isolation;
- filtering and paging;
- no duplicate trips.

### Notification payloads

Verify pickup, delivery, assignment, and completion payloads include the expected structured context and remain idempotent.

Verify renamed records after the event do not corrupt the original snapshot presentation fields.

### Default Driver

1. valid truck default is suggested/selected;
2. unavailable default returns a stable reason;
3. no default does not cause arbitrary Driver selection;
4. manager override applies only to the trip;
5. truck default remains unchanged;
6. cross-tenant Driver ID is rejected;
7. reserved/inactive/on-trip Driver cannot be assigned.

---

## Flutter test requirements

Add tests for:

### Cross-session refresh behavior

- Active Trips silently refreshes without losing filters;
- an item disappears when the refreshed server projection marks it completed;
- completed count/tab becomes current;
- active trip detail updates to Completed;
- detail polling stops after terminal status;
- responses arriving out of order cannot restore an old status;
- repeated polling failures show stale feedback while preserving data;
- logout disposes timers and state.

### Identity shell

- Owner identity and localized role;
- Operations identity and localized role;
- Driver identity and localized role;
- company name;
- compact layout account menu;
- Arabic RTL;
- Settings, password, and logout actions;
- no manager navigation appears for Driver.

### Notifications

- contextual pickup text;
- contextual delivery text;
- missing optional field fallback;
- Arabic/English formatting;
- notification overlay and list view;
- sound deduplication remains intact;
- Owner navigation to trip detail;
- Driver navigation to My Trip;
- no raw enum/GUID/JSON is rendered.

### Active trip overview

- moving route displays segment progress, remaining distance, and ETA;
- waiting phase displays a meaningful milestone instead of a fake percentage;
- missing/stale/offline telemetry presentation;
- attention ordering;
- Dashboard limited list and View All action;
- Active Trips full list;
- responsive wide and compact layouts;
- Arabic RTL;
- no full-screen loading flicker during silent refresh.

### Default Driver UX

- truck selection auto-selects valid default Driver;
- explanation is shown;
- unavailable default leaves Driver empty and explains why;
- no default leaves Driver empty;
- manual choice is preserved according to the documented rule;
- review step shows selection source and account-link state.

Do not count only JSON/model parsing tests as sufficient UI coverage.

---

## Mandatory real-browser acceptance

Use:

- real Flutter Web release build;
- real API and PostgreSQL;
- real MapLibre/OpenFreeMap configuration;
- browser-independent simulator worker;
- two independently isolated Owner and Driver browser profiles/storage contexts.

Do not use two ordinary tabs sharing one authentication store.

### Acceptance scenario A — Default Driver assignment

1. Create/use a disposable active Driver with an application account.
2. Create/use a disposable active truck whose default Driver is that Driver.
3. Create a ready trip.
4. In Owner UI, choose the truck.
5. Verify the correct default Driver is automatically selected and explained.
6. Verify Review shows truck, Driver, source, and linked account.
7. Assign through the UI.
8. Verify the Driver receives the contextual assignment notification.

Also verify a truck with no default Driver leaves the Driver field empty rather than selecting the first eligible Driver.

### Acceptance scenario B — Complete operational lifecycle with Owner watching

1. Keep Owner Dashboard or Active Trips open.
2. In the isolated Driver profile, open the assignment and confirm departure.
3. Verify Owner Active Trips shows the correct phase without manual refresh.
4. Advance using normal background simulator behavior and supported speed configuration; do not mutate trip status directly in the database.
5. Verify pickup arrival notification names truck, trip, and pickup location.
6. Driver confirms loading/departure through the UI.
7. Verify Owner overview changes to `To delivery` and shows progress, remaining distance, and ETA.
8. Verify delivery arrival notification names truck, trip, and delivery location.
9. Verify Owner overview shows `Awaiting delivery confirmation` rather than prematurely Completed.
10. Driver confirms delivery through the UI.
11. Without browser reload:
    - Owner trip detail changes to Completed if open;
    - Active Trips removes the trip;
    - Dashboard active count decreases;
    - completed-today count increases;
    - truck/Driver availability becomes current;
    - Completed Trips contains the trip.
12. Verify Driver post-trip map/session behavior remains available.

### Acceptance scenario C — Identity clarity

Capture Owner and Driver pages simultaneously or sequentially using isolated profiles and prove that each clearly shows:

- account/display name;
- localized role;
- company;
- appropriate navigation.

### Acceptance constraints

- no manager lifecycle override in the normal flow;
- no direct lifecycle endpoint call from the harness when the UI action is under test;
- no database status manipulation;
- no manual browser refresh to prove synchronization;
- no screenshots from partial/failed runs presented as passing evidence;
- if the browser workflow fails, mark the sprint incomplete.

---

## Evidence requirements

Store evidence under:

```text
docs/evidence/sprint4_2/
```

Include:

- `README.md` with an honest result;
- automated validation summary;
- browser acceptance narrative;
- machine-readable browser result JSON;
- cross-session synchronization timing JSON;
- before/after API/database lifecycle projection evidence;
- screenshots of Owner identity, Driver identity, Dashboard overview, Active Trips, enriched pickup notification, enriched delivery notification, waiting-for-confirmation state, and Completed state;
- English/LTR and Arabic/RTL evidence;
- default Driver selection evidence;
- polling/operation counts or equivalent proof of non-overlap;
- retained-data before/after evidence.

Record useful timings:

- Driver completion click;
- persisted `CompletedAt`;
- notification persistence;
- Owner detail observed Completed;
- Active Trips removal;
- Dashboard count convergence.

State the configured polling interval and measured convergence latency.

Never store:

- passwords;
- access/refresh tokens;
- private headers;
- connection strings;
- `.env` content;
- real customer personal data;
- retained database dumps.

---

## Retained-data safety

Before migrations or acceptance:

1. Identify retained Compose project and volume names.
2. Record non-sensitive counts for tenants, users, clients, trucks, Drivers, trips by status, positions, notifications, and photos.
3. Prefer a separate disposable Compose project and volumes.
4. Fail closed if acceptance resolves to the retained database/volume.
5. Do not change existing passwords or `.env` to simplify automation.
6. Do not create unexplained demo records in the user's tenant.
7. Restore the retained stack to its initial running/stopped state.
8. Compare retained after-counts and explain any legitimate background simulator heartbeats separately from business-data changes.

If a migration is required:

- use a forward-only, default-safe migration;
- do not fabricate operational data;
- preserve nullable compatibility where appropriate;
- verify EF model drift is zero;
- do not apply it to retained data solely for evidence convenience.

---

## Architecture constraints

Preserve existing boundaries:

- Domain owns lifecycle invariants.
- Application owns operational projection and orchestration.
- Infrastructure owns efficient EF queries and provider implementations.
- API exposes stable tenant-scoped contracts.
- Flutter renders server-owned operational facts and localizes them.
- tracking and routing remain provider-neutral.
- read endpoints remain side-effect free.
- simulator controls remain Development/Testing-only and Owner-authorized.

Do not:

- implement lifecycle truth only in Flutter;
- calculate progress from arbitrary screen state;
- make the overview call one endpoint per trip;
- duplicate active-status definitions throughout the codebase;
- add SignalR merely for novelty;
- make notification text language-specific in the database;
- turn the default Driver into an inflexible permanent assignment.

---

## Documentation updates

Update at least:

```text
README.md
docs/architecture.md
docs/sprints/README.md
docs/sprints/sprint-4.2/SPRINT4_2_IMPLEMENTATION_PLAN.md
```

Document:

- lifecycle completion authority;
- Owner convergence/polling behavior;
- operational overview projection;
- progress semantics;
- attention codes;
- notification snapshot contract;
- account identity presentation;
- default Driver rules;
- how to run the two-profile manual test;
- configurable polling intervals;
- deferred SignalR/real GPS work.

---

## Validation requirements

Run the repository's supported commands. At minimum:

### Backend

```text
dotnet build
dotnet test
```

Requirements:

- zero errors;
- zero new warnings;
- all architecture tests pass;
- all integration tests pass;
- EF pending-model/drift check passes.

### Flutter

```text
flutter analyze
flutter test
flutter build web --release ...
```

Requirements:

- analyzer clean;
- all Flutter tests pass;
- release Web build succeeds;
- production build keeps simulator mutation safeguards;
- mandatory browser workflow passes.

### Android

Build/run only if a valid SDK and device/emulator exist. If unavailable, record the exact environmental limitation. Do not claim Android validation without running it, and do not use Android absence to skip Web acceptance.

---

## Definition of Done

Sprint 4.2 is complete only when all items below pass:

### Lifecycle and synchronization

- [ ] Driver delivery confirmation persists `Completed` and `CompletedAt` exactly once.
- [ ] Active query no longer contains the completed trip.
- [ ] Completed query contains it.
- [ ] Dashboard/client/resource projections converge.
- [ ] An already-open Owner Active Trips screen updates without manual reload.
- [ ] An already-open active trip detail updates without manual reload.
- [ ] Live polling stops for terminal detail status.
- [ ] Driver post-trip vehicle session still works.

### Identity

- [ ] Owner, Operations, and Driver accounts show name, localized role, and company.
- [ ] compact and wide layouts work.
- [ ] Driver navigation remains restricted.
- [ ] Arabic RTL is correct.

### Notifications

- [ ] pickup notification identifies truck, trip, and pickup location.
- [ ] delivery notification identifies truck, trip, and delivery location.
- [ ] assignment/completion notifications contain appropriate structured context.
- [ ] sound and unread behavior remain deduplicated.
- [ ] notification navigation is role-correct and tenant-safe.

### Operational overview

- [ ] Dashboard shows prioritized active trips without requiring map selection.
- [ ] Active Trips shows the complete operational list.
- [ ] moving phases show honest segment progress, remaining distance, and ETA.
- [ ] waiting phases show the required human action instead of a fake percentage.
- [ ] stale/offline/missing/off-route states are explicit.
- [ ] overview retrieval avoids N+1 API/database behavior.
- [ ] filters and UI state survive silent refresh.

### Default Driver

- [ ] valid truck default Driver is selected and explained.
- [ ] unavailable default is explained and not silently replaced.
- [ ] no default leaves Driver unselected.
- [ ] manager can override per trip.
- [ ] trip override does not modify truck default.
- [ ] review step identifies the selected resources and source.

### Quality and evidence

- [ ] backend/architecture/Flutter tests pass.
- [ ] analyzer and Web release build pass.
- [ ] EF drift is clean.
- [ ] real two-profile browser lifecycle passes through Completed.
- [ ] no manager override/direct endpoint/database shortcut bypasses UI acceptance.
- [ ] retained data and credentials remain safe.
- [ ] evidence and actual elapsed-time records are complete.

If any blocking browser or lifecycle item fails, report the sprint as **incomplete**.

---

## Final response format

At the end, report:

1. concise outcome summary;
2. confirmed root causes of stale completion;
3. lifecycle and synchronization changes;
4. identity/profile changes;
5. notification contract and examples;
6. Dashboard/Active Trips behavior;
7. default Driver behavior;
8. backend and Flutter test totals;
9. browser acceptance pass/fail;
10. measured Driver-completion-to-Owner-convergence latency;
11. query/polling performance notes;
12. data-safety result;
13. Android status;
14. actual elapsed-time table and total;
15. unresolved limitations;
16. exact git status;
17. explicit confirmation that no commit or push was performed.

Do not call Sprint 4.2 complete unless the Owner observes a Driver-completed trip leave Active Trips and appear as Completed without manually reloading the page.
