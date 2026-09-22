# Sprint 3.2 Implementation Plan and Execution Log

Sprint 3.2 replaces the fixed-line tracking demonstration with tenant-scoped,
route-aware trip planning, stored route snapshots, geometry-based progress, and
route-driven simulation. Timestamps use UTC; elapsed values are recorded from
actual wall-clock execution, not estimates.

## Repository Baseline

- Started: 2026-09-17 18:11:41 UTC.
- Actual HEAD: `81571c14c6fb93be633e15e7807bc15306850542`
  (`feat: harden Sprint 3 map and tracking`), matching the prepared baseline.
- Working tree: clean tracked state; only the user-supplied Sprint 3.1 and 3.2
  prompt files were untracked. They are unrelated inputs and will be preserved.
- No `AGENTS.md` exists in the repository.

## Confirmed Limitations

- `Trip` stores `Origin` and `Destination` as required text only. There are no
  coordinates, ordered stops, planned geometry, route provider metadata, or
  route revision.
- The create/edit experience is a 520-pixel modal with two text fields; it has
  no search, map selection, route preview, distance, or duration.
- `SimulatedTrackingProvider.GetCurrent` increments one company-wide integer on
  every read. Poll frequency therefore controls movement, simultaneous reads
  accelerate it, and all trucks are offset along the same Ankara–Istanbul chord.
- Current map annotations are circles. The UI has no selected trip route,
  travelled trail, progress/ETA, synchronized fleet list/filter, directional
  truck icon, or route-aware camera bounds.
- Planned and actual geometry are not represented separately because planned
  geometry does not exist. Existing history is tenant-filtered and bounded at
  query time, but is unrelated to a trip plan.

## Proposed Domain Model and Rationale

- `TripStop`: tenant-owned ordered child with sequence, `Pickup`/`Delivery`/
  future `Waypoint` type, label/address, nullable coordinates for legacy
  compatibility, and optional planning fields. New route-aware writes require
  exactly one sequenced pickup and delivery with valid, distinct coordinates.
- `TripRoutePlan`: tenant-owned one-to-one trip snapshot containing normalized
  GeoJSON LineString geometry, format/version, distance, duration, provider,
  general-driving profile, calculation time, and stops fingerprint/revision.
- `Trip` remains the aggregate root and the authoritative write path. Draft
  updates replace stops and route atomically. Assignment freezes planning;
  assigned/started/later trips cannot be replanned in this sprint.
- Legacy `Origin`/`Destination` columns remain readable compatibility labels.
  Route-aware writes derive them from structured stops; they are no longer an
  independent UI write path.

## Migration and Backfill Strategy

- Add `trip_stops` and `trip_route_plans` with explicit tenant columns, foreign
  keys, indexes, precision, and uniqueness for trip sequence/one route plan.
- Backfill two label-only stops for every existing trip using its preserved
  origin/destination. Coordinates remain null; no positions are invented.
- Legacy trips remain readable and are marked as requiring geographic planning.
  Only Draft legacy trips can be upgraded through the planner.
- The migration is reversible by dropping the new tables; legacy columns and
  existing tracking history remain untouched.

## Provider Strategy

- Application owns `IGeocodingProvider`, `IRoutingProvider`, coordinates,
  provider results, profiles, and deterministic failure codes.
- Infrastructure provides unconfigured adapters, an optional policy-conscious
  Nominatim HTTP adapter, an OSRM-compatible driving adapter, and deterministic
  fake adapters in Testing. Provider URLs/identification/timeouts stay in server
  configuration. Flutter never receives credentials or vendor payloads.
- Route calculation is cached by normalized ordered-stop/profile fingerprint.
  Preview and immediate save reuse the result; map render and tracking polls do
  not call providers.
- The development OSRM public demo is general driving only, is never described
  as HGV-aware, and is not production infrastructure.

## UI Flow and Wire Description

- `/trips/new` and `/trips/:id/edit` use a responsive full-page planner. Wide
  screens show a form/search/summary pane beside the map; narrow screens stack
  them. Pickup and delivery can be selected from a configured search result or
  by activating a stop and tapping the map.
- Route preview is explicit and shows provider/profile limitation, blue road
  geometry, distance, duration, pickup/delivery markers, loading, and stable
  localized errors. Save is disabled until a valid preview exists.
- Dashboard keeps Sprint 3.1 lifecycle states and adds one directional truck
  symbol per current truck, state shape/label plus color, selection halo,
  filters/list, route/trail overlays only for the selected trip, a legend, and
  progress/remaining/ETA/off-route details.

## Task Breakdown

| # | Task | Status | Started (UTC) | Finished (UTC) | Elapsed |
|---:|---|---|---|---|---:|
| 1 | Inspect prompt, referenced product patterns, repository, and baseline | Complete | 2026-09-17 18:11:41 | 2026-09-17 18:14:01 | 00:02:20 |
| 2 | Add route domain model, geometry/progress logic, providers, APIs, and migration | Complete | 2026-09-17 18:14:01 | 2026-09-17 18:26:30 | 00:12:29 |
| 3 | Redesign simulator for elapsed-time route movement and observational reads | Complete | 2026-09-17 18:19:30 | 2026-09-17 18:27:00 | 00:07:30 |
| 4 | Build responsive Flutter planner and route-selection workflow | Complete | 2026-09-17 18:29:00 | 2026-09-17 18:44:00 | 00:15:00 |
| 5 | Upgrade fleet map, selection, route/trail/progress, filters, and localization | Complete | 2026-09-17 18:36:00 | 2026-09-17 18:45:00 | 00:09:00 |
| 6 | Add backend/Flutter/integration coverage and resolve regressions | Complete | 2026-09-17 18:24:00 | 2026-09-17 22:25:50 | 04:01:50 |
| 7 | Compose/browser visual evidence and platform validation | Complete | 2026-09-17 18:45:00 | 2026-09-17 22:25:50 | 03:40:50 |
| 8 | Documentation, final audit, timing, and report | Complete | 2026-09-17 22:25:50 | 2026-09-17 22:38:40 | 00:12:50 |

Tasks 2–7 overlap where implementation and validation ran concurrently; their
elapsed values are wall-clock spans per workstream and are not additive.

## Risks and Mitigations

- Provider/network instability: deterministic Testing adapters cover automation;
  public services are used only for explicitly labeled development evidence.
- Coordinate-order bugs: normalize OSRM longitude/latitude at the adapter and
  test it with asymmetric coordinates.
- Geometry payload/CPU growth: validate point counts, use bounded history, cache
  duplicate previews, and calculate progress in memory only for selected/current
  fleet scale.
- Read-driven movement: simulator position is a pure function of saved anchor,
  elapsed clock time, speed, and route; only commands mutate simulator state.
- Legacy compatibility: nullable coordinates only for migration-created stops;
  route-aware request validators reject them.
- Map platform-view tests: isolate map callbacks/builders and assert application
  layers independently; browser evidence proves actual rendering separately.

## Test Plan

- Domain/geometry: coordinate and stop validation, GeoJSON normalization,
  distance/projection/progress/clamping/remaining/ETA/off-route, interpolation,
  heading, arrival.
- Backend integration: fake search/preview, route-aware create/update/read,
  route immutability, legacy readability, role/tenant isolation, route simulator,
  idempotent reads, pause/resume/reset, distinct routes, progress and history.
- Flutter: planner validation/map selection/search cancellation/preview states,
  route layer data, legacy state, RTL/LTR, marker heading/selection, filters,
  planned-versus-actual overlays, provider unavailable.
- Full build/migration: .NET restore/build/tests, migration application and drift,
  localization generation/format/analyze/tests, Web release, Compose health,
  Android only when a valid SDK exists.
- Browser: full Arabic-to-English route-aware workflow with five required
  screenshots and recorded numeric simulator evidence.

## Acceptance Checklist

- [x] Structured tenant-owned stops and immutable stored route snapshot.
- [x] Legacy trips readable with no invented coordinates.
- [x] Backend geocoding/routing abstractions and safe configured adapters.
- [x] Manual map selection and configured search selection.
- [x] Real road-following preview with distance/duration/provider limitation.
- [x] Geometry-based progress, remaining distance, ETA, phase, and off-route.
- [x] Poll-independent, route-aware simulator with deterministic controls.
- [x] One directional state-distinct marker per truck and selected route/trail.
- [x] Fleet filters and synchronized row/marker selection.
- [x] Complete English/LTR and Arabic/RTL localization.
- [x] Tenant/security/provider failure coverage.
- [x] Migration, backend, Flutter, Web, Compose, and browser validation.
- [x] Screenshot and numeric simulator evidence.
- [x] Documentation and actual timing complete.

## Deferred Work

HGV restrictions, traffic/rerouting, route/stop optimization, driver navigation,
customer links, proof of delivery, templates/import, multi-stop UI, GPS vendors,
SignalR, geofence alerts, maintenance/documents, and high-volume telemetry
retention remain explicitly out of scope.

## Timing Summary

- Sprint start: 2026-09-17 18:11:41 UTC
- Sprint finish: 2026-09-17 22:38:40 UTC
- Total actual elapsed: 04:26:59

## Verification Record

- .NET build: succeeded with zero warnings/errors.
- Backend integration suite: 20/20 passed, including route math, coordinate
  order, simulator idempotency/pause/step/reset, legacy readability, route
  immutability, progress movement, and cross-tenant route/trail isolation.
- Flutter: generated localization, `flutter analyze` clean, 11/11 widget tests
  passed, and Web release output produced.
- Compose: registry/build access available; both PostgreSQL and API healthy.
  Migration applied on an existing volume (six legacy stops, zero invented route
  plans) and on a fresh volume.
- Live provider: OSRM returned a 5,253-point Ankara–Istanbul route of about
  440 km. Initial .NET requests received HTTP 403; adding the configurable
  identifying User-Agent fixed the integration and live trip save succeeded.
- Browser: headless Firefox completed the full route-aware workflow with real
  MapLibre tiles and five evidence screenshots under
  `apps/transport_management_app/build/sprint3_2_evidence/`.
- Android: not built or run. `flutter doctor -v` reports the configured
  `/home/pc/Android/Sdk` does not exist; the repository-local SDK folder lacks
  platform/build tools and no Android device is available.
