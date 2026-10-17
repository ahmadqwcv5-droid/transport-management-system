# Sprint 4.4.2 — Atlas Pulse Visual Foundation and Owner Command Center

You are working in the existing `transport-management-system` repository. Start from the current checked-out `HEAD`; do not assume that an older sprint report describes the current code exactly.

## Mission

Implement the approved **Atlas Pulse V2** design direction inside the real Flutter application as the first production-quality visual slice.

This sprint is deliberately limited to:

1. A reusable and replaceable visual foundation.
2. The Owner/management application shell.
3. The Owner operational dashboard and its real MapLibre/OpenFreeMap fleet experience.
4. Regression protection for all existing Driver screens and operational behavior.

This is an implementation sprint, not another concept-generation exercise. Do not invent a competing design or merely enlarge the existing cards. Translate the approved direction into maintainable Flutter code and connect every visible operational value to real application state.

## Approved references

- Interactive design reference: `https://transport-atlas-pulse-design.livelytern2.chatgpt.site`
- Preferred visual reference, when available in the supplied materials: `concept_b_dashboard_1440_ar.png`
- Design direction: a precise, calm, dark operational command center with a dominant map; compact, integrated panels; subtle depth; restrained color; and high information clarity.

If the private interactive reference is inaccessible, do not block. Follow the complete specification below. The prototype's SVG map and sample values are visual references only; they must never replace the real map or real application data.

## Non-negotiable rules

- Preserve all existing business behavior, permissions, localization, tracking, routing, notifications, tenancy, and Driver workflows.
- Use the existing **MapLibre/OpenFreeMap** integration. Do not replace it with a static image, SVG map, iframe, or another provider.
- Do not introduce fake trucks, trips, alerts, KPIs, weather, ETAs, drivers, routes, or locations to make the dashboard resemble the prototype.
- Every operational value must come from existing real state/endpoints, be derived truthfully from that state, or show a localized unavailable/empty state.
- Do not recreate or dispose the map because a KPI, notification, list selection, or polling result changes.
- Do not globally clear and rebuild map annotations during polling.
- Do not change the Driver workspace design or workflows except where harmless shared visual primitives are required. The current Driver screens are approved.
- Do not add database migrations or backend schema changes for visual convenience. If a missing backend field materially blocks a truthful UI, document it and use an honest unavailable state. Only make a minimal backend change if it is demonstrably necessary and fully tested.
- Do not modify `.env`, retained credentials, existing PostgreSQL data, Docker volume identities, or production defaults.
- Do not commit or push. Leave the completed changes in the working tree for review.
- Do not claim browser, Android, visual, or interaction validation that was not actually performed.

## Required pre-work

Before editing code:

1. Inspect the repository structure, current Flutter architecture, application shell, dashboard state/controllers, MapLibre lifecycle, tracking polling, localization setup, design/theme code, and existing tests.
2. Read the latest sprint plans, architecture documentation, and evidence relevant to UI, map behavior, tracking, Driver workspace, and Sprint 4.4.x.
3. Record the current Git `HEAD`, worktree state, running Compose project, container/volume identities, current migration, retained record counts, `.env` hash, and baseline test results without exposing secrets.
4. Identify existing user changes and preserve them.
5. Create and maintain:

   `docs/sprints/sprint-4.4.2/SPRINT4_4_2_IMPLEMENTATION_PLAN.md`

The plan must contain tasks, risks, design decisions, acceptance criteria, actual elapsed time per task, and the final total. Update it during the work, not retroactively at the end.

## 1. Reusable visual foundation

Create a small, documented design layer rather than embedding one-off values throughout the dashboard.

Centralize at minimum:

- semantic colors for command-center background, elevated surfaces, secondary surfaces, borders, primary text, muted text, success, warning, critical, informational, route planned, and route travelled;
- typography roles and numeric styles;
- spacing scale;
- corner-radius scale;
- borders, shadows/elevation, icon sizes, control heights, and panel density;
- motion durations and curves;
- responsive breakpoints or layout policies.

Prefer Flutter theme primitives and `ThemeExtension`/equivalent semantic abstractions over global constants tied to one screen. The foundation must support:

- the dark Owner command center;
- existing light data/CRUD screens;
- Arabic RTL and English LTR;
- future visual replacement without rewriting business logic.

Create reusable presentation components where appropriate, such as:

- command-center shell;
- KPI/stat item;
- status badge;
- section header;
- fleet row;
- selected-vehicle inspector;
- operational alert/exception item;
- active-trip progress item;
- compact command button;
- loading, empty, partial-data, stale-data, offline, and error states.

Do not build a giant dashboard widget or allow presentation widgets to own repositories, polling, map synchronization, routing logic, or domain transitions. Introduce view models/adapters where necessary so widgets do not depend directly on transport DTOs.

Document where the tokens and reusable components live and how future screens should adopt them.

## 2. Owner application shell

Implement the approved Owner shell across Owner/management screens while preserving their current business content.

Required characteristics:

- refined dark sidebar with restrained density and clear active state;
- company/workspace identity and active role;
- compact integrated top bar;
- notifications and account entry points using the real existing flows;
- locale-aware RTL/LTR ordering;
- responsive navigation for narrower screens;
- clear keyboard focus and hover/pressed states;
- no fake search control: either connect search to a useful existing search flow or omit it from this sprint;
- no hardcoded weather, clock, “live” status, company, user, or role values.

Other Owner domain pages may retain their current light content surfaces in this sprint. Ensure the transition between the dark shell and light work areas is intentional and visually coherent. Do not redesign all CRUD pages yet.

## 3. Owner operational dashboard

Replace the current dashboard composition with the approved Atlas Pulse command-center hierarchy.

### 3.1 Compact operational summary

Create a compact KPI ribbon using the existing dashboard/tracking state. Show only metrics that can be derived truthfully, for example:

- connected vehicles;
- moving/on-trip vehicles;
- available vehicles;
- active trips;
- items requiring attention.

Metric labels, semantics, and calculations must remain consistent with the existing domain definitions. A loading, partial, failed, or unavailable endpoint must not silently display zero.

### 3.2 Dominant map stage

The map must be the dominant visual surface, not one card among many. Integrate:

- the real MapLibre/OpenFreeMap basemap;
- the existing real truck image markers and status treatments;
- planned route, travelled trail segments, pickup/delivery stops, and existing route semantics;
- existing Arabic label shaping and locale behavior;
- the real selected truck, route, progress, and telemetry state.

The static prototype map must not enter production code.

### 3.3 Integrated fleet dock

Place a compact fleet list beside/over the map on wide layouts. It must:

- use real tenant-scoped trucks and current positions;
- show plate/display name, current Driver when available, connectivity/operational state, and physical speed when available;
- provide useful filters based on states the current domain can support, such as all, connected, moving, stationary, offline, or attention;
- synchronize selection bidirectionally with the map marker and inspector;
- preserve the selected item during polling and incremental updates;
- virtualize or otherwise avoid avoidable rebuild cost if the fleet grows;
- show truthful empty/unavailable states.

### 3.4 Floating selected-vehicle inspector

Selecting a truck from the map or fleet dock must open/update one compact inspector showing real available information:

- truck identity and image/avatar treatment already supported by the application;
- connection and movement state;
- Driver/current session when available;
- trip number and phase when assigned;
- physical speed;
- ETA, remaining distance, and progress only when valid;
- route summary and relevant operational action links.

Do not fabricate trip information for an idle truck. Provide real navigation to the existing truck or trip detail screen where permissions allow.

### 3.5 Active trips and exceptions rail

Below the map, add a compact responsive rail containing:

- active trips ordered by an operationally useful existing value such as ETA or progress;
- progress/phase, truck, route summary, and remaining time only when valid;
- operational exceptions/alerts drawn from the existing notification/operational state;
- real links to the relevant trip, truck, or notification destination.

Do not create new backend alert semantics in this visual sprint. If the existing system cannot provide a proposed exception category, omit it instead of simulating it.

## 4. Map lifecycle and interaction contract

Preserve and verify all established behavior from previous map/tracking sprints:

- camera modes: fleet overview, follow vehicle, free explore, and route overview;
- selecting a vehicle focuses it at an appropriate close operational zoom;
- an explicit action displays the full route;
- mouse-wheel zoom while the pointer is over the map changes the map zoom and does **not** scroll the containing page;
- wheel zoom preserves follow mode;
- manual pan/drag pauses follow and enters free exploration;
- polling never moves the camera during free exploration;
- the user can explicitly resume following or recenter;
- camera zoom is not reset on normal position updates;
- latest-wins interpolation and heading behavior remain intact;
- stale/offline handling remains accurate;
- no marker-image-to-placeholder flash during movement;
- no map failure when a vehicle reaches pickup/delivery or a route/trail/stop annotation changes;
- no route refit during polling;
- annotations remain incremental and independently synchronized;
- no global symbol, line, or circle clears.

The selected vehicle, fleet dock, inspector, map route/trail, and bottom trip item must converge on the same state without race conditions.

## 5. Visual language

Use the following as semantic direction, not as permission to scatter raw color values throughout widgets:

- command-center background near `#04131C`;
- primary operational surface near `#071D28`;
- secondary operational surface near `#092531`;
- restrained border near `#164151`;
- primary text near `#EDF9FB`;
- muted text near `#7F9EAA`;
- teal/mint operational accent near `#53D7C8`;
- warning amber and critical coral used only for meaningful states.

Visual requirements:

- compact 8–12 px panel radii rather than large rounded cards everywhere;
- thin borders and subtle depth instead of heavy shadows;
- clear spacing rhythm and information hierarchy;
- dense but readable operational layout;
- the map, fleet dock, inspector, KPI ribbon, and lower rail should feel like one integrated system;
- no gradients or glass effects that reduce map/label readability;
- no excessive pills, oversized typography, or decorative whitespace;
- numbers and Latin identifiers must retain correct LTR isolation inside Arabic UI.

The goal is calm precision, not visual spectacle.

## 6. Motion and accessibility

Use motion only where it communicates state or continuity:

- hover/focus/press: approximately 120–180 ms;
- selection and panel transitions: approximately 180–240 ms;
- route/inspector changes may use restrained opacity/position transitions without replacing map objects;
- no decorative infinite animation, pulsing status dots, bouncing markers, or continuous background motion;
- do not animate rapidly updating numeric telemetry on every poll;
- honor Flutter/platform reduced-motion preferences and provide an immediate equivalent state;
- animations must never block an operational action or conceal stale data.

Accessibility requirements:

- correct semantic reading order in RTL and LTR;
- visible keyboard focus;
- meaningful labels/tooltips for icon-only actions;
- sufficient contrast for text, controls, routes, status, and selected states;
- touch targets suitable for supported devices;
- color is not the only indicator of status.

## 7. Responsive requirements

Validate at minimum:

- desktop: 1440 × 900;
- compact desktop/tablet landscape: approximately 1024 × 768;
- narrow browser/mobile-width layout sufficient to remain operational without overflow.

Expected adaptation:

- wide desktop: fleet dock + map + floating inspector + full lower rail;
- compact layout: fleet dock may become a constrained overlay/drawer and lower rail may stack;
- narrow layout: preserve map usability, selection, inspector access, and navigation; secondary dashboard information may collapse progressively.

Do not force the entire desktop command center into an unreadable mobile grid. A complete Owner mobile redesign is out of scope, but the screen must remain usable.

## 8. Driver workspace protection

Keep the approved Driver screens visually and functionally stable:

- Today;
- My Truck;
- My Trips and trip history/details;
- profile/password;
- active-trip map;
- idle and post-trip truck map visibility;
- assignment/acceptance workflow;
- simultaneous Owner and Driver sessions.

Shared theme refactoring must not unintentionally darken, resize, reorder, or otherwise redesign Driver surfaces. Capture before/after or regression evidence demonstrating that Driver behavior remains intact.

## 9. Explicitly out of scope

- redesigning every Trips, Trucks, Clients, Drivers, People, Invitations, Settings, or CRUD screen;
- finance, maintenance, documents, or new business modules;
- trip-state or dispatch workflow changes;
- notification-domain changes;
- simulator feature changes;
- routing-provider changes;
- real GPS provider integration;
- a new map provider;
- new database entities solely for the dashboard;
- speculative analytics or fabricated operational alerts;
- production deployment, commit, or push.

## 10. Required automated validation

Run and report the repository's relevant commands. At minimum:

- .NET Release build with zero warnings/errors, unless a documented pre-existing warning is proven from baseline;
- all backend tests;
- EF migration/model drift verification;
- Flutter dependency resolution;
- Flutter analyzer with no issues;
- all Flutter unit/widget tests;
- focused tests for new visual primitives and dashboard state mapping;
- Flutter Web release build;
- any existing localization generation/checks;
- existing Driver and map regression suites.

Add tests that prove at least:

- KPI unavailable state is distinct from zero;
- fleet filtering and selection synchronization;
- selection persists across a tracking update;
- idle truck inspector does not invent a trip;
- RTL/LTR order and identifier isolation;
- responsive layout has no overflow at required sizes;
- reduced-motion disables nonessential transitions;
- dashboard rebuilds do not recreate the map/controller;
- wheel events over the map do not scroll the page;
- pan pauses follow, wheel zoom preserves follow, and free camera is not moved by polling.

## 11. Mandatory real-browser acceptance

Use the available real browser (Firefox is acceptable when Chrome is unavailable) against the real local stack. Do not substitute only widget tests for browser acceptance.

Test with retained or isolated tenant data as safely appropriate:

1. Log in as Owner.
2. Open the redesigned dashboard in Arabic RTL.
3. Verify real KPI values and meaningful loading/empty/error behavior.
4. Select trucks from both the fleet dock and map.
5. Confirm map marker, list, inspector, route/trail, and trip rail remain synchronized.
6. Exercise all fleet filters.
7. Test wheel zoom without page movement.
8. Test follow → zoom → follow preserved.
9. Test follow → manual pan → free explore.
10. Observe at least 30 tracking updates and verify:
    - one map instance remains active;
    - no global annotation clears;
    - no polling camera moves while free exploring;
    - no selected-truck loss;
    - no marker image flash;
    - no fatal map renderer errors.
11. Test route overview and explicit recenter/follow.
12. Exercise stale, offline, no-position, no-active-trip, partial-data, and map-failure/retry states where safely possible.
13. Switch to English LTR and repeat the key hierarchy/map checks.
14. Validate the 1440 × 900, 1024 × 768, and narrow layouts.
15. Open a separate Driver profile and verify approved Driver screens and concurrent session behavior remain intact.
16. Log out independently and verify background polling stops only for the logged-out session.

If a real browser scenario is blocked by the environment, state the exact blocker and do not mark that scenario passed.

## 12. Evidence requirements

Create:

`docs/evidence/sprint4_4_2/README.md`

Include sanitized evidence for:

- Arabic Owner dashboard at 1440 × 900;
- English Owner dashboard at the same state/viewport;
- compact desktop layout;
- narrow responsive layout;
- selected vehicle with route/trail/stops and inspector;
- fleet filter state;
- empty/partial/failure state;
- reduced-motion state or automated proof;
- unchanged Driver Today/My Truck/My Trips/Profile screens;
- browser console/renderer result;
- annotation/map lifecycle counters across at least 30 updates;
- Docker health, migration status, test results, and retained-data checks.

Record counters where instrumentation permits:

- map creations and disposals;
- image registrations;
- marker additions/updates/removals;
- route/trail/stop additions/updates/removals;
- global clears;
- polling camera moves;
- follow-preserving zooms;
- manual-pan follow pauses;
- fatal renderer errors.

Evidence must be sanitized. Never retain invitation tokens, QR secrets, passwords, OAuth credentials, bearer tokens, or personal data in screenshots/logs.

## 13. Documentation

Update the relevant documentation, including:

- `README.md` for visual/runtime behavior where needed;
- `docs/architecture.md` with a concise UI architecture/design-system decision;
- the Sprint 4.4.2 plan with decisions, compromises, validation, limitations, and exact active elapsed time.

Explain:

- token/component ownership;
- the boundary between presentation state and operational/map state;
- how later screens should adopt Atlas Pulse incrementally;
- how dark operational surfaces coexist with light CRUD surfaces;
- how reduced motion and RTL/LTR are handled;
- what remains intentionally deferred.

## Definition of done

Sprint 4.4.2 is complete only when all of the following are true:

- the real Owner dashboard visibly reflects the approved Atlas Pulse V2 hierarchy and polish;
- the result is a genuine structural redesign, not resized versions of the previous cards;
- all displayed operational information is real or truthfully unavailable;
- the real map remains stable and functionally equivalent or better;
- Arabic RTL and English LTR are both correct;
- the required viewport sizes are usable without overflow;
- motion is restrained and reduced-motion is honored;
- Driver screens and workflows remain intact;
- automated and real-browser acceptance pass, or any environmental limitation is reported honestly;
- retained data, `.env`, credentials, containers, and volumes remain safe;
- evidence and documentation are complete;
- changes are left uncommitted and unpushed.

## Final report format

Return a concise report containing:

1. Implemented visual foundation and component structure.
2. Implemented Owner shell/dashboard behavior.
3. Map lifecycle and interaction results.
4. Driver regression results.
5. Automated validation totals.
6. Real-browser scenarios and screenshots/evidence locations.
7. Retained-data and environment safety results.
8. Known limitations and deliberately deferred work.
9. Per-task active elapsed time and total.
10. Git status, explicitly confirming that no commit or push was performed.
