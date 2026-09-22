# Codex Implementation Prompt — Sprint 3.1: Map Reliability and Honest Verification

## Role

Act as a senior full-stack engineer and pragmatic software architect working inside the existing `transport-management-system` repository.

Your job is to inspect the current implementation first, then complete a focused hardening sprint. Do not rebuild the project, replace the existing architecture, or expand the product into unrelated features.

The repository is expected to contain:

- ASP.NET Core backend
- PostgreSQL and Entity Framework Core
- Flutter application targeting Web and Android
- Docker Compose for the local backend stack
- Sprint 3 localization, tracking abstraction, simulator, fleet dashboard, and MapLibre integration

The current local backend is expected to run at:

```text
http://localhost:5080
```

The current repository is:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

## Sprint Name

**Sprint 3.1 — Map Reliability and Honest Verification**

## Primary Goal

Make the fleet map reliably display a real geographic base map when correctly configured, fail clearly and recoverably when it cannot load, and create verification that distinguishes the real MapLibre map from the tile-independent fallback.

The sprint must also close two small gaps found during Sprint 3 review:

1. Expose the already-supported simulator commands in the development-only UI.
2. Prevent uncontrolled position-history growth caused by saving unchanged positions during repeated polling.

This is a hardening sprint, not a feature-expansion sprint.

---

## Known Findings to Verify

Do not blindly accept these statements. Confirm them against the current repository and document what you find.

1. `MAP_STYLE_URL` is currently read through `String.fromEnvironment`, so it is a compile-time Flutter value.
2. If `MAP_STYLE_URL` is empty, the application shows a tile-independent fallback instead of MapLibre.
3. The existing browser smoke test locates keys such as `truck-marker-*`, which belong to the fallback implementation rather than the real MapLibre map.
4. The current implementation does not reliably transition to a visible error/fallback state if a non-empty MapLibre style URL fails after map initialization.
5. Backend simulator commands for speed, step, online, and offline may exist without corresponding controls in the Flutter development UI.
6. Position records may be inserted repeatedly even when a paused truck has not changed position.

Before changing code:

- Inspect the repository and working tree.
- Read `README.md`, `docs/architecture.md`, the Sprint 3 plan, current map/dashboard code, tracking provider code, simulator endpoints, tests, Compose files, and Flutter launch/build instructions.
- Preserve unrelated user changes.
- Do not use destructive Git operations.
- Do not commit or push unless explicitly requested by the user.

---

## Mandatory Deliverable: Implementation Plan

Create or update:

```text
docs/sprints/sprint-3.1/SPRINT3_1_IMPLEMENTATION_PLAN.md
```

It must contain:

- Baseline findings
- Exact root cause of the missing real map
- Files/components to change
- Task breakdown
- Risks and mitigations
- Test plan
- Acceptance-criteria checklist
- Deferred items
- Actual elapsed time per task
- Total actual sprint time

Update the plan as work progresses. Do not fill timing with estimates presented as actual time.

---

# Required Work

## 1. Establish a Truthful Map State Model

Replace any implicit two-way behavior with an explicit state model that can represent at least:

```text
unconfigured
loading
loaded
failed
fallback
```

The exact implementation may use an enum, sealed class, state object, or the project's existing state-management convention.

Requirements:

- A non-empty style URL must not automatically mean that the map loaded successfully.
- Treat MapLibre as loaded only after the appropriate MapLibre style/map-ready callback fires.
- Add a reasonable configurable loading timeout.
- If initialization or style loading fails or times out, display a localized failure state.
- The failure state must offer:
  - **Retry map**
  - **Use fallback**
- The user must never be left with a silently blank map panel.
- Do not claim that individual tiles loaded if the available MapLibre API only proves that the style loaded. Name statuses and tests precisely.
- Dispose timers, controllers, and listeners safely.
- Prevent state updates after widget disposal.

If the current MapLibre Flutter package does not expose every required error callback, implement the strongest reliable detection supported by the package and document the limitation honestly. Do not invent success signals.

## 2. Fix and Document Map Configuration

Ensure the real map can be launched and built reproducibly.

At minimum, support and document:

```text
API_BASE_URL
MAP_STYLE_URL
TRACKING_POLLING_INTERVAL_SECONDS
MAP_LOADING_TIMEOUT_SECONDS
```

Requirements:

- Keep secrets out of source control.
- Do not hard-code a paid provider key.
- Keep the map style/tile provider replaceable.
- If compile-time `--dart-define` configuration remains the correct approach, document it explicitly and make the launch/build commands copy-pasteable.
- Clearly explain that Docker Compose currently serves the backend, not necessarily Flutter Web, unless you intentionally add and validate a web-serving container.
- Provide a development example using a legal public demo style or a local deterministic test style. Label public demo infrastructure as non-production.
- Add or update an example configuration/launch script only if it matches existing repository conventions.
- A missing style URL must produce an intentional localized “map not configured” state, not pretend to be a real map.

Do not migrate to Google Maps or another map SDK in this sprint.

## 3. Implement Reliable Error, Retry, and Fallback UX

Provide localized English and Arabic UI for:

- Map not configured
- Loading map
- Map ready/style loaded
- Map failed to load
- Retry map
- Use simplified fallback
- Fallback mode indicator

Requirements:

- Arabic layout must remain correct in RTL.
- English layout must remain correct in LTR.
- Fallback mode must be visually identified as a simplified tracking view, not a geographic map.
- Truck data and details must remain usable in fallback mode.
- Retry must create a genuine new loading attempt and must not merely toggle a label.
- Switching locale must not corrupt or unnecessarily recreate tracking state.

## 4. Separate Real-Map Tests from Fallback Tests

The existing test must no longer be allowed to pass as proof of MapLibre merely because fallback markers are visible.

Create separate verification paths:

### A. Fallback test

Run with no map style URL or with fallback explicitly selected and verify:

- Simplified fallback is visible.
- Fallback mode is clearly labeled.
- Truck markers/details are displayed.
- Localization and RTL/LTR still work.

### B. Real MapLibre test

Run with a valid deterministic map style and verify, at minimum:

- The MapLibre widget/canvas is present.
- The MapLibre style-loaded callback or equivalent real readiness signal fired.
- The fallback widget and fallback-only marker keys are absent.
- The UI exposes a testable non-visual status indicating the real style loaded; this status must be driven by the genuine MapLibre callback, not by a timer or configuration presence.
- Geographic truck annotations/symbols/circles are added after map/style readiness.
- Selecting a truck exposes the expected truck details.

### C. Failure and retry test

Run with a deliberately invalid or unreachable style URL and verify:

- Loading changes to failed after a real error or timeout.
- A localized error is visible.
- The user can enter fallback mode.
- Retry starts a new attempt.

### D. Manual visual evidence

Because a Flutter widget assertion alone cannot prove that geographic tiles visibly rendered, perform a browser smoke test and capture evidence of the actual geographic base map.

The final report must state separately:

- MapLibre compiled
- MapLibre widget initialized
- Style-ready callback fired
- Geographic base map was visually observed
- Fallback was tested

Never combine these into an unsupported statement such as “the map was fully verified” if one of them was not proven.

If network restrictions prevent external tiles from loading, use a deterministic local test fixture if practical. Otherwise report the blocked visual step clearly; do not substitute the fallback and call it MapLibre verification.

## 5. Complete the Development-Only Simulator Controls

Inspect the backend simulator API first and reuse its existing contract where sound.

Expose all already-supported simulator operations in the development-only Flutter control panel:

- Start
- Pause
- Resume
- Stop
- Reset
- Step
- Simulation speed
- Set truck online
- Set truck offline

Requirements:

- The panel must remain unavailable in production builds or production environments according to the project's existing environment convention.
- Provide clear feedback for successful and failed commands.
- Localize all new labels and messages in English and Arabic.
- Do not create a second simulator implementation in Flutter.
- Do not add real GPS-provider integration.

## 6. Stop Uncontrolled Position-History Growth

Inspect where position history is currently persisted and determine whether HTTP polling itself causes new database rows or merely reads positions. Document the exact result.

If unchanged positions are being stored repeatedly:

- Do not insert a new history row solely because the dashboard polled again.
- Persist only when a meaningful telemetry event occurs, such as:
  - coordinates changed beyond a defensible tolerance,
  - online/offline state changed,
  - speed/heading changed meaningfully,
  - simulator step/tick produced a new position,
  - or a configurable heartbeat interval elapsed.
- Preserve correct tenant isolation.
- Preserve or improve efficient retrieval of the latest truck position.
- Add tests proving paused stationary trucks do not create a new row on every read/poll.
- Add tests proving movement and meaningful status changes are persisted.

If the current code already avoids this problem, do not redesign it. Add a regression test and document the verified behavior.

Do not build a full telemetry retention, partitioning, archiving, or time-series subsystem in Sprint 3.1. Record those as deferred production-hardening work.

## 7. Security and Multi-Tenancy

For every changed or added endpoint/query:

- Enforce authentication.
- Derive tenant/company scope from the authenticated user/context, not from a trusted client-supplied company ID.
- Prevent cross-tenant access to current positions, history, dashboard summaries, and simulator commands.
- Keep simulator mutation endpoints development-only.
- Add or retain integration tests for tenant isolation.

Do not weaken authorization for test convenience.

## 8. Documentation

Update at least:

```text
README.md
docs/architecture.md
docs/sprints/sprint-3.1/SPRINT3_1_IMPLEMENTATION_PLAN.md
```

Documentation must include:

- How the map state model works
- How to run Flutter Web with a real style URL
- How to run fallback mode intentionally
- How failure/timeout/retry works
- The difference between style readiness and visual tile verification
- How the development simulator controls are gated
- Position-history write behavior
- Exact automated and manual validation performed
- Known limitations and deferred items

Correct any Sprint 3 documentation that currently overstates what the browser smoke test verified.

---

# Testing and Validation

Run the strongest relevant validation supported by the repository and environment.

## Backend

- Restore/build
- All existing tests
- New integration/unit tests
- EF Core migration drift check
- Tenant-isolation tests
- Position-history deduplication/regression tests
- Compose health checks

Create a database migration only if the data model genuinely changes. Do not generate an empty or unnecessary migration.

## Flutter

- Dependency resolution
- Localization generation
- Formatter
- Static analyzer with no new warnings
- Existing tests
- New widget/unit tests for map states and simulator controls
- Web release build
- Android build only if a valid Android SDK exists

Do not mark Android validation as passed when the SDK/device is unavailable. Report the environment limitation exactly.

## Browser

Validate all of the following where the environment permits:

1. Login
2. English/LTR dashboard
3. Arabic/RTL dashboard
4. Real MapLibre state using a valid style
5. Visible geographic base map
6. Truck annotations and details
7. Invalid-style failure state
8. Retry behavior
9. Manual switch to fallback
10. Development simulator operations
11. Pause and verify location/history stability
12. Resume/step and verify movement
13. Online/offline status changes
14. Logout

Use Firefox/GeckoDriver if Chrome is unavailable. Record the actual browser used.

Do not let a fallback-only browser test satisfy the real-map acceptance criteria.

---

# Acceptance Criteria

Sprint 3.1 is complete only when all applicable items below are proven:

- [ ] Root cause of the missing map is documented from the actual code/environment.
- [ ] A copy-pasteable command launches Flutter Web with a real configured style.
- [ ] Map states distinguish unconfigured, loading, loaded, failed, and fallback.
- [ ] A blank map cannot silently remain indefinitely.
- [ ] Failure provides localized Retry and Use Fallback actions.
- [ ] Fallback is clearly labeled and is not presented as a geographic map.
- [ ] Real MapLibre verification does not depend on fallback-only widget keys.
- [ ] A genuine MapLibre readiness callback drives the real-map loaded test state.
- [ ] Browser evidence confirms whether a geographic base map was actually visible.
- [ ] English/LTR and Arabic/RTL work in the map states and controls.
- [ ] All existing backend simulator operations are usable from the development-only UI.
- [ ] Stationary/paused trucks do not produce a position-history row on every poll/read.
- [ ] Movement and meaningful status changes remain persisted.
- [ ] Tenant isolation remains enforced and tested.
- [ ] Backend build and tests pass.
- [ ] Flutter analyzer and tests pass.
- [ ] Flutter Web release build passes.
- [ ] Compose services are healthy.
- [ ] Documentation accurately describes what was and was not verified.
- [ ] Actual elapsed time is recorded per task and in total.

If an acceptance criterion cannot be completed because of a genuine environment limitation, mark it **Blocked**, explain the evidence, and do not mark Sprint 3.1 fully complete.

---

# Explicitly Out of Scope

Do not implement any of the following in Sprint 3.1:

- Finance, expenses, payments, receivables, or profitability
- Maintenance or document management
- Real GPS hardware or vendor integration
- Traccar, Wialon, Teltonika, or another real provider
- SignalR/WebSocket migration
- Route optimization
- Geofencing or speed alerts
- Full route-history playback
- Production-scale telemetry retention/partitioning
- Replacing MapLibre with Google Maps
- Large UI redesign unrelated to the map reliability work

---

# Engineering Constraints

- Follow the repository's existing architecture and naming conventions.
- Prefer small, reviewable changes.
- Avoid duplicate abstractions.
- Do not hide errors or weaken tests to make them pass.
- Do not hard-code tenant IDs, credentials, secrets, API keys, or machine-specific absolute paths.
- Preserve backward compatibility unless a change is necessary and documented.
- Keep all user-facing strings localized through ARB resources.
- Keep error handling deterministic and testable.
- Preserve unrelated uncommitted work.
- Do not commit or push unless explicitly instructed.

---

# Required Final Report

At the end, provide a concise but evidence-based report with these sections:

## Baseline and Root Cause

- What was actually wrong
- Whether `MAP_STYLE_URL` was missing, invalid, unreachable, blocked by CORS/WebGL, or affected by another issue
- Which earlier test result was misleading and why

## Implemented

- Map-state and fallback changes
- Configuration/documentation changes
- Test separation
- Simulator UI completion
- Position-history behavior

## Validation Results

List exact commands and results for:

- Backend build/tests
- Flutter analyzer/tests/build
- EF migration drift
- Compose health
- Browser tests

Report the following as separate facts:

```text
MapLibre compiled: PASS/FAIL/BLOCKED
MapLibre widget initialized: PASS/FAIL/BLOCKED
Style-ready callback fired: PASS/FAIL/BLOCKED
Geographic base map visually observed: PASS/FAIL/BLOCKED
Fallback verified: PASS/FAIL/BLOCKED
Failure and retry verified: PASS/FAIL/BLOCKED
```

## Tests Added or Changed

- Name each important test
- Explain what it proves
- Explain what it intentionally does not prove

## Data-Growth Verification

- Rows created during a fixed paused polling period
- Rows created after movement/step
- Rows created after online/offline change

## Environment Limitations

- Android SDK/device availability
- Browser availability
- Network/tile-provider restrictions
- Any WebGL/CORS limitations

## Timing

Provide actual elapsed time per task and total sprint time.

## Changed Files

List changed files grouped by backend, Flutter, tests, and documentation.

## Deferred Items

List only genuinely deferred work; do not quietly omit incomplete acceptance criteria.

## Git Status

State whether changes are uncommitted, committed, or pushed. Do not perform commit/push without explicit instruction.
