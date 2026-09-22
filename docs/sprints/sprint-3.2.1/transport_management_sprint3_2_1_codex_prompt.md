# Codex Implementation Prompt — Sprint 3.2.1: Professional Fleet Map, Real Truck Markers, and Flicker-Free Updates

## Role

Act as a senior Flutter GIS engineer, MapLibre specialist, frontend performance engineer, and product-quality reviewer.

Work inside the existing `transport-management-system` repository. This is a focused corrective sprint for the visual and runtime defects remaining after Sprint 3.2.

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected baseline when this prompt was prepared:

```text
1e00306 feat: add route-aware trip planning
```

Do not assume the repository still matches that commit. Record the actual HEAD and working-tree state before implementation.

Do not rebuild the route domain, routing backend, simulator mathematics, or trip planner unless a narrowly necessary fix is discovered and documented.

---

# Sprint Name

**Sprint 3.2.1 — Professional Fleet Map, Real Truck Markers, and Flicker-Free Updates**

## Primary Goal

Finish the visual and rendering quality that Sprint 3.2 claimed but did not actually deliver:

1. Use a road-detailed MapLibre basemap in development instead of the country-polygon demo map.
2. Render a genuine directional truck marker rather than a text arrow and plate number.
3. Eliminate map/route/truck flicker during tracking polling.
4. Implement correct camera behavior for fleet overview, selected truck, and selected trip.
5. Prove the result through real browser visual evidence and annotation-operation tests.

This sprint is not complete if the map merely compiles, if the route is mathematically correct but roads are invisible, or if a text glyph is described as a truck icon.

---

# Confirmed Current Defects

Verify these findings against the current code before changing it.

## 1. Wrong development basemap

The documented launch command currently uses:

```text
https://demotiles.maplibre.org/style.json
```

That MapLibre demo style primarily displays low-detail country polygons and boundaries. It is appropriate for hello-world/CI examples, not a road-fleet dashboard.

The user already manually verified that this road-detailed MapLibre style works in the current application:

```text
https://tiles.openfreemap.org/styles/liberty
```

Reference:

- https://openfreemap.org/quick_start/
- https://github.com/maplibre/demotiles

## 2. Fake “truck icon”

The current fleet map uses behavior equivalent to:

```dart
SymbolOptions(
  textField: '➤  ${position.plateNumber}',
  textRotate: position.heading,
)
```

This is a rotated text arrow plus a plate number. It is not a truck marker and does not satisfy Sprint 3.2.

## 3. Flicker/blinking during simulator operation

The current annotation synchronization clears and recreates all map objects during normal position updates, using operations equivalent to:

```text
clearSymbols()
clearLines()
clearCircles()
add all symbols again
add route again
add endpoints again
add trail again
```

Because tracking data polls repeatedly, the truck, planned route, trail, and stop markers temporarily disappear and reappear. The user observes this as strong flicker/blinking.

## 4. Weak camera behavior

The fleet map currently starts near the first position with a fixed broad zoom and does not reliably fit the selected trip route. It must not remain at country scale when the operational object is a local/regional route.

## 5. Visual verification was overstated

The previous implementation plan marked road-detail and truck-icon requirements complete even though the code and screenshot show country polygons and a text marker. Sprint 3.2.1 must correct the implementation and the documentation honestly.

---

# Mandatory Implementation Plan

Create and maintain:

```text
docs/sprints/sprint-3.2.1/SPRINT3_2_1_IMPLEMENTATION_PLAN.md
```

It must include:

- Actual starting commit and Git status
- Confirmed root causes
- Chosen marker implementation and asset provenance
- Annotation lifecycle design
- Camera-state design
- Performance/flicker test strategy
- Task checklist
- Acceptance checklist
- Actual elapsed time per task
- Total actual elapsed time
- Known limitations

Do not copy the prior Sprint 3.2 completion claims without re-verifying them.

---

# Required Work

## 1. Correct the development road basemap

Keep `MAP_STYLE_URL` configurable through `--dart-define`. Do not permanently couple the application domain to OpenFreeMap or another tile provider.

Update development documentation and examples to use:

```text
https://tiles.openfreemap.org/styles/liberty
```

Requirements:

- Update the copy-pasteable Flutter Web development command.
- Update `.env.example`, scripts, or launch configuration if they currently recommend the country-only demo style.
- Clearly label the configured style as development infrastructure, not a guaranteed production SLA.
- Preserve an explicit production placeholder/configuration path.
- Preserve the MapLibre loading/error/retry/fallback states from Sprint 3.1.
- Preserve required map-data attribution according to the selected style/data provider.
- Do not hard-code a paid API key.
- Do not remove configurability.
- Do not claim that changing the basemap changes route calculation; OSRM/routing and MapLibre rendering remain separate.

The application must visibly show roads, road labels, towns/cities, and normal operational map detail at useful zoom levels.

## 2. Add a genuine truck marker asset

Replace the text-arrow implementation with a real directional truck marker.

Requirements:

- Use a project-owned or correctly licensed transparent marker asset.
- Prefer a clean top-down truck/lorry silhouette designed for map rotation.
- The asset must have a known “forward” direction so heading rotation is mathematically correct.
- Add the asset through Flutter's declared asset pipeline if file-backed.
- Load/register the marker image only after the MapLibre style is ready.
- Register the image once per style load/map instance, not on every tracking poll.
- Use MapLibre symbol `iconImage` behavior rather than `textField` as the vehicle graphic.
- Set sensible icon size across desktop and mobile.
- Allow overlapping where necessary for a small fleet, while keeping selection usable.
- Anchor the icon appropriately so its geographic point represents the truck location.
- Use map-aligned rotation so the marker heading follows the road when the map bearing changes.
- Verify heading values at 0°, 90°, 180°, and 270°.
- If the asset's intrinsic direction is not north/up, apply and document the required rotation offset.

Do not use an emoji, Unicode arrow, text character, plate number, or Material icon rendered as text in place of a map truck symbol.

## 3. Represent truck state professionally

The map must distinguish at least:

- Online and moving
- Online and stationary
- Offline
- Selected
- Maintenance/out of service when those statuses are available in the current model

Use an accessible combination of marker treatment, badge/halo, opacity, outline, or secondary status indicator. Do not rely only on red/green color.

Acceptable approaches include:

- multiple registered marker variants,
- one base marker plus a selection/status circle layer,
- an SDF-compatible marker if the current package supports it reliably,
- or another tested MapLibre-native solution.

Requirements:

- Selected truck must have an obvious halo/emphasis.
- Offline marker must remain visible but clearly muted.
- Moving and stationary states must be distinguishable in the selected details/list even if the map icon difference is subtle.
- Maintenance/out-of-service must not look actively moving.
- Marker updates must not recreate the entire map.

## 4. Remove plate number from the permanent moving marker

Do not continuously render the complete plate number as the moving map marker.

Show the plate number in:

- the selected-truck card,
- the synchronized fleet list,
- and optionally a selected-only label/callout.

If an always-visible compact label is retained, it must be visually subordinate, collision-aware, and must not replace the truck icon. For the current seven-truck target, the preferred default is icon-only until selection.

## 5. Replace destructive annotation synchronization

Refactor the current synchronization method. Rename misleading methods such as `_syncCircles` if they now manage symbols, lines, and endpoints.

Normal polling updates must never execute global annotation clearing.

The following calls, or their equivalents, are forbidden during an ordinary position-only update:

```text
clearSymbols()
clearLines()
clearCircles()
```

They may be used only for explicit teardown, map/style replacement, or a carefully documented full reset—not for every poll.

Implement an incremental annotation registry/coordinator with stable identity.

Suggested state:

```text
truckId -> MapLibre Symbol handle
selectedTripId/routeRevision -> planned route Line handle
selectedTripId/trailRevision -> actual trail Line handle
selectedTripId -> pickup/delivery marker handles
selectedTruckId -> selection halo handle
```

The exact implementation may differ, but behavior must match.

### Position diff behavior

For each update:

- Add a marker only for a newly visible truck.
- Update an existing marker's geometry, heading, and status only when changed.
- Remove a marker only when that truck is no longer part of the visible filtered set.
- Preserve stable symbol identity for unchanged trucks.
- Do not touch route/trail/stop annotations when only truck position changed.

### Route behavior

- Create the planned route once when a selected trip becomes available.
- Update/replace it only when selected trip or route revision/geometry changes.
- Do not clear and redraw the planned route on every position poll.

### Trail behavior

- Keep one stable trail line for the selected trip/truck.
- Update the existing line geometry when bounded history grows.
- Do not remove the line before updating it.
- Avoid fetching or rendering trails for unselected trucks.

### Stop marker behavior

- Create pickup/delivery markers once per selected route.
- Leave them stable during position updates.
- Replace them only when selected route changes.

### Style reload behavior

MapLibre style reload invalidates registered images/annotations. Handle this deliberately:

- rebuild the registry after a genuine style reload,
- re-register marker images,
- then restore current annotations once,
- without confusing this controlled rebuild with normal polling.

## 6. Prevent overlapping async synchronization

The current polling interval can produce another widget update while async MapLibre operations are still running.

Implement safe serialization/coalescing:

- Never run two annotation synchronization passes concurrently.
- Coalesce rapid incoming state so the latest snapshot wins.
- Cancel/ignore stale generations safely.
- Do not leave partially cleared state.
- Check `mounted` and controller lifecycle correctly.
- Handle map disposal/style reload without calling a dead controller.
- A failed update must not permanently block future updates.

Prefer a small dedicated map-annotation coordinator over a large monolithic widget method.

## 7. Smooth marker motion without redrawing the map

After eliminating destructive clears, add a short bounded coordinate interpolation for an existing moving truck marker if practical with the current package and browser performance.

Requirements:

- Interpolate only the marker position between the previous and new GPS/simulator sample.
- Do not animate or rebuild the entire map widget.
- Do not redraw the planned route on animation frames.
- Rebase safely if a new sample arrives before the previous interpolation finishes.
- Snap immediately when the distance is unreasonably large, tracking resumes after a long gap, the truck changes trip, or the previous point is unavailable.
- Heading interpolation must take the shortest angular path across 0°/360°.
- Pause/offline states must settle at the final known coordinate without oscillation.
- Keep animation duration shorter than the configured polling interval.
- Respect reduced-motion/platform constraints if the application already has such support.

If frame-by-frame MapLibre symbol updates are unstable on Flutter Web, prioritize stable non-flickering atomic marker updates and document why smooth tweening was not enabled. Never reintroduce clear/recreate flicker to simulate smooth movement.

## 8. Correct camera behavior

Implement explicit camera modes.

### Fleet overview

- On first successful map load, fit all visible trucks with padding.
- If there is only one truck, center it at a useful city/street zoom.
- Do not repeatedly recenter on every poll.

### Selected truck without active route

- Animate to the truck with a useful local zoom.
- Do not continuously force the camera while the user pans.

### Selected active trip

- Fit pickup, delivery, and full planned route with responsive padding.
- Ensure the selected-truck detail card/sidebar does not cover the important route.
- Refit only when selection/route changes or when the user presses an explicit recenter button.

### User control

- Manual pan/zoom must be respected.
- Add a clear “Recenter”/“Fit route” action if not already present.
- Do not create a camera feedback loop from marker animation or polling.

### Filters

- When filters change, fit the newly visible set once if appropriate.
- Do not jump to a country-scale default merely because one filtered state is empty.

## 9. Clean up map overlays

The current bottom overlay renders a row of action chips for every truck. It consumes map space and duplicates the marker/list function.

Refactor it into one of these:

- a compact collapsible fleet panel beside the map,
- a small scrollable overlay that does not cover the route,
- or a synchronized list outside the map viewport.

Requirements:

- Selecting a list row selects/focuses the truck marker.
- Selecting a marker selects the corresponding list row/card.
- The map must retain enough unobstructed space to understand the route.
- Plate number, driver, speed, trip, status, progress, and last update belong in the selected card/list—not as the moving symbol itself.
- Preserve Arabic RTL and English LTR layout.

Do not redesign the entire dashboard outside this focused scope.

## 10. Preserve route semantics

Do not change the correct Sprint 3.2 distinction:

```text
Planned route = blue
Actual travelled trail = contrasting green/darker color
Pickup = green marker
Delivery = red marker
Current position = truck marker
```

Improve visibility if necessary, but preserve these separate semantic objects.

The planned route, actual trail, pickup, and delivery must not blink during position updates.

---

# Testing and Verification

## 11. Extract a testable annotation coordinator

Platform-view screenshot tests alone are not enough. Make annotation lifecycle behavior testable without relying entirely on a real browser.

Use an adapter/coordinator abstraction or equivalent test seam around the MapLibre controller.

Automated tests must prove:

- Initial style load registers truck marker images once.
- Initial snapshot adds one symbol per truck.
- An unchanged snapshot causes no annotation operations.
- A position-only change updates exactly the affected symbol.
- A heading-only change updates the affected symbol without recreating it.
- A status change updates only the affected marker/status decoration.
- Adding a truck adds only one marker.
- Removing/filtering a truck removes only that marker.
- Position polling does not clear symbols.
- Position polling does not clear or recreate planned route.
- Position polling does not clear or recreate stop markers.
- Trail growth updates one existing line.
- Selecting a different trip changes only route-specific annotations.
- A genuine style reload performs one controlled rebuild and re-registers images.
- Rapid updates are serialized/coalesced and latest state wins.

Add explicit test assertions that ordinary synchronization has zero calls to global clear operations.

## 12. Marker tests

Test that:

- truck markers use `iconImage`, not a text arrow,
- marker asset is declared and loadable,
- plate number is not the vehicle glyph,
- heading mapping is correct for 0/90/180/270 degrees,
- selection treatment is visible in the annotation model,
- offline/maintenance state does not appear identical to moving state.

Do not satisfy these tests with an off-map Material `Icons.local_shipping` chip. The map annotation itself must use the truck image.

## 13. Camera tests

Using a camera-controller test seam, verify:

- one truck produces local zoom/center behavior,
- multiple trucks produce bounds fitting,
- selected route fits route bounds,
- polling does not invoke camera movement,
- user pan is not immediately overridden,
- recenter explicitly restores the correct view,
- responsive padding accounts for the selected detail panel.

## 14. Real browser visual test

Run Flutter Web with:

```text
MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty
```

Perform this workflow:

1. Login.
2. Open dashboard.
3. Verify roads and road labels are visibly rendered.
4. Select or create a route-aware active trip.
5. Verify pickup, delivery, planned route, current truck, and actual trail.
6. Start simulator.
7. Observe at least ten consecutive polling cycles.
8. Verify the route, trail, stops, and truck do not disappear/reappear.
9. Verify marker moves without map reconstruction.
10. Pause and verify marker becomes stable.
11. Resume and verify movement continues from the same point.
12. Select another truck and verify synchronized list/card selection.
13. Manually pan/zoom and verify polling does not steal camera control.
14. Use Recenter/Fit route and verify correct bounds.
15. Switch Arabic/RTL and English/LTR.

## 15. Visual evidence

Capture screenshots showing:

- Road-detailed fleet basemap
- Real truck marker at local zoom
- Selected truck marker with emphasis
- Planned route plus actual trail plus pickup/delivery
- Arabic RTL map and selected card

Because screenshots cannot prove absence of flicker, also provide one of:

- a short browser screen recording/GIF covering multiple polls, or
- deterministic annotation-operation telemetry plus documented live observation across at least ten polls.

The final report must not claim “flicker-free” based only on a single screenshot.

## 16. Operation-count evidence

Add a test/debug instrumentation path that can report annotation operations without exposing it in production UI.

For a scenario of one selected moving truck across ten position updates, record:

```text
style image registrations
symbol additions
symbol updates
symbol removals
route line additions
route line updates
route line removals
trail line additions
trail line updates
pickup/delivery additions
global clearSymbols calls
global clearLines calls
global clearCircles calls
camera moves caused by polling
```

Expected normal-poll behavior:

```text
global clears = 0
planned route additions after initial creation = 0
pickup/delivery additions after initial creation = 0
camera moves caused by polling = 0
only current marker and growing trail are updated as needed
```

---

# Validation Commands

Run all relevant existing validation plus new focused coverage.

## Flutter

- `flutter pub get`
- localization generation
- formatting
- `flutter analyze`
- all Flutter unit/widget tests
- relevant integration tests
- Flutter Web release build

## Backend regression

The sprint is primarily Flutter-focused, but run:

- .NET build
- existing backend/integration tests
- EF migration drift check

No new migration should be required for this visual correction. If one appears necessary, stop and explain why before creating it.

## Compose

- Confirm API and PostgreSQL remain healthy.
- Confirm route/tracking APIs still work.

## Android

Build/test only if a valid Android SDK exists. Report missing SDK/device honestly rather than claiming success.

---

# Acceptance Criteria

Sprint 3.2.1 is complete only when all applicable criteria are proven:

- [ ] Development documentation uses a road-detailed MapLibre style, not the country-only demo style.
- [ ] Roads and road labels are visibly present in the real browser.
- [ ] `MAP_STYLE_URL` remains configurable.
- [ ] Proper attribution is retained.
- [ ] A genuine truck image is registered with MapLibre.
- [ ] Map vehicle symbols use `iconImage` or an equivalent real image-based marker.
- [ ] No Unicode arrow/text glyph is used as the truck graphic.
- [ ] Plate number is not the permanent moving-marker graphic.
- [ ] Marker heading is correct at 0/90/180/270 degrees.
- [ ] Selected, offline, moving, stationary, and maintenance/out-of-service states are distinguishable.
- [ ] Ordinary polling never calls global symbol/line/circle clearing.
- [ ] Planned route remains stable across position polls.
- [ ] Pickup and delivery markers remain stable across position polls.
- [ ] Actual trail updates without disappearing first.
- [ ] Current truck marker updates without disappearing first.
- [ ] Async map updates cannot overlap destructively.
- [ ] Marker movement is smooth or at minimum atomic and visibly non-flickering.
- [ ] Initial fleet view fits visible trucks.
- [ ] Selected route fits pickup, delivery, and route geometry.
- [ ] Polling does not move the camera.
- [ ] Manual pan/zoom is respected.
- [ ] Recenter/Fit route works explicitly.
- [ ] Fleet list/card and marker selection remain synchronized.
- [ ] Map overlays no longer obscure a large portion of the route.
- [ ] Arabic RTL and English LTR remain correct.
- [ ] Existing route planning, progress, ETA, trail, simulator, and fallback tests still pass.
- [ ] Flutter analyzer is clean.
- [ ] Flutter tests pass.
- [ ] Flutter Web release build passes.
- [ ] Backend regression tests pass.
- [ ] Compose services remain healthy.
- [ ] Browser evidence covers at least ten polling cycles.
- [ ] Annotation operation counts prove zero global clears during normal polling.
- [ ] Documentation accurately describes what was visually verified.
- [ ] Actual elapsed time is recorded per task and in total.

If a required visual/performance criterion is not proven, report Sprint 3.2.1 as **Partially Complete** or **Blocked**. Do not mark it complete merely because tests compile.

---

# Explicitly Out of Scope

Do not implement:

- Finance or Sprint 4 features
- Real GPS provider integration
- SignalR/WebSockets
- Live traffic or rerouting
- HGV restriction routing
- Multi-vehicle route optimization
- Driver application
- Customer public tracking
- Proof of delivery
- Large dashboard redesign unrelated to the map
- Changes to trip-state business rules
- New database entities or migrations unless an unexpected critical blocker is explained first
- Marker clustering for the current seven-truck target

---

# Engineering Constraints

- Inspect repository instructions and `AGENTS.md` if present.
- Preserve unrelated user changes.
- Do not use destructive Git operations.
- Do not commit or push unless explicitly requested.
- Keep MapLibre-specific implementation in Flutter presentation/infrastructure code, not the backend domain.
- Prefer a dedicated, testable annotation coordinator over a monolithic state widget.
- Keep stable object identity across updates.
- Dispose controllers, timers, animations, and subscriptions safely.
- Keep new user-facing strings in ARB resources.
- Keep tests deterministic and independent of public tile services except the explicitly manual browser check.
- Document third-party asset license/provenance.
- Do not hide visual defects behind a fallback or off-map chip.

---

# Required Final Report

Provide a concise evidence-based final report.

## Baseline and Root Causes

- Actual starting commit and worktree
- Why roads were absent
- Why the marker was not a real truck
- Why annotations flickered
- Why camera framing was weak

## Implemented

- Basemap documentation/configuration
- Truck marker asset and registration
- Status/selection treatment
- Incremental annotation coordinator
- Async update serialization/coalescing
- Marker interpolation or documented atomic-update choice
- Camera modes and recenter behavior
- Overlay/list cleanup

## Annotation Operation Evidence

Provide the operation counts for ten normal position updates:

```text
image registrations:
symbol additions:
symbol updates:
symbol removals:
planned-route additions/updates/removals:
trail additions/updates/removals:
stop-marker additions/removals:
global symbol clears:
global line clears:
global circle clears:
camera moves caused by polling:
```

## Visual Verification

Report separately:

```text
Roads visibly rendered: PASS/FAIL/BLOCKED
Real truck icon rendered on map: PASS/FAIL/BLOCKED
Heading rotation visually correct: PASS/FAIL/BLOCKED
Selected state visibly distinct: PASS/FAIL/BLOCKED
Route/trail/stops stable across 10 polls: PASS/FAIL/BLOCKED
Truck marker stable across 10 polls: PASS/FAIL/BLOCKED
Manual pan respected: PASS/FAIL/BLOCKED
Fit route/recenter: PASS/FAIL/BLOCKED
Arabic RTL: PASS/FAIL/BLOCKED
```

## Validation Results

List exact commands and results for:

- Flutter generation/format/analyze/tests
- Flutter Web release build
- Browser workflow
- .NET build/tests
- EF migration drift
- Compose health
- Android if available

## Evidence Files

List screenshots and recording/telemetry evidence paths. Ensure the evidence is retained in a repository-visible or otherwise user-accessible location rather than only a disposable ignored build directory.

## Changed Files

Group by:

- Flutter map implementation
- Assets
- Tests
- Localization
- Documentation

## Timing

- Actual elapsed time per task
- Total actual elapsed time

## Known Limitations

State any MapLibre Flutter Web limitations, external style/tile dependency, or interpolation compromises honestly.

## Git Status

State whether changes are uncommitted, committed, or pushed. Do not commit/push without explicit authorization.
