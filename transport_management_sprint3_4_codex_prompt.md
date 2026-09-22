# Sprint 3.4 — Trip Operations and Management UX

## Role

Act as a senior product engineer, logistics product designer, domain architect, and technical lead working inside the existing **Transport Management System** repository.

Implement this sprint end to end. Do not only produce a plan, mockup, or code review. Inspect the current implementation, design a coherent trip-management model, implement the backend and Flutter changes, migrate existing data safely, validate the complete browser workflow, and document all decisions.

---

## Repository and Baseline

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Start from the current `main` branch, which includes Sprint 3.3.1 and commit `5e68145` or a later reviewed commit.

Before changing anything:

1. Fetch the latest repository state.
2. Inspect `git status` and preserve unrelated user changes.
3. Read `README.md`, `docs/architecture.md`, and Sprint 3.2–3.3.1 implementation plans.
4. Trace the complete trip flow through domain, persistence, API, Flutter routing, list screen, planner, details screen, dashboard, tracking, repositioning, and simulator.
5. Inspect all database constraints and filtered indexes related to trip/resource reservation.
6. Record the current trip-management usability gaps with focused baseline evidence.

Preserve all correct existing behavior:

- multi-tenant isolation;
- authentication and role authorization;
- English/Arabic localization and RTL/LTR;
- route planning, MapLibre/OpenFreeMap, and immediate stop markers;
- trip repositioning/dispatch-to-pickup workflow;
- simulator location setup and stationary heartbeat;
- tracking history, route progress, and no-teleport guarantees;
- stable map annotations, zero global clears, and no polling camera moves;
- immutable activated route/repositioning snapshots;
- physical simulator-speed semantics.

Do not replace these systems with unrelated implementations.

---

## Product Problem

The trip domain now supports routing, dispatch-to-pickup, cargo execution, and tracking, but the trip-management UX is still a technical CRUD prototype.

Current limitations include:

- trips have no human-readable company trip number;
- the Flutter list has no search, operational tabs, filters, or pagination;
- creating a trip requires completing stops and route calculation before saving anything;
- a routing/geocoding failure can prevent saving an otherwise useful draft;
- the planner uses a long technical form instead of a resumable workflow;
- planned start is entered as raw ISO-8601 text;
- there is no safe Draft deletion workflow;
- cancellation does not capture a reason or actor;
- completed/cancelled trips cannot be archived out of daily operations;
- assigned trips cannot be unassigned or reassigned before dispatch;
- trip details do not provide a complete immutable operational timeline;
- available actions are not organized around a clear daily workflow;
- the current operations state loads all trips with other resources and is not suitable for long-term pagination.

This sprint must make trip management usable for a real transport-company manager while preserving the existing execution and tracking model.

---

## Sprint Goal

Deliver a coherent, auditable, and scalable trip-operations module covering:

1. Human-readable trip numbering.
2. Server-side paginated/searchable/filterable trip lists.
3. A resumable multi-step trip creation/editing workflow.
4. Draft saving without route-provider dependency.
5. Explicit route calculation as a later draft step.
6. Safe Draft deletion.
7. Assignment, reassignment, and unassignment before dispatch.
8. Reasoned cancellation rather than deletion of operational trips.
9. Archiving of completed/cancelled trips.
10. An immutable trip event timeline.
11. A reorganized trip-details screen with contextual actions.

This sprint completes trip operations before real-customer validation and before finance.

---

## Mandatory Working Process

Create `SPRINT3_4_IMPLEMENTATION_PLAN.md` before material implementation.

The plan must include:

- baseline findings;
- proposed trip lifecycle and deletion/archive semantics;
- trip-number generation design;
- incomplete-Draft persistence strategy;
- route calculation/persistence boundary;
- pagination/search/filter API design;
- assignment/reassignment concurrency design;
- event timeline design;
- migration/backfill strategy;
- Flutter state-management and navigation design;
- ordered tasks;
- automated and browser test strategy;
- risks and explicit decisions;
- actual start/end timestamps and elapsed time per task;
- total active sprint time.

Update elapsed times while work is performed. Do not fabricate all timing retrospectively.

Add focused regression tests for the important baseline gaps before implementing their fixes.

---

## Core Product Rules

### Operational records are not generic deletable CRUD rows

Use these semantics:

| Trip condition | Allowed removal action |
|---|---|
| Draft with no execution | Permanent Draft deletion with explicit confirmation |
| Assigned but not dispatched | Unassign, edit if rules allow, or Cancel with reason |
| En Route to Pickup / At Pickup / Started / In Transit | Cancel with reason when current business rules permit; never hard-delete |
| Delivered / Completed | Archive only; never hard-delete |
| Cancelled | Archive/unarchive; never hard-delete as an operational record |

Hard deletion must be a narrow domain operation, not a generic repository delete.

### Draft saving must not depend on external routing

A manager must be able to save and resume a Draft even when:

- pickup/delivery has not been selected yet;
- coordinates are incomplete;
- OSRM is unavailable;
- geocoding is unavailable;
- price or planned time is not final;
- no truck or driver is assigned.

The system must distinguish:

- Draft data that may be incomplete;
- assignment readiness;
- dispatch readiness;
- execution readiness.

Never use fake placeholder strings or invented coordinates merely to satisfy non-null database columns.

### Activated execution data remains immutable

Once dispatch/execution begins, do not silently mutate:

- cargo route snapshot;
- repositioning route snapshot;
- executed stop coordinates;
- tracking associations;
- trip number.

### Every important transition is auditable

Store stable event codes and structured metadata. Do not store localized UI sentences as the event source of truth.

---

## 1. Human-Readable Trip Number

Add an immutable tenant-scoped trip number, for example:

```text
TRP-2026-000123
```

Requirements:

- unique within a company;
- generated server-side;
- concurrency-safe under simultaneous creation requests;
- stable after creation;
- not reused after deletion/cancellation;
- searchable case-insensitively;
- shown prominently in list, details, dialogs, timeline, and map trip details;
- not used as the database primary key;
- format and sequence rules documented.

Choose a robust implementation such as a tenant/year counter protected by a database constraint/transaction or an equivalent concurrency-safe strategy. Do not calculate `MAX + 1` without protection.

### Existing data backfill

Backfill every existing trip deterministically and safely:

- partition by company;
- order by stable creation time and ID tie-breaker;
- derive the displayed year consistently;
- guarantee uniqueness;
- do not renumber again on subsequent deployments.

Review the generated/custom migration carefully and test it against PostgreSQL with multiple tenants.

---

## 2. Incomplete and Resumable Drafts

Refactor Draft persistence so the initial save does not call the routing provider.

### Draft fields

Define which fields are required for the first Draft save. Prefer a minimal useful set, such as client and/or cargo summary, but make a deliberate documented decision.

Fields that are allowed to remain incomplete in Draft must be represented honestly as nullable/incomplete values rather than fake placeholders.

Update:

- domain invariants;
- database nullability/constraints;
- request/response contracts;
- list/detail rendering;
- validation messages;
- migration and old-data compatibility.

### Readiness model

Expose backend-derived readiness rather than scattering rules across Flutter:

- `DraftCompletion` or equivalent checklist;
- `CanCalculateRoute`;
- `CanAssign`;
- `CanDispatch` through existing rules;
- missing requirements/error codes.

Assignment must remain impossible until the trip has:

- active valid client;
- required cargo/business fields;
- valid pickup and delivery coordinates;
- a current authoritative cargo route snapshot;
- planned timing required by policy.

Do not trust a client-provided Boolean readiness flag.

---

## 3. Multi-Step Trip Wizard

Replace the single long planner flow with a responsive, resumable wizard/stepper.

Recommended steps:

1. **Trip basics**
   - client;
   - cargo description;
   - optional notes;
   - initial Draft save.
2. **Pickup and delivery**
   - location search;
   - map selection;
   - manual coordinates;
   - immediate stable markers;
   - addresses/names.
3. **Schedule and commercial details**
   - planned date and time using localized date/time pickers;
   - price with clear currency-neutral numeric handling;
   - validation.
4. **Route**
   - explicit Calculate Route;
   - route distance/duration/provider/warnings;
   - retry without losing Draft data.
5. **Assignment (optional during creation)**
   - select eligible truck and driver or leave unassigned;
   - show availability and useful context.
6. **Review**
   - summary;
   - readiness checklist;
   - save/finish action.

Requirements:

- Save Draft is available before route calculation.
- Leaving and reopening the wizard resumes persisted state.
- Navigating between steps does not lose entered data.
- Route/geocoding failure does not erase other fields.
- Editing a Draft initializes map markers and completed steps correctly.
- Browser refresh after a saved step restores the Draft.
- Validation is step-specific and localized.
- Desktop Web layout and narrow/mobile layout do not overflow.
- English/LTR and Arabic/RTL are both correct.
- Do not expose raw ISO-8601 entry as the normal planned-date UX.

Autosave is optional only if implemented safely and visibly. Explicit Save Draft is mandatory.

---

## 4. Authoritative Route Calculation

Separate saving stops from calculating/persisting the authoritative cargo route.

Requirements:

- Draft stops can be saved without calling OSRM.
- Route calculation is an explicit server-side operation.
- The backend calculates through the configured routing abstraction.
- Client-supplied GeoJSON is not trusted as authoritative.
- A route snapshot records the stops fingerprint/version.
- Changing route-relevant stops invalidates the old Draft route and readiness.
- Route calculation failure leaves the Draft and stops intact.
- Assignment requires a route matching the current stop fingerprint.
- Existing route-aware trips remain valid after migration.
- Once execution begins, route immutability remains enforced.

Avoid calculating the same route twice during preview and save unless there is a deliberate documented reason.

---

## 5. Paginated Trip List and Operational Views

Implement server-side pagination and filtering. Do not fetch every trip and filter only in Flutter.

### API query capabilities

Support bounded, validated parameters for:

- page/page size or cursor pagination;
- free-text search;
- individual status or operational status group;
- archived/unarchived;
- client;
- truck;
- driver;
- planned date range;
- sort field and direction from a safe allowlist.

Search should cover at least:

- trip number;
- client name where architecture permits an efficient query;
- pickup/origin name;
- delivery/destination name;
- truck plate where appropriate.

Return:

- items;
- total count;
- page/cursor metadata;
- applied page size.

Enforce a maximum page size and add indexes supporting common tenant-scoped filters.

### Flutter operational tabs

Provide clear tabs/views:

- Active;
- Planned;
- Completed;
- Cancelled;
- Archived.

Define status-group membership in one consistent backend/shared contract or a carefully tested frontend mapping. Recommended semantics:

- Active: EnRouteToPickup, AtPickup, Started, InTransit, Delivered;
- Planned: Draft, Assigned;
- Completed: Completed and not archived;
- Cancelled: Cancelled and not archived;
- Archived: archived Completed/Cancelled records.

### List/card/table content

Each item should show:

- trip number;
- pickup -> delivery or an explicit Incomplete Draft label;
- client;
- status;
- planned date/time;
- truck and driver when assigned;
- route/readiness warning when incomplete;
- appropriate quick actions.

Provide:

- debounced search;
- filter controls;
- clear-filters action;
- loading, empty, error, and refresh states;
- pagination controls/infinite loading with duplicate-request protection;
- accessible keyboard behavior on Web.

Do not load clients, trucks, drivers, and every trip again after every small list action if a more focused state flow is appropriate. Refactor the monolithic operations loading carefully while preserving the other resource screens.

---

## 6. Draft Deletion

Add a dedicated domain/application/API operation for permanent Draft deletion.

Requirements:

- only a Draft may be permanently deleted;
- it must never have begun dispatch or execution;
- tenant ownership and authorization enforced;
- confirmation dialog names the trip number;
- UI explains deletion is permanent;
- related Draft-only stops and route snapshot are removed intentionally without orphaned records;
- no tracking/repositioning history may be deleted through this operation;
- invalid deletion returns stable `TRIP_DELETE_NOT_ALLOWED` or equivalent;
- concurrent deletion/update produces deterministic conflict/not-found behavior;
- list pagination/count updates correctly afterward.

Do not implement a generic `DELETE` that bypasses domain checks.

---

## 7. Cancellation with Reason

Enhance cancellation into an auditable business action.

Store at least:

- cancellation reason code/category if useful;
- required human-readable reason/comment;
- cancelled timestamp;
- cancelling user ID;
- optional previous state in the event timeline.

Requirements:

- localized confirmation form;
- non-empty bounded reason;
- resources released consistently;
- active repositioning plan expired/cancelled deliberately;
- simulator/tracking stops treating the trip as active;
- no deletion of tracking history;
- cancellation event appended transactionally;
- repeat cancellation is rejected or idempotent by documented policy;
- completed/delivered-state rules remain explicit.

Do not store localized event sentences as the canonical reason category/event code.

---

## 8. Archive and Unarchive

Archiving removes historical trips from daily operational views without changing their execution status or deleting data.

Requirements:

- only Completed or Cancelled trips may be archived;
- archive timestamp and actor user ID stored;
- archived flag/state is separate from trip execution status;
- archived trips remain available through Archived search;
- archive does not change tracking history, routes, metrics, client, or financial readiness;
- unarchive restores list visibility without changing execution status;
- tenant isolation and authorization enforced;
- stable event entries appended for archive/unarchive;
- dashboard active metrics remain correct.

---

## 9. Assignment, Reassignment, and Unassignment Before Dispatch

Support operational corrections before a truck begins repositioning.

### Allowed scope

Allow from Assigned, before dispatch activation:

- change truck;
- change driver;
- change both;
- unassign and return to Draft/planned state according to the chosen model.

Do not support changing the truck during active repositioning or cargo execution in this sprint.

### Rules

- enforce current tenant;
- resources active and available;
- unique reservation constraints;
- concurrency-safe transaction;
- expire/invalidate any Proposed repositioning plan when the truck changes or assignment is removed;
- preserve cargo route;
- clear only assignment-dependent data;
- append assignment/reassignment/unassignment events with old/new IDs in structured metadata;
- return stable conflict codes;
- Flutter shows only eligible resources and explains unavailable choices;
- require confirmation for unassignment and reassignment.

Assignment readiness must be backend-derived and checked again at mutation time.

---

## 10. Immutable Trip Event Timeline

Add a tenant-owned append-only trip event/audit entity.

At minimum capture stable event codes for:

- TripCreated;
- DraftUpdated;
- StopsUpdated;
- RouteCalculated;
- Assigned;
- Reassigned;
- Unassigned;
- DispatchedToPickup;
- ArrivedAtPickup;
- TripStarted;
- MarkedInTransit;
- Delivered;
- Completed;
- Cancelled;
- Archived;
- Unarchived.

Design requirements:

- `CompanyId` and `TripId`;
- event ID;
- stable event type/code;
- occurrence timestamp;
- actor user ID when initiated by a user;
- source such as User/System when useful;
- bounded structured metadata for meaningful old/new values;
- tenant-scoped chronological index;
- append-only behavior through normal application paths;
- no sensitive tokens/secrets;
- no localized prose as canonical storage.

### Existing trip backfill

Do not invent a detailed history that cannot be proven. For existing trips:

- create a clearly identified migration/import baseline event if necessary; or
- reconstruct only events directly supported by existing timestamps/state;
- document the decision.

### Timeline UI

Display newest-first or oldest-first consistently with:

- localized event label;
- timestamp in locale-appropriate formatting;
- actor display name when available;
- concise structured details;
- clear System actor for automated arrival events.

The API must paginate/bound timeline results if needed.

---

## 11. Trip Details Information Architecture

Reorganize details into clear sections/tabs without redesigning the whole application:

- Overview;
- Stops and cargo route;
- Truck/driver assignment;
- Dispatch to pickup;
- Cargo progress/tracking;
- Timeline;
- contextual actions.

Requirements:

- trip number prominent;
- status and archived badge;
- incomplete-Draft checklist;
- no raw GUIDs shown as primary labels;
- actions grouped and ordered by workflow;
- destructive actions visually distinct;
- confirmation dialogs for Delete, Cancel, Archive, Unassign, and Reassign;
- actions reload only required state and surface localized API errors;
- details remain usable in Arabic RTL and narrower layouts.

Do not overload one row with every possible action.

---

## 12. Duplicate Trip as Draft

Provide a useful **Duplicate as Draft** action for an existing trip.

Copy only appropriate planning data:

- client;
- cargo description;
- notes if appropriate;
- stops and coordinates;
- commercial fields according to documented policy.

Do not copy:

- trip number;
- status;
- truck/driver assignment by default;
- repositioning plan;
- execution timestamps;
- tracking history;
- archive/cancellation state;
- event history.

The duplicate receives a new trip number and Created event. Route reuse/recalculation must be a deliberate documented decision based on stop fingerprint and route snapshot semantics.

---

## 13. Limited Tracking Housekeeping

Keep this section deliberately small. Do not turn Sprint 3.4 into telemetry retention work.

### Heartbeat write rate

Sprint 3.3.1 defaults to a 15-second stationary simulator heartbeat, up to 240 rows per truck per hour while sampled. Review and reduce the Development default to a more practical rate, targeting no more than 60 persisted stationary heartbeat rows per truck per hour under normal defaults, while keeping:

- simulator trucks Current;
- offline detection coherent;
- dispatch position freshness below 300 seconds;
- production/non-simulator thresholds unchanged.

Adjust Development-only thresholds coherently rather than weakening production validation.

### Terminal/released trip association

Ensure stationary heartbeats after Completed, Cancelled, archived, or unassigned transitions do not continue indefinitely with stale trip/route/repositioning associations.

Requirements:

- current fleet position remains available;
- new idle heartbeat context becomes CurrentLocation/unassigned where appropriate;
- historical trip records remain immutable;
- no false extra travelled distance or trail;
- no deletion/rewrite of old tracking history;
- add focused tests.

Long-term retention, partitioning, and real GPS ingestion remain out of scope.

---

## API and Error-Code Requirements

Use REST shapes consistent with the repository. Exact endpoint names may follow existing conventions.

Add stable ProblemDetails error codes for new failure classes, including repository-consistent equivalents of:

- `TRIP_NOT_READY_FOR_ROUTE`;
- `TRIP_NOT_READY_FOR_ASSIGNMENT`;
- `TRIP_DELETE_NOT_ALLOWED`;
- `TRIP_CANCEL_REASON_REQUIRED`;
- `TRIP_ARCHIVE_NOT_ALLOWED`;
- `TRIP_REASSIGN_NOT_ALLOWED`;
- `TRIP_UNASSIGN_NOT_ALLOWED`;
- `TRIP_CONCURRENCY_CONFLICT`;
- existing resource availability conflicts.

Centralize Flutter localization mappings in English and Arabic.

Do not expose raw database/EF exceptions.

---

## Multi-Tenancy, Authorization, and Concurrency

Every query and mutation must remain tenant-scoped.

Add tests proving Tenant A cannot:

- search Tenant B's trip number;
- read Tenant B's list/timeline;
- delete, cancel, archive, unarchive, duplicate, assign, reassign, or unassign Tenant B's trip;
- use Tenant B's truck, driver, or client;
- observe Tenant B's counts through pagination metadata.

Authorization:

- preserve Owner/Operations management policies;
- read-only roles cannot mutate;
- actor user IDs come from authenticated context, never request payload.

Concurrency:

- use transactions and database constraints;
- protect trip-number allocation;
- protect resource reservations;
- prevent two users from assigning the same truck/driver concurrently;
- prevent lost updates to Drafts through optimistic concurrency or an equivalent documented strategy;
- return clean conflict responses.

---

## Migration and Compatibility

Create a Sprint 3.4 EF Core migration.

Requirements:

- preserve all existing trip, stop, route, repositioning, tracking, client, truck, and driver data;
- backfill trip numbers safely;
- alter Draft field nullability only as deliberately designed;
- add cancellation/archive/audit fields/entities and indexes;
- preserve status strings and existing lifecycle states;
- update filtered resource-reservation indexes only if required;
- do not invent coordinates or execution history;
- review migration SQL and model snapshot;
- apply to retained PostgreSQL volume;
- verify zero EF model drift;
- verify existing trips still render and execute correctly.

Avoid destructive table rebuilds unless justified and proven safe.

---

## Required Automated Tests

Add focused tests at domain, application, integration, and Flutter layers.

### Trip numbering

1. Numbers are unique per tenant and stable.
2. Concurrent creation cannot duplicate a number.
3. Existing trips receive deterministic unique backfills.
4. Deleting a Draft does not reuse its number.
5. Search by trip number is tenant-scoped.

### Draft and wizard backend behavior

1. Minimal Draft can be saved without stops or route provider.
2. Incomplete Draft cannot be assigned.
3. Stops can be saved separately.
4. Route calculation failure preserves Draft/stops.
5. Successful calculation stores authoritative route/fingerprint.
6. Changing a stop invalidates stale route readiness.
7. Existing executed route immutability remains enforced.
8. optimistic/concurrent Draft update behavior is deterministic.

### Delete/cancel/archive

1. Draft deletion succeeds and cleans only Draft-owned dependents.
2. Non-Draft deletion is rejected.
3. Cancellation requires a bounded reason and records actor/time/event.
4. Cancellation releases resources and stops active targeting.
5. Completed/Cancelled archive and unarchive work.
6. Invalid archive state is rejected.
7. Archive leaves routes/tracking/metrics intact.

### Assignment corrections

1. Assigned trip can change truck/driver before dispatch.
2. Reassignment invalidates a proposed repositioning plan when required.
3. Unassign returns to the designed planning state and releases reservations.
4. Active repositioning/cargo reassignment is rejected.
5. Concurrent resource assignment remains protected.

### Timeline

1. Important transitions append one correct event transactionally.
2. Automated arrival records System source.
3. User events record authenticated actor, not request-supplied ID.
4. Events are chronological, tenant-isolated, and immutable through public APIs.
5. Duplicate-as-Draft creates only new planning/Created events.

### Pagination/search/filter

1. Page boundaries, total count, stable sorting, and max page size.
2. Search fields and case-insensitive trip number.
3. Every operational tab/status group.
4. Date/client/truck/driver/archive filters.
5. No cross-tenant total-count leakage.

### Flutter

1. Tabs issue correct server queries.
2. Search is debounced and stale requests cannot overwrite newer results.
3. Pagination avoids duplicates and handles refresh/filter changes.
4. Wizard saves/resumes incomplete Draft.
5. Date/time picker produces correct UTC/local behavior.
6. Stop markers and route calculation remain correct.
7. Route failure does not lose saved fields.
8. Readiness checklist and actions match backend response.
9. Delete/Cancel/Archive/Unassign/Reassign confirmations and error handling.
10. Timeline localization and actor display.
11. English/LTR and Arabic/RTL on desktop and narrow layout.
12. Existing dispatch, map, simulator, and tracking tests remain green.

Prefer observable behavior/data assertions over tests that only verify mocks were called.

---

## Mandatory Browser Acceptance Workflow

Run a real Flutter Web workflow against the real API and PostgreSQL database using a dedicated smoke-test tenant. Do not overwrite preserved credentials or tenant records.

The workflow must prove:

1. Create a minimal Draft without selecting map stops or calculating a route.
2. Leave the wizard, reload the browser, and resume the same Draft.
3. Select pickup and delivery; confirm immediate distinct markers.
4. Save stops before route calculation.
5. Simulate or exercise a route-provider failure and prove Draft data remains.
6. Restore provider availability and calculate/persist the route.
7. Select planned date/time using the UI picker, not raw ISO text.
8. Complete readiness and assign truck/driver.
9. Reassign one resource before dispatch and verify the timeline.
10. Unassign or use a second Draft to verify unassignment and reservation release.
11. Duplicate an existing trip as a new Draft with a new trip number and no execution data.
12. Delete an unused Draft through a confirmation dialog.
13. Attempt to delete a non-Draft and prove rejection/no UI affordance.
14. Execute a trip through relevant existing stages and cancel another with a required reason.
15. Complete or use a completed trip, archive it, verify it disappears from Completed, appears in Archived, and can be unarchived.
16. Verify timeline events, actor, timestamps, and structured details.
17. Create enough trips to exercise pagination.
18. Exercise search by trip number and filters by status/date/client/truck/driver.
19. Verify active/planned/completed/cancelled/archived tabs and total counts.
20. Confirm existing dispatch-to-pickup, map tracking, and simulator behavior remain functional.
21. Verify English/LTR and Arabic/RTL.
22. Verify desktop and a narrow responsive viewport without overflow.

Retain evidence under:

`docs/evidence/sprint3_4/`

Evidence must include:

- minimal saved/resumed Draft;
- wizard steps and localized date/time picker;
- immediate pickup/delivery markers;
- route-provider failure preservation;
- trip number generation and uniqueness evidence;
- paginated/filterable list screenshots;
- reassignment/unassignment evidence;
- Draft deletion and non-Draft protection;
- cancellation reason;
- archive/unarchive;
- timeline with user/system events;
- duplicate-as-Draft comparison;
- tenant-isolation database/API evidence;
- heartbeat association/write-rate cleanup evidence;
- English, Arabic, desktop, and narrow-layout screenshots;
- concise machine-readable browser-workflow output.

Do not claim browser success if only widget tests or direct API calls were used for the primary UX workflow.

---

## Documentation Requirements

Update at least:

- `README.md`;
- `docs/architecture.md`;
- API/configuration documentation;
- `SPRINT3_4_IMPLEMENTATION_PLAN.md`.

Document:

- trip number format/allocation/backfill;
- incomplete Draft invariants and readiness;
- wizard/resume flow;
- authoritative route calculation boundary;
- list pagination/filter/status groups;
- deletion vs cancellation vs archive semantics;
- reassignment/unassignment rules;
- event timeline schema and backfill policy;
- concurrency strategy;
- heartbeat cleanup;
- migration behavior and rollback considerations;
- deferred scope.

Include a concise lifecycle/action table and data flow.

---

## Validation Requirements

Run the repository's correct equivalents of:

- .NET restore/build with zero warnings and errors under current standards;
- all backend integration tests;
- focused trip-number/draft/pagination/lifecycle/audit/concurrency tests;
- EF migration application against PostgreSQL;
- EF model/migration drift check;
- Flutter dependency resolution;
- Flutter analyzer;
- all Flutter tests;
- focused wizard/list/timeline/responsive tests;
- Flutter Web release build with required dart-defines;
- real Firefox or Chrome browser workflow;
- Docker Compose API/PostgreSQL health verification;
- live tenant-isolation and migration/backfill queries;
- existing map/tracking/simulator regression workflow.

Report exact counts. Do not suppress warnings, weaken assertions, remove tests, delete data, or skip failures to obtain a green report.

If Android cannot be built because the SDK/device is unavailable, state the exact limitation and do not claim Android passed.

---

## Acceptance Criteria

Sprint 3.4 is complete only when all applicable conditions are true:

- [ ] Every trip has an immutable tenant-unique human-readable number.
- [ ] Existing trips are deterministically backfilled without data loss.
- [ ] A minimal incomplete Draft can be saved without routing/geocoding availability.
- [ ] Draft state survives navigation and browser refresh.
- [ ] Wizard provides a clear resumable multi-step flow.
- [ ] Planned date/time uses localized pickers rather than raw ISO input.
- [ ] Stops save separately and immediate map markers remain correct.
- [ ] Route calculation is explicit, server-authoritative, and failure-safe.
- [ ] Assignment readiness is backend-derived.
- [ ] Trip list is server-paginated, searchable, sortable, and filterable.
- [ ] Active/Planned/Completed/Cancelled/Archived views are correct.
- [ ] Only eligible Drafts can be permanently deleted.
- [ ] Operational trips cannot be hard-deleted.
- [ ] Cancellation requires reason and records actor/time/event.
- [ ] Completed/Cancelled trips can be archived and unarchived without data loss.
- [ ] Assigned trips can be safely reassigned/unassigned only before dispatch.
- [ ] Timeline is immutable, localized, tenant-safe, and complete for new events.
- [ ] Duplicate as Draft creates no copied execution state.
- [ ] Resource reservation remains concurrency-safe.
- [ ] All new API errors use stable localized codes.
- [ ] Heartbeat default write rate is reduced and terminal/released associations are cleared correctly.
- [ ] Existing dispatch, tracking, route, map, and simulator behavior remains green.
- [ ] English/LTR and Arabic/RTL pass.
- [ ] Desktop and narrow responsive layouts pass.
- [ ] Backend and Flutter suites pass.
- [ ] EF migration drift is absent.
- [ ] Flutter Web release build succeeds.
- [ ] Real browser evidence covers the full management workflow.
- [ ] Documentation and actual elapsed times are complete.

Do not describe the sprint as complete if routing is still required to save a Draft, non-Draft trips can be deleted, lists still fetch every trip, or important transitions lack audit events.

---

## Explicitly Out of Scope

Do not expand Sprint 3.4 into:

- expenses, payments, receivables, or profitability;
- real GPS vendor integration;
- SignalR/WebSockets;
- production telemetry ingestion/retention platform;
- maintenance/documents;
- driver photos/avatar map markers;
- changing truck during active repositioning/cargo execution;
- multiple future trip reservations for one truck;
- advanced multi-stop planner redesign;
- recurring-trip templates;
- route optimization across vehicles;
- notifications and geofence alert delivery;
- customer portal;
- broad dashboard redesign.

Preserve the data needed by future finance and GPS sprints without implementing them now.

---

## Git and Data Safety

- Do not commit.
- Do not push.
- Do not rewrite Git history.
- Do not discard unrelated local changes.
- Do not delete PostgreSQL volumes.
- Do not overwrite existing owner credentials or tenant data.
- Use a dedicated smoke-test tenant and document it.
- Preserve `.env` unless the user explicitly requested a change.
- Leave all Sprint 3.4 changes uncommitted for review.

---

## Final Report Format

Return a concise, evidence-based report containing:

1. Baseline trip-management problems confirmed.
2. Trip-number allocation and backfill.
3. Draft/readiness and wizard design.
4. Route-calculation separation.
5. Pagination/search/filter implementation.
6. Delete/cancel/archive semantics.
7. Assignment/reassignment/unassignment behavior.
8. Event timeline and actor attribution.
9. Flutter list/details/responsive/localization changes.
10. Heartbeat cleanup.
11. Migration and compatibility results.
12. Automated test counts/results.
13. Browser workflow results.
14. Evidence paths.
15. Environment limitations.
16. Actual elapsed time per task and total.
17. Exact `git status --short` summary.

Explicitly state whether any commit or push was performed. The expected answer is that neither was performed.
