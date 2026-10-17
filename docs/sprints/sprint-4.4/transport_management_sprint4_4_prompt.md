# Sprint 4.4 — Product Experience, Flexible Design System, Driver Trip History, and Pilot Build

You are working in the existing `transport-management-system` repository. Implement Sprint 4.4 end to end.

This is a product-experience and release-packaging sprint, not a rewrite and not a broad feature sprint. The current application already contains substantial authentication, multi-tenancy, fleet, trip, routing, tracking, simulator, notification, invitation, QR, handover, Arabic/English, and MapLibre functionality. Preserve all validated behavior while making the product visually professional, easier to understand, responsive, and easy to redesign later.

Do not commit or push unless explicitly requested. Do not overwrite `.env`, retained PostgreSQL data, Docker volumes, user credentials, or business fixtures. Use isolated fixtures or an isolated Compose project for destructive acceptance tests.

---

## 1. Primary outcome

Deliver a polished, role-aware application experience in which:

1. The Owner/Operations dashboard feels like a professional fleet operations product and gives the map substantially more usable space.
2. The Driver has a mobile-first workspace and can browse their own current, upcoming, completed, and cancelled trips with meaningful details and trip-related places.
3. Appropriate motion improves comprehension without distracting the user or destabilizing MapLibre.
4. Visual styling is driven by reusable design tokens and interchangeable components, so a future redesign does not require changing business logic or rewriting screens.
5. Development retains the simulator, while Pilot and Production builds contain no usable simulator UI or backend mutation endpoints and create no demo data.

The result must work in English/LTR and Arabic/RTL and must preserve tenant isolation, role authorization, tracking chronology, map stability, camera behavior, notification semantics, and the existing trip state machine.

---

## 2. Scope boundaries

### In scope

- A reusable, documented Flutter design system.
- A responsive, role-aware application shell.
- Professional visual refinement of the highest-value Owner and Driver screens.
- A larger and more useful operational fleet map.
- Driver trip history and trip details.
- Clear loading, empty, stale, offline, error, and success states.
- Purposeful, accessible animations.
- Explicit Development, Demo, Pilot, and Production capability profiles.
- Complete automated and real-browser validation.
- Documentation, evidence, and actual elapsed-time records.

### Explicitly out of scope

- Finance, payments, receivables, subscriptions, or billing.
- Maintenance management.
- Public company/Driver marketplace or public company search.
- Driver ratings or gamification.
- Customer portal or public trip-sharing links.
- Multi-provider GPS integration.
- SignalR or a real-time architecture rewrite.
- Route optimization across multiple vehicles.
- Dark mode unless it is nearly free after the token architecture; do not let it expand the sprint.
- Replacing Flutter, Riverpod, MapLibre, ARB localization, the backend architecture, or the existing trip workflow.
- A full-screen-by-screen rewrite of the application.
- Unrelated dependency upgrades, backend restructuring, or database redesign.

---

## 3. Mandatory baseline and planning

Before changing code:

1. Fetch and inspect the latest repository state and record the exact HEAD SHA.
2. Read the current README, architecture decisions, recent Sprint 4.2–4.3.2 plans/evidence, and the existing Owner/Driver/map/simulator implementations.
3. Run and record the current backend build/tests, Flutter analyzer/tests, EF migration drift check, and Web build.
4. Inspect the existing configuration switches for simulator UI, simulator endpoints, seed data, tracking providers, MapLibre, routing, and geocoding. Reuse and improve them instead of creating conflicting switches.
5. Inventory existing shared widgets, theme definitions, hard-coded colors/spacing, navigation shells, large screens, route guards, map lifecycle ownership, and Driver trip APIs.
6. Create `docs/sprints/sprint-4.4/SPRINT4_4_IMPLEMENTATION_PLAN.md` before implementation.

The plan must contain:

- Baseline SHA and baseline results.
- Current UX/design audit.
- Task list with status.
- Intended files/modules.
- Data/migration impact.
- Risks and rollback notes.
- Acceptance mapping.
- Actual active elapsed time per task and total. Do not invent durations.

If the working tree already contains unrelated user changes, preserve them and work around them. Do not reset, clean, discard, or overwrite them.

---

## 4. Flexible design architecture — non-negotiable

The design must be easy to change later. Do not merely replace hard-coded values with different hard-coded values.

### 4.1 Central design tokens

Create or consolidate a single coherent design-token layer covering at least:

- Semantic colors: primary, surface, canvas, border, text, muted text, success, warning, danger, information, selected, disabled, online, offline, stale, moving, stationary, maintenance, trip phases, and map overlays.
- Typography roles for Arabic and English.
- Spacing scale.
- Radius scale.
- Elevation/shadow scale.
- Control heights and touch-target minimums.
- Responsive breakpoints and content-width constraints.
- Motion durations and curves.

Use Flutter `ThemeData`, `ColorScheme`, `TextTheme`, and `ThemeExtension` or an equally idiomatic centralized solution. Bundle the selected Arabic/Latin fonts locally if licensing permits; do not make runtime font availability depend on an external CDN.

The application must have one polished visual preset in this sprint, but the architecture must allow a future preset or brand to be introduced by changing/composing tokens rather than editing business screens. Do not build a runtime theme editor.

Make the theme injectable and add a focused architecture test proving that an alternate test token preset can restyle migrated screens without feature-level code changes. This is an extensibility proof, not a second production theme.

### 4.2 Replaceable presentation components

Create reusable presentation primitives for the repeated UI patterns actually used by the product, for example:

- Page header and role/workspace identity.
- Primary, secondary, danger, and icon actions.
- Status badge/chip.
- Metric card.
- Responsive data list/table.
- Empty, loading/skeleton, error, offline, and stale states.
- Map action button and compact map panel.
- Trip summary card.
- Timeline item.
- Confirmation/details dialog.
- Responsive side panel/bottom sheet.

Keep the component set purposeful; do not create a speculative component library. Presentation components should receive typed data and callbacks. They must not perform API calls or own business state.

### 4.3 Separate presentation from behavior

- Keep API calls, polling, authorization, trip transitions, and map orchestration in the appropriate repositories/controllers/providers/services.
- Do not move business rules into widgets.
- Do not let visual components import feature data sources directly.
- Preserve stable routes, semantic keys, localization keys, and testability.
- Centralize breakpoint decisions instead of scattering raw screen-width conditions.
- A future redesign of cards, navigation, colors, or layout must not change backend contracts or trip logic.

Add `docs/design-system.md` documenting tokens, component responsibilities, responsive rules, motion rules, and how to create a future visual preset.

---

## 5. Visual direction and accessibility

The visual character should be calm, modern, operational, and trustworthy: a fleet command center rather than a generic admin template.

Use a restrained palette with clear semantic status colors, strong information hierarchy, consistent alignment, and reduced visual noise. Do not imitate or copy a proprietary product pixel-for-pixel.

Mandatory requirements:

- Arabic and English typography must both look intentional.
- Arabic RTL must be verified on every changed screen and must not regress MapLibre label shaping.
- Text contrast, focus visibility, keyboard navigation, semantic labels, and minimum touch targets must be checked.
- Avoid color-only communication; combine color with labels/icons where status matters.
- Avoid excessive gradients, glass effects, decorative shadows, or continuous motion.
- Do not reduce operational data density so far that the dashboard becomes decorative rather than useful.

---

## 6. Responsive application shell

Refine the shared shell and navigation without changing permissions.

### Owner/Operations navigation

The shell should make the existing management areas easy to discover and should clearly display:

- Current account identity.
- Current company/workspace.
- Active roles.
- Notifications.
- Language/profile/logout actions.

Use a stable desktop navigation rail/sidebar and a suitable compact/mobile pattern. Do not render links the current membership cannot access.

### Driver navigation

Provide a focused Driver navigation model using the existing permission system:

- Today / My current work.
- My trips.
- My truck.
- Notifications.
- Profile/settings.

For multi-role accounts, preserve management access and Driver access without duplicating or corrupting navigation state. For accounts in multiple companies, preserve workspace switching and ensure all Driver history remains scoped to the active company.

Avoid unauthorized-content flashes during login, membership refresh, role changes, logout, or workspace switching.

Apply the shared visual foundation consistently to authentication/invitation, notification, and profile surfaces that are encountered in the mandatory acceptance workflow. Keep their behavior unchanged; this is not permission to redesign the underlying account or membership domain.

---

## 7. Owner/Operations dashboard and larger fleet map

Redesign the dashboard composition around the fleet map while preserving its proven lifecycle and tracking behavior.

### Desktop/tablet

- The map should occupy approximately 60–70% of the useful viewport height on normal desktop screens where practical.
- Keep the most important operational metrics compact and above or beside it.
- Provide a collapsible fleet list/filter panel.
- Show selected-truck details in a compact overlay/side panel that does not unnecessarily cover the route.
- Provide explicit controls for Follow Vehicle, Recenter, Route Overview/Fit Route, Fleet Overview, and Full Screen.
- Keep connected/moving/status filters understandable and localized.
- Place recent trips and secondary operational information below the primary map area.

### Mobile/narrow widths

- Give the map most of the available area.
- Use a responsive bottom sheet or equivalent compact surface for truck details and the fleet list.
- Controls must remain reachable and must not overlap attribution or important map content.

### Map invariants

Do not regress any previously fixed behavior:

- Do not recreate/dispose the map during polling or ordinary panel animations.
- Do not globally clear annotations.
- Preserve incremental/latest-wins marker, route, trail, and stop synchronization.
- Preserve truck photo/avatar marker treatment, heading, state decoration, and selection.
- Preserve Arabic/English MapLibre labels and the pinned RTL behavior.
- Preserve camera modes: zoom may preserve follow, intentional pan pauses follow, and polling must never move a free camera.
- Do not refit the camera because a panel opens, a poll arrives, or an animation completes.
- Avoid layout animations that resize MapLibre on every frame. If the map container changes size, perform it deliberately and safely.
- Preserve route/trail segmentation and tracking chronology.
- Full-screen exit must restore the previous camera mode and selection without creating another map instance.

---

## 8. Purposeful motion system

Create centralized motion tokens and use animation only where it communicates change.

Appropriate targets include:

- Page/section entrance where it improves orientation.
- Side panel and bottom-sheet transitions.
- Status changes.
- Trip progress changes.
- List insertion/removal.
- Notification/toast presentation.
- Loading skeletons.

Requirements:

- Prefer Flutter's built-in animation primitives; do not add a large animation dependency without a documented reason.
- Typical UI transitions should be approximately 150–300 ms.
- High-frequency telemetry must not trigger whole-page animations or rebuild the map.
- Repeated polling must not restart entrance animations.
- Animations must be interruptible and must settle on the newest state.
- Respect platform reduced-motion/accessibility preferences where available, with an application-level fallback if needed.
- Reduced motion must remove nonessential transitions without hiding state changes.

---

## 9. Driver workspace refinement

Make the Driver experience mobile-first and operationally explicit.

The Driver home screen must clearly show, as applicable:

- Driver identity and active company.
- Assigned/current truck with photo/plate/status.
- Connection and location freshness.
- Current or next trip.
- Pickup/delivery summary.
- Current trip phase, progress, remaining distance, and ETA when available.
- The single next action expected from the Driver.
- A map even when the Driver has a resolved truck but no active trip, without fabricating trip details.

Preserve the existing rules for acceptance, departure, loading, delivery, completion, QR truck switching, approval-based handover, default truck resolution, and post-trip map retention. Do not redesign the state machine in this sprint.

Use clear disabled states and actionable explanations rather than silently unavailable buttons.

---

## 10. Driver trip history and details

Implement a complete, tenant-safe `My Trips` experience for the authenticated Driver.

### 10.1 History categories

At minimum support understandable categories/tabs or filters for:

- Current/active.
- Upcoming/assigned.
- Completed.
- Cancelled.

Use the actual existing domain statuses and map them deliberately to presentation categories. Do not invent or alter lifecycle semantics merely to fit the UI.

### 10.2 Trip list

Each item should display only authorized, useful information, such as:

- Trip number/reference.
- Status.
- Date.
- Truck/plate used.
- Client when the Driver is allowed to see it.
- Pickup and delivery place names.
- Planned/actual distance and duration when available.
- Start, pickup, delivery, and completion timestamps when available.

Provide pagination or bounded incremental loading. Provide date/status filtering appropriate to the existing dataset. Avoid an unbounded download of all historical trips.

### 10.3 Trip detail

The detail experience must include, when data exists:

- Trip identity and status.
- Truck and assignment information.
- Structured pickup/delivery stops.
- Route snapshot and planned distance/duration.
- Actual operational timestamps.
- A localized chronological lifecycle/activity timeline.
- Route/trail map for the trip, using existing route and tracking-history semantics.
- Cancellation reason and handover/participation information when available and authorized.
- Meaningful empty/fallback content when coordinates, route geometry, or telemetry do not exist.

Do not expose finance, internal-only notes, other Drivers' information, unrelated telemetry, or cross-company data.

### 10.4 Privacy boundary

“Places visited” means trip-associated pickup/delivery stops and the trip's authorized tracking session. Do not create an off-duty or perpetual Driver-location history. A Driver must never be able to query another Driver's trips by changing a URL or ID.

History participation must be based on the Driver's real assignment/control interval, not merely the trip's final `DriverId`. When an approved handover occurred, both participating Drivers should retain an appropriate history record and role/interval indication. Each Driver may see only the trail/time segment they are authorized to see unless existing product policy explicitly grants a broader view. Do not erase Driver A's history when Driver B becomes the final assignee.

### 10.5 Backend/API behavior

Inspect and reuse existing trip, route, assignment, timeline, notification, and tracking-history data before adding tables or duplicating facts.

If a new Driver-scoped history endpoint/query is needed:

- Resolve the Driver from the authenticated account and active company membership on the server; never trust a client-supplied Driver ID.
- Apply tenant isolation and role authorization server-side.
- Return a paginated summary projection and a separate detail projection.
- Avoid N+1 queries and excessive route/trail payloads in the list response.
- Load route geometry and authorized tracking history only when opening the detail, not in list results. Bound or downsample very large rendered trails without changing stored evidence.
- Use stable error codes and existing localized client mapping.
- Add only the indexes demonstrably required by the query.
- Use safe nullable/backfilled migrations only when unavoidable. Do not invent historical coordinates or timestamps.
- Store timestamps in UTC and render them using the existing company/user timezone policy. If that policy is not yet explicit, document and implement the smallest consistent policy rather than silently using the browser machine timezone.

---

## 11. Empty, loading, stale, offline, and error states

Every changed high-value screen must have deliberate states rather than blank space or indefinite spinners.

Examples:

- No trucks yet: explain how an Owner adds the first truck.
- No active trips: offer the permitted next action.
- Driver has no linked Driver record: provide an actionable, role-appropriate explanation.
- Driver has a truck but no trip: keep the truck map and current position visible.
- No location: explain how Development can set one, but do not mention simulator controls in Pilot/Production.
- Stale/offline vehicle: show last update and operational impact.
- Map style/provider failure: preserve the existing retry/fallback behavior without destroying surrounding page state.
- Trip route/history unavailable: keep textual details usable.
- API retry: prevent duplicate mutations.

Use skeletons for predictable content loading, but do not obscure errors with permanent shimmer effects.

---

## 12. Capability profiles and simulator isolation

Do not delete the simulator. Formalize the existing configuration into clearly documented capabilities.

Required behavioral matrix:

| Capability | Development | Demo | Pilot | Production |
|---|---:|---:|---:|---:|
| Simulator UI | Enabled | Explicitly configurable/restricted | Disabled | Disabled |
| Simulator mutation endpoints | Enabled | Explicitly configurable/restricted | Not mapped | Not mapped |
| Demo seed data | Explicitly configurable | Explicitly configurable | Disabled | Disabled |
| Real tracking provider | Configurable | Configurable | Configurable/required by deployment | Required when production tracking is claimed |
| Diagnostic evidence controls | Development-only | Restricted | Disabled | Disabled |

Implementation requirements:

- Prefer capability objects/policies over scattered environment checks.
- Backend authorization and endpoint registration are authoritative; hiding Flutter controls is not sufficient.
- Pilot/Production must not map simulator mutation endpoints. Return normal `404` behavior rather than advertising hidden functionality.
- Simulator background services must not run in Pilot/Production.
- Flutter Pilot/Production builds must not expose simulator routes, controls, labels, manual location mutation actions, or navigation entries.
- Do not create fake trucks, Drivers, trips, users, or tracking rows in Pilot/Production.
- Preserve the current Development simulator and its existing tests.
- Document exact commands/configuration for Development, Demo, Pilot, and Production-style Web builds.
- Add automated assertions proving the intended profile behavior. Do not rely only on visual inspection.

Do not claim that Pilot/Production uses real GPS merely because the simulator is absent. If no real provider is configured, present a clear unconfigured/no-live-tracking state.

---

## 13. Localization requirements

- All new text must use ARB localization resources.
- Complete English and Arabic translations are mandatory.
- Validate Arabic grammar, number/date formatting, status terminology, truncation, mirroring, icon direction, and map overlays.
- Do not localize server-side by returning human-readable English messages. Preserve stable error/event codes and localize in Flutter.
- Driver timeline events and empty/error states must be localized from typed/stable event semantics.
- Do not regress anonymous invitation/login localization or language persistence.

---

## 14. Testing requirements

### 14.1 Backend

Add or update tests for:

- Driver can list only their own trips within the active company.
- Cross-tenant trip/history access is rejected without leaking existence.
- Another Driver in the same company cannot read the first Driver's detail.
- Multi-company account sees only the active workspace history.
- Approved handover keeps the trip in both participating Drivers' histories with correct authorization boundaries and permitted trail intervals.
- Status/date filters, ordering, and pagination are deterministic.
- Pagination remains deterministic with at least 100 history records and the query does not introduce N+1 behavior.
- Route/trail detail is bounded and associated with the correct trip/tracking run.
- Legacy or incomplete trips return safe partial details.
- Pilot/Production does not register simulator mutation endpoints or run simulator workers.
- Development simulator behavior remains available.
- Existing membership, QR, handover, notification, tracking, and trip tests remain green.

### 14.2 Flutter

Add or update focused tests for:

- Token/theme application and semantic status mapping.
- Arabic/English and RTL/LTR on changed screens.
- Centralized responsive breakpoints.
- An injected alternate test token preset restyles migrated screens without feature-level edits.
- Owner/Operations and Driver navigation visibility.
- Dashboard/map layout at representative desktop, tablet, and mobile sizes.
- Driver history categories, filters, pagination/incremental loading, empty state, error/retry, and detail timeline.
- Driver with an idle resolved truck still sees the map.
- Reduced-motion mode.
- Animations do not restart on equivalent polling state.
- Pilot/Production contains no simulator navigation or mutation actions.
- Development retains simulator controls.
- Existing map camera, interpolation, marker, RTL label, and annotation-operation tests remain green.

Use selected golden/screenshot tests only where they add durable value. Do not create a brittle screenshot test for every screen.

### 14.3 Real-browser acceptance

Run a real Firefox workflow with separate Owner and Driver profiles against an isolated or safely retained environment. At minimum prove:

1. Owner login and role/workspace identity.
2. Professional responsive dashboard at desktop and mobile-width viewport.
3. Larger map, fleet filter, truck selection, follow, zoom, intentional pan, route overview, recenter, and full-screen restore.
4. At least 20 tracking updates with no map recreation, no global annotation clear, no unintended camera movement, and no fatal renderer error.
5. Driver login and mobile-first home screen.
6. Driver active/assigned/completed/cancelled history categories using authorized fixtures.
7. Opening a completed trip shows its stops, timeline, and map/fallback correctly.
8. Driver cannot open another Driver's trip via a changed URL/ID.
9. Driver with an assigned truck but no trip still sees the truck map.
10. Arabic RTL and English LTR for Owner and Driver experiences.
    Validate representative viewports near 360 px, 768 px, and 1440 px with no overflow or unusable controls.
11. Reduced-motion behavior.
12. A Pilot-style build has no simulator UI; simulator endpoint probes return `404`.
13. A Development build still supports the simulator without regression.
14. Logout in one browser profile does not break the other profile.

Retain sanitized screenshots at representative desktop and mobile widths. Do not include passwords, tokens, QR secrets, invitation secrets, private emails, or full sensitive tracking payloads.

### 14.4 Required final checks

- `.NET` Release build with zero warnings/errors.
- Full backend integration suite.
- Flutter format check.
- Flutter analyzer with no issues.
- Full Flutter test suite.
- EF migration drift check.
- Development Web release build.
- Pilot/Production-style Web release build.
- Docker/API/PostgreSQL health checks.
- Verify `.env`, retained database/volume identity, and retained business counts were not unexpectedly modified.
- Attempt Android validation only if a valid SDK/device exists. Report the exact environment limitation honestly if unavailable.

---

## 15. Performance and regression guardrails

- Do not add a new high-frequency whole-dashboard polling loop merely for the redesign.
- Do not fetch complete trip geometry/tracking history in Driver history list responses.
- Cancel or supersede stale requests using the project's latest-wins patterns.
- Avoid rebuilding large map/widget subtrees because unrelated notification/profile data changed.
- Keep Company Users and notification convergence behavior intact.
- Do not add an unnecessary global state-management or animation package.
- Do not perform unrelated package upgrades in this sprint. If a dependency change is essential, isolate and justify it in the plan and final report.
- Do not refactor large working files solely for aesthetics; extract components along real ownership boundaries and keep behavior covered by tests.
- Preserve deep links, browser refresh behavior, workspace switching, and route guards.
- Preserve all existing business data and migrations.

Record useful evidence such as map create/dispose counts, annotation adds/updates/removals, polling camera moves, fatal map errors, and simulator endpoint availability by profile. Do not fabricate browser or performance evidence.

---

## 16. Documentation and evidence

Update:

- `README.md` with build-profile commands and the new Driver history entry points.
- `docs/architecture.md` with an ADR for the flexible design system/capability profiles if this changes architectural policy.
- `docs/design-system.md` with tokens, component boundaries, breakpoints, typography, motion, accessibility, and future theme replacement instructions.
- `docs/sprints/sprint-4.4/SPRINT4_4_IMPLEMENTATION_PLAN.md` with final status and actual elapsed times.
- `docs/evidence/sprint4_4/README.md` as an evidence index.

Evidence should include:

- Test/build outputs.
- Migration drift result.
- Capability-profile matrix verification.
- Backend authorization/isolation results.
- Sanitized desktop/mobile screenshots in both languages.
- Owner/Driver browser workflow results.
- Map lifecycle/annotation/camera counters.
- Known limitations and deferred work.

Do not bloat the main README with raw evidence. Link to focused documentation instead.

---

## 17. Definition of done

Sprint 4.4 is complete only when all of the following are true:

- One coherent professional visual preset is implemented through centralized tokens.
- A future theme/layout revision can replace presentation components/tokens without changing business logic or API contracts.
- Core Owner and Driver screens are responsive and polished in Arabic and English.
- The fleet map is materially larger and supports full-screen use without lifecycle or camera regressions.
- Driver `My Trips` history and authorized trip detail are complete, paginated/bounded, and tenant-safe.
- Trip-associated places and trails are available without introducing off-duty Driver surveillance.
- Motion is purposeful, centralized, interruptible, and respects reduced motion.
- Development retains the simulator.
- Pilot/Production exposes no simulator UI or mutation endpoints and creates no demo data.
- All existing functionality and full automated suites pass.
- Mandatory real Firefox acceptance passes.
- Data safety checks pass.
- Documentation and sanitized evidence are complete.
- The implementation plan contains truthful active elapsed times.
- No commit or push was performed unless explicitly requested.

If a mandatory scenario cannot be verified, report the sprint as incomplete and explain the exact blocker. Do not substitute API calls, unit tests, or screenshots for a required real UI workflow, and do not claim success for behavior that was not observed.

---

## 18. Final response format

At completion, report:

1. What changed, grouped by design system, Owner experience, Driver experience, and build profiles.
2. Important architectural decisions that preserve future design flexibility.
3. Automated validation totals and build results.
4. Real-browser scenarios completed.
5. Capability-profile proof for Development versus Pilot/Production.
6. Data-safety verification.
7. Exact known limitations, including Android/device limitations.
8. Documentation/evidence paths.
9. Actual elapsed time by task and total.
10. Git status and confirmation that nothing was committed or pushed unless requested.
