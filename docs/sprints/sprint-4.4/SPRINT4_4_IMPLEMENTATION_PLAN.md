# Sprint 4.4 Implementation Plan

## Status and timing policy

- Sprint status: **Incomplete — real-Firefox acceptance blocked**. Automated,
  build, profile, Compose, and data-safety gates pass. Two clean Firefox 157 /
  geckodriver attempts were blocked at WebDriver session creation by Flutter
  3.47.4 before application interaction. Mandatory browser scenarios and
  screenshots therefore remain unverified and are not replaced by API/widget
  evidence.
- Plan/timing checkpoint: `2026-10-17 00:44:21 +03:00`
  (Europe/Istanbul).
- Active time is recorded at task boundaries. Validation command runtimes are
  recorded separately. The initial source audit began before a timestamp was
  captured, so no invented start time is assigned to that interval.
- No commit or push is authorized by the Sprint 4.4 prompt.

## Baseline

- Branch/HEAD: `main` at
  `42b7576ff66e240a0b94e49465c2df2fe713ef5b`
  (`feat(sprint-4.3.2): harden invitations QR and notifications`).
- Initial worktree contained only the user-provided `SPRINT4_4.md` and two
  pre-existing SQL backups. The backups are unrelated, must remain untouched,
  and will never be staged as product source.
- Root filesystem: 6.1 GB free (98% used). Workspace filesystem: 70 GB free.
  Builds must avoid unnecessary caches and retained Docker volumes must not be
  removed.
- Backend Release build: passed, 0 warnings/errors, 8.80 seconds.
- Backend tests: 95 passed, 0 failed/skipped, 11.92 seconds.
- EF drift: no model changes since the latest migration, 2.07 seconds. The
  local EF tool is 10.0.0 while runtime packages are 10.0.13; this advisory did
  not invalidate the result.
- Flutter format baseline: failed because the formatter reported five files;
  the resulting working tree remained byte-clean, so this is recorded as a
  baseline formatting inconsistency rather than silently called a pass.
- Flutter analyzer: no issues, 6.58 seconds.
- Flutter tests: 92 passed, 0 failed, 6.96 seconds.
- Development Web release build: passed in 30.4 seconds. The existing
  `flutter_secure_storage_web` WebAssembly dry-run advisory remains; the
  JavaScript release build is valid.
- Baseline validation command time: 67.44 seconds. Source/document audit time
  before `00:44:21` was not instrumented and is deliberately not fabricated.

## Current UX and architecture audit

### Design foundation

- `app.dart` creates `ThemeData` directly from one seed color and only adds an
  outline input theme. There is no semantic token extension, spacing/radius/
  elevation scale, typography policy, motion policy, or replaceable preset.
- Only five shared widgets currently exist. Repeated headers, metrics, status
  chips, loading/error/empty states, responsive panels, trip cards, and
  timelines are implemented ad hoc in feature screens.
- Eight Flutter files use direct `Colors`/literal color values. Layout spacing,
  radii, and heights remain distributed through feature widgets.
- No bundled Arabic/Latin font is currently declared. A locally licensed font
  will be used only if already available or safely vendorable; otherwise the
  system typography stack and explicit Arabic/Latin roles will be documented
  without adding a runtime CDN dependency.

### Shell and responsive behavior

- `AppShell` owns role-aware navigation and prevents Driver-only access to
  management routes, but it has one local `720` breakpoint and a large bottom
  navigation set for managers. Breakpoint policy is not centralized.
- The shell shows notification/account controls, while workspace and role
  identity are delegated to an account menu rather than consistently visible.
- Driver navigation currently has My Trip, Notifications, and Settings only;
  there is no My Trips history or dedicated My Truck destination.
- Multi-role routing selects management navigation and can still reach
  `/my-trip`, but the future shell must expose both capabilities without
  duplicating route state or flashing unauthorized content.

### Owner dashboard and map

- Dashboard content is a generic scrolling column: nine small metric cards,
  all active-operation cards, optional simulator controls, then the fleet map,
  then recent trips. The map is not the primary visual surface and receives no
  guaranteed viewport-height allocation.
- `FleetMap` already owns proven annotation diffing, map lifecycle telemetry,
  camera modes, Arabic style handling, marker interpolation, and explicit
  overview/follow/route actions. Sprint 4.4 must compose around that widget,
  not recreate or move its behavioral ownership.
- Responsive fleet list/details panels and a full-screen restore surface need
  to be added without frame-by-frame map resizing.

### Driver workspace and trip history

- `DriverMyTripScreen` supports the current operational trip, QR connection,
  approach/departure actions, and idle resolved-truck map. Its loading/error/
  empty states and information hierarchy are basic.
- No Driver-scoped history route, repository, list filters, pagination, or
  details screen exists.
- Existing `TripDriverParticipation` rows already preserve Driver assignment
  intervals, phases, handovers, and boundary position IDs. Existing trip stops,
  route plans, trip events, and trip-scoped tracking history can be projected;
  no off-duty location table is required.
- Existing generic trip endpoints are manager-oriented. New Driver history
  queries must resolve the linked Driver from the authenticated account and
  active company on the server and must never accept a Driver ID.

### Capability profiles

- Flutter simulator UI is currently gated by
  `ENABLE_SIMULATOR_CONTROLS`, default false.
- Backend provider/worker registration is already limited to Development or
  Testing plus explicit simulator settings.
- Simulator controller actions are nevertheless mapped in every environment
  and fail through provider behavior instead of being absent. Pilot and
  Production require authoritative endpoint non-registration (`404`).
- Development seeding is gated at startup; Testing acceptance can explicitly
  opt in. A single capability object/policy will formalize Development, Demo,
  Pilot, and Production without conflicting switches.

## Architecture decisions

1. Introduce one injectable `AppDesignPreset` composed into `ThemeData` and a
   `ThemeExtension` for semantic product tokens. Features consume tokens and
   typed presentation primitives, never preset literals.
2. Centralize breakpoints and content constraints in the design layer. Shell
   and high-value screens select layouts from the same policy.
3. Keep MapLibre ownership and all camera/annotation orchestration in existing
   map controllers/widgets. Responsive panels animate independently and map
   size changes happen only at deliberate layout boundaries.
4. Add a Driver-history application query/store and dedicated controller
   routes. Identity is resolved from the active membership and linked Driver;
   missing or foreign trips use stable not-found/authorization semantics.
5. Driver list projections remain bounded and geometry-free. Detail loads only
   stops, route snapshot, events, participation, and the requesting Driver's
   authorized tracking interval, with bounded/downsampled trail output.
6. Use existing participation rows as the authorization boundary; add only a
   supporting index if query evidence demonstrates it is needed.
7. Introduce one server capability profile resolved from the host environment
   and explicit configuration. Simulator endpoints are conditionally mapped,
   workers/providers follow the same policy, and seed eligibility is explicit.
8. Flutter uses a compile-time product profile/capability object. Pilot and
   Production builds cannot construct simulator routes/actions; hiding a
   visible widget alone is insufficient.
9. Motion uses built-in Flutter primitives and centralized durations/curves,
   checks accessible-navigation/reduced-motion state, and never animates an
   entire map or restarts entrance effects on equivalent polling data.

## Intended files/modules

- Flutter design system: `lib/design_system/**`, `lib/app.dart`, purposeful
  shared presentation widgets, `docs/design-system.md`.
- Shell/routes: `lib/app.dart`, `shared/widgets/app_shell.dart`, account and
  navigation presentation tests.
- Owner experience: dashboard composition and small presentation components;
  existing dashboard controller/repository and `FleetMap` behavior remain the
  source of truth.
- Driver history: new Application contracts/service/store port, Infrastructure
  projection store, API controller, Flutter domain/repository/controller/
  screens, localization, and focused tests.
- Capability profiles: API startup/DI/configuration, conditional endpoint
  mapping, Flutter compile-time capabilities, profile tests and build docs.
- Documentation/evidence: README, architecture ADR, design-system guide, this
  plan, and `docs/evidence/sprint4_4/**`.

## Data and migration impact

- Preferred design: no new business tables and no historical backfill.
- An additive index on `(CompanyId, DriverId, StartedAt, TripId)` may be added
  to `trip_driver_participations` only after the actual query shape is fixed.
- Existing timestamps remain UTC. Flutter will render with the current client
  locale/local-time behavior, documented as the smallest existing policy.
- Never invent missing coordinates, route geometry, timestamps, or historical
  participation.

## Risks and rollback

- **Map regression:** presentation composition can trigger platform-view
  recreation or camera movement. Preserve widget identity and assert lifecycle/
  camera counters at 20+ updates.
- **Authorization leak:** generic trip loaders could expose another Driver's
  data. Use a dedicated authenticated Driver query path and indistinguishable
  missing/unauthorized responses.
- **Handover leakage:** final `DriverId` is insufficient. Authorize by
  participation and restrict tracking timestamps to that participation.
- **Profile drift:** UI and backend flags can disagree. One capability model on
  each side plus endpoint-registration tests is required.
- **Responsive overflow:** validate 360, 768, and 1440 widths in EN/LTR and
  AR/RTL.
- **Root disk exhaustion:** avoid redundant Docker rebuilds, inspect space
  before builds, and remove only confirmed disposable build artifacts if
  needed. Never prune retained volumes.
- Rollback is a code/configuration revert plus an additive-index migration Down
  if that index is added. No destructive data migration is planned.

## Acceptance mapping

| Requirement | Planned proof |
|---|---|
| Tokenized, replaceable visual preset | Theme-extension/unit/widget architecture test with alternate preset |
| Role-aware responsive shell | EN/AR widget tests at 360/768/1440 for Owner, Operations, Driver, multi-role |
| Larger stable Owner map | Layout tests plus real Firefox lifecycle/camera/annotation counters |
| Mobile-first Driver workspace | Widget tests and isolated Driver Firefox profile |
| Tenant-safe My Trips | Backend integration tests for tenant, Driver, workspace, handover interval, filters, 100+ pagination |
| Bounded detail/trail | Projection tests and real completed-trip detail/map/fallback workflow |
| Purposeful/reduced motion | Motion policy unit/widget tests and Firefox reduced-motion check |
| Profile isolation | Endpoint registration/worker/seed tests, build artifact checks, Development and Pilot probes |
| Regression/data safety | Full suites/builds/EF drift/Compose health plus hashes, volume IDs, counts |
| Android | Build/run only if SDK/device is valid; otherwise exact environment limitation |

## Task checklist

- [x] 0. Read prompt, capture SHA/worktree, run baseline gates, and audit the
  current architecture.
- [x] 1. Implement centralized design tokens, responsive policy, motion policy,
  and reusable presentation primitives with extensibility/accessibility tests.
- [x] 2. Refine role-aware shell and high-value authentication/profile surfaces.
- [x] 3. Recompose Owner dashboard around a larger stable fleet map and
  responsive fleet/detail panels.
- [x] 4. Implement authenticated Driver trip-history API projections,
  authorization boundaries, pagination/filtering, and interval-bounded detail.
- [x] 5. Implement mobile-first Driver My Trips list/detail UI and refine the
  current/idle-truck workspace.
- [x] 6. Formalize Development/Demo/Pilot/Production capability profiles and
  enforce simulator/seed isolation on backend and Flutter.
- [x] 7. Complete localization, focused tests, full automated gates, both Web
  profiles, EF drift, Docker health, and Android environment check.
- [ ] 8. Run mandatory isolated Owner/Driver real-Firefox acceptance and retain
  sanitized evidence. **Blocked before app startup by the repeated WebDriver
  `/session` connection failure; no browser acceptance is claimed.**
- [x] 9. Finish README, architecture ADR, design-system guide, evidence index,
  data-safety comparison, and final elapsed-time audit.

## Task timing

Times use Europe/Istanbul. Active elapsed excludes explicit user/environment
pauses and does not double-count concurrent commands.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 0 | Baseline validation and architecture audit | Before timing checkpoint | 2026-10-17 00:44:21 +03:00 | 1m 07.44s measured validation; audit interval not instrumented | Completed with one format-baseline deviation |
| 1 | Design system and reusable primitives | 2026-10-17 00:44:21 +03:00 | 2026-10-17 01:06:10 +03:00 | Part of the 21m 49s interleaved implementation block | Completed |
| 2 | Role-aware responsive shell | 2026-10-17 00:44:21 +03:00 | 2026-10-17 01:06:27 +03:00 | Part of the 22m 06s interleaved implementation block | Completed |
| 3 | Owner dashboard/map composition | 2026-10-17 00:44:21 +03:00 | 2026-10-17 01:02:27 +03:00 | Part of the 18m 06s interleaved implementation block | Completed |
| 4 | Driver history backend and authorization | 2026-10-17 00:44:21 +03:00 | 2026-10-17 00:51:06 +03:00 | Part of the 6m 45s interleaved implementation block | Completed |
| 5 | Driver history/workspace Flutter UX | 2026-10-17 00:44:21 +03:00 | 2026-10-17 00:57:54 +03:00 | Part of the 13m 33s interleaved implementation block | Completed |
| 6 | Capability profiles and simulator isolation | 2026-10-17 00:44:21 +03:00 | 2026-10-17 01:04:12 +03:00 | Part of the 19m 51s interleaved implementation block | Completed |
| 7 | Automated/build/data-safety validation | 2026-10-17 01:03:40 +03:00 | 2026-10-17 01:17:46 +03:00 | 14m 06s wall-clock; overlaps implementation/test fixes and final rebuilds | Completed |
| 8 | Real Firefox acceptance | 2026-10-17 01:12:04 +03:00 | 2026-10-17 01:14:02 +03:00 | 1m 58s across two attempts, excluding Flutter compilation already counted as validation | Blocked before app interaction |
| 9 | Documentation/evidence/final audit | 2026-10-17 01:14:05 +03:00 | 2026-10-17 01:17:46 +03:00 | 3m 41s | Completed with screenshot/browser evidence absent |
|  | **Total measured active wall-clock** | 2026-10-17 00:44:21 +03:00 | 2026-10-17 01:17:46 +03:00 | **33m 25s plus the separately measured 1m 07.44s baseline validation** | **Sprint incomplete** |

Tasks 1–6 were intentionally implemented and validated in an interleaved pass;
their intervals overlap and must not be summed. The total uses the enclosing
wall-clock interval once. File modification timestamps and command runtimes are
the audit source; no unsupported per-file “effort” durations were invented.

## Final validation result

- .NET Release build: 0 warnings/errors; all 106 tests passed.
- Flutter analyzer: no issues; all 95 tests passed.
- EF: no pending model changes.
- Development and Pilot Web release builds passed; artifact inspection proves
  Development includes and Pilot excludes simulator semantic keys.
- Compose API/PostgreSQL healthy; recovery false; retained counts remained
  3/13/120/141/146; retained volume names and `.env` hash unchanged.
- Android SDK/device unavailable at the configured path.
- Mandatory real Firefox acceptance and screenshots remain blocked, so the
  Definition of Done is not met and Sprint 4.4 remains incomplete.
