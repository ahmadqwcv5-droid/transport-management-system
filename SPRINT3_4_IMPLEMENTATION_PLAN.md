# Sprint 3.4 Implementation Plan

## Objective

Turn trip management from a route-dependent CRUD form into a tenant-safe,
auditable operations workflow with immutable trip numbers, resumable incomplete
Drafts, explicit server-authoritative route calculation, paginated operational
views, safe lifecycle actions, and a localized event timeline.

## Baseline Findings

- Baseline is `main` at `5e68145`; `origin/main` matched after the required
  fetch on 2026-09-22. The pre-existing untracked Sprint 3.1 prompt is unrelated
  and will remain untouched. The Sprint 3.4 prompt is task input.
- `TripRequest` and the current planner require client, cargo, price, planned
  start, two stops, and an already calculated route before persistence. Route
  provider failure therefore blocks saving useful planning data.
- `TripsController` exposes a non-paginated list and the Flutter operations
  controller loads trips together with all clients, trucks, and drivers. There
  are no operational tabs, bounded search, filter metadata, or stale-request
  protection.
- Trips have only GUID identity. There is no tenant/year sequence, immutable
  display number, deterministic backfill, or number search.
- The domain has lifecycle methods but no narrowly checked Draft deletion,
  reasoned cancellation, archive state, reassignment/unassignment, duplication,
  optimistic Draft concurrency, or append-only event model.
- Existing cargo and repositioning route snapshots and trip-aware tracking are
  already immutable after activation and must remain so. Resource reservations
  are backed by PostgreSQL filtered unique indexes.
- The Development simulator heartbeat default is 15 seconds (up to 240
  stationary rows/hour), and released trips can retain stale context unless
  idle heartbeat association is explicitly normalized.

Focused baseline regression tests will be added before each corresponding fix
for minimal Draft persistence, route independence/invalidation, paginated tenant
counts, lifecycle restrictions, actor-attributed events, resource correction,
and released-heartbeat association cleanup.

## Lifecycle and Removal Semantics

Execution status stays separate from archival state. A never-executed Draft may
be permanently deleted through a dedicated checked operation. Assigned trips
may be unassigned back to Draft before dispatch. Operational trips are cancelled
with a required bounded reason and never hard-deleted. Completed and Cancelled
trips may be archived/unarchived without changing execution status or deleting
routes, tracking, or events. Activated route/repositioning snapshots, executed
stops, tracking associations, and trip number remain immutable.

## Trip Number Allocation and Backfill

- Format: `TRP-{year}-{sequence:000000}`, unique per company.
- A tenant/year `TripNumberCounter` row with a unique `(CompanyId, Year)` key is
  allocated inside the trip-creation transaction. PostgreSQL row locking/update
  plus retry on first-row races prevents duplicate allocation; `MAX + 1` is not
  used during normal creation.
- Numbers are immutable and counters never decrement, so deleted Draft numbers
  are not reused.
- Migration backfill partitions existing trips by company and derived UTC
  creation year, orders by `CreatedAt, Id`, assigns deterministic row numbers,
  and seeds each counter to the resulting maximum. The non-null unique index is
  added only after the backfill and is idempotent on subsequent deployments.

## Incomplete Draft and Readiness Design

The first Draft save requires an active tenant-visible client and a non-empty,
bounded cargo summary. Notes, price, planned time, stops, route, truck, and
driver may remain absent. Nullable persistence represents absence honestly.
Backend responses expose a readiness checklist and missing stable requirement
codes plus `canCalculateRoute`, `canAssign`, and existing dispatch readiness.
Assignment revalidates active client, business fields, both valid stops, current
matching authoritative route, and planned timing; Flutter never supplies a
trusted readiness Boolean.

Draft mutations carry a concurrency token/version. Stale edits fail with
`TRIP_CONCURRENCY_CONFLICT`, preventing silent lost updates.

## Route Calculation Boundary

Stops are saved as Draft data without a routing call. A dedicated calculate
operation validates both coordinate-bearing stops, calls the configured backend
routing port once, stores the authoritative snapshot and a deterministic stop
fingerprint, and appends an event transactionally. Any route-relevant stop
change invalidates the Draft route/readiness but leaves other Draft data intact.
Provider failure preserves all persisted Draft/stops. Activated execution data
remains immutable.

## Pagination, Search, and Filter API

Use one tenant-scoped query with validated `page`/`pageSize` (bounded maximum),
debounced free text, operational group or exact status, archive state, resource
IDs, UTC planned range, and allowlisted sort/direction. Return `items`,
`totalCount`, `page`, `pageSize`, and `totalPages`. Search covers trip number,
client, stop labels, and truck plate. Status-group membership is backend-owned:
Active = EnRouteToPickup/AtPickup/Started/InTransit/Delivered; Planned =
Draft/Assigned; Completed and Cancelled exclude archived; Archived contains
archived Completed/Cancelled. Tenant-prefixed indexes support the common paths.

## Assignment and Concurrency Design

Assignment, reassignment, and unassignment execute in transactions, derive the
tenant/actor from authentication, recheck readiness/resource availability, and
retain the filtered unique reservation indexes as the concurrency backstop.
Only Assigned trips before dispatch may be corrected. Truck change or unassign
expires Proposed repositioning data and clears assignment-dependent state while
preserving the cargo route. Events store structured old/new resource IDs. EF or
unique-index conflicts map to stable 409 codes.

## Event Timeline Design

Add tenant-owned append-only `TripEvent` rows with event ID, company/trip IDs,
stable code, UTC occurrence, nullable actor user ID, source (`User`, `System`,
or `Migration`), and bounded JSON metadata. A tenant/trip/time/index supports a
bounded paginated timeline. All important transitions append in the same unit
of work as their mutation. Automated arrival uses System; request bodies cannot
supply actor IDs. Existing trips receive one honest `ImportedBaseline` migration
event describing the known current state rather than invented history.

## Flutter State and Navigation Design

- Split trip-list state from reference-data state. A dedicated Riverpod
  controller owns the server query, debounce generation, pagination, refresh,
  and duplicate-request/stale-response protection.
- Replace the long planner with a responsive persisted wizard: Basics, Stops,
  Schedule/Commercial, Route, Assignment, Review. Explicit Save Draft is
  available early; reopening `/trips/{id}/edit` restores persisted values and
  map markers. Material localized date/time pickers replace raw ISO entry.
- Details present Overview, Stops/route, Assignment, Dispatch, Tracking,
  Timeline, and contextual actions. Confirmation forms/dialogs cover every
  destructive or resource-changing action. Stable error codes map centrally to
  English/Arabic strings.

## Migration and Compatibility Strategy

Create one reviewed Sprint 3.4 EF migration that adds number/counter, nullable
Draft fields, route fingerprint/version, cancellation/archive/concurrency data,
and trip events/indexes. Backfill numbers and baseline events without inventing
coordinates or execution history. Preserve current statuses, routes, tracking,
repositioning, and reservation indexes. Apply to the retained PostgreSQL volume,
inspect generated SQL/snapshot, and verify no pending model changes. Rollback
must remove only Sprint 3.4 schema additions; operators must understand that
rolling back after new incomplete Drafts exist is data-incompatible.

## Ordered Tasks

1. Finish architecture/database/UI trace, capture baseline evidence, and add
   focused regression tests for confirmed gaps.
2. Implement domain/persistence model, number allocation/backfill, readiness,
   event append, concurrency fields, and Sprint 3.4 migration.
3. Implement Draft/stops/route endpoints and lifecycle operations: delete,
   cancellation reason, archive/unarchive, assign/reassign/unassign, duplicate.
4. Implement paginated/searchable/filterable list and bounded event timeline,
   including tenant isolation and indexes.
5. Implement Flutter trip-list state/tabs/filters/pagination and responsive
   resumable wizard with localized date/time and explicit route calculation.
6. Reorganize details/actions/timeline, add English/Arabic localization, and
   preserve existing dispatch/map/tracking flows.
7. Reduce Development heartbeat rate coherently and clear released/terminal
   association for future idle heartbeats, with focused regression tests.
8. Generate/apply/review migration, run all automated/build/drift checks, update
   documentation, and execute the real browser/PostgreSQL evidence workflow.

## Automated and Browser Test Strategy

Backend tests cover concurrent numbering, deterministic migration behavior,
minimal Draft and route failure/invalidation, concurrency conflict, all lifecycle
and assignment rules, event actor/source/tenant isolation, pagination/search/
filters/count isolation, reservation conflicts, and heartbeat cleanup. Flutter
tests cover query generation/debounce/pagination, wizard resume/pickers/route
failure, markers/readiness, contextual confirmations/timeline, EN/AR, and narrow
layout. The required real Firefox workflow uses a dedicated Sprint 3.4 tenant,
real API/PostgreSQL, visible UI interactions for the primary workflow, and stores
screenshots plus machine-readable/database evidence under
`docs/evidence/sprint3_4/`.

## Risks and Explicit Decisions

- The scope crosses schema, API, and substantial Flutter UI; changes will be
  delivered in vertical increments with full regression runs at milestones.
- Public OSRM/OpenFreeMap availability can affect live evidence. Failure safety
  is tested deterministically, while browser success is claimed only for real UI
  steps actually exercised.
- `CreatedAt` is the deterministic displayed-year source for backfill. New trip
  numbers use the server UTC creation year.
- Duplicate-as-Draft copies client, cargo, notes, stops, planned time, and price,
  but no assignment/execution/history/archive/cancellation data. Route is not
  copied; it must be recalculated to establish a new authoritative snapshot.
- Cancellation is rejected when already terminal and is non-idempotent to avoid
  masking repeated user actions. Archive/unarchive are explicit state changes.
- Development stationary heartbeat target is 60 seconds (at most 60/hour), kept
  below the 300-second dispatch freshness policy; production defaults are not
  weakened.
- Finance, real GPS, telemetry retention, notifications, and active-execution
  vehicle changes remain deferred.

## Elapsed Time

The sprint ran in two work windows separated by an IDE/user pause. The initial
start was recorded before implementation. Some intermediate rows were not
updated before that interruption, so their checkpoint times below come from
the corresponding file timestamps/command logs and are labeled as wall time.
No invented active-time breakdown is substituted for the missing live entries.

| Task | Started (UTC) | Finished (UTC) | Elapsed | Status | Result |
|---|---:|---:|---:|---|---|
| Baseline fetch, architecture trace, evidence, plan, and regression tests | 2026-09-22 04:29:31 | 2026-09-22 04:35:15 | 00:05:44 wall | Complete | Baseline at `5e68145`; plan and first domain files mark the boundary |
| Backend domain, persistence, migration, readiness, and lifecycle | 2026-09-22 04:35:15 | 2026-09-22 04:55:43 | 00:20:28 wall | Complete | Numbering, nullable Drafts, optimistic versioning, checked lifecycle operations, migration |
| Paginated query and timeline API | 2026-09-22 04:48:39 | 2026-09-22 05:00:04 | 00:11:25 wall | Complete | Interleaved with backend work; bounded query/search/filter/sort and timeline |
| Flutter list, wizard, details, timeline, and localization | 2026-09-22 05:00:04 | 2026-09-22 10:12:29 | 05:12:25 wall | Complete | Includes the interruption; initial UI plus resumed individual-fetch/localization hardening |
| Heartbeat cleanup and focused regressions | 2026-09-22 04:55:43 | 2026-09-22 04:57:49 | 00:02:06 wall | Complete | 60-second Development default and idle association normalization |
| Full validation, Compose/PostgreSQL, browser evidence, and documentation | 2026-09-22 05:15:00 | 2026-09-22 10:23:26 | 05:08:26 wall | Partially complete | Includes the interruption; automated suites/drift/release/docs and live PostgreSQL passed; full authenticated browser workflow remains incomplete |
| Live PostgreSQL integration correction | 2026-09-22 10:46:40 | 2026-09-22 10:54:03 | 00:07:23 wall | Complete | Reproduced relational allocator failure, replaced composed `SqlQuery` with parameterized atomic scalar command, corrected Flutter error labeling, rebuilt healthy API |
| PostgreSQL first-stop concurrency correction | 2026-09-22 11:10:50 | 2026-09-22 11:33:41 | 00:22:51 wall | Complete | Traced the UI's `409` to new GUID-keyed stops being inferred as `Modified`; explicitly registered replacement rows as inserts, retained a created Draft for safe retry, added regression coverage, verified a rolled-back real PostgreSQL save, and rebuilt a healthy API |

Total wall-clock sprint span through the integration corrections: **07:04:10**
(2026-09-22 04:29:31–11:33:41 UTC). Exact active time cannot be recovered
honestly after the interruption because live timing was not persisted for every
row; the overlapping wall spans above are not summed or mislabeled as active.

## Final Validation Record

- .NET solution: build passed, 0 warnings, 0 errors.
- Backend integration tests: 46 passed, 0 failed, 0 skipped.
- EF model drift: none.
- Flutter analyzer: no issues.
- Flutter tests: 36 passed, 0 failed, 0 skipped.
- Flutter Web release build: passed. The dependency's WebAssembly dry run notes
  that `flutter_secure_storage_web` still uses legacy `dart:html`; the standard
  JavaScript web build is successful.
- Docker Compose/PostgreSQL: subsequently available and healthy after the user
  started the stack. The Sprint 3.4 migration is applied; all 70 retained trips
  have non-null tenant-unique numbers and 70 honest baseline events. Public OSRM
  returns a route from inside the API container. The primary authenticated
  Firefox workflow remains incomplete.
- Android: not built. `flutter doctor -v` reports
  `ANDROID_HOME=/home/pc/Android/Sdk`, but no SDK exists there and no Android
  device is available.
- Evidence index: `docs/evidence/sprint3_4/README.md`. No browser screenshots
  were fabricated from widget tests.

## Post-implementation Integration Fixes

- Replaced EF composition over PostgreSQL `INSERT ... RETURNING` in the trip
  number allocator with a parameterized scalar command. This fixed the live
  `POST /api/trips` failure while preserving atomic tenant/year allocation.
- Corrected the planner's error presentation so API failures are localized by
  their stable error code instead of every save failure appearing to be a
  routing-provider failure.
- Fixed the live first-stop false concurrency conflict. New GUID-keyed
  `TripStop` entities discovered through an existing aggregate were inferred by
  EF as `Modified`; the application store now explicitly registers replacement
  stop rows as `Added` before saving.
- Retained the newly created Draft in planner state before saving stops. If a
  later request fails, retry updates that Draft instead of creating another
  empty trip.
- Added create-minimal-Draft then save-first-stops regression coverage. The
  final verification record is 46 backend tests, 36 Flutter tests, clean
  Flutter analysis, a successful rolled-back PostgreSQL persistence probe, and
  healthy API/PostgreSQL Compose services.

Real PostgreSQL verification and the user-driven browser workflow both exposed
and confirmed fixes for integration-only defects. The complete scripted browser
acceptance workflow still could not be run with the preserved owner's unknown
password, so Sprint 3.4 is ready for review but is not described as fully
acceptance-complete.

## Git and Data Safety

Commit and push are performed only after the user's explicit request. `.env`,
preserved owner credentials, retained PostgreSQL volumes, and the unrelated
Sprint 3.1 prompt remain excluded. The Sprint 3.4 prompt, implementation plan,
source, migration, tests, documentation, and non-secret `.env.example` changes
belong to the Sprint 3.4 commit.
