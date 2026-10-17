# Sprint 4.4.1 — Original Visual Redesign and Interaction Repair

You are working in the existing `transport-management-system` repository. Implement Sprint 4.4.1 as a two-phase, approval-gated visual redesign and interaction-repair sprint.

The application already has substantial, validated business behavior. Sprint 4.4 added useful Driver trip history, capability profiles, local fonts, and an initial token layer, but it did **not** deliver the intended visible redesign. The repository's own Sprint 4.4 evidence also records that mandatory real-browser visual acceptance was incomplete. Treat this sprint as a corrective product-design sprint, not as a new business-feature sprint.

Do not commit or push unless explicitly requested. Do not overwrite `.env`, retained PostgreSQL data, Docker volumes, credentials, uploads, or user business records. Do not reset, clean, or discard unrelated working-tree changes.

---

## 1. Mission

Deliver a genuinely original, polished visual identity and interaction model for the transport-management product while preserving all existing domain behavior.

The final product must:

1. Look intentionally designed for this fleet-operations product rather than like a generic Material admin template.
2. Have a recognizable, original visual identity that works especially well in Arabic, while remaining equally strong in English.
3. Use purposeful, smooth motion where it improves comprehension.
4. Keep operational information dense, legible, and fast to use.
5. Remain easy to redesign later through tokens, component variants, and reusable layout compositions.
6. Fix the map wheel-zoom/page-scroll conflict.
7. Provide a real full-screen fleet-map experience.
8. Make Driver **Today**, **My Truck**, and **My Trips** genuinely different, purposeful destinations.
9. Preserve the successful Sprint 4.4 Driver history and simulator isolation.

---

## 2. Reference-site rule

The public site `https://smartfleetksa.com` is supplied only as a **quality benchmark** for:

- Visual craftsmanship.
- Cohesive branding.
- Arabic typography.
- Hierarchy and whitespace.
- Original card treatments and graphical details.
- Subtle motion and interaction polish.

It is **not** a requested design template.

Mandatory restrictions:

- Do not copy its layout, logo, colors, illustrations, CSS, assets, text, animations, or component shapes.
- Do not scrape or reuse any of its files.
- Do not produce a pixel-level imitation.
- Do not turn the operations application into a spacious marketing landing page.
- Use it only to understand the expected level of care and cohesion.

Create a product identity that is original to this transport-management system: modern, confident, calm, operational, Arabic-first, and trustworthy.

---

## 3. Hard phase gate — do not skip

This sprint has two phases. **Phase A must stop for user approval.**

### Phase A — Visual design exploration

Create real, inspectable design concepts and present them to the user. Do not implement the production redesign yet.

### Phase B — Approved implementation

Begin only after the user explicitly selects or approves a concept and provides any requested corrections.

If no explicit approval has been received, stop after Phase A. Do not select a design on the user's behalf, do not silently merge concepts, and do not report the sprint as complete.

---

## 4. Scope boundaries

### In scope

- Original product identity and visual language.
- A design-preview/Design Lab used only during Phase A.
- Flexible design architecture beyond simple color tokens.
- Application shell and navigation redesign.
- Owner/Operations command-center dashboard redesign.
- Fleet-map layout and interaction repair.
- A dedicated Driver My Truck screen.
- Visual redesign of Driver Today and My Trips.
- Consistent styling of core operational and account screens.
- Purposeful motion and loading transitions.
- Accessibility, Arabic/English, responsive behavior, and real-browser verification.
- Regression tests, sanitized evidence, and documentation.

### Explicitly out of scope

- Finance, payments, billing, or subscriptions.
- Maintenance management.
- New trip states or trip-workflow redesign.
- New authentication, membership, QR, notification, handover, or Driver-history business features.
- Real GPS provider integration.
- Public company/Driver marketplace.
- SignalR or polling-architecture replacement.
- Route optimization.
- Dark mode unless approved as the selected identity and achievable without expanding scope.
- Backend/domain refactoring unrelated to an essential UI contract.
- Dependency upgrades unrelated to the approved implementation.

Prefer no backend schema or API changes. A UI redesign is not justification for changing validated business behavior.

---

## 5. Baseline and investigation

Before Phase A:

1. Fetch and inspect the latest repository state and record the exact HEAD SHA.
2. Read Sprint 4.4's prompt, plan, evidence, design-system document, and architecture changes.
3. Run and record the current backend build/tests, Flutter analyzer/tests, EF drift check, and Web build.
4. Inspect the current application in a real browser at representative widths.
5. Capture sanitized baseline screenshots of the current UI at the same viewports that will be used for final comparison.
6. Confirm the following known issues from code and runtime rather than assuming they are already fixed:
   - `/my-trip` and `/my-truck` currently resolve to the same screen.
   - Wheel input over the fleet map can zoom the map and scroll the dashboard simultaneously.
   - Current “full screen” only enlarges the map inside the dashboard scroll view.
   - The KPI grid can produce three oversized rows on wide desktops.
   - Most existing feature screens have not adopted the new design system.
   - Motion tokens have little or no visible adoption.
7. Inventory existing routes, stable test keys, MapLibre lifecycle guarantees, camera modes, notification behavior, Driver history, and simulator capability profiles.

Create:

`docs/sprints/sprint-4.4.1/SPRINT4_4_1_IMPLEMENTATION_PLAN.md`

It must include baseline SHA/results, design audit, risks, phase status, task status, intended files, acceptance mapping, rollback notes, and truthful active elapsed times.

---

# PHASE A — DESIGN EXPLORATION AND USER APPROVAL

## 6. Development-only Design Lab

Create a temporary, Development-only design-preview surface that can render realistic static/sanitized data without modifying the retained database or calling mutation APIs.

Acceptable implementations include:

- A guarded Flutter `Design Lab` route compiled only for Development.
- A standalone Flutter preview entry point using the real design-system components.

The preview must:

- Use real Flutter rendering, not only prose or a mood board.
- Be excluded from Pilot/Production navigation and builds.
- Use representative Arabic and English content.
- Use realistic truck, trip, status, ETA, and notification examples.
- Contain no real credentials, QR secrets, tokens, or personal information.
- Reuse production-intended primitives so the approved concept can be implemented faithfully.

Do not modify live feature screens during Phase A beyond the minimal isolated preview infrastructure.

---

## 7. Produce three genuinely distinct original concepts

Create three original visual directions. They must not be trivial recolors of the same generic Material layout.

Each concept must define and visibly demonstrate:

- Design rationale and three to five identity adjectives.
- Original palette with semantic operational colors.
- Arabic and Latin typography pairing.
- Brand/app mark treatment. If the product has no final brand name/logo, create a replaceable, original code-native placeholder mark rather than copying any external identity.
- Navigation/sidebar language.
- Background and surface strategy.
- Card variants and information density.
- Table/list treatment.
- Map controls and overlay treatment.
- Status and alert treatment.
- Buttons, inputs, filters, tabs, and dialogs.
- Empty/loading/error states.
- Motion direction with at least three visible microinteraction examples.
- Mobile adaptation.

At least one concept may explore a deeper operational/navy visual language, but do not default to the application's existing Material blue or reproduce Smart Fleet's palette. The three concepts must be recognizably different in composition, not merely hue.

For every concept, render these same representative surfaces:

1. Owner/Operations dashboard at approximately 1440 px width in Arabic RTL.
2. Owner/Operations dashboard at approximately 1440 px width in English LTR.
3. Driver Today at approximately 390 px width in Arabic RTL.
4. Driver My Truck at approximately 390 px width in Arabic RTL.
5. A component/motion sheet showing navigation, buttons, inputs, status badges, trip progress, notification, loading state, and side/bottom-panel transition.

Also verify the concepts do not overflow near 360 px and remain structurally reasonable near 768 px.

---

## 8. Phase A deliverables and mandatory stop

Save under:

`docs/evidence/sprint4_4_1/design_concepts/`

Required Phase A evidence:

- A short concept brief for each direction.
- Exact palettes and typography.
- Sanitized screenshots at the required sizes.
- A short motion description or captured frames/GIF/video if the environment supports safe, reproducible capture.
- A comparison table covering originality, readability, density, Arabic quality, mobile suitability, implementation risk, and long-term flexibility.
- A recommendation, clearly labeled as a recommendation rather than a decision.
- Clear instructions for previewing each concept locally.

At the end of Phase A:

1. Report baseline findings.
2. Present the three concepts and evidence paths.
3. Ask the user to choose one concept or request specific changes.
4. Mark the sprint `awaiting_design_approval`.
5. Stop. Do not begin Phase B.

---

# PHASE B — IMPLEMENT THE APPROVED CONCEPT

Proceed only after explicit user approval.

## 9. Flexible visual architecture

Preserve the useful Sprint 4.4 token work, but extend flexibility into four clear layers:

1. **Foundation tokens** — color, typography, spacing, radius, elevation, icon sizing, borders, touch targets, breakpoints, and motion.
2. **Component variants** — buttons, inputs, cards, badges, navigation items, alerts, tables/lists, dialogs, map controls, panels, skeletons, and empty/error states.
3. **Layout compositions** — application shell, page frame, command-center layout, KPI strip, map workspace, list/detail workspace, Driver task surface, responsive side panel, and mobile bottom sheet.
4. **Feature composition** — screens compose the reusable layouts/components with typed state and callbacks, without embedding branding decisions or business logic.

Requirements:

- The selected preset must be injectable.
- Migrated feature screens must not define brand colors, fonts, common shadows, or primary radii directly.
- Presentation components must not perform API calls or own domain rules.
- Business controllers/providers/repositories must remain design-agnostic.
- Centralize breakpoints and density rules.
- Bundle licensed fonts locally; do not rely on runtime font CDNs.
- Do not create a runtime theme editor.
- Remove the temporary unapproved concepts and Development Design Lab from the final production path after approval, retaining only useful documentation/screenshots.
- Add an architecture test proving a test preset can restyle migrated surfaces without editing feature-screen source.

Update `docs/design-system.md` with the selected identity and explicit replacement points for future redesigns.

---

## 10. Original application shell

Replace the generic shell with a branded, role-aware operational shell.

### Desktop

Provide an intentional sidebar/navigation system with:

- Original product mark/name area.
- Clearly grouped destinations.
- Strong but restrained selected state.
- Compact/collapsed mode where appropriate.
- Account, workspace, and role identity.
- Notifications and language access.
- Consistent hierarchy and spacing.

### Mobile

Use a deliberate bottom-navigation/drawer pattern appropriate to each role, with safe-area handling and no overcrowding.

Requirements:

- Preserve route guards, permissions, workspace switching, multi-role behavior, login restoration, and logout behavior.
- Do not render unauthorized destinations.
- Prevent unauthorized-content flashes.
- Ensure Arabic RTL changes placement and flow correctly without awkward icon mirroring.
- Navigation selection and shell transitions should use the approved motion language.

---

## 11. Owner/Operations command center

Redesign the dashboard for real operational scanning.

### Information hierarchy

At a glance the manager should understand:

- How many vehicles are active, available, offline, or need attention.
- Which trips are active or nearing pickup/delivery.
- Where the fleet is.
- Which exceptions require action.

### KPI treatment

- Do not use nine equally prominent oversized cards.
- Show approximately three to five primary KPIs in a compact, responsive strip.
- Show secondary fleet states as compact counters/status pills or a concise secondary row.
- At 1440 px, the primary KPI area should normally occupy no more than one row.
- At 768 px, it should normally occupy no more than two compact rows.
- The top portion of the map must remain visible in the initial 1440×900 viewport without scrolling.

### Map workspace

- Give the map the dominant operational area, generally around 60–70% of the useful viewport height on desktop.
- Provide a visually integrated fleet list/filter panel.
- Provide a focused selected-truck panel.
- Keep route, trail, stops, truck marker/avatar, ETA, phase, connection state, and last update legible.
- Use the approved component and motion language without covering essential map content or attribution.
- Keep secondary sections such as active/recent trips below or in a deliberate split view.

Preserve the existing tracking, chronology, marker, label, RTL, follow, camera, and annotation guarantees.

---

## 12. Repair wheel zoom versus page scroll

Fix the underlying pointer-signal/gesture arbitration rather than hiding the symptom.

Required behavior:

- When the pointer is over an interactive fleet map, mouse-wheel input changes map zoom and does not move the ancestor dashboard/page scroll position.
- When the pointer is outside the map, mouse-wheel input scrolls the page normally.
- Touch pinch/drag behavior remains correct on touch devices.
- Intentional map pan pauses follow according to existing rules.
- Wheel zoom preserves follow according to the approved existing behavior.
- The solution must not disable normal keyboard/page scrolling or trap focus.

Add:

- A focused widget/integration test with the map listener nested inside a real scrollable, asserting that map zoom occurs while the parent scroll offset remains unchanged.
- A second assertion that wheel input outside the map scrolls the page.
- A real Firefox mouse-wheel acceptance test using actual rendered UI, not only a direct callback invocation.

Do not claim this is fixed based only on `onPointerSignal` being called.

---

## 13. Real full-screen map

Replace the current height toggle with a true viewport-level full-screen experience.

Requirements:

- Hide or overlay the surrounding dashboard while full screen.
- Fill the usable browser viewport.
- Preserve the same selected truck, camera coordinates, zoom, bearing, follow/free-explore state, route/trail visibility, filters, and annotation state on entry and exit.
- Provide a clear localized exit control.
- Support Escape/back behavior where appropriate.
- Do not create a second active map, duplicate polling, clear annotations, or reset the camera.
- Do not place the full-screen map inside the dashboard's scrolling content.
- Maintain MapLibre attribution.

Instrument and prove map create/dispose counts during full-screen entry/exit.

---

## 14. Distinct Driver destinations

The Driver navigation must contain three semantically different experiences.

### 14.1 Today

Purpose: **What must I do now?**

Show:

- Driver and active company identity.
- Current/next assigned trip.
- Pickup/delivery summary.
- Current phase, progress, remaining distance, and ETA.
- The single next required Driver action.
- Connection/location freshness.
- A compact truck summary linking to My Truck.
- Clear no-trip state without losing the Driver's vehicle context.

### 14.2 My Truck

Create a dedicated `DriverTruckScreen` or equivalently clear feature screen. Do not route it to `DriverMyTripScreen`.

Purpose: **Which vehicle am I responsible for, and what is its current state?**

Show, when authorized/available:

- Truck photo/avatar.
- Plate, fleet code, make/model, and operational status.
- Current Driver–truck session/default assignment distinction.
- Online/offline/stale state and last location update.
- Current speed/heading when meaningful.
- Live truck map even when there is no active trip.
- Current trip reference as a link when one exists, without duplicating the full Today workflow.
- QR/manual truck-switch entry point and approval state using the existing business rules.
- Clear actions for the existing supported session/switch workflow.
- Useful no-truck, unavailable-location, stale, and offline states.

Do not expose another Driver's private data or add new truck-session business semantics.

### 14.3 My Trips

Purpose: **What work have I been assigned and completed?**

Preserve Sprint 4.4's tenant-safe pagination, filters, handover participation intervals, route/trail authorization, and detail timeline. Redesign its presentation using the selected visual language without regressing the backend behavior.

Mandatory distinction tests:

- `/my-trip` and `/my-truck` render different screen keys, headings, purpose, and primary content.
- Today does not become a duplicate truck-profile page.
- My Truck does not become a duplicate trip-action page.
- An idle Driver with a resolved truck can open My Truck and see its current authorized map/state.

---

## 15. Core-screen visual migration

The redesign must not stop at the dashboard while the rest of the product remains visually unrelated.

### Deeply redesign in this sprint

- Login and invitation entry surface.
- Shared application shell.
- Owner/Operations dashboard and fleet map.
- Trips list and trip details/planner's shared visual structure, without workflow changes.
- Trucks list/details' shared visual structure.
- Driver Today.
- Driver My Truck.
- Driver My Trips and trip history detail.
- Notifications.

### Apply the global selected system consistently

At minimum ensure Clients, Drivers, Company Users, Settings, membership/workspace screens, dialogs, forms, tables, and empty/error states inherit the selected typography, inputs, buttons, surfaces, navigation, spacing, and status treatments. Avoid a visibly old app embedded inside a new shell.

Do not perform risky feature refactors solely to remove every raw Material widget. Migrate through reusable primitives where it materially improves consistency and future replacement.

---

## 16. Purposeful motion

Motion must be visible enough to make the product feel crafted, but restrained enough for daily operations.

Implement the approved motion language in meaningful places such as:

- Navigation selection and sidebar expansion.
- Page/section entrance.
- Selected-truck panel and mobile bottom sheet.
- Trip phase/progress changes.
- Status badge transitions.
- Notification/toast appearance.
- Loading skeleton to loaded content.
- Empty-state/action transitions.
- Full-screen map entry/exit.

Requirements:

- Centralize durations and curves.
- Typical UI motion should generally remain around 150–350 ms.
- Prefer Flutter-native animation primitives.
- Do not add a large animation dependency without explicit justification.
- Do not animate whole pages on each poll.
- Telemetry updates must not restart entrance animations.
- Newer state wins; animations must be interruptible.
- Respect `disableAnimations`/reduced motion.
- Reduced motion must preserve clarity and functionality.
- Maintain map stability and avoid per-frame MapLibre container resizing where unsafe.

---

## 17. Original assets and brand safety

- Use only original, appropriately licensed, or already-owned assets.
- Do not copy icons, logos, illustrations, CSS, screenshots, or animation files from the reference site or other products.
- Prefer the existing icon system, original SVG/code-native marks, or original generated assets when genuinely needed.
- If an image-generation capability is used, document prompts/source and ensure the output is original and appropriate for commercial product use.
- Keep brand assets replaceable through one documented layer.

---

## 18. Preserve validated functionality

Do not regress:

- Authentication, Google readiness/login, refresh-token behavior, and logout.
- Invitations, membership lifecycle, workspace switching, and multi-role accounts.
- Driver/account linking.
- Truck QR/manual codes and handover approval.
- Trip planner/state machine and assignment rules.
- Driver confirmation workflow.
- Notification categories, destinations, sound, and convergence.
- Arabic MapLibre labels and RTL shaping.
- Truck image markers, interpolation, route/trail rendering, and map camera modes.
- Driver history authorization and pagination.
- Development simulator behavior.
- Pilot/Production simulator isolation.
- Tenant isolation and retained data.

Do not reintroduce simulator controls into Pilot/Production. Development may retain them exactly as intended.

---

## 19. Testing requirements

### 19.1 Automated Flutter tests

Add or update tests for:

- Selected preset/theme injection.
- Semantic tokens and component variants.
- Layout composition at approximately 360, 390, 768, 1024, and 1440 px.
- Arabic RTL and English LTR.
- No overflow on all migrated critical screens.
- Distinct Today/My Truck/My Trips routes and content.
- Idle Driver My Truck state.
- Wheel-over-map consumes zoom without changing ancestor scroll offset.
- Wheel-outside-map scrolls the page.
- True full-screen state preserves map selection/camera/follow state and does not create a duplicate map.
- Reduced-motion behavior.
- Polling does not restart decorative animations.
- Pilot/Production remains simulator-free.
- Existing map, Driver history, capability, auth, notification, QR, and workflow suites remain green.

Use durable golden/visual regression tests for a small set of critical selected-concept surfaces:

- Owner dashboard at 1440 LTR and RTL.
- Driver Today at approximately 390 RTL.
- Driver My Truck at approximately 390 RTL.
- One representative operational dialog/panel.

Do not create hundreds of brittle goldens.

### 19.2 Backend validation

No backend behavior should need redesign. Run the full backend suites and prove no tenant, Driver-history, simulator-capability, trip, QR, handover, auth, or notification regression.

If an API/backend change becomes truly necessary, stop and document why before expanding scope.

### 19.3 Real-browser acceptance — mandatory

Use a real rendered browser workflow. The exact automation framework is an implementation detail; if the Flutter integration runner fails, use a reliable installed alternative such as direct Selenium/GeckoDriver or Playwright against the built Web application. API calls and widget tests are not substitutes for visual acceptance.

Prove at minimum:

1. Owner dashboard in Arabic and English at 1440 px.
2. Responsive shell and dashboard near 768 px and 360/390 px.
3. The selected visual concept visibly matches the approved Phase A design.
4. Primary KPI strip remains compact and the map is visible in the first desktop viewport.
5. Mouse wheel over map zooms without page movement; record map zoom and page scroll offset before/after.
6. Mouse wheel outside map scrolls normally.
7. Full-screen map fills the viewport, Escape/exit works, and camera/selection/follow state survives.
8. At least 20 tracking updates produce no map recreation, global annotation clear, unintended camera move, or renderer failure.
9. Driver Today, My Truck, and My Trips are distinct and functional in separate routes.
10. Idle Driver with an assigned/resolved truck sees My Truck map/state.
11. Driver trip history/detail remains functional.
12. Navigation, panels, progress, notifications, and loading transitions visibly use the approved motion language.
13. Reduced-motion mode suppresses nonessential motion.
14. Independent Owner and Driver sessions remain valid.
15. Pilot/Production exposes no simulator controls or endpoints.

If no real browser can complete these scenarios, mark the sprint incomplete. Do not describe it as visually accepted.

---

## 20. Visual evidence and acceptance comparison

Save sanitized final evidence under:

`docs/evidence/sprint4_4_1/final/`

For each critical viewport, include:

- Baseline Sprint 4.4 screenshot.
- Approved Phase A concept screenshot.
- Final implemented screenshot.

Use matching viewport sizes and equivalent data/state to make comparison meaningful.

Evidence must include:

- Arabic and English desktop dashboard.
- Driver Today and My Truck mobile views.
- My Trips/history detail.
- Full-screen map.
- Wheel/scroll numeric evidence.
- Map lifecycle/annotation/camera counters.
- Reduced-motion state.
- Test/build results.
- Data-safety results.

Do not include secrets, personal emails, QR/manual codes, invitation tokens, access tokens, passwords, or precise sensitive business-location data.

---

## 21. Required validation

Before final completion run and record:

- `.NET` Release build with zero warnings/errors.
- Full backend automated suite.
- Flutter format check.
- Flutter analyzer with no issues.
- Full Flutter test suite.
- Focused design/interaction/golden tests.
- EF migration drift check.
- Development Web release build.
- Pilot/Production-style Web release build.
- Simulator artifact/endpoint isolation checks.
- Docker API/PostgreSQL health.
- Real-browser acceptance.
- `.env` hash comparison.
- Retained PostgreSQL volume identity and retained business-count comparison.

Attempt Android validation only if a valid SDK/device exists. Report the exact limitation honestly if unavailable.

---

## 22. Documentation

Update:

- `README.md` only with concise user/developer entry points.
- `docs/design-system.md` with the approved identity, tokens, variants, layout compositions, responsive rules, motion, accessibility, asset policy, and future replacement guide.
- `docs/architecture.md` with an ADR only if architectural policy changed.
- `docs/sprints/sprint-4.4.1/SPRINT4_4_1_IMPLEMENTATION_PLAN.md` with both phase histories and truthful elapsed times.
- `docs/evidence/sprint4_4_1/README.md` as a concise evidence index.

Do not bloat README with raw logs or screenshots.

---

## 23. Definition of done

Sprint 4.4.1 is complete only when:

- Phase A produced three genuinely distinct original concepts.
- The user explicitly approved one concept before production implementation.
- The final UI visibly reflects the approved concept rather than generic Material defaults.
- No external site's protected visual identity or assets were copied.
- The application shell, dashboard, fleet map, Driver Today, Driver My Truck, Driver My Trips, and core shared surfaces form one coherent identity.
- Driver My Truck is a dedicated experience, not an alias of Today.
- The map wheel no longer scrolls the page when zooming.
- Outside-map scrolling remains normal.
- Full-screen map is genuinely viewport-level and preserves map state without duplicate map/polling.
- Motion is visible, purposeful, centralized, interruptible, and accessible.
- Arabic/English and responsive acceptance pass.
- Real-browser acceptance passes.
- Existing automated suites remain green.
- Driver history and simulator isolation remain correct.
- Retained data, `.env`, and volumes are preserved.
- Evidence and documentation are complete.
- Actual task times are recorded honestly.
- Nothing was committed or pushed unless explicitly requested.

If any mandatory requirement is unverified, report the sprint as incomplete with the exact blocker.

---

## 24. Phase A response format

When Phase A is ready, report only:

1. Baseline findings.
2. Concept A/B/C names and short rationales.
3. Screenshot/preview paths.
4. Palette/typography/motion comparison.
5. Accessibility and implementation-risk notes.
6. Your recommendation.
7. The explicit statement: `Awaiting user design approval; Phase B has not started.`
8. Git status and confirmation that no commit/push occurred.

Do not report Sprint 4.4.1 as complete at this point.

---

## 25. Final Phase B response format

After approved implementation and complete acceptance, report:

1. Approved concept and any user-requested modifications.
2. What changed by shell, Owner experience, map, Driver experience, motion, and shared screens.
3. How future redesign flexibility is preserved.
4. Exact wheel-scroll and full-screen fixes.
5. Automated test totals/build results.
6. Real-browser scenarios and visual evidence.
7. Map lifecycle/performance counters.
8. Simulator-profile and data-safety verification.
9. Known limitations.
10. Documentation paths.
11. Actual elapsed time by phase/task and total.
12. Git status and confirmation that no commit/push occurred unless requested.
