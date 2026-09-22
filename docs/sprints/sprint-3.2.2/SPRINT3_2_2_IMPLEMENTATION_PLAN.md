# Sprint 3.2.2 Implementation Plan

## Objective

Make persisted tracking history trip-aware and discontinuity-safe, while keeping
reported vehicle speed physically realistic when the development simulator runs
faster than wall-clock time. Preserve Sprint 3.2.1 map stability, localization,
tenant isolation, route snapshots, and provider-neutral boundaries.

## Baseline Findings

- `TruckPosition` stores tenant, truck, telemetry, source, and time, but no trip,
  route revision, or tracking-run context.
- `TrackingService` correlates a provider sample only with a truck when it writes
  history. `TrackingTarget` already carries active trip and route revision context,
  so the application layer is the appropriate correlation boundary.
- `GET /api/tracking/trucks/{truckId}/history` returns the newest records first and
  cannot distinguish trips, route revisions, or simulator resets.
- Flutter requests that generic truck history for the selected trip and renders it
  as one green line, allowing unrelated points to be connected.
- `SimulatedTrackingProvider` correctly multiplies distance advancement by the
  multiplier, but also multiplies `TrackingSample.Speed`, so `65 km/h` becomes
  `650 km/h` at `10x`.
- Reset changes the in-memory distance but does not expose a fresh tracking-run
  discriminator to persistence.
- Sprint 3.2.1 already provides serialized latest-wins incremental annotations,
  stable truck markers, and event-only camera movement; these must be extended,
  not replaced.

## Root Cause

The persisted history schema loses the operational context already known while
polling. Consequently, a truck-scoped query cannot reconstruct which trip, route
snapshot, or continuous tracking run produced a sample. The client compensates by
drawing every recent truck point as one path. Separately, simulator acceleration
is incorrectly modeled as physical velocity instead of accelerated simulated time.

## Proposed Data Model

Add nullable `TripId` and `RoutePlanId`, plus non-null `TrackingRunId`, to new
`TruckPosition` writes. The application correlates vendor-neutral telemetry with
the active `TrackingTarget`; providers do not need to understand persistence or
trip entities. The simulator exposes a run discriminator that changes on reset and
route revision changes. Non-simulator providers can use an application-managed
stable run per truck/process until a future vendor supplies a stronger session.

Trip history will return bounded, chronological segments. Segment boundaries are
created for tracking-run changes, route-plan changes, excessive timestamp gaps,
and implausible Haversine-distance jumps. Backend segmentation is chosen so every
client receives the same deterministic safety behavior and it can be tested
without MapLibre.

## Migration and Compatibility Strategy

- Add nullable foreign keys for trip and route plan; do not backfill associations.
- Add a nullable database column for tracking run if required for legacy rows,
  while requiring a run for every new application write. Legacy null-run rows stay
  valid but cannot enter trip history because their `TripId` remains null.
- Add a tenant/trip/time index matching the bounded trip-history query and retain
  the existing tenant/truck/latest-position index.
- Use restrictive deletes for operational associations so tracking history is not
  silently removed. Review generated SQL/model snapshot and verify zero drift.

## Ordered Tasks

1. Record the baseline and add a focused regression test that fails on cross-trip
   history/current simulator speed semantics.
2. Extend the domain/application contracts, persistence model, EF configuration,
   and migration with trip/route/run context.
3. Implement tenant-validated trip history and deterministic segmentation with
   configurable limits/gap/jump thresholds.
4. Correct simulator time/multiplier/run behavior and confirm ETA remains based on
   operational physical speed.
5. Update Flutter models/repository/controller/map coordinator for independent
   stable trail segments, selection cleanup, localized legend, and visibility.
6. Add backend and Flutter coverage for isolation, ordering, segmentation,
   simulator behavior, map stability, localization, and no-history behavior.
7. Update README/architecture, apply PostgreSQL migration, run all builds/tests,
   and execute the real Flutter Web browser workflow with retained evidence.

## Acceptance Criteria

- [x] New positions persist tenant, truck, active trip, route plan, and run context.
- [x] Legacy/unassigned positions remain valid and never enter selected-trip trails.
- [x] Trip history is tenant-validated, bounded, chronological, and segmented.
- [x] Cross-trip, reset, route-revision, time-gap, and distance-jump connectors are impossible.
- [x] `1x` and `10x` report the same physical moving speed while `10x` advances faster.
- [x] Pause/resume, stop/offline, multiplier changes, and reset preserve correct semantics.
- [x] Flutter renders stable independent segments without global clears or poll camera movement.
- [x] Planned/travelled semantics and trail visibility are localized in English and Arabic.
- [x] Backend/Flutter suites, EF migration/drift, web release, Compose/API, and browser workflow pass.
- [x] Evidence is retained in `docs/evidence/sprint3_2_2/`.

## Test Strategy

- Application/integration tests exercise persistence correlation, trip isolation,
  tenant isolation, chronological results, legacy rows, completed/reused trucks,
  and all segmentation boundaries.
- Deterministic simulator tests compare equal wall-clock intervals at `1x`/`10x`,
  physical speeds, pause/resume anchoring, multiplier changes, and reset run IDs.
- Flutter repository/controller/coordinator/widget tests verify endpoint selection,
  independent stable segment IDs, no stale segment carryover, no global clearing,
  no poll camera moves, safe empty history, realistic speed, and both locales.
- Live PostgreSQL/API checks validate the migration and endpoint. A real Firefox
  Flutter Web workflow validates two trips on one truck, reset segmentation,
  `10x`, manual pan over ten polls, stable annotations, and RTL/LTR.

## Risks and Decisions

- Route geometry can legitimately contain long legs, so jump segmentation combines
  consecutive recorded points with a configurable threshold rather than mutating
  route data.
- Legacy rows cannot be safely attributed; null is deliberately preserved.
- Bounded queries fetch the newest applicable run/revision data, then normalize it
  oldest-to-newest before segmentation.
- Operational ETA remains real-world ETA derived from route distance and physical
  assumptions; the demo multiplier affects demo progress only.
- Public OpenFreeMap/OSRM availability may affect browser evidence, not domain tests.
- Android validation depends on an installed, complete SDK/device and will be
  reported as an environment limitation if unavailable.

## Elapsed Time

| Task | Started (UTC) | Finished (UTC) | Elapsed | Result |
|---|---:|---:|---:|---|
| Baseline audit, trace, and plan | 2026-09-18 10:55:47 | 2026-09-18 10:59:30 | 00:03:43 | Completed — traced provider-to-MapLibre flow and confirmed both root causes |
| Regression reproduction and backend design | 2026-09-18 10:59:30 | 2026-09-18 11:01:00 | 00:01:30 | Completed — added failing endpoint/speed regressions and selected backend segmentation |
| Backend model, migration, API, and simulator | 2026-09-18 11:01:00 | 2026-09-18 11:07:00 | 00:06:00 | Completed — added nullable context migration, tenant-safe API, segmentation, physical speed, and reset runs |
| Flutter segmented-trail integration | 2026-09-18 11:07:00 | 2026-09-18 11:10:00 | 00:03:00 | Completed — uses trip history, stable independent lines, localized legend, and trail visibility |
| Automated tests and documentation | 2026-09-18 11:10:00 | 2026-09-18 11:17:30 | 00:07:30 | Completed — added backend, repository, coordinator, widget, browser, README, architecture, and evidence coverage |
| PostgreSQL migration and browser workflow | 2026-09-18 11:17:30 | 2026-09-18 11:40:23 | 00:22:53 | Completed — migration applied with no drift; real Firefox workflow passed and retained four screenshots plus JSON |
| Resumed independent final validation | 2026-09-21 06:21:00 | 2026-09-21 06:35:16 | 00:14:16 | Completed — reran builds/tests/drift/web build, recovered Compose v1 stale containers without removing their volume, retained a read-only PostgreSQL isolation query, and refreshed the passing English/Arabic browser evidence |

Total active implementation and validation time: **00:58:52**. The user pause
between 2026-09-18 and 2026-09-21 is excluded.

## Validation Results

- `.NET restore/build`: dependency restore completed in the local and Compose
  builds; final build passed with 0 warnings and 0 errors.
- `.NET integration tests`: 27 passed, 0 failed, 0 skipped.
- EF Core drift check: `No changes have been made to the model since the last migration.`
- Live PostgreSQL migration: applied successfully on the first live run; the
  resumed API log confirms the database is already up to date.
- Flutter dependency resolution: passed; final browser run resolved the locked
  dependencies successfully.
- Flutter analyzer: no issues.
- Flutter tests: 28 passed.
- Flutter web release: built successfully. The optional Wasm dry run reports the
  existing `flutter_secure_storage_web` JS interop limitation; the JavaScript web
  build is valid.
- Docker Compose: image build succeeded from the available registry/cache. Legacy
  Compose v1 initially raised its stale-container `ContainerConfig` error; only
  the two stopped `tms-smoke` containers were recreated, preserving
  `tms-smoke_postgres_data`. PostgreSQL and API then reported healthy, and the API
  health check logged HTTP 200.
- Browser workflow: headless Firefox passed against the real Compose API and
  MapLibre map. It used `owner@sprint322.local`, a dedicated local smoke tenant,
  and did not overwrite the existing demo user's credentials. Evidence records
  approximately 1,001.6 m at 1x versus 10,013.5 m at 10x with physical speed fixed
  at 65 km/h, trip-isolated history, and multiple reset/run segments. English/LTR
  and Arabic/RTL captures both passed on the real map.
- Stable annotations: the ten-poll coordinator evidence records one initial image,
  one truck/trail addition, ten in-place truck/trail updates, zero global clears,
  and zero polling camera moves.
- Repository integrity: Dart formatting and `git diff --check` passed.

## Limitations

- Android was not built or run. `flutter doctor -v` reports
  `ANDROID_HOME=/home/pc/Android/Sdk`, but no Android SDK exists at that path, and
  no Android device is available.
- Chrome is not installed; Firefox/geckodriver provided the real browser path.
- The sandbox cannot directly connect to host port 5080, but the Compose API's
  in-container health check returned HTTP 200 and the successful Firefox workflow
  exercised the same published API before the resumed validation.

## Final Data Flow

`Provider telemetry -> application trip correlation -> persisted position context -> trip-scoped history -> ordered segments -> Flutter map annotations`

## Git Status

Sprint 3.2.2 work is intentionally uncommitted and unpushed for review, as the
prompt requires. The Sprint 3.2.2 prompt and plan are included in the working
tree. The pre-existing untracked `docs/sprints/sprint-3.1/transport_management_sprint3_1_codex_prompt.md`
is unrelated and remains untouched.
