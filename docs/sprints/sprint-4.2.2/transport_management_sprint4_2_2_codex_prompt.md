# Sprint 4.2.2 — Unified Live Tracking, Locale-Aware Maps, and Driver Idle Vehicle Workspace

## Role

Act as a senior full-stack engineer, Flutter/MapLibre specialist, ASP.NET Core architect, GIS engineer, QA engineer, and logistics product engineer.

Work directly in the existing `transport-management-system` repository, starting from the latest `main` branch after Sprint 4.2.1.

This is a focused map and live-tracking reliability sprint. Do not start finance, maintenance, document management, chat, route optimization, SignalR, or a real GPS-provider integration.

---

# Mission

Deliver one consistent live-tracking experience for Owners and Drivers and close the remaining map defects before moving to broader trip-management work.

The sprint must accomplish all of the following:

1. Correct Arabic labels inside the real OpenFreeMap/MapLibre basemap.
2. Introduce a tenant-configurable operational country/area used for the default fleet overview.
3. Make Owner and Driver follow behavior consistent and predictable.
4. Allow zooming while following a truck without stopping follow mode.
5. Smooth truck-marker and camera motion without fabricating telemetry.
6. Keep the Driver’s assigned truck and its map visible even when no trip is active.
7. Reject out-of-order live positions from the current-position projection.
8. Replace false-positive map acceptance evidence with real canvas/map verification.

Reliability, data integrity, and truthful validation are more important than adding features.

---

# Confirmed baseline facts

Treat these as confirmed starting conditions, but verify their call paths before editing:

- The latest reviewed Sprint 4.2.1 commit was `5bd5cac`.
- The user manually verified that selecting a truck correctly recommends/selects its linked default Driver.
- Therefore, default-Driver selection is **working product behavior** and must be preserved with regression coverage. It is not a product defect.
- The Sprint 4.2.1 browser report recorded `defaultDriverUi: false` only because Selenium could not reliably operate the Flutter dropdown and used an API fallback. Keep this documented as a test-harness limitation; do not redesign working assignment behavior merely to satisfy Selenium.
- Arabic basemap names are still visibly reversed or incorrectly shaped in the real map.
- The Sprint 4.2.1 files named `arabic-rtl-four-city-map.png` and `english-ltr-four-city-map.png` show a trip-details page rather than an actual rendered fleet map. They are not valid basemap-label evidence.
- The Owner map currently treats mouse-wheel/pointer-signal zoom as a manual interaction that pauses follow mode.
- Owner recenter/follow currently requests a local-truck camera plan that forces zoom `13.5`.
- The Driver map centers with `newLatLng`, preserving its current zoom, so it feels smoother than the Owner map.
- The Driver UI returns an empty `NO_ACTIVE_TRIP` state before building the map.
- The backend returns a truck without an active trip only when a post-trip `DriverTruckSession` still exists; a Driver linked as a truck’s default Driver may otherwise receive no truck/map projection.
- Flutter uses `maplibre_gl 0.27.1`; the Web wrapper loads MapLibre GL JS `6.4.1`.
- The configured development basemap is OpenFreeMap Liberty.

If repository state differs, document the exact difference in the implementation plan before changing code.

---

# Mandatory working rules

## Repository and data safety

- Inspect `git status`, branch, recent commits, Sprint 4.2.1 plan/evidence, README, architecture docs, migrations, and existing tests before implementation.
- Preserve all user changes and unrelated files.
- Do not reset, discard, or overwrite unrelated work.
- Do not commit or push.
- Do not modify `.env`, credentials, retained PostgreSQL data, or Docker volumes.
- Never inject smoke-test clients, trucks, Drivers, trips, or users into the user’s existing tenant.
- Prefer test fixtures and isolated databases.
- If browser validation needs real records, use a uniquely named disposable tenant in an isolated Compose project and completely remove it afterward.
- Record retained-data counts before and after and prove that existing tenant data was unchanged.
- Any migration must be additive, safe for existing rows, tenant-safe, and reversible.
- Never invent coordinates, country settings, Driver links, or vehicle assignments for legacy rows.

## Required implementation plan

Before editing production code, create:

`docs/sprints/sprint-4.2.2/SPRINT4_2_2_IMPLEMENTATION_PLAN.md`

The plan must contain:

- baseline and reproduction evidence;
- root cause for each defect;
- architecture decisions and rejected alternatives;
- task checklist with acceptance criteria;
- migration/data-safety strategy;
- testing matrix;
- actual active elapsed time for every task;
- final result and deferred work.

Update it throughout implementation. Do not invent task times afterward.

---

# Workstream 1 — Real Arabic basemap-label correction

## Problem

Arabic Flutter widgets are correctly RTL, but Arabic names drawn inside the MapLibre canvas are reversed or incorrectly shaped. The previous sprint verified the renderer version but did not reproduce or correct the visible defect.

OpenFreeMap Liberty uses bilingual label expressions that commonly concatenate `name:latin` and `name:nonlatin` in one `text-field`. The implementation must investigate whether this mixed-direction expression is the actual cause in the current runtime.

## Prohibited fixes

- Do not reverse Arabic strings manually.
- Do not preprocess tile strings character by character.
- Do not alter Flutter’s application `Directionality` to compensate for canvas text.
- Do not claim success because MapLibre documentation says the renderer supports Arabic.
- Do not rename a non-map screenshot as map evidence.
- Do not switch back to the old country-only demo style.
- Do not remove OpenFreeMap attribution.
- Do not blindly enable the deprecated RTL plugin without proving that the verified runtime requires it.

## Required implementation

1. Reproduce the reversed Arabic label on the actual dashboard or route-planner map before modifying code.
2. Record:
   - actual runtime MapLibre GL JS version;
   - style URL and style version;
   - glyph URL and font stack;
   - exact symbol-layer IDs and `text-field` expressions responsible;
   - raw feature properties used for at least one affected city.
3. Implement locale-aware basemap label expressions:
   - Arabic application locale must prefer a correctly shaped Arabic/local-script name.
   - English application locale must prefer the Latin/English name.
   - Avoid concatenating Latin and Arabic inside one label when that causes incorrect bidirectional rendering.
   - Use a readable fallback chain when the preferred property is absent.
4. The solution may use versioned local/custom style JSON files or controlled runtime style transformation, but it must be deterministic, documented, testable, and compatible with the configurable tile/style provider architecture.
5. Do not fetch and mutate the remote style on every polling cycle.
6. If a custom style is stored in the repository, preserve remote vector-tile, sprite, and glyph URLs correctly and document how the style is maintained.
7. Switching application locale may intentionally reload/swap the style once, but it must restore:
   - current camera target and zoom;
   - selected truck;
   - follow/free/overview mode;
   - route and trail visibility;
   - truck markers and images.
8. A language change must not create duplicate annotations or leave stale managers/controllers.

## Required visual cases

Verify these names inside the real map canvas at useful zoom levels:

- `حمص`
- `دمشق`
- `حلب`
- `بيروت`

Also verify:

- one Arabic road name;
- one mixed Arabic/Latin or road-number case;
- corresponding English labels after switching to English.

Expected result:

- correct visual order;
- connected Arabic glyph shaping;
- no double reversal;
- no separated letters caused by missing glyphs;
- no regression in English labels;
- no regression in routes, stops, truck images, selection, camera, or attribution.

If a platform-specific limitation remains after a documented investigation, show a readable Latin-only fallback on that platform rather than broken Arabic. This is an explicit last-resort fallback and must not be reported as full Arabic success.

---

# Workstream 2 — Tenant-configurable operational country/area

## Product goal

When the Owner opens the fleet dashboard or returns to fleet overview, the initial map must show the country/operational area where the company works, together with its connected trucks.

The map must not start tightly zoomed on the first truck, and no country may be hardcoded because the product is multi-tenant SaaS.

## Tenant map preferences

Introduce an Owner-managed, tenant-scoped map preference containing the minimum durable data required for a deterministic overview, such as:

- operational country code using ISO 3166-1 alpha-2;
- display label snapshot when useful;
- south/west/north/east bounds;
- optional center fallback;
- optional validated overview zoom fallback;
- updated timestamp and actor/audit metadata consistent with the existing architecture.

Prefer storing explicit validated geographic bounds so the dashboard does not call an external geocoder every time it opens.

The exact entity/API shape may follow the existing company-preference architecture, but it must be:

- tenant isolated;
- Owner-only for mutation;
- safe for existing tenants with no preference;
- language-neutral in storage;
- validated for latitude/longitude ranges and bound ordering;
- compatible with countries crossing unusual longitude boundaries or documented if that case is deferred.

## Settings UX

Add a localized Owner setting for operational country/area:

- search/select a country or operational area;
- preview the resulting bounds on the real map;
- save explicitly;
- change or clear the setting;
- show a clear fallback explanation when no area is configured.

Reuse the existing configurable geocoding abstraction where appropriate. If country bounds are resolved externally, resolve them only during explicit setup/change and persist the result. Provide a deterministic provider for tests.

Do not introduce a mandatory paid provider.

## Fleet-overview camera policy

Implement one shared policy with this priority:

1. If tenant operational bounds exist, use them as the base overview.
2. Include all currently connected trucks that are inside those bounds.
3. If connected trucks are outside the configured area, expand the overview enough to include them and expose a small localized cross-border/outside-area indication; do not silently hide them.
4. If no operational bounds exist but connected trucks exist, fit all connected trucks with padding and clamp the result to a country/regional overview zoom rather than zooming closely into one truck.
5. If neither bounds nor connected trucks exist, use the existing configurable regional fallback.

Additional rules:

- Compute the camera from viewport size and bounds; do not assume one desktop resolution.
- Account for side panels and RTL/LTR panel placement.
- Polling must never refit the fleet overview automatically.
- Initial overview may run once after the map/style is ready.
- Add a localized `Fleet overview` / `عرض الأسطول` button that returns to this policy from selected-truck, free-pan, follow, or route-overview modes.
- Clearing truck selection must return to free mode but must not unexpectedly jump the camera unless the user presses Fleet overview.
- Selecting a truck may transition to local follow view.
- Showing the full route remains an explicit action.

---

# Workstream 3 — Unified Owner and Driver follow semantics

## Goal

Owner and Driver maps must follow the same interaction contract even if their overlays differ.

Centralize the camera/follow policy in a reusable controller/state object instead of maintaining conflicting rules in two screens.

## Required interaction modes

Use explicit modes equivalent to:

- `fleetOverview`;
- `followVehicle`;
- `freeExplore`;
- `routeOverview`.

## Required gesture behavior

| Interaction | Required result |
|---|---|
| Select a truck | Enter follow mode and center it at a sensible local zoom once |
| Mouse-wheel zoom while following | Keep follow mode and preserve the new zoom |
| Touchpad/pinch zoom without intentional pan | Keep follow mode and preserve the new zoom |
| Drag/pan away from the truck | Enter free-explore mode |
| Explicit rotate/pitch exploration, if enabled | Enter free-explore mode |
| Programmatic camera update | Must not be classified as a user gesture |
| New position while following | Animate center to the truck without changing zoom |
| New position while free/route overview | Update marker only; do not move camera |
| Resume follow | Center the truck while preserving a reasonable current zoom |
| Fleet overview | Fit tenant operational area and connected fleet |
| Full route | Fit the selected route once; do not refit on polling |

## Implementation constraints

- Remove the blanket rule that every `PointerSignal` pauses follow.
- Distinguish wheel/pinch zoom from pan intent as reliably as the Flutter Web/MapLibre APIs permit.
- Do not reset zoom to `13.5` on every tracking update.
- A local follow update should change center/bearing only as intended, not overwrite the user’s zoom.
- Prevent `onCameraMove`, `onCameraIdle`, and asynchronous programmatic animations from racing and accidentally changing modes.
- Keep an obvious localized follow-state control/icon so the user always knows whether follow is active.
- Preserve manual-pan protection.
- Preserve zero polling camera moves when not in follow mode.

---

# Workstream 4 — Smooth marker and camera interpolation

## Goal

Movement should appear continuous without creating fake telemetry or persisting interpolated positions.

## Requirements

- Animate the visible truck marker from the previous accepted coordinate to the newest accepted coordinate.
- Derive animation duration from the source timestamps/poll cadence and clamp it to a safe UI range.
- The animation must finish before or near the next expected update and must never accumulate an unbounded queue.
- Use latest-wins cancellation: when a newer accepted position arrives, cancel/retarget the current visual interpolation from the current visual point.
- Interpolated UI frames must not be saved to the backend, history, trail, audit log, or notification engine.
- Preserve the real reported speed, timestamp, heading, trip progress, and ETA.
- Interpolate heading through the shortest angular direction and avoid abrupt `359° → 0°` spins.
- Keep the circular truck photo/icon registered and stable; animation must not flash to the fallback icon.
- In follow mode, camera center motion must use compatible easing and must preserve zoom.
- In free or overview modes, only the marker moves.
- Offline or stale vehicles must not continue visually moving after their last accepted position.
- Large intentional simulator reset/seed jumps must snap or start a new visual segment rather than animating across a country.

Add deterministic animation/controller tests using fake time. Do not rely only on screenshot inspection.

---

# Workstream 5 — Monotonic live-position projection

Real tracking providers may deliver delayed or out-of-order packets. The current marker must never move backward in time.

## Required behavior

- Compare incoming telemetry by authoritative recorded timestamp and stable tie-breaking rules.
- The live/current-position projection accepts only a position newer than the current accepted position.
- Older packets may remain in immutable history when valid, but they must not replace the current marker, current speed, current heading, ETA, geofence state, or offline freshness clock.
- Duplicate packets must be idempotent.
- Tenant, truck, trip, tracking-run, and route-revision associations must remain correct.
- Simulator reset or a new tracking run must use explicit run/revision semantics rather than bypassing chronology accidentally.
- Document how clock skew and equal timestamps are handled.

Add backend integration tests for:

- newer then older packet;
- duplicate packet;
- equal timestamp conflict;
- new tracking run/reset;
- cross-tenant attempt;
- history order versus current projection.

---

# Workstream 6 — Driver truck map without an active trip

## Product rule

A Driver who has a current/assigned truck must be able to see that truck on the map even when no trip is assigned.

Trip assignment and vehicle association are related but not identical concepts.

## Required backend resolution policy

Resolve the Driver’s visible/current truck in this order:

1. Truck assigned to the Driver’s current active trip.
2. Truck in the Driver’s active vehicle session.
3. A single active truck whose linked/default Driver is this Driver.
4. No truck.

If data contains multiple valid default/current trucks for one Driver, do not silently choose the first row. Return an explicit language-neutral ambiguity state and log the invariant violation. Provide an Owner-facing way to resolve it using existing truck/Driver management, or enforce a safe uniqueness rule after auditing legacy data.

Do not fabricate an active trip or route to make the map visible.

## Required workspace states

Support clear states equivalent to:

- `ACCOUNT_NOT_LINKED`;
- `NO_VEHICLE_ASSIGNED`;
- `VEHICLE_ASSIGNMENT_AMBIGUOUS`;
- `VEHICLE_ASSIGNED_IDLE`;
- `TRIP_ASSIGNED_NO_TELEMETRY`;
- active-trip tracking states;
- `POST_TRIP_VEHICLE`.

The exact names may follow existing conventions, but semantics must be explicit and covered by tests.

## Driver idle-vehicle UI

When a truck exists without an active trip, show:

- Driver identity;
- truck photo/avatar;
- plate and fleet code;
- truck operational status;
- map with current or last known position;
- online/current/stale/offline status;
- last update time and age;
- speed and heading when meaningful;
- a localized `No active trip` informational state;
- refresh action;
- no route, ETA, progress, pickup, delivery, or trip action buttons.

If the truck has no telemetry, keep the truck card visible and show actionable guidance rather than replacing the entire page with `No assigned trip`.

After trip completion, the map must remain available while the vehicle association/session remains active.

When the Owner reassigns or unlinks the truck, the Driver workspace must converge through polling without logout/login.

## Authorization

- A Driver may access only their own resolved truck/workspace.
- A Driver must not enumerate other tenant trucks or positions.
- Owner mutation remains tenant-scoped and authorized.
- Photo endpoints must preserve the same authorization rules.

---

# Workstream 7 — Preserve working default-Driver selection

The user manually confirmed that selecting a truck correctly selects/recommends its linked default Driver.

Therefore:

- Preserve this behavior in trip planner and trip-detail assignment.
- Do not rewrite it unless a demonstrated regression requires a minimal correction.
- Keep no-default behavior: when a truck has no linked Driver, leave Driver empty.
- Keep ineligible-default behavior: explain why the linked Driver cannot be selected and require an explicit alternative.
- Keep manual override behavior without mutating the truck’s permanent default relation.
- Add or retain focused widget/domain regression tests.
- If Selenium still cannot operate the Flutter dropdown, report that as an automation limitation. Do not report the product feature as failed, and do not use a backend API fallback as proof that the UI passed.

---

# Workstream 8 — Localization and UX consistency

- Add all new Owner/Driver map modes, operational-area settings, tracking-quality states, ambiguity guidance, and buttons to English and Arabic ARB files.
- Verify Arabic RTL and English LTR layouts.
- Use locale-aware date/time and duration formatting.
- Do not show raw enum values, GUIDs, error codes, country codes, or backend English messages to users.
- Keep stable backend codes language-neutral and translate them in Flutter.
- Ensure side-panel padding and map controls work in both RTL and LTR.
- Preserve visible map attribution.

---

# Automated validation

## Backend

Run and pass:

- full `.NET` build with zero warnings and zero errors;
- all existing backend tests;
- tenant map-preference authorization and isolation tests;
- bounds/coordinate validation tests;
- Driver idle-truck resolution tests for every priority state;
- multiple-truck ambiguity tests;
- live-position monotonicity/idempotency tests;
- trip and vehicle-session regression tests;
- notification/geofence regression tests;
- EF Core migration/model drift validation.

## Flutter

Run and pass:

- `flutter analyze` with zero issues;
- all existing Flutter tests;
- follow-state transition tests;
- wheel/pinch zoom preserves follow tests where the platform abstraction allows it;
- pan pauses follow tests;
- programmatic camera does not pause follow tests;
- zoom preservation tests;
- fleet-overview camera-policy tests;
- country/operational-area settings tests;
- deterministic marker interpolation tests;
- stale/offline animation-stop tests;
- Driver idle-truck workspace tests;
- Arabic RTL and English LTR tests;
- working default-Driver selection regression tests;
- Flutter Web release build.

Do not delete, weaken, or skip existing tests to produce a green result.

---

# Mandatory real-browser acceptance

Use real independent Owner and Driver browser profiles against an isolated disposable tenant.

## Scenario A — Operational country overview

1. Configure an operational country/area as Owner.
2. Reload the dashboard.
3. Confirm the initial camera displays the configured country/area rather than zooming to the first truck.
4. Confirm all connected trucks are visible or the bounds expand to include any truck outside the area.
5. Select a truck and enter follow mode.
6. Press Fleet overview and confirm the country/fleet bounds return.
7. Resize the viewport and verify padding/bounds remain correct in Arabic and English.

## Scenario B — Owner follow gestures

1. Select a moving truck.
2. Confirm follow is visibly active.
3. Change zoom using the mouse wheel at least three times.
4. Allow at least five live position updates.
5. Prove the truck remains centered and the chosen zoom is preserved.
6. Drag the map away and prove follow pauses.
7. Allow more updates and prove the camera remains still while the marker moves.
8. Resume follow and prove the camera recenters without resetting to an unwanted fixed zoom.
9. Show full route and confirm polling does not refit it.

## Scenario C — Driver idle vehicle

1. Log in as a Driver linked to one active truck but with no active trip.
2. Confirm truck identity/photo/status and map are visible.
3. Confirm current/stale/offline and last-update information is correct.
4. Confirm no route, ETA, trip progress, or trip action is fabricated.
5. Assign a trip in the Owner profile and confirm the already-open Driver workspace converges to the assigned-trip state.
6. Complete the trip and confirm the Driver still sees the truck map afterward.

## Scenario D — Smoothness and chronology

1. Run at least 30 position updates in Owner and Driver views.
2. Capture movement showing stable truck imagery and smooth visual interpolation.
3. Inject a valid older telemetry packet in the isolated test environment.
4. Prove history may include it but the live marker/current projection does not move backward.
5. Confirm stale/offline state stops continued visual motion.

## Scenario E — Real Arabic map labels

1. Open the actual Dashboard or route map containing a MapLibre canvas/platform view.
2. Switch to Arabic.
3. Navigate to map locations displaying `حمص`, `دمشق`, `حلب`, and `بيروت`.
4. Capture screenshots that visibly include the map, labels, attribution, and enough surrounding geography to prove they are basemap labels.
5. Inspect the screenshots manually at original resolution.
6. Switch to English and capture the same map area.
7. Confirm camera/selection/follow state survives the locale change as designed.

## Scenario F — Default-Driver regression

1. In a real Owner browser, select a truck with a valid linked/default Driver.
2. Confirm the correct Driver appears automatically.
3. Confirm a truck with no default leaves Driver empty.
4. Confirm manual override remains possible.

If the automation framework cannot reliably manipulate the Flutter dropdown, retain focused widget tests and record the harness limitation. Since the user has manually verified the behavior, do not classify the product as broken without reproducible product evidence.

---

# Evidence and observability

Create:

`docs/evidence/sprint4_2_2/`

Include:

- exact baseline reproduction notes;
- real Arabic basemap before/after screenshots;
- matching English map screenshot;
- operational-country settings screenshot;
- country/fleet overview screenshot;
- Owner wheel-zoom-follow sequence;
- Owner pan-paused-follow sequence;
- Driver idle-truck map screenshot;
- Driver assigned-trip and post-completion screenshots;
- smooth-motion browser/video evidence if practical, otherwise timestamped frame sequence and telemetry log;
- out-of-order packet database/API evidence;
- map operation and camera-mode counters;
- browser result JSON;
- automated validation results;
- migration/data-safety evidence;
- retained-data before/after counts.

Record at least:

- map instances created/disposed;
- style loads and locale-triggered style swaps;
- image registrations;
- marker additions/updates/removals;
- interpolation starts/completions/cancellations/snaps;
- accepted/rejected/duplicate live positions;
- programmatic camera moves by reason;
- camera moves while free mode;
- follow pauses by gesture type;
- zoom changes that preserved follow;
- global annotation clears;
- recoverable and fatal map errors.

Expected during normal polling:

- global annotation clears: `0`;
- camera moves while free/route-overview mode: `0`;
- truck-image re-registration per poll: `0`;
- duplicate current-position regressions: `0`;
- fatal map errors caused by annotation updates: `0`.

Evidence filenames must describe their actual contents. Do not retain misleading files from failed or unrelated pages in the final evidence index.

---

# Documentation

Update:

- `README.md`;
- `docs/architecture.md`;
- environment-variable/configuration documentation;
- `docs/sprints/README.md`;
- `docs/sprints/sprint-4.2.2/SPRINT4_2_2_IMPLEMENTATION_PLAN.md`.

Document:

- locale-aware style strategy;
- operational-area preference and fallback policy;
- shared camera/follow state machine;
- interpolation versus authoritative telemetry;
- monotonic current-position rule;
- Driver truck-resolution priority;
- data migration and rollback;
- platform limitations and browser coverage.

Do not include credentials, tokens, real customer data, or secrets.

---

# Definition of done

Sprint 4.2.2 is complete only when:

- Arabic basemap names are visibly correct in a real map, not merely in Flutter widgets.
- Evidence screenshots genuinely contain the rendered map and required city labels.
- Each tenant can configure its operational country/area without hardcoded geography.
- The default Owner fleet camera presents that country/area and connected trucks.
- A Fleet overview action restores the operational overview.
- Mouse-wheel zoom no longer disables follow mode.
- Follow updates preserve the user’s zoom.
- Drag/pan pauses follow reliably.
- Owner and Driver maps use the same follow-state contract.
- Marker and follow-camera movement are smooth and latest-wins.
- Stale/offline vehicles stop visual motion.
- Older telemetry cannot replace the live current position.
- A Driver with an assigned/current truck can see it without an active trip.
- No trip route, ETA, or action is fabricated in idle-vehicle state.
- The map remains available after trip completion while the truck association/session remains valid.
- Working default-Driver selection remains intact.
- Existing data, `.env`, credentials, and retained PostgreSQL volumes remain unchanged.
- No smoke-test data remains in the user’s tenant.
- All available builds and automated tests pass.
- Real-browser Owner and Driver acceptance passes or any unavailable platform is reported honestly.
- Documentation, evidence, and actual elapsed-time records are complete.
- No commit or push was performed.

---

# Final response format

When finished, report:

1. Root causes found.
2. Arabic style/renderer solution and exact label properties used.
3. Operational-country preference design and fallback behavior.
4. Shared follow/camera behavior implemented.
5. Marker interpolation and chronology rules.
6. Driver idle-vehicle behavior.
7. Default-Driver regression result.
8. Migration details and legacy-data handling.
9. Exact backend/Flutter test totals and build results.
10. Real-browser scenarios completed.
11. Map, camera, interpolation, and telemetry counters.
12. Data-preservation proof.
13. Environment/platform limitations.
14. Actual active elapsed time per task and total.
15. Paths to plan and evidence.
16. `git status` summary confirming no commit or push.

Be explicit about anything not tested. Compilation is not visual validation, and API fallback is not proof that a Flutter UI interaction passed.
