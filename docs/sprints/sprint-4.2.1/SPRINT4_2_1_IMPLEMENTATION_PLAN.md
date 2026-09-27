# Sprint 4.2.1 Implementation Plan

## Baseline

- Started: `2026-09-26 23:58:29 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `98a070f` (`feat(operations): add sprint 4.2 control center`), synchronized with `origin/main`.
- Initial worktree: clean except for the user-provided untracked Sprint 4.2.1 prompt.
- Safety boundary: do not edit `.env`, retained PostgreSQL data, credentials, or Docker volumes. Do not commit or push.
- Existing architecture: Flutter polling, MapLibre/OpenFreeMap, immutable notification JSON snapshots, tenant query filters, and Driver-owned lifecycle commands remain authoritative.

## Baseline findings and defects to reproduce

These are initial hypotheses from source discovery and must be confirmed by call-path tracing and tests before a fix is accepted.

1. Map lifecycle: `FleetMap` keys renderer attempts while overlay synchronization and style state are coordinated separately; conditional parents and broad error propagation may incorrectly replace a usable platform view or promote an annotation failure to a fatal map failure.
2. Arabic labels: the Dart package is `maplibre_gl ^0.27.1`; the actual injected Web JS renderer, style glyph endpoint, font stacks, and bidi/shaping behavior still require browser/runtime verification.
3. Notifications: Sprint 4.2 snapshot rendering exists, but event coverage, location/time fields, prominent alert copy, sound deduplication, and legacy fallback require end-to-end auditing.
4. Driver details: assignment notification and workspace summary may not expose the complete client/truck/cargo/stops/schedule/distance/duration context.
5. Assignment: planner and existing-trip dialog use separate selection state, risking policy drift and first-item fallback.
6. Localization: newly added active-operation/default-driver strings include hardcoded English.
7. Query shape: `ActiveOperationsService` composes broad store reads in memory; tenant scoping exists, but status filtering/projection must move into a bounded database query.

## Chosen design and rejected alternatives

- Preserve one MapLibre platform view and separate renderer/style fatal state from recoverable overlay synchronization. Reject remounting the map on route/phase changes and reject global annotation clears.
- Verify the real Web renderer before selecting built-in shaping, compatible RTL support, or a documented Latin fallback. Reject manual Arabic reversal and Flutter `Directionality` workarounds.
- Extend immutable language-neutral snapshot payloads and localize them in Flutter. Reject reconstructing historical messages from mutable entities.
- Centralize assignment recommendation/eligibility behavior while retaining backend submission-time validation. Reject arbitrary first-driver selection and implicit mutation of a truck default.
- Add a bounded tenant/status projection in Infrastructure or a dedicated query abstraction. Reject loading complete tenant tables into Application memory.
- Continue polling; SignalR and unrelated redesigns are out of scope.

## Task checklist and acceptance criteria

- [x] Baseline tests and exact root-cause tracing recorded.
- [x] Stable map instance and error boundaries covered by regression tests.
- [x] Runtime Web renderer/style/glyph/font behavior documented and Arabic/English Firefox evidence recorded.
- [x] Operational notifications contain localized immutable truck/trip/location/time context and do not replay alerts.
- [x] Driver assignment/confirmation surfaces complete trip context without changing lifecycle state on open.
- [x] All assignment entry points use the same linked/default-driver policy and backend conflict validation.
- [x] New/hardcoded operational strings moved to English and Arabic ARB resources with RTL coverage.
- [x] Active-operations query is bounded, tenant-safe, ordered, and tested without N+1 materialization.
- [x] Full .NET/Flutter validation, EF drift, Web release build, isolated Docker health, and available browser scenarios recorded.
- [x] Final evidence and documentation match the final code; no commit or push performed.

## Risks and rollback

- Web renderer upgrades can break annotations or controller callbacks; keep dependency changes minimal and verify Web release behavior before retaining them.
- Map platform-view identity changes can leak controllers; unit-test create/dispose counts and keep disposal explicit.
- Snapshot additions must remain compatible with legacy JSON payloads and require no invented historical data.
- Query hardening must preserve global tenant filters and response ordering; rollback is the prior Application aggregation if parity tests fail.
- Browser acceptance must use isolated data and disposable Compose resources; if unavailable, report the limitation rather than mutating retained data.

## Validation matrix

| Area | Required evidence | Result |
|---|---|---|
| .NET build/tests | Zero warnings/errors; all tests and focused additions | Passed: 78/78 |
| EF model | No pending model changes, or safe additive migration proof | Passed: no pending changes |
| Flutter | Analyze, complete tests, focused map/assignment/notification/RTL tests | Passed: analyze clean; 69/69 |
| Web | Release build and actual renderer version | Passed: JS release; MapLibre GL JS 6.4.1 |
| Browser map | 30+ polls, transition counters, Arabic labels, LTR/RTL | Passed in Firefox; screenshots/counters recorded |
| Browser workflow | Independent manager/Driver contexts and deduplication | Passed; dropdown Selenium limitation recorded |
| Docker/data safety | Isolated health and retained-data proof | Passed; retained counts unchanged |

## Task timing

Times are updated during execution. The implementation areas were deliberately worked as one interleaved diagnostic/fix interval; no artificial per-area split is claimed because separate transition timestamps were not captured. Pending rows are not estimates.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline, prompt organization, root-cause tracing, and interleaved implementation (map, renderer investigation, notifications, driver details, assignment, localization, query) | 2026-09-26 23:58:29 +03:00 | 2026-09-27 00:30:47 +03:00 | 00:32:18 | Completed |
| 2 | Focused backend and Flutter regression validation | 2026-09-27 00:30:47 +03:00 | 2026-09-27 00:30:47 +03:00 | 00:00:00 (included in task 1 interval) | Completed: backend 4/4; Flutter 32/32 |
| 3 | Full automated validation, EF drift, and release builds | 2026-09-27 00:30:47 +03:00 | 2026-09-27 06:43:06 +03:00 | 06:12:19 wall-clock | Completed: 78 .NET, 69 Flutter, EF clean, Web release |
| 4 | Isolated Docker and real-browser acceptance/evidence | 2026-09-27 06:43:06 +03:00 | 2026-09-27 07:21:30 +03:00 | 00:38:24 | Completed with documented Selenium dropdown limitation |
| 5 | Documentation, retained-data proof, and final audit | 2026-09-27 07:21:30 +03:00 | 2026-09-27 07:26:11 +03:00 | 00:04:41 | Completed |

Task 3 includes a long wall-clock interruption between validation checkpoints;
it is reported as elapsed wall time rather than invented active keyboard time.

## Deferred work

SignalR/push, route optimization, new GPS providers, finance, maintenance, chat, document management, and unrelated dashboard features remain deferred by the sprint scope.
