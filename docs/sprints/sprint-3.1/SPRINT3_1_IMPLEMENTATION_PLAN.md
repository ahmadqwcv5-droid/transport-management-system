# Sprint 3.1 Implementation Plan and Execution Log

Sprint 3.1 hardens map reliability and verification, completes the existing
development simulator UI, and prevents read-driven tracking-history growth.
Timestamps use UTC and elapsed values are measured from actual wall-clock work.

## Baseline Findings and Root Cause

- Baseline commit: `ce8dac7` (`feat: deliver Sprint 3 localization and tracking`).
- The worktree was clean except for the user-supplied, untracked Sprint 3.1
  prompt; it will be preserved.
- `FleetMap.styleUrl` uses `String.fromEnvironment('MAP_STYLE_URL')`, so the
  style is fixed at Flutter compile time. Docker Compose serves PostgreSQL and
  the API only; it does not inject configuration into or serve Flutter Web.
- The inspected local Flutter process was launched with only
  `--dart-define=API_BASE_URL=http://localhost:5080`; no `MAP_STYLE_URL` define
  was present. Its compile-time style was therefore empty. That missing launch
  argument—not PostgreSQL, the API, MapLibre compilation, CORS, or WebGL—was the
  exact cause of the previously missing geographic base map in this environment.
- An empty style immediately selects `offline-map-surface`. A non-empty style
  immediately creates `MapLibreMap`, but the UI has no explicit unconfigured,
  loading, loaded, failed, or fallback state and no timeout/recovery actions.
- The only positive readiness signal currently used is
  `onStyleLoadedCallback`. The package integration does not expose a reliable
  tile-rendered signal, so style readiness and visual base-map evidence must be
  reported separately.
- `sprint3_smoke_test.dart` deliberately runs without `MAP_STYLE_URL` and finds
  `truck-marker-*`, keys created only by the simplified fallback. Its earlier
  success proved tracking/fallback behavior, not MapLibre initialization or a
  visible geographic base map.
- The backend supports `step`, `speed`, per-truck `online`, and per-truck
  `offline`, but the Flutter control card exposes only start/pause/resume/stop/reset.
- `TrackingService.CurrentAsync` calls the provider and unconditionally inserts
  every returned sample. The simulator returns samples on every read even while
  paused, with a new timestamp, so dashboard/current-position polling grows
  history without a telemetry change.
- Existing tracking stores and endpoints remain tenant-filtered. Simulator
  control is Owner-only and provider registration is gated to Development or
  Testing plus explicit configuration.

## Components to Change

- Flutter dashboard map, simulator controls, configuration, ARB localizations,
  widget tests, and browser smoke tests.
- Tracking application service/store contract and integration tests.
- README, architecture ADRs, example configuration, and this execution log.
- No database schema change is expected; no migration will be created unless
  implementation reveals a genuine model change.

## Task Plan

| # | Task | Status | Started (UTC) | Finished (UTC) | Elapsed |
|---:|---|---|---|---|---:|
| 1 | Inspect Sprint 3.1 scope and establish baseline | Complete | 2026-09-17 09:12:01 | 2026-09-17 09:14:06 | 00:02:05 |
| 2 | Implement explicit reliable map state and localized recovery UX | Complete | 2026-09-17 09:14:06 | 2026-09-17 17:10:26 | 07:56:20 |
| 3 | Complete development-only simulator controls | Complete | 2026-09-17 09:14:06 | 2026-09-17 17:10:26 | 07:56:20 shared implementation window |
| 4 | Deduplicate unchanged tracking samples and add backend regression tests | Complete | 2026-09-17 09:14:06 | 2026-09-17 17:10:26 | 07:56:20 shared implementation window |
| 5 | Separate fallback, real-map, and failure/retry automated verification | Complete | 2026-09-17 17:10:26 | 2026-09-17 17:27:32 | 00:17:06 |
| 6 | Browser/manual map evidence and Compose validation | Complete | 2026-09-17 17:10:59 | 2026-09-17 17:29:28 | 00:18:29 |
| 7 | Documentation, final validation, and timing report | Complete | 2026-09-17 17:27:32 | 2026-09-17 17:32:30 | 00:04:58 |

Tasks 2–4 were implemented and debugged in one interleaved work period; their
shared wall-clock window is recorded rather than inventing unsupported per-file
stopwatch values. Tasks 5–7 also overlap where builds, browser verification,
and documentation were performed together. Total sprint wall time is therefore
measured independently and is not the sum of overlapping rows.

## Risks and Mitigations

- MapLibre may not expose style-load failures on every platform. A configurable
  timeout will provide deterministic recovery; success will only be set by the
  genuine style-loaded callback. Documentation will not equate that callback
  with proof that all tiles rendered.
- External demo tiles may be blocked, rate-limited, or affected by CORS/WebGL.
  Automated readiness tests will use a deterministic local style when practical,
  while manual evidence will record the actual browser outcome honestly.
- Rebuilding a platform view in widget tests can be brittle. Map lifecycle logic
  will be isolated behind an injectable/testable host while production still
  uses the real `MapLibreMap` callback.
- Deduplication must retain meaningful state transitions. Comparison will cover
  coordinates, online state, speed, and heading, with tests for pause, movement,
  and online/offline changes.
- Locale changes rebuild parts of the app. Map state will remain widget-local,
  keyed by configuration/attempt rather than coupled to translated strings.

## Test Plan

- Backend build, all integration tests, new row-count regression tests, tenant
  isolation, and EF pending-model check.
- Flutter dependency resolution, localization generation, formatting, analyzer,
  all tests, new explicit map-state tests, simulator-control tests, and Web
  release builds with fallback and configured map values.
- Browser smoke paths for fallback, valid MapLibre style, invalid-style timeout,
  retry/fallback, locale direction, simulator step/speed/online/offline, history
  stability/movement, and logout where supported by the environment.
- Compose rebuild/health and Android toolchain audit.

## Acceptance Checklist

- [x] Root cause documented from code and environment.
- [x] Copy-pasteable configured-map launch/build command.
- [x] Explicit unconfigured/loading/loaded/failed/fallback states.
- [x] Configurable timeout prevents silent blank map.
- [x] Localized retry and fallback recovery in English/Arabic and RTL/LTR.
- [x] Fallback clearly identified as simplified and retains details.
- [x] Real-map tests do not use fallback marker keys.
- [x] Genuine style callback drives loaded state.
- [x] Browser visual evidence reported separately from callback readiness.
- [x] All existing simulator operations exposed only in development UI.
- [x] Stationary polling adds no history rows.
- [x] Movement and state changes are persisted.
- [x] Tenant isolation remains enforced.
- [x] Backend, Flutter, Web build, EF, and Compose checks pass.
- [x] Documentation and actual timing are complete.

## Deferred Items

- Real GPS/telematics providers, SignalR, production-scale telemetry retention,
  route playback, geofencing/alerts, and non-map product expansion remain out of
  scope.
- A production map style/tile contract, SLA, and licensed hosting choice remain
  deployment concerns; the public demo style is development-only.

## Timing Summary

- Sprint start: 2026-09-17 09:12:01 UTC
- Sprint finish: 2026-09-17 17:32:30 UTC
- Total actual elapsed: 08:20:29

## Verification Record

- 2026-09-17 09:14 UTC — clean Sprint 3 baseline: .NET build succeeded
  with 0 warnings/errors, backend tests passed 13/13, Flutter analyzer was clean,
  and Flutter tests passed 8/8.
- 2026-09-17 17:10 UTC — changed implementation: .NET build succeeded with
  0 warnings/errors; all backend integration tests passed 14/14; Flutter analyzer
  reported no issues; all Flutter tests passed 11/11.
- EF Core reported `No changes have been made to the model since the last
  migration`; no empty Sprint 3.1 migration was created.
- Both fallback and configured-style Flutter Web release builds completed.
  Flutter reported the existing `flutter_secure_storage_web` WebAssembly dry-run
  incompatibility; JavaScript Web output built successfully.
- The repository Compose stack rebuilt successfully with registry access and
  both services became healthy. Its persisted demo user's old password does not
  match the current `.env` (verified 401), so it was preserved and not reset.
  Browser tests used an isolated disposable Compose database/API seeded from the
  current `.env`; both isolated services were healthy and direct login was 200.
- Firefox with GeckoDriver ran three independent browser paths: fallback
  workflow PASS; deliberately unreachable style timeout/retry/fallback PASS;
  configured MapLibre public-demo style PASS. The configured path asserted the
  real MapLibre widget, genuine style callback state, geographic annotations,
  details, and absence of fallback-only keys.
- Screenshot `build/sprint3_1_evidence/maplibre-real-map.png` is 1600x938 and was
  visually inspected: the geographic coastlines, country fill/label for Turkey,
  surrounding seas, and two green truck circles were visible. This is separate
  evidence from style-callback readiness and remains an ignored build artifact.
- The expanded live fallback run issued all nine simulator operations; API logs
  recorded nine corresponding HTTP 200 responses from 17:28:55–17:29:01 UTC.
- `StationaryPollingIsDeduplicatedWhileMovementAndStateChangesPersist` proves
  exactly 2 initial rows after start/pause, 0 additional rows for three paused
  polls, 1 row after step (3 total), and 1 row for each offline/online transition
  (4 then 5 total). Existing cross-tenant tracking coverage remains passing.
- Android validation is unavailable: `/home/pc/Android/Sdk` is absent. Firefox
  and GeckoDriver were available; Chrome/Chromium were not detected.
- Final validation after stale-attempt callback hardening: .NET build PASS with
  0 warnings/errors, backend tests PASS 14/14, Flutter format unchanged,
  analyzer clean, Flutter tests PASS 11/11, configured Web release build PASS,
  and `git diff --check` PASS. The disposable stack and its test-only volume
  were removed; the original `tms-smoke` API/PostgreSQL services remain healthy.
