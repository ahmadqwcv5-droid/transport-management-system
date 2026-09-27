# Sprint 4.2.2 Implementation Plan

## Baseline

- Started: `2026-09-27 09:58:56 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `5bd5cac` (`feat(operations): harden sprint 4.2.1 reliability`), synchronized with `origin/main`.
- Initial worktree: clean except for the user-provided untracked Sprint 4.2.2 prompt, now organized in this sprint folder.
- Safety boundary: do not edit `.env`, credentials, retained PostgreSQL data, or Docker volumes. Use tests and an isolated disposable Compose project. Do not commit or push.
- Available browser/tooling and retained-data counts will be rechecked before runtime acceptance.

## Verified baseline and initial reproduction evidence

1. Arabic evidence gap: Sprint 4.2.1 recorded MapLibre GL JS 6.4.1 and OpenFreeMap Liberty, but its locale screenshots were trip-detail pages and do not prove canvas label shaping. The exact Liberty symbol expressions and raw vector feature properties still require capture on the real map.
2. Owner follow: `fleet_map_adapter.dart` forwards both pointer-down and every pointer signal to `onManualCameraInteraction`; `FleetMap._pauseFollow` changes any non-free mode to free. Wheel zoom therefore pauses follow.
3. Owner zoom reset: `MapLibreFleetAnnotationAdapter.animateCamera` uses `CameraUpdate.newLatLngZoom(..., 13.5)` for every local-truck plan, including polling recenter.
4. Driver inconsistency: `DriverWorkspaceMap` uses `newLatLng` for poll updates, but any pointer-down switches to free and explicit follow uses fixed zoom 13.5. Owner and Driver do not share one state machine.
5. No interpolation: both maps replace symbol geometry directly at each poll. There is no fake-time/latest-wins visual interpolation, heading-wrap handling, stale/offline stop, or large-jump snap policy.
6. Current-position chronology: persistence stores immutable `truck_positions`, while latest/current readers order by `RecordedAt`. There is no separately guarded current projection or database compare-and-set, so equal/out-of-order semantics and stable tie-breaking are not explicit.
7. Driver idle truck: `DriverWorkflowService.WorkspaceAsync` resolves active trip, then active session, then returns `NO_ACTIVE_TRIP`; it does not resolve a unique active truck whose `DefaultDriverId` is the linked Driver. The Flutter screen renders an empty-state page before building `DriverWorkspaceMap`.
8. Tenant map preference: `Company` currently has only name, slug, and active state. There is no operational-area entity/API/settings UI or persisted bounds used by the initial fleet camera.
9. Working default-Driver recommendation is implemented through the shared `AssignmentSelectionPolicy` and must be preserved; the prior Selenium dropdown result is a harness limitation, not a product defect.

## Architecture decisions and rejected alternatives

- Add one optional, tenant-owned operational-area preference with validated ISO alpha-2 code, language-neutral label snapshot, bounds, optional center/zoom, updated timestamp, and actor. Existing tenants remain null/unconfigured. Reject a hardcoded country and reject geocoding on every dashboard open.
- Resolve area candidates through the existing geocoding boundary only during explicit Owner setup; persist validated bounds. Extend the deterministic provider for tests. Reject a required paid provider.
- Provide locale-aware style selection through a deterministic, cached transformation of the configured style: Arabic prefers local/non-Latin name with safe Latin fallback; English prefers Latin/English with local fallback. Reject manual reversal and per-poll remote mutation.
- Introduce a shared platform-neutral camera interaction controller used by Owner and Driver: fleet overview, follow vehicle, free explore, and route overview. Zoom preserves follow; deliberate pan/rotate/pitch pauses it; programmatic moves are guarded. Reject fixed zoom on poll updates.
- Introduce a latest-wins visual motion controller that interpolates marker/heading only in Flutter, never in persistence. Large jumps and stale/offline states snap/stop. Reject invented backend telemetry and queued animations.
- Keep immutable position history and add an explicit tenant-owned current-position projection updated transactionally only by a strict chronology rule. Equal timestamps use a stable packet identity/tie rule and conflicting equals do not replace current. New runs are explicit. Reject relying solely on unordered insertion or query timing.
- Resolve Driver vehicle in priority order: active trip, active session, unique active default-linked truck, none/ambiguous. Never select the first of multiple linked trucks. Reject fabricating a trip/route for idle vehicles.

## Migration and data-safety strategy

- Add nullable-safe operational-area storage and an explicit current-position projection. No legacy company receives invented geography; no legacy truck receives invented current telemetry.
- Backfill each current projection deterministically from the newest historical timestamp, then the highest packet ID. Runtime equal-time conflicts never replace current. The final migration and rollback are documented in the evidence.
- Audit existing default-Driver multiplicity before considering a uniqueness constraint. If legacy-safe enforcement cannot be proven, return an explicit ambiguity state and log it rather than adding a destructive constraint.
- Generate an EF migration, inspect Up/Down manually, run model-drift checks, and apply only to an isolated database for acceptance.
- Capture retained counts before/after without writing retained data. Drop only the disposable acceptance database/tenant afterward; never delete volumes.

## Task checklist and acceptance criteria

- [x] Reproduce and record actual Arabic canvas defect, style layers/expressions, raw properties, glyph/font/runtime details.
- [x] Implement deterministic locale-aware map style and prove real Arabic/English canvas labels with attribution.
- [x] Add tenant operational-area domain/API/migration, Owner settings preview/save/clear, authorization, isolation, and validation.
- [x] Implement shared fleet-overview bounds policy with viewport/RTL padding, outside-area indication, and explicit Fleet overview action.
- [x] Implement shared Owner/Driver follow state machine; zoom preserves follow/zoom, pan pauses, polling is mode-safe.
- [x] Implement latest-wins marker/heading/camera interpolation with snap and stale/offline stop rules.
- [x] Implement monotonic current-position projection with deterministic duplicate/equal/run/reset/tenant behavior.
- [x] Implement Driver idle/default-linked truck resolution, explicit ambiguity/no-vehicle states, secure photo access, and idle UI.
- [x] Preserve default-Driver selection and expand focused regression coverage without redesigning it for Selenium.
- [x] Complete English/Arabic localization, RTL/LTR layout, accessible state controls, and attribution.
- [x] Pass full backend/Flutter tests, analyze, EF drift, Web release build, and isolated Docker health.
- [x] Complete available real-browser scenarios with genuine map evidence and honest platform limitations.
- [x] Finish README, architecture, sprint index, evidence, data proof, and elapsed-time table. No commit/push.

## Testing matrix

| Area | Required proof | Result |
|---|---|---|
| Backend build/tests | Zero warnings/errors; all tests plus preference, idle vehicle, chronology, tenant isolation | Passed: build clean; 81/81 tests |
| Migration | Additive Up/Down inspected; isolated apply; no pending model changes | Passed in isolated PostgreSQL; EF drift clean |
| Flutter | Analyze; all tests; camera/follow/interpolation/settings/idle/RTL/default-Driver focus | Passed: analyze clean; 78/78 full and 34/34 focused tests |
| Web | Release build; actual locale style transformation and attribution | Passed: JavaScript release build and real MapLibre rendering |
| Browser Owner | Country overview, wheel zoom follow, pan pause, resume, route overview | Passed in real Firefox: wheel zoom preserved follow; pan paused; moved-position polling stayed paused |
| Browser Driver | Idle truck, assigned trip convergence, post-trip map | Passed in real Firefox: idle/default-linked, assigned-trip convergence, and post-trip vehicle map |
| Arabic canvas | Genuine before/after map screenshots for required cities/road/mixed case | Passed: local RTL plugin and genuine Firefox Arabic/English captures |
| Chronology | Older/duplicate/equal/reset packet API/DB evidence and counters | Passed: focused store tests plus isolated history/projection proof |
| Data safety | Isolated tenant/database cleanup and retained-stack comparison | Passed: isolated containers/volumes/temp secrets removed; business counts and retained volume identities unchanged |

## Task timing

Times are recorded at task boundaries. Active elapsed excludes explicitly recorded user/environment pauses; concurrent work is not double-counted.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline audit, prompt organization, reproduction, architecture, and initial implementation | 2026-09-27 09:58:56 +03:00 | 2026-09-27 10:41:16 +03:00 | 42m 20s | Completed |
| 2 | Backend/Flutter implementation closure and focused regression coverage | 2026-09-27 10:41:16 +03:00 | 2026-09-27 11:13:38 +03:00 | 32m 22s | Completed |
| 3 | Full automated validation and locale-style lifecycle correction | 2026-09-27 11:13:38 +03:00 | 2026-09-27 11:20:46 +03:00 | 7m 08s | Completed |
| 4 | Isolated Docker build, migration apply, health, and disposable fixture setup | 2026-09-27 11:20:46 +03:00 | 2026-09-27 11:25:19 +03:00 | 4m 33s | Completed |
| 5 | Independent Owner/Driver Firefox acceptance, genuine map captures, chronology/data proof | 2026-09-27 11:25:19 +03:00 | 2026-09-27 13:02:57 +03:00 | 1h 37m 38s | Completed |
| 6 | Documentation, disposable cleanup, retained-data comparison, and final audit | 2026-09-27 13:02:57 +03:00 | 2026-09-27 13:30:50 +03:00 | 27m 53s | Completed |
| **Total** | **Sprint 4.2.2 active work** | **2026-09-27 09:58:56 +03:00** | **2026-09-27 13:30:50 +03:00** | **3h 31m 54s** | **Completed** |

Current snapshot: backend tests `81/81`, Flutter tests `78/78`, focused map
tests `34/34`, .NET build `0` warnings/errors, Flutter analyze clean, EF drift
clean, Flutter Web release build passed, and real Firefox Owner/Driver acceptance
passed. The isolated API/PostgreSQL, media/database volumes, browser sessions,
ports, and temporary credentials were removed. No commit or push was performed.

## Final result and deferred work

Completed. Sprint 4.2.2 now provides genuine Arabic MapLibre shaping and
locale-aware labels, persisted tenant operational bounds, one Owner/Driver
camera contract, latest-wins UI interpolation, strict monotonic current
positions, and Driver idle/default-linked vehicle maps. The additive migration,
full automated validation, real Firefox acceptance, isolated cleanup, and
retained-data audit passed. Chrome and Android were unavailable; Flutter Web was
validated through Firefox, while browser automation of the Flutter
default-Driver dropdown remains a documented harness limitation backed by
focused regression tests and prior user verification.

SignalR/push, route optimization, real GPS-provider integration, finance,
maintenance, documents, chat, advanced telemetry retention/partitioning, and
