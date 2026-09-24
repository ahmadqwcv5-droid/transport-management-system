# Sprint 4.1 Implementation Plan and Execution Log

## Objective

Connect trusted tracking, stable pickup/delivery geofences, persisted
notifications, linked-driver confirmations, secure truck photos, explicit fleet
map camera modes, and the simulator into one tenant-safe live-operations flow.

## Baseline

- Branch: `main`.
- Local and remote starting commit:
  `55d3c1ee627b6010f08d382118016a899f443298`.
- Worktree before organization contained only the user-provided Sprint 4.1
  prompt; it is preserved beside this plan.
- Latest GitHub `quality-gate` for the baseline is successful:
  <https://github.com/ahmadqwcv5-droid/transport-management-system/actions/runs/36019742336>.
- Untouched local baseline: zero-warning backend build, 11 architecture tests,
  52 integration tests, clean Flutter formatting/analyzer, 40 Flutter tests,
  and release Web build.
- Retained `.env`, credentials, PostgreSQL container/volume, prior migrations,
  and unrelated user data must remain unchanged.

## Existing State-Machine Analysis

The persisted lifecycle is `Draft -> Assigned -> EnRouteToPickup -> AtPickup ->
Started -> InTransit -> Delivered -> Completed`, plus `Cancelled`. Dispatch can
mark immediate pickup arrival; tracking currently evaluates a single accepted
sample for pickup arrival. `Started` begins cargo simulation, `Delivered` keeps
resources reserved, and `Complete` releases the driver. Truck operational state
is derived from reserving trip states. Existing UI exposes each legacy step.

The fleet map has selection, one-shot route fitting, manual-pan protection, and
incremental latest-wins annotation updates, but no explicit follow state.
Simulator state is process-local while persisted telemetry allows route-position
restoration after restart. Users and drivers are independent tenant entities.

## Target Lifecycle and Compatibility

Canonical new behavior is:

```text
Draft -> Assigned -> EnRouteToPickup -> AtPickup
      -> InTransit -> AtDelivery -> Completed
```

- `AtDelivery` is a new persisted state and reserving state.
- `Confirm loaded` moves `AtPickup` directly to `InTransit` and writes
  `ActualStartAt`, actor/source audit, events, and a notification atomically.
- `Confirm delivery` moves `AtDelivery` directly to `Completed`, writes arrival,
  delivery and completion timestamps, releases the driver reservation, and
  stops simulator targeting atomically.
- Historical `Started` and `Delivered` remain persisted and readable.
  Legacy `/start`, `/mark-in-transit`, `/deliver`, and `/complete` endpoints
  remain manager-authorized compatibility commands. Started can continue to
  InTransit; Delivered can complete. No historical timestamp is rewritten or
  invented. Flutter renders Started as legacy cargo-start and Delivered as
  legacy awaiting completion; all new flows use the canonical states and two
  commands.

## Geofence Algorithm and Persistence

- Add tenant-owned `TripGeofenceObservation`, unique by company, trip, stop
  stage, and route revision. It records first qualifying time, last qualifying
  sample/time, consecutive count, and completion time.
- Evaluate only accepted online samples belonging to the assigned truck.
- Defaults: arrival radius 50 m, exit radius 80 m, two qualifying samples,
  minimum dwell 20 seconds, maximum sample age 60 seconds. Values are bounded
  configuration, not Domain constants.
- Inside arrival radius advances evidence; outside exit radius resets it; the
  hysteresis band preserves current evidence. Evaluation consumes timestamps
  supplied by deterministic clocks/tests and requires no sleeps.
- A transaction updates observation, trip state, repositioning state, events,
  and notification. Unique event keys plus optimistic trip concurrency make
  retries/concurrent samples idempotent. Queries remain bounded.

## Notification Design

- Add tenant-owned `OperationNotification` with stable type/severity, optional
  trip/truck/driver IDs, bounded JSON data, unique tenant event key, UTC created
  time, and read actor/time.
- Mandatory keys use event type + trip ID + lifecycle/route revision so pickup,
  delivery, driver departure, and driver delivery each persist once.
- Owner/Operations receive the company bounded feed and unread count. A Driver
  receives only notifications whose DriverId matches their linked driver.
- Focused list/count/read/mark-visible-read endpoints use polling. Flutter
  localizes from type/payload and never stores localized source text.

## Driver Identity and Authorization

- Add nullable `Driver.UserId` with tenant-scoped one-to-one uniqueness and an
  explicit `Driver` role. Owner-only link/unlink endpoints validate tenant,
  uniqueness, and user role. No registration or automatic linking is added.
- Named policies separate operational management, driver workflow, notification
  access, photo read, and owner-only linking.
- Driver endpoints resolve the authenticated user to exactly one same-tenant
  driver and expose only their current assigned trip, minimum stop/truck/route
  data, and allowed confirmations. Company lists, dashboard, simulator, map,
  and other trips remain backend-forbidden.

## Truck Photo Storage and Security

- Add one `TruckPhoto` metadata row per truck and application-owned
  `ITruckPhotoStorage`; local durable storage is an Infrastructure adapter and
  Compose-mounted directory. Storage keys are generated server-side.
- Use SkiaSharp (MIT) to decode actual JPEG/PNG/WebP bytes, enforce a 5 MB
  upload limit and bounded dimensions/pixels, strip metadata by re-encoding,
  and produce detail and 192 px WebP thumbnail variants. SVG and unknown or
  invalid signatures are rejected.
- Authenticated tenant-scoped upload/read/remove endpoints return ETag/photo
  version. Database replacement commits before best-effort old-file cleanup;
  failed database updates remove newly written files. No public directory or
  user filesystem path is exposed.

## Fleet-Map Camera State

- Add explicit `Free`, `FollowSelectedTruck`, and `RouteOverview` modes to the
  platform-neutral coordinator.
- Selection enters Follow at local zoom 14.5 with panel padding. Only accepted
  selected-truck position changes may move the camera in Follow.
- Gesture callbacks pause follow using a programmatic-camera guard; a visible
  Resume Follow control restores it.
- Show Full Route fits once, enters RouteOverview, and polling performs zero
  camera fits there. Back to Truck resumes Follow. Clear returns to Free.
- Photo identities are `truck-photo:{truckId}:{version}`; authenticated bytes
  are cached/registered once per style generation and failure immediately uses
  the existing icon. Obsolete versions are bounded and normal polling never
  globally clears annotations.

## Migration and Rollback

One new migration will add `AtDelivery`-compatible reservation indexes,
delivery-arrival/audit fields, Driver/User link, truck-photo metadata,
notifications, and geofence observations. It will not update historical status
or invent timestamps, links, photos, confirmations, or notification rows.

Rollback removes only Sprint 4.1 metadata/tables/columns and restores prior
reservation-index predicates. Physical photo files are deployment artifacts;
rollback leaves them for explicit safe cleanup rather than risking deletion of
referenced data during migration.

## Mutation and Automatic Refresh Matrix

| Event | Trips/details | Truck/client | Dashboard/map | Driver My Trip | Notifications/options |
|---|---:|---:|---:|---:|---:|
| Pickup/delivery geofence | Poll + invalidate | Reload | Poll projection | Poll | Reload/count |
| Driver departure/delivery | Reload/regroup | Reload | Reload | Reload | Reload; options on release |
| Manager override | Reload/regroup | Reload | Reload | Reload | Reload |
| Photo replace/remove | — | List/detail reload | Marker/card version reload | Truck reload | Options reload |
| Notification read | — | — | — | — | List/count reload |

Generation guards preserve filters, selected truck, and camera mode while stale
responses cannot replace newer mutation or polling state. Polling is focused and
coalesced to avoid request storms.

## Automated and Browser Test Plan

- Domain/integration: canonical/legacy transitions, atomic release, stable error
  codes, jitter/dwell/hysteresis/stale/restart/concurrency/tenant geofences,
  notification dedup/read/isolation, user-driver uniqueness/authorization,
  override audit, photo validation/storage/isolation/replacement, and map-safe
  projections.
- Flutter: notification center/badge, Driver Mode/actions, manager overrides,
  photo/fallback rendering and versioned loader, marker registration, explicit
  camera modes/telemetry/manual gesture guard, refresh, RTL/LTR.
- Real Firefox: dedicated manager and linked-driver accounts, secure photo,
  follow/manual-pan/route-overview poll sequences, stable pickup and delivery
  geofences, both driver confirmations, override/isolation, notifications,
  release, English/Arabic, and logout. Evidence goes to
  `docs/evidence/sprint4_1/`.

## Risks and Known Limitations

- Local photo storage is single-node durable storage; object storage is a future
  adapter. Files and database changes cannot share one transaction, so recovery
  and cleanup paths are explicit and tested.
- Polling is intentionally used instead of push; changes may appear within the
  configured interval.
- Accuracy filtering applies only when a trusted provider supplies accuracy;
  current telemetry lacks that field.
- Browser synthetic gestures and authenticated map images require adapter tests
  plus real Firefox evidence.
- Android is validated only if a usable SDK and device/emulator exist.

## Delivery Sequence

1. Baseline, plan, lifecycle/geofence/notification/identity/photo design.
2. Domain, focused Application services/ports, Infrastructure, APIs, migration.
3. Backend security, concurrency, compatibility, and integration tests.
4. Flutter notifications, Driver Mode, photo UI/loader/marker, camera modes.
5. Flutter tests, localization, simulator and refresh integration.
6. Retained PostgreSQL/Compose, Firefox acceptance, documentation, evidence,
   final timing and changed-file summary.

## Task Timing (Active UTC Time)

Timings are updated at task boundaries; user pauses are excluded.

| Task | Started (UTC) | Finished (UTC) | Active elapsed | Status | Result |
|---|---:|---:|---:|---|---|
| Baseline fetch, required reading, CI verification, inventory, untouched quality gate | 2026-09-24 16:39:12 | 2026-09-24 16:42:10 | 00:02:58 | Complete | Baseline commit and green GitHub run verified; 63 backend and 40 Flutter tests plus release Web build pass |
| Plan and detailed technical design | 2026-09-24 16:42:10 | 2026-09-24 16:43:11 | 00:01:01 | Complete | Lifecycle compatibility, persisted geofence evidence, notification deduplication, driver boundary, secure photo storage, camera modes, migration, refresh, and tests designed |
| Backend lifecycle, geofence, notifications, driver authorization, photo storage, migration | 2026-09-24 16:43:11 | 2026-09-24 19:12:00 | 02:28:49 | Complete | Canonical lifecycle, persisted stable geofences, tenant notifications, linked-driver authorization, manager overrides, secure durable WebP photo pipeline, simulator integration, and one migration implemented; final suite has 66 backend tests |
| Flutter Driver Mode, notifications, photo UI/markers, camera modes, refresh | 2026-09-24 19:12:00 | 2026-09-24 20:34:23 | 01:22:23 | Complete | Role-aware Driver Mode, localized notification center/badge, authenticated photos, upright photo markers, explicit camera modes, lifecycle actions, and refresh coordination implemented; analyzer and 41 Flutter tests passed |
| Automated tests, retained PostgreSQL/Compose, browser evidence, docs, final audit | 2026-09-24 20:34:23 | 2026-09-24 22:02:05 | 01:27:42 | Complete | 66 backend and 41 Flutter tests pass; format/analyzer, zero-warning Release build, release Web build, EF drift, retained Compose health, migration, Firefox evidence, RTL/LTR, and logout verified; Android unavailable because no SDK/device exists |

## Final Changed-File Summary

- Domain/Application/API: canonical `AtDelivery` lifecycle, stable geofence
  evidence, operation notifications, linked-driver workflow, manager overrides,
  secure truck-photo contracts/services, and focused authorization endpoints.
- Infrastructure/schema: one Sprint 4.1 migration and snapshot, tenant filters
  and indexes, focused live-operation/photo stores, SkiaSharp processing, and
  durable Compose photo storage with non-root ownership.
- Flutter: Driver Mode, My Trip confirmations, localized notification center and
  unread badge, authenticated truck-photo UI/markers, accessible fleet selector,
  explicit map camera modes, lifecycle/override actions, and focused refresh.
- Tests/evidence/docs: manager/driver/geofence/photo/isolation integration
  coverage, 10-update camera coordinator evidence, a passing real-Firefox
  workflow with 16 screenshots/JSON, ADR-026, README run instructions, and this
  completed timing log.

The completed implementation contained 92 changed/untracked paths (67
tracked-file diffs, plus new Sprint 4.1 source, migration, tests, prompt/plan,
and evidence). It was initially left uncommitted as required by the Sprint 4.1
brief; the user's later explicit instruction authorized committing and pushing
the completed work.
