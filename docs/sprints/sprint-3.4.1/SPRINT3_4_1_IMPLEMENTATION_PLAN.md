# Sprint 3.4.1 Implementation Plan

## Objective

Repair the Sprint 3.4 trip planner into a four-step, resumable workflow that
preserves an authoritative route across semantically identical saves, performs
optional assignment inside the wizard, explains resource eligibility, and
recovers from provider, concurrency, and assignment failures without duplicate
Drafts.

## Baseline Assessment

- Baseline is `main` at `f00bcbf`; `origin/main` matches after the required
  fetch on 2026-09-22. Only the unrelated untracked Sprint 3.1 prompt and the
  Sprint 3.4.1 task prompt existed before implementation; both are preserved.
- The six-step Flutter planner exposes global Save/Calculate actions, allows
  unrestricted step tapping and `Next`, and renders Route, Assignment, and
  Review as placeholder text rather than workflows.
- `_saveDraft` always sends the stops endpoint when two stops parse, even when
  the persisted stop snapshot is identical. It updates its persisted version
  only after the complete chained save succeeds.
- `Trip.ReplaceStops` always clears `RoutePlan`, even for a byte-identical or
  display-label-only resubmission. `RoutePlanningService.Fingerprint` is already
  the server normalization authority and hashes ordered coordinates plus route
  profile at six-decimal precision.
- Assignment on trip details filters to active `Available` resources in the
  client. The backend rechecks safety during assignment, but no trip-scoped API
  explains inactive, maintenance, out-of-service, on-trip, or reserved choices.
- Sprint 3.4 automated checks passed, while the required complete authenticated
  browser workflow was not completed.

## Confirmed Root Causes

1. Stop endpoint invocation is treated as proof of route change instead of
   comparing the new normalized route fingerprint with the stored snapshot.
2. Flutter has no persisted normalized-stop snapshot/dirty state and therefore
   resubmits stops after unrelated Draft changes.
3. Stepper reachability is represented only by an integer; no validation or
   server-persisted route gate controls navigation.
4. Assignment lives in a details dialog backed by a broad reference-data load,
   not a trip-specific server eligibility contract.
5. Final actions are not modeled as one retry-safe orchestration over the same
   persisted Draft.

## Product Decisions

- Four steps: Details; Pickup, Delivery and Route; Truck and Driver; Review and
  Confirm.
- Draft save is always explicit and may occur before route or assignment.
- Stops are persisted only when their normalized route-input snapshot or their
  editable display fields differ. The server remains authoritative and safely
  accepts identical resubmission.
- Route freshness uses the existing server `RoutePlanningService.Fingerprint`
  only. Labels/address are display-only under the current OSRM contract; ordered
  coordinates and route profile are route-relevant. The existing contract does
  not route by arrival/service-duration fields, so the sprint will not falsely
  claim that it does.
- Assignment options show tenant resources with eligibility and stable reason
  codes. Actual assign/reassign commands continue to recheck readiness and
  reservation constraints.
- Skip for now finishes as an unassigned Draft. Selecting both eligible
  resources enables Create/Save and Assign.
- Existing details assignment will reuse the same options API/component.

## Backend Changes

- Compare the submitted stop fingerprint with the stored route fingerprint
  before replacement; preserve the route for identical normalized inputs and
  invalidate only for genuine changes.
- Append `RouteInvalidated` only when a non-null authoritative route is removed.
- Add tenant-scoped `GET /api/trips/{id}/assignment-options` with stable
  eligibility reason codes and optional safe conflicting trip identity.
- Keep actual assignment checks and database reservation indexes as the race
  backstop; improve deterministic availability conflict codes where needed.
- Add route-preservation, invalidation/event, eligibility/isolation, race, and
  lifecycle invariant integration coverage.

## Flutter Changes

- Replace the six decorative steps with four meaningful, validated steps.
- Move route calculation, loading/failure/stale state, map, distance, duration,
  and provider attribution into step 2.
- Track persisted stop snapshots and avoid unchanged stop updates; refresh the
  local Trip/version after every successful request.
- Add real truck/driver option controls, disabled reasons, refresh, current
  assignment, and explicit skip path in step 3.
- Add a complete review summary with edit actions and Draft/Assign final actions.
- Preserve the same Draft and return to assignment after an assignment race.
- Add localized EN/AR text, stable widget keys, reachable-step rules, visual
  step state, and guarded exit behavior.

## Migration Decision

No schema migration is planned. Existing stop, route fingerprint, version,
status, reservation, and audit structures are sufficient. An EF drift check is
still mandatory. If implementation disproves this assumption, the plan must be
updated before creating any migration.

## Test Strategy

- Add a baseline regression proving calculate -> identical stop save currently
  destroys the route, then implement until it passes and assignment succeeds.
- Cover pickup/delivery coordinate changes, coordinate reversal, unrelated
  Draft changes, display-only stop changes, and exact invalidation event count.
- Cover eligible/ineligible options, reason codes, tenant isolation, current
  assignment, direct command recheck, and concurrent reservation.
- Add Flutter tests for all four steps, reachability, stop dirty state, stale
  route, eligibility reasons, skip/assign paths, complete review, edit links,
  recovery, resume, LTR, and RTL.
- Run every existing backend and Flutter test after focused suites.

## Browser Acceptance Workflow

Use a dedicated Development/Testing smoke tenant and runtime-only credentials.
Run the exact 21-step authenticated Firefox workflow from the task prompt,
including AR/RTL, map location selection, route visualization, options/reasons,
assigned and unassigned final paths, resume and unchanged save, EN/LTR, and a
deterministic assignment-race recovery. Never reset the retained owner or delete
the PostgreSQL volume.

## Evidence Plan

Store the browser driver, machine-readable result, screenshots, HTTP/database
checks, validation transcript summary, and limitations index under
`docs/evidence/sprint3_4_1/`. Automated tests and direct API/database probes are
supporting evidence only and will not be labeled browser acceptance.

## Risks and Rollback Notes

- EF relationship replacement can delete a preserved route if the domain and
  tracking state diverge; tests will assert route ID/fingerprint retention.
- Availability can change after options load; final assignment must fail safely
  without deleting or duplicating the Draft.
- Public routing/map services may be unavailable; provider failure recovery is
  deterministic in tests, while browser success is reported only if actually
  observed.
- The corrective sprint should roll back as application/API/UI code only because
  no schema change is expected. Existing Sprint 3.4 migration remains untouched.
- `.env` and retained credentials/data remain excluded. Commit and push were
  subsequently authorized by the user together with the Sprint documentation
  reorganization and inclusion of the previously untracked Sprint 3.1 prompt.

## Task Timing (Active UTC Time)

Active time counts only periods spent working on this sprint in this session.
Rows are updated at task boundaries; unfinished rows are never backfilled with
invented values.

| Task | Started (UTC) | Finished (UTC) | Active elapsed | Status | Result |
|---|---:|---:|---:|---|---|
| Baseline fetch, required reading, code trace, plan, and failing regressions | 2026-09-22 17:25:03 | 2026-09-22 17:28:21 | 00:03:18 | Complete | Baseline/root causes confirmed; identical-stop regression fails because `routePlan` becomes null |
| Backend route idempotency, events, assignment options, and invariants | 2026-09-22 17:28:21 | 2026-09-22 17:56:00 | 00:27:39 | Complete | Identical/display-only saves preserve the route; real changes invalidate once; tenant-scoped explainable options and 48 passing integration tests |
| Four-step Flutter workflow, eligibility UI, recovery, and localization | 2026-09-22 17:56:00 | 2026-09-22 18:58:05 | 01:02:05 | Complete | Four gated/resumable steps, EN/AR, safe final actions, Draft recovery, lifecycle fixes, and complete Firefox workflow passed |
| Documentation, evidence harness, and full validation | 2026-09-22 18:58:05 | 2026-09-22 19:04:27 | 00:06:22 | Complete | Plans/docs/evidence updated; analyzer, 36 Flutter tests, two web builds, EF drift, PostgreSQL, and Compose health passed; Android SDK unavailable |
| Sprint documentation reorganization and release preparation | 2026-09-22 19:24:03 | 2026-09-22 19:27:05 | 00:03:02 | Complete | All 11 prompt/plan pairs grouped under `docs/sprints/`, cross-references updated, index added, Sprint 3.1 prompt included, and staged diff verified |

**Total active elapsed:** 01:42:26.

## Final Validation Summary

- Backend integration tests: 48 passed, 0 failed.
- Flutter analyzer: no issues; Flutter tests: 36 passed, 0 failed.
- Production release and Development/Testing profile web builds: passed.
- EF pending-model check: no changes; no Sprint 3.4.1 migration required.
- Compose API and PostgreSQL: healthy after rebuilding only the API and
  preserving the retained PostgreSQL volume.
- Authenticated Firefox result: passed all required workflow and recovery
  checks; ten screenshots and machine-readable evidence are stored under
  `docs/evidence/sprint3_4_1/`.
- Android: not built or run because `/home/pc/Android/Sdk` is absent and no
  usable SDK/device is available.
