# Sprint 3.4.1 — Trip Creation Workflow Repair

## Role

You are a senior product engineer working on an existing multi-tenant transport-management system.

Act as all of the following:

- Senior ASP.NET Core engineer
- Senior Flutter engineer
- Product designer specialized in operational workflows
- Multi-tenant SaaS architect
- QA and regression-test engineer

Your task is to repair and simplify the trip-creation workflow delivered in Sprint 3.4. This is a corrective sprint, not a feature-expansion sprint.

Do not merely make the existing buttons compile. The final workflow must be understandable and usable by a transport-company manager without technical knowledge.

---

## Repository

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Expected baseline at the start of this sprint:

`f00bcbf feat(trips): deliver sprint 3.4 operations workflow`

Before editing:

1. Pull or fetch the latest repository state.
2. Confirm the actual current commit.
3. Inspect all uncommitted changes and preserve unrelated user work.
4. Read:
   - `README.md`
   - `docs/architecture.md`
   - `docs/sprints/sprint-3.4/SPRINT3_4_IMPLEMENTATION_PLAN.md`
   - `docs/sprints/sprint-3.4/transport_management_sprint3_4_codex_prompt.md`
   - `docs/evidence/sprint3_4/README.md`
5. Inspect the existing trip domain, APIs, Flutter planner, trip details page, localization resources, integration tests, and widget tests before designing the fix.

Do not assume the paths or implementation are exactly as described below. Verify the repository first and adapt safely.

---

## Sprint Goal

Repair the trip workflow so a manager can complete this understandable sequence:

1. Enter trip information.
2. Select pickup and delivery locations.
3. calculate and inspect the cargo route.
4. Optionally select an eligible truck and driver.
5. Review a real summary.
6. Save the trip as a Draft or create and assign it.

The workflow must not silently invalidate a valid route, must not present empty or decorative steps, and must explain why a truck or driver cannot be selected.

The following real user-reported failures must be fixed:

- A route can be calculated successfully, but saving the Draft resubmits unchanged stops and invalidates the route.
- Once the route is invalidated, assignment disappears or fails with `TRIP_NOT_READY_FOR_ASSIGNMENT`.
- The current Route, Assignment, and Review steps are mostly placeholder text.
- The user can advance by clicking Next without completing meaningful work.
- Assignment is unexpectedly moved to the trip-details page instead of being performed in the Assignment step.
- Unavailable drivers and trucks are silently hidden, so the user cannot understand why assignment is impossible.
- The previous Sprint 3.4 evidence did not complete the full authenticated browser workflow.

---

## Non-Negotiable Product Principles

1. Every wizard step must have a clear purpose, visible state, and meaningful user action.
2. A Next button must never be a decorative step counter.
3. The UI must explain blockers where the user can act on them.
4. Saving unchanged data must be idempotent.
5. A valid route may be invalidated only when route-relevant input actually changes.
6. The backend remains authoritative for readiness, resource eligibility, route validity, and assignment.
7. The Flutter client must not infer operational permission from translated text.
8. Arabic and English must both be first-class experiences, including RTL layout.
9. Multi-tenant isolation and existing trip lifecycle rules must remain intact.
10. Do not add new major product domains during this corrective sprint.

---

## Mandatory Planning and Time Record

Before implementation, create:

`docs/sprints/sprint-3.4.1/SPRINT3_4_1_IMPLEMENTATION_PLAN.md`

It must contain:

- Baseline assessment
- Confirmed root causes
- Product decisions
- Backend changes
- Flutter changes
- Migration decision
- Test strategy
- Browser acceptance workflow
- Evidence plan
- Risks and rollback notes
- Task-by-task start time, end time, and active elapsed time
- Final total active elapsed time

Update the plan throughout the work. Do not invent elapsed times after completing the sprint.

---

# 1. Fix Route Invalidation Correctly

## 1.1 Confirm the regression

Reproduce and document this exact flow before changing it:

1. Create a Draft.
2. Add valid pickup and delivery stops.
3. Calculate the route.
4. Confirm `readiness.canAssign == true`.
5. Save the Draft again without changing either stop.
6. Observe whether `routePlan` becomes null or assignment becomes unavailable.

Add a regression test that fails on the baseline implementation.

## 1.2 Backend idempotency

The stop-update behavior must distinguish between:

- A semantic route-input change
- A non-route change
- A byte/formatting-only or identical resubmission

Do not clear `Trip.RoutePlan` merely because the stops endpoint was called.

Preserve the current authoritative route when the normalized route inputs are unchanged.

At minimum, route relevance must account for the same normalized values used by route fingerprinting, including:

- Stop sequence
- Stop type
- Latitude
- Longitude
- Any timing or service-duration field that the route fingerprint currently treats as route-relevant
- Route profile where applicable

Changing display-only text must not invalidate a route unless the backend routing contract genuinely depends on it.

Use one consistent server-side normalization and fingerprint strategy. Do not create competing equality rules in the domain, application service, and Flutter UI.

Required behaviors:

- Identical stop resubmission preserves `RoutePlan`.
- Changing only unrelated Draft fields preserves `RoutePlan`.
- A real coordinate change invalidates `RoutePlan`.
- Reversing pickup and delivery invalidates `RoutePlan`.
- Changing route-relevant fields invalidates readiness and requires recalculation.
- All decisions remain tenant-safe and concurrency-safe.

Append a route-invalidation event only when an existing authoritative route is actually invalidated. Do not create noisy invalidation events for identical saves.

## 1.3 Flutter dirty-state protection

The Flutter client must not call the stops update endpoint when the normalized stop values are unchanged.

However, this is only a client optimization. The backend must still be idempotent and safe if another client resubmits identical values.

After every successful save or route calculation, update the local persisted snapshot and version so later actions do not use stale data.

Prevent double submission and stale-version races.

---

# 2. Replace the Decorative Wizard with a Real Workflow

Refactor the current six-step experience into four meaningful steps.

## Step 1 — Trip Details

Editable fields:

- Client
- Cargo description
- Planned date and time
- Price, if used by the current domain
- Notes, if currently supported

Requirements:

- Use localized date and time pickers.
- Do not expose ISO timestamps.
- Show inline validation next to the field.
- The user may save an incomplete Draft without being forced to call routing or geocoding providers.
- Next must validate only what is required to meaningfully continue to locations.

## Step 2 — Pickup, Delivery, and Route

This step must contain the actual location and route work, not a placeholder summary.

It must provide:

- Pickup search
- Pickup map selection
- Pickup manual coordinates where already supported
- Delivery search
- Delivery map selection
- Delivery manual coordinates where already supported
- Immediate pickup and delivery markers
- A Calculate route or Recalculate route action inside this step
- Loading state
- Provider failure state with retry
- Map route preview
- Distance
- Estimated duration
- Route provider attribution where required
- A visible stale-route warning after a route-relevant edit

The user must not need to discover a global button elsewhere on the page.

Next is enabled only when:

- Both stops have valid coordinates.
- Pickup and delivery are not identical.
- The server has persisted the current stops.
- The authoritative current route matches those stops.

If routing fails, preserve the Draft and locations so the user can retry without re-entering data.

## Step 3 — Truck and Driver

This must be a real assignment step.

It must contain:

- Truck selector
- Driver selector
- Availability status for each candidate
- A clear explanation for disabled candidates
- Current assignment when editing or resuming
- Refresh availability action
- Explicit `Skip for now` option

The user must be able to choose one of two paths:

1. Continue with an eligible truck and driver.
2. Skip assignment and keep the trip as an unassigned Draft.

Do not tell the user to leave the wizard and assign from another page.

Do not silently omit every unavailable resource. Show active resources with localized eligibility information. A candidate may be visible but disabled.

Example reasons:

- Available
- Inactive
- On another active trip
- Maintenance
- Out of service
- Driver currently on trip
- Not eligible for the selected time, only if scheduling conflicts are actually implemented

Do not claim a scheduling-conflict rule that the backend does not implement.

## Step 4 — Review and Confirm

This must be a real review screen containing:

- Trip number if already allocated
- Client
- Cargo
- Planned date/time
- Price
- Pickup
- Delivery
- Route distance
- Route duration
- Selected truck or `Not assigned`
- Selected driver or `Not assigned`
- Readiness status
- Any missing requirement or availability conflict

Provide Edit actions that return to the corresponding step without losing data.

Final actions:

- `Save as Draft`
- `Create and Assign Trip` when eligible resources were selected

If the trip already exists as a Draft, use localized wording such as:

- `Save Draft`
- `Assign Trip`

Do not create duplicate Drafts during retries.

After a successful final action, navigate to the trip-details page and show a localized success message.

---

# 3. Wizard Navigation and Validation

The user must not be able to click through meaningless steps.

Implement:

- Per-step validation
- Completed, current, blocked, and error visual states
- Next and Back with stable state retention
- Direct step tapping only when the target step is already reachable
- Auto-save or explicit save behavior that is understandable and documented
- Unsaved-change protection when leaving the page
- Safe resume of an existing Draft after refresh
- No duplicate creation if a later API call fails

Do not block saving a minimal Draft merely because routing or assignment is incomplete.

Separate these concepts clearly:

- Draft persistence
- Route readiness
- Assignment eligibility
- Operational dispatch readiness

Do not treat them as one boolean.

---

# 4. Assignment Options and Explainable Eligibility

## 4.1 Backend-owned options

Add or adapt an endpoint that returns authoritative assignment options for a specific trip.

A preferred shape is:

`GET /api/trips/{tripId}/assignment-options`

The exact route may differ if the existing architecture has a better convention.

The response should include active trucks and drivers relevant to the tenant, with fields such as:

- Resource ID
- Display name or plate number
- Current status
- `isEligible`
- Stable `reasonCode` when ineligible
- Optional conflicting trip ID and human-readable trip number when safe and relevant

Examples of stable reason codes:

- `AVAILABLE`
- `RESOURCE_INACTIVE`
- `TRUCK_MAINTENANCE`
- `TRUCK_OUT_OF_SERVICE`
- `TRUCK_ALREADY_ASSIGNED`
- `DRIVER_ON_TRIP`
- `DRIVER_ALREADY_ASSIGNED`
- `TRIP_NOT_READY_FOR_ASSIGNMENT`

Use existing codes when semantically equivalent. Avoid unnecessary duplicate codes.

Never rely on English backend messages to control Flutter behavior.

The endpoint must:

- Be tenant-filtered
- Require the same authorization as trip management
- Never disclose another tenant's resources or trips
- Recheck availability during the actual assign command to prevent races

## 4.2 UI behavior

Flutter must render localized statuses and reasons.

If no eligible driver or truck exists, show an actionable empty state rather than an empty dropdown.

Examples:

- `No eligible driver is currently available.`
- `Driver Ahmad is already assigned to TRP-2026-000104.`
- `Truck ABC-123 is in maintenance.`

Keep the existing trip-details reassignment controls working, but reuse the same assignment-options behavior and UI component to avoid inconsistent rules.

---

# 5. Repair Existing Resource State Safely

Investigate whether retained development data contains trucks or drivers stuck in `OnTrip` even though no resource-reserving trip references them.

Do not silently mutate production-like data during normal reads.

If inconsistency exists:

- Document the cause.
- Add an invariant test.
- Fix lifecycle transitions that fail to release resources.
- Provide a deliberate Development/Testing-only reconciliation command or a reviewed migration only if genuinely necessary.
- Do not change a resource to Available when an active trip still reserves it.

Existing Completed and Cancelled flows must continue to release resources according to the domain rules.

---

# 6. Preserve Existing Trip Operations

Do not regress:

- Tenant-generated trip numbers
- Draft resume
- Search, filtering, sorting, and pagination
- Cancellation reason
- Archive and unarchive
- Duplicate as Draft
- Reassign and unassign before dispatch
- Immutable trip-event timeline
- Dispatch-to-pickup workflow
- Route-to-pickup preview
- Trip-aware tracking history
- Simulator behavior
- Fleet-map stability
- Arabic and English localization
- RTL and LTR
- Production hiding of simulator mutations

The corrective sprint must reuse the existing lifecycle rather than creating a second parallel trip model.

---

# 7. Error Handling and Recovery

Add localized, actionable handling for at least:

- Route not current
- Route provider unavailable
- Stops incomplete
- Identical stops
- Truck unavailable
- Driver unavailable
- Truck already reserved
- Driver already reserved
- Optimistic concurrency conflict
- Resource availability changed between review and confirmation
- Network failure during final assignment

When assignment fails after the Draft is saved:

- Preserve the Draft.
- Keep all entered data.
- Return the user to the Assignment step.
- Refresh eligibility.
- Explain what changed.
- Do not create a second trip.

---

# 8. Localization and Accessibility

All new user-visible text must be in ARB resources.

Verify:

- English/LTR
- Arabic/RTL
- Step ordering and alignment
- Dropdown and disabled-reason readability
- Date/time localization
- Map controls in RTL
- Long Arabic resource names
- Keyboard navigation on Flutter Web
- Visible focus states
- Buttons are not identified only by color
- Loading and disabled states are understandable

Do not hard-code English strings in widgets.

---

# 9. Backend Tests

Add integration tests covering at least:

## Route preservation regression

1. Create Draft.
2. Save valid stops.
3. Calculate route.
4. Confirm `canAssign == true`.
5. Resubmit identical stops.
6. Confirm route ID/fingerprint remains valid.
7. Confirm `canAssign == true`.
8. Assign an eligible truck and driver successfully.

## Route invalidation

- Change pickup coordinates and confirm route invalidation.
- Change delivery coordinates and confirm route invalidation.
- Reverse stops and confirm route invalidation.
- Change only cargo/price/notes and confirm route preservation.
- Confirm invalidation event is emitted only for a genuine invalidation.

## Assignment options

- Eligible resources are selectable.
- Reserved resources are returned as ineligible with stable reason codes.
- Maintenance and out-of-service trucks are ineligible.
- On-trip drivers are ineligible.
- Another tenant's resources never appear.
- Direct assignment still rechecks availability.
- A race between two assignment requests produces one safe success and one deterministic conflict.

## Lifecycle invariants

- Completion releases resources.
- Cancellation releases resources when appropriate.
- Unassignment releases the reservation.
- Active trips keep their reservations.
- Reconciliation, if added, never releases genuinely reserved resources.

## Draft and failure recovery

- Route provider failure does not delete the Draft or its stops.
- Assignment conflict does not duplicate the trip.
- Repeated final submission is safe or deterministically rejected without duplication.

Keep all existing integration tests passing.

---

# 10. Flutter Tests

Add focused tests for:

- Step 1 validation
- Step 2 markers and route calculation
- Next disabled until the current route is valid
- Identical save does not issue a stop update
- Actual stop change marks the route stale
- Step 3 contains real truck and driver controls
- Ineligible resources remain visible with localized reasons
- Skip assignment path
- Step 4 displays the complete review summary
- Edit-from-review navigation
- Save as Draft navigation
- Create and Assign navigation
- Assignment race recovery without data loss
- Resuming an existing Draft at the correct meaningful step
- English/LTR
- Arabic/RTL
- No placeholder-only Route, Assignment, or Review steps

Use stable widget keys for the acceptance workflow, but do not expose test-only behavior in production.

Keep all existing Flutter tests passing.

---

# 11. Mandatory Real Browser Acceptance Test

The sprint must not be declared complete without a real authenticated browser workflow.

Create or use a dedicated Development/Testing smoke tenant and known test credentials. Do not reset or overwrite the user's retained owner password or database volume.

Test in Firefox if Chrome is unavailable.

Execute and capture evidence for this exact workflow:

1. Log in.
2. Switch to Arabic and verify RTL.
3. Open Trips.
4. Start a new trip.
5. Complete Trip Details.
6. Choose pickup by clicking the map and confirm the marker appears at the clicked location.
7. Choose delivery using search or the map.
8. Calculate the route.
9. Verify route line, distance, and duration.
10. Move forward to Assignment.
11. Verify eligible and ineligible resources with reasons.
12. Select an eligible truck and driver.
13. Review the complete summary.
14. Save and assign.
15. Verify navigation to details and assigned resource names.
16. Create a second trip and save it unassigned as a Draft.
17. Reopen and resume that Draft.
18. Recalculate its route.
19. Save unchanged data.
20. Verify the route remains valid and assignment remains available.
21. Switch to English and verify LTR.

Also verify one failure-recovery case:

- Make a selected resource unavailable between review and confirmation, or simulate the equivalent deterministic conflict.
- Confirm the Draft survives, availability refreshes, and no duplicate trip is created.

Store screenshots, browser results, relevant HTTP evidence, and a concise index in:

`docs/evidence/sprint3_4_1/`

Do not claim browser acceptance if only widget tests or direct HTTP calls were run.

---

# 12. Validation Commands and Quality Gates

Run the repository-appropriate equivalents of:

- .NET restore/build
- Full backend integration suite
- EF Core migration drift check
- Flutter dependency resolution
- Flutter analyzer
- Full Flutter test suite
- Flutter Web release build with production flags
- Flutter Web build with Development/Testing simulator flags where relevant
- Docker Compose health checks
- Real PostgreSQL verification
- Real authenticated browser acceptance

Android:

- Build and run it only if a valid Android SDK and device/emulator are available.
- If unavailable, report the exact limitation without presenting Android as passed.

No validation claim may be stronger than the evidence.

---

# 13. Migration Rules

Prefer no database migration if the repair can be implemented safely with existing fields.

If a schema change is genuinely required:

- Explain why in the implementation plan.
- Create one reviewed migration.
- Preserve existing tenant data.
- Do not invent route, location, assignment, or audit history.
- Verify migration application against PostgreSQL.
- Verify no EF model drift remains.

Do not rewrite or delete previous migrations.

---

# 14. Documentation

Update:

- `README.md`
- `docs/architecture.md`
- `docs/sprints/sprint-3.4.1/SPRINT3_4_1_IMPLEMENTATION_PLAN.md`
- `docs/evidence/sprint3_4_1/README.md`

Document:

- The four-step user workflow
- Draft versus assigned-trip semantics
- Route preservation and invalidation rules
- Assignment-option eligibility rules
- Stable error/reason codes
- Concurrency behavior
- Failure recovery
- How to run the browser smoke test
- Any remaining limitations

---

# 15. Explicitly Out of Scope

Do not expand this sprint into:

- Finance
- Payments
- Expenses
- Profitability
- Maintenance management beyond displaying current truck eligibility
- Documents
- Alerts
- Real GPS provider integration
- SignalR
- Route optimization for multiple trips
- Driver mobile application
- Driver profile photographs
- New role/permission redesign
- Major dashboard redesign

Only make small adjacent changes required to deliver a correct trip-creation and assignment workflow.

---

# 16. Definition of Done

Sprint 3.4.1 is complete only when all of the following are true:

- Saving identical stops no longer invalidates a valid route.
- Real stop changes still invalidate the route.
- Saving unrelated Draft details preserves the route.
- A user can assign an eligible truck and driver within the creation workflow.
- Unavailable resources are visible with clear reasons.
- Route, Assignment, and Review are functional steps rather than placeholder text.
- Next cannot advance past incomplete required work.
- A user can intentionally save an unassigned Draft.
- A user can resume that Draft without losing data.
- The Review step shows a complete, accurate summary.
- Final success navigates to trip details.
- Assignment conflicts preserve the Draft and do not create duplicates.
- Multi-tenant isolation is tested.
- Backend build passes with zero warnings and errors.
- All backend integration tests pass.
- Flutter analyzer is clean.
- All Flutter tests pass.
- Flutter Web release build passes.
- EF migration drift is absent.
- Docker Compose services are healthy.
- The complete authenticated Firefox workflow passes.
- Arabic RTL and English LTR are verified with real screenshots.
- Documentation and evidence are complete.

---

# 17. Git and Safety Constraints

- Do not commit.
- Do not push.
- Do not force-reset or discard unrelated changes.
- Do not overwrite `.env`.
- Do not reset retained user credentials.
- Do not delete or recreate the PostgreSQL volume.
- If Compose must be repaired, recreate only the minimum required containers and preserve data.
- Do not fabricate screenshots or test results.
- Leave all Sprint 3.4.1 changes uncommitted for user review.

---

# 18. Required Final Report

At completion, provide:

## Implemented

- Root causes fixed
- Backend route-idempotency changes
- Wizard UX changes
- Assignment eligibility changes
- Error recovery changes
- Localization changes

## Validation

- .NET build result
- Backend integration test count
- Flutter analyzer result
- Flutter test count
- Flutter Web build result
- EF drift result
- Docker/PostgreSQL status
- Browser acceptance result
- Arabic/RTL and English/LTR evidence
- Android result or exact blocker

## Regression evidence

Explicitly report the result of:

`Calculate route -> save unchanged Draft -> route remains valid -> assign truck and driver`

## Evidence

Link the evidence directory and the implementation plan.

## Timing

Report task-level active elapsed times and total active elapsed time.

## Git status

Confirm that no commit or push was performed and list the changed files at a high level.

If any mandatory acceptance criterion is not proven, state that Sprint 3.4.1 is incomplete rather than describing it as fully delivered.
