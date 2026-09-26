# Sprint 4.2 Implementation Plan

## Baseline and initial state

- Started: `2026-09-26 11:32:11 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `958bd5d` (`feat(driver): repair assignment activation workflow`), matching both the prompt baseline and `origin/main`.
- Initial worktree: clean except for the user-provided untracked Sprint 4.2 prompt.
- Retained environment at start: `tms-smoke` containers stopped; retained volumes `tms-smoke_postgres_data` and `tms-smoke_truck_photo_data` exist.
- `.env` will not be modified. No commit, push, branch, or pull request is authorized by this request.

## Investigation and confirmed root causes

- Domain completion is correct: Driver confirmation owns `AtDelivery -> Completed`, writes `DeliveredAt` and `CompletedAt`, releases the Driver, and rejects duplicate confirmation without duplicate events/notifications.
- Persistence and backend trip-group queries already exclude `Completed` from active results. The observed stale active trip is client-side: Trips and trip detail had no cross-session polling, while Dashboard polling refreshed unrelated broad datasets.
- Dashboard and Trips used inconsistent active definitions; Assigned was counted differently and there was no server-owned operational phase/attention projection.
- Authentication exposed only account display name and role; linked Driver identity was not available to the global shell.
- Operational notification payloads carried trip number and little else, so stable truck/Driver/stop context could not be rendered.
- The planner selected the first eligible Driver when no valid truck default existed, creating an unsafe implicit assignment.

## Lifecycle and cross-session refresh design

Preserve Domain lifecycle authority: `AtDelivery -> Completed` remains Driver-confirmed, idempotent, and responsible for commercial resource release while retaining the post-trip vehicle session. Add focused, read-only, non-overlapping Owner polling: Dashboard at its existing configurable interval, Active Operations at a clamped three-second default, and operational trip detail at a clamped three-second default that stops after terminal status. Silent refresh keeps the last good state, current filters/tab/page/scroll/camera, and rejects stale generations.

## Operational overview/read-model design

Add one tenant-scoped Application projection backed by a bounded Infrastructure query, not per-trip API calls. It will join active/attention-relevant trips to client, assigned truck/Driver, default/photo metadata, latest telemetry, and stored route/repositioning plans. The payload excludes route geometry/history and publishes server-owned phase, next milestone, meaningful segment progress, remaining distance, ETA, tracking health, last update, online/off-route state, waiting duration, and attention priority. Assigned is included as an operational attention item while remaining in the planned lifecycle group; counts will not double-count it.

## Progress and attention semantics

- `Assigned`: Awaiting Driver departure; no percentage/ETA fabrication.
- `EnRouteToPickup`: approach-route projected progress/remaining/ETA.
- `AtPickup`: Awaiting loading confirmation; no moving percentage.
- `InTransit` (and compatible `Started`): cargo-route projected progress/remaining/ETA.
- `AtDelivery`: Awaiting delivery confirmation; no moving percentage.
- Missing/stale/offline telemetry keeps phase and last update while suppressing fabricated distance/ETA.
- Priority: off-route/offline/stale/overdue, then human confirmation, then nearest ETA, then other operations.

## Identity/profile design

Extend the existing authenticated bootstrap only additively if needed so the shell can render account display name, localized role, company, email, and the same-tenant linked Driver operational name without an extra page request. Wide layouts show compact initials/name/role/company; compact layouts expose the same facts and Settings/password/sign-out actions in a menu/sheet. Driver routes remain restricted.

## Notification data contract

Persist language-neutral snapshot payloads. Assignment, pickup arrival, delivery arrival, Driver confirmations, and completion will carry the applicable trip number, truck plate/fleet code, Driver name, stop type/name/address, timestamps, distance, pickup name, and confirmation flag. Stable event keys retain exactly-once semantics; Flutter localizes concise overlays and detailed list subtitles with graceful optional-field fallback and role-correct navigation.

## Default Driver selection rules

A truck default is a preferred Driver, never a permanent binding. Selecting a truck proposes and selects its default only when currently eligible. Missing or unavailable defaults leave Driver empty with an explanation; no arbitrary first eligible Driver is selected. A manual Driver choice is preserved across unrelated edits and while eligible; changing truck reevaluates the choice: if the manual Driver remains eligible it is preserved and marked manual, otherwise selection clears and the new valid default may be proposed. Trip assignment never mutates the truck default. Review displays truck, Driver, selection source, link state, and warnings.

## API and Flutter changes

- Centralize operational/lifecycle group predicates used by active projection and counts.
- Add focused active-operations endpoint with bounded search/filter/page/limit.
- Verify/repair completion consistency, events, notifications, resource availability, and tenant isolation.
- Add Dashboard summary and enhanced Trips Active projection with silent refresh.
- Add terminal-aware trip-detail polling and convergence indicators.
- Add responsive shell identity control and localized role labels.
- Enrich notification snapshots/rendering/navigation.
- Repair assignment default-Driver selection/review behavior.

## Tenant and security analysis

Every projection begins from the authenticated company scope; filters are intersected with tenant-owned IDs. No overview exposes route geometry, position history, another tenant's identifiers, or manager routes to Drivers. Notification snapshots are immutable display facts, not authorization inputs. Driver identity is resolved from the authenticated user. Simulator mutations remain Owner-only and Development/Testing-only. Reads remain side-effect free.

## Test and browser-acceptance matrix

- Backend: completion convergence/idempotency/event-notification uniqueness; resource/session invariants; all operational phases/telemetry health/attention sorting; filtering/paging/no duplicates/tenant isolation; structured notification snapshots; default-Driver eligibility and tenant rules.
- Flutter: silent polling/out-of-order/disposal/stale feedback; terminal detail stop; shell roles/layout/RTL/actions; contextual notifications/navigation/sound dedupe; Dashboard/Active responsive projections; waiting versus moving semantics; default-Driver source/explanations/review.
- Runtime: disposable Compose project/volumes, real release Flutter Web, OpenFreeMap, independent Owner/Driver Firefox profiles, default/no-default assignment, normal lifecycle through Completed, Owner convergence without reload, contextual notifications, identity evidence, and post-trip Driver session.

## Retained-data safety plan

Temporarily start only retained PostgreSQL if necessary to record non-sensitive before counts, then return it to the initial stopped state before implementation. Runtime acceptance will use a distinct `tms-s42` project and volumes and fail closed if resolved mounts reference either retained volume. Do not migrate retained data for evidence. After acceptance, remove only disposable containers, restore the retained stack to its initial stopped state, and compare counts with background heartbeats explained separately.

## Task timing

Times are updated during execution. Unfinished rows are not estimates.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 1 | Baseline, prompt, plan, retained-data snapshot | 2026-09-26 11:32:11 +03:00 | 2026-09-26 11:33:48 +03:00 | 1m 37s | Complete |
| 2 | Trace lifecycle, projections, notifications, identity, assignment | 2026-09-26 11:33:48 +03:00 | 2026-09-26 11:39:36 +03:00 | 5m 48s | Complete |
| 3 | Backend operational projection and lifecycle/notification repairs | 2026-09-26 11:39:36 +03:00 | 2026-09-26 11:44:30 +03:00 | 4m 54s | Complete |
| 4 | Flutter identity, overview, polling, notifications, assignment UX | 2026-09-26 11:44:30 +03:00 | 2026-09-26 11:51:59 +03:00 | 7m 29s | Complete |
| 5 | Automated tests, migration/drift, builds, Docker | 2026-09-26 11:51:59 +03:00 | 2026-09-26 12:03:30 +03:00 | 11m 31s | Complete |
| 6 | Mandatory two-profile browser lifecycle acceptance | 2026-09-26 12:03:30 +03:00 | 2026-09-26 12:40:21 +03:00 | 36m 51s | Failed/incomplete |
| 7 | Evidence, documentation, retained comparison, final audit | 2026-09-26 12:40:21 +03:00 | 2026-09-26 12:45:36 +03:00 | 5m 15s | Complete |

**Total active sprint time:** 1h 13m 25s.

## Final validation and unresolved limitations

Implementation, automated suites, migration drift, release Web build, and disposable Docker startup passed. The mandatory two-profile browser workflow remains incomplete: Owner and Driver authentication, identity, the no-default-Driver state, and Driver workspace were reached, but Selenium could not reliably activate Flutter Web's canvas-backed Truck dropdown for the default-Driver assignment. No cross-session completion timing or partial screenshots are claimed as passing. Android was not built because the configured SDK path does not exist. The sprint must remain incomplete until the full browser scenario passes.
