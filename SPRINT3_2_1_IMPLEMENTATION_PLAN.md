# Sprint 3.2.1 Implementation Plan

## Status

- Sprint: Professional Fleet Map, Real Truck Markers, and Flicker-Free Updates
- Started: 2026-09-18 06:08:09 UTC
- Finished: 2026-09-18 06:48:15 UTC
- Status: Complete
- Starting commit: `1e003066e0c63cc499576e7c45dbf710aa243d66`
- Starting branch: `main` tracking `origin/main`
- Starting worktree: untracked `transport_management_sprint3_1_codex_prompt.md` and `transport_management_sprint3_2_1_codex_prompt.md`; no tracked modifications
- Preservation rule: the pre-existing untracked Sprint 3.1 prompt is unrelated user work and will not be modified.

## Confirmed Root Causes

1. Development documentation and `.env.example` use `https://demotiles.maplibre.org/style.json`, a demonstration style that does not provide useful road-level fleet context.
2. `_ConfiguredFleetMapState._syncCircles` creates `SymbolOptions(textField: '➤  <plate>')`; no truck image is declared, loaded, or registered.
3. Every widget update invokes `clearSymbols`, `clearLines`, and `clearCircles` before rebuilding every annotation, so polling creates visible gaps and unstable annotation identity.
4. The initial camera centers the first position at fixed zoom 6 and has no explicit fleet, selected-truck, or selected-route camera state.
5. The full-width bottom action-chip overlay duplicates fleet selection and obscures operational map content.

## Chosen Marker and Asset Provenance

- Use a repository-owned transparent PNG, purpose-built for this application from an original simple top-down truck silhouette.
- Intrinsic forward direction: north/up; therefore MapLibre heading uses the tracking heading directly with a `0°` asset offset.
- Register state-specific image variants once after each genuine style load, then use MapLibre `iconImage`, `iconRotate`, map rotation alignment, centered anchoring, and overlap settings.
- Encode moving, stationary, offline, maintenance, and selected states through image variant/opacity plus a separate selection halo, so state is not communicated by color alone.
- Document the asset as original project artwork under the repository license; no third-party icon or paid API key is required.

## Annotation Lifecycle Design

- Introduce a platform-neutral, deterministic annotation coordinator driven by immutable fleet snapshots.
- Maintain stable registries for truck symbols, selection halo, planned-route line, actual-trail line, and pickup/delivery markers.
- Diff snapshots: unchanged objects cause zero operations; changed objects update in place; additions/removals touch only their own handles.
- Route identity is based on selected trip plus route geometry; trail geometry updates its existing line; stops remain stable until route selection changes.
- Normal polling never calls a global clear operation.
- A style reload explicitly invalidates handles, registers images once, and restores the latest complete snapshot once.
- Serialize asynchronous passes and coalesce rapid requests so the latest pending snapshot wins. Disposal and generation checks prevent calls into dead controllers.

## Camera-State Design

- First ready snapshot: fit multiple visible trucks; use a local zoom for one truck.
- Selection without a route: animate once to the selected truck.
- Selection with a route: fit the full route and stops with responsive padding for the side detail panel.
- Position polling never moves the camera. Filter and selection transitions may request one fit; explicit Recenter/Fit route always restores the relevant view.
- Manual pan/zoom remains authoritative between explicit camera events.

## Performance and Flicker Test Strategy

- Unit-test a fake annotation adapter and operation telemetry for unchanged, position, heading, state, add/remove, route, trail, selection, rapid-update, and style-reload cases.
- Assert zero global clears and zero polling camera moves.
- Run a ten-update deterministic scenario and retain its operation counts as evidence.
- Run Flutter Web against OpenFreeMap Liberty and observe at least ten polling cycles; retain screenshots and telemetry in `docs/evidence/sprint3_2_1/`.
- Prefer stable atomic in-place coordinate updates. Enable interpolation only if repeated browser testing proves frame updates reliable; otherwise document the deliberate stability-first compromise.

## Task Checklist

- [x] Record baseline commit, Git status, and root causes.
- [x] Add and document genuine directional truck marker assets.
- [x] Implement incremental annotations and serialized/coalesced synchronization.
- [x] Implement state treatment, selection synchronization, and compact fleet panel.
- [x] Implement fleet/selection/route camera modes and explicit recenter.
- [x] Update development basemap configuration and attribution documentation.
- [x] Add annotation, marker, camera, and operation-count tests.
- [x] Run Flutter generation, formatting, analysis, tests, integration coverage, and web build.
- [x] Run .NET build/tests and EF migration drift check.
- [x] Verify Compose health and route/tracking APIs.
- [x] Run real-browser workflow and retain evidence.
- [x] Check Android SDK availability and report the invalid/incomplete SDK honestly.
- [x] Record actual timing, limitations, evidence, and final Git state.

## Acceptance Checklist

- [x] Road-detailed configurable development style and correct attribution.
- [x] Real image-based MapLibre truck marker; no arrow/text vehicle glyph.
- [x] Correct 0/90/180/270 heading mapping.
- [x] Selected, moving, stationary, offline, and maintenance states distinguishable.
- [x] Stable incremental annotation identity with zero normal-poll global clears.
- [x] Planned route, trail, and stops remain stable across polls.
- [x] Serialized/coalesced updates with latest snapshot winning.
- [x] Initial fleet fit, selected route fit, manual-pan respect, and explicit recenter.
- [x] Compact synchronized fleet list and selected detail card in LTR/RTL.
- [x] Deterministic ten-update operation evidence.
- [x] Browser evidence across at least ten polls.
- [x] Flutter, backend, EF, Compose, and applicable Android validation reported honestly.

## Actual Elapsed Time

| Task | Started (UTC) | Finished (UTC) | Elapsed | Result |
|---|---:|---:|---:|---|
| Baseline audit and implementation design | 2026-09-18 06:08:09 | 2026-09-18 06:12:06 | 00:03:57 | Completed — confirmed all four defects and designed stable registries/camera intents |
| Marker assets and annotation coordinator | 2026-09-18 06:12:06 | 2026-09-18 06:21:40 | 00:09:34 | Completed — added transparent north-facing truck artwork, MapLibre adapter, and latest-wins coordinator |
| Camera modes and fleet-map UI | 2026-09-18 06:21:40 | 2026-09-18 06:25:10 | 00:03:30 | Completed — added event-driven fitting, selected halo, compact fleet panel, and visible Recenter/Fit route |
| Tests and documentation | 2026-09-18 06:25:10 | 2026-09-18 06:28:52 | 00:03:42 | Completed — added 14 focused tests, telemetry evidence, localization, provenance, README, and ADR |
| Full validation and evidence | 2026-09-18 06:28:52 | 2026-09-18 06:48:15 | 00:19:23 | Completed — fixed selected-trail refresh, passed all suites/browser workflow, and retained final screenshots |

Total actual elapsed time: **00:40:06**.

## Known Limitations

- OpenFreeMap Liberty is development infrastructure with no application-owned production SLA; production must provide an explicitly selected style/provider.
- Public OSRM routing and MapLibre basemap rendering remain separate services and changing the basemap does not change route calculation.
- Browser platform-view screenshots alone cannot prove absence of flicker, so operation telemetry and sustained live observation are required.
- Frame-by-frame interpolation is deliberately not enabled. The current
  MapLibre Flutter Web annotation bridge has no cancellation-safe animation
  primitive; stable in-place atomic coordinate updates were visually clean and
  avoid reintroducing destructive redraws.
- The local `.tooling/android-sdk` contains only an incomplete command-tools
  directory. `flutter doctor -v` reports "Android SDK not found", so no Android
  build or device run was claimed.
- Headless Firefox gestures are less observable than physical pointer input;
  manual-pan safety is additionally proven by zero polling camera operations
  and focused camera tests.

## Validation Results

- Flutter dependency restore and localization generation: passed.
- `dart format lib test integration_test test_driver`: clean.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 25/25 passed, including 14 focused map tests.
- Flutter Web release build with OpenFreeMap Liberty: passed. Flutter emitted
  the existing `flutter_secure_storage_web` WebAssembly compatibility advisory;
  the HTML/JS build succeeded.
- Headless Firefox workflow: passed with nine retained screenshots, ten
  poll/step cycles, live progress/trail refresh, pause/resume, synchronized
  selection, manual pan attempt, route fit, and Arabic RTL.
- .NET build: passed with 0 warnings and 0 errors.
- Backend integration tests: 20/20 passed.
- EF pending-model check: no changes since the last migration.
- Docker Compose: API and PostgreSQL healthy. Legacy Compose v1 first hit its
  known `ContainerConfig` recreation error; removing only project containers
  and network (no volumes) and recreating resolved it.
- Authenticated local API checks: health `Healthy`; positions `200` with four
  current smoke positions; route preview `200` with 5,253 coordinates.
- Android: blocked by incomplete SDK, reported above.

## Evidence

- `docs/evidence/sprint3_2_1/annotation_operation_counts.md`
- `docs/evidence/sprint3_2_1/01-road-detailed-selected-truck.png`
- `docs/evidence/sprint3_2_1/02-route-trail-stops-after-10-polls.png`
- `docs/evidence/sprint3_2_1/03-manual-pan-preserved.png`
- `docs/evidence/sprint3_2_1/04-fit-route-recentered.png`
- `docs/evidence/sprint3_2_1/05-synchronized-fleet-selection.png`
- `docs/evidence/sprint3_2_1/06-arabic-rtl-fleet.png`
- Planner/route preview/detail screenshots in the same directory.

## Git Status

Sprint 3.2.1 changes, this plan, the retained evidence, and
`transport_management_sprint3_2_1_codex_prompt.md` are included in the Git
commit containing this final plan and pushed to `origin/main`. The pre-existing
untracked `transport_management_sprint3_1_codex_prompt.md` remains untouched.
