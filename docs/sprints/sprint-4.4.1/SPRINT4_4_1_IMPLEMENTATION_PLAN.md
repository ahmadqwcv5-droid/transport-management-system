# Sprint 4.4.1 Implementation Plan

## Status and phase gate

- Sprint status: **Incomplete — Phase A complete; awaiting design approval**.
- Phase state: `awaiting_design_approval`. Three inspectable concepts and their
  evidence are ready; production redesign remains unauthorized and untouched.
- Baseline checkpoint: `2026-10-17 07:17:15 +03:00` (Europe/Istanbul).
- Phase B may start only after explicit user approval of one concept and any
  requested corrections.
- No commit or push is authorized by the sprint prompt.

## Baseline

- Branch/HEAD: `main` at
  `dd16677273b95ae2b596ee6139aba23e74ddc0a9`
  (`feat(sprint-4.4): add responsive fleet workspace`), equal to
  `origin/main` after `git fetch --prune origin`.
- Initial worktree: the user-provided Sprint 4.4.1 prompt and two pre-existing
  SQL backups only. The prompt is now organized in this sprint folder. The SQL
  backups are unrelated and remain untouched/untracked.
- Root filesystem: 5.4 GB free. Workspace filesystem: 69 GB free.
- Retained Compose API and PostgreSQL services: healthy before Phase A; ports
  5080 and 5432 remain mapped by project `tms-smoke`.
- .NET Release build: passed with 0 warnings/errors in 8.84 seconds.
- Backend tests: 106 passed, 0 failed/skipped in 13.48 seconds.
- EF drift: no model changes since the latest migration in 2.16 seconds. The
  EF CLI 10.0.0 versus runtime 10.0.13 advisory remains non-blocking.
- Flutter analyzer: no issues in 4.23 seconds.
- Flutter tests: 95 passed in 9.43 seconds.
- Development Web release build: passed in 27.80 seconds.
- Flutter format baseline: the non-writing check reports the same five
  pre-existing files recorded during Sprint 4.4. It made no source changes.

## Design and interaction audit

Confirmed from source/runtime rather than assumed:

- `/my-trip` and `/my-truck` both construct `DriverMyTripScreen`; they are not
  distinct experiences.
- `FleetMap` handles wheel input through a `Listener`, but does not arbitrate
  the ancestor dashboard scroll position; real-browser proof is absent.
- The full-screen button only toggles the map card height inside the dashboard
  scrollable (`viewport height - 96`); it is not viewport-level full screen.
- The dashboard renders nine equally weighted metrics in a 3-column grid on
  expanded screens, producing three oversized rows before the map.
- Sprint 4.4 introduced useful tokens and four primitives, but most operational
  screens still compose raw Material cards, fields, dialogs, and lists.
- Motion tokens exist, while visible adoption is limited primarily to one
  panel `AnimatedContainer`; polling/entrance behavior has not received real
  browser motion acceptance.
- Existing MapLibre camera, annotation, route/trail, locale-style, and latest-
  wins ownership resides in current map widgets/controllers and must not move
  into presentation concepts.
- Driver history and capability-profile boundaries are validated and must
  remain unchanged.

## Phase A concept strategy

Build one isolated Flutter Design Lab entry point that is not imported by the
production application. It uses sanitized static data, no repositories, no
mutation APIs, and no retained database state. Three presets will share typed
preview data but differ materially in composition, navigation, surfaces,
density, graphical language, and motion treatment:

1. **Concept A — Route Beacon:** warm mineral surfaces, a strong route spine,
   compact command bands, and directional beacon geometry.
2. **Concept B — Night Dispatch:** deep operational canvas, luminous telemetry
   modules, docked panels, and radar-like spatial cues.
3. **Concept C — Field Ledger:** editorial light canvas, precise rules,
   condensed operational rows, and physical dispatch-document cues.

Every concept will render dashboard AR/EN at about 1440 px, Driver Today AR
and My Truck AR at about 390 px, and a component/motion sheet. It will also be
checked near 360 and 768 px.

## Intended Phase A files

- `apps/transport_management_app/lib/design_lab/**`: isolated concept models,
  preview compositions, reusable candidate primitives, and static fixtures.
- `apps/transport_management_app/lib/design_lab_main.dart`: separate
  Development-only preview entry point; never imported by `main.dart`.
- `apps/transport_management_app/test/sprint441_design_lab_test.dart`: preview
  rendering, RTL/LTR, responsive, data-isolation, and production-entry-point
  isolation checks.
- `docs/evidence/sprint4_4_1/design_concepts/**`: briefs, palettes,
  typography/motion notes, comparison, preview instructions, and sanitized
  screenshots.
- `docs/evidence/sprint4_4_1/baseline/**`: matching sanitized current-UI
  screenshots and audit notes.
- This plan and the archived prompt. No backend/schema files are intended.

## Risks and rollback

- **Phase leakage:** Design Lab code must not be imported by production
  `main.dart`, router, shell, Pilot, or Production builds. Prove isolation with
  source/artifact checks.
- **Accidental mutations:** Preview data is compile-time/static and may not
  instantiate API repositories or token stores.
- **Generic concepts:** Concepts must differ in layout, surface strategy,
  navigation, density, mobile adaptation, and motion—not just palette.
- **Reference imitation:** No assets, CSS, copy, layout, logo, or palette from
  the benchmark site will be downloaded or reused.
- **Screenshot leakage:** Evidence uses invented company/person/vehicle data
  and excludes credentials, tokens, QR codes, precise retained locations, and
  private emails.
- **Browser tooling:** direct GeckoDriver reproduced the existing empty
  `/session` response even though Firefox/Marionette started. Phase A therefore
  used a temporary Playwright Chromium installation outside project
  dependencies. All required concept screenshots are real rendered browser
  evidence; no Firefox acceptance is claimed for Phase B.
- Rollback before approval is removal of the isolated Design Lab and evidence
  only. Live features, backend behavior, data, and migrations remain unchanged.

## Acceptance mapping

| Phase A requirement | Planned proof |
|---|---|
| Three original, compositionally distinct concepts | Same five representative surfaces rendered for A/B/C plus comparison brief |
| Arabic-first and English parity | 1440 AR/EN dashboard screenshots and 390 AR Driver screenshots |
| 360/768 structural safety | Focused widget tests and browser captures/checks |
| Inspectable Flutter previews | Separate Development Design Lab Web build and local preview instructions |
| Motion direction | Three visible/inspectable microinteractions per concept and documented reduced-motion behavior |
| No production or data impact | Import/artifact checks, static fixtures, clean backend diff, retained health/hash/count checks |
| Approval gate | Plan/evidence status set to `awaiting_design_approval`; Phase B untouched |

## Task checklist

- [x] 0. Read both sprint prompts and prior Sprint 4.4 plan/evidence/design/ADR;
  fetch baseline; record exact SHA and initial gates.
- [x] 1. Capture sanitized real-browser Sprint 4.4 baseline at matching
  desktop/mobile/tablet viewports and finish route/key/map/capability inventory.
- [x] 2. Build isolated Development Design Lab infrastructure and sanitized
  typed preview fixtures.
- [x] 3. Implement Concept A surfaces and motion examples.
- [x] 4. Implement Concept B surfaces and motion examples.
- [x] 5. Implement Concept C surfaces and motion examples.
- [x] 6. Validate 360/390/768/1440, AR/EN, reduced motion, and production
  isolation; capture sanitized real-browser concept evidence.
- [x] 7. Finish briefs, palette/typography/motion comparison, evidence index,
  local preview instructions, recommendation, and elapsed-time audit.
- [x] 8. Stop with status `awaiting_design_approval`; do not start Phase B.

## Task timing

Active elapsed uses Europe/Istanbul wall-clock task boundaries and excludes
future user approval pauses. Overlapping work will be reported once rather
than double-counted.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 0 | Baseline documents, repository fetch, automated gates, initial audit | 2026-10-17 07:17:15 +03:00 | 2026-10-17 07:20:36 +03:00 | 3m 21s | Completed |
| 1 | Browser harness, baseline evidence, and detailed inventory | 2026-10-17 07:20:36 +03:00 | 2026-10-17 07:41:33 +03:00 | Part of 20m 57s interleaved browser/implementation block | Completed in Chromium; GeckoDriver blocker documented |
| 2 | Isolated Design Lab and fixtures | 2026-10-17 07:32:44 +03:00 | 2026-10-17 07:40:43 +03:00 | Part of 7m 59s interleaved concept block | Completed |
| 3 | Concept A | 2026-10-17 07:32:44 +03:00 | 2026-10-17 07:40:43 +03:00 | Part of 7m 59s interleaved concept block | Completed |
| 4 | Concept B | 2026-10-17 07:32:44 +03:00 | 2026-10-17 07:40:43 +03:00 | Part of 7m 59s interleaved concept block | Completed |
| 5 | Concept C | 2026-10-17 07:32:44 +03:00 | 2026-10-17 07:40:43 +03:00 | Part of 7m 59s interleaved concept block | Completed |
| 6 | Responsive/browser/isolation validation and screenshots | 2026-10-17 07:40:21 +03:00 | 2026-10-17 07:49:23 +03:00 | 9m 02s, overlapping final docs | Completed |
| 7 | Concept briefs, comparison, recommendation, brand-safety review, final Phase A audit | 2026-10-17 07:45:36 +03:00 | 2026-10-17 07:50:42 +03:00 | 5m 06s | Completed |
| 8 | Approval gate | 2026-10-17 07:50:42 +03:00 | 2026-10-17 07:50:42 +03:00 | <1s | Awaiting user decision |
|  | **Measured Phase A wall-clock total** | 2026-10-17 07:17:15 +03:00 | 2026-10-17 07:50:42 +03:00 | **33m 27s** | **Awaiting design approval** |

Tasks 1–6 were intentionally interleaved while browser tooling downloaded and
concept code compiled. Their individual intervals must not be summed; the
wall-clock total counts the enclosing interval once. File timestamps and
command checkpoints are the audit source.

## Phase A validation result

- Real Chromium baseline: Owner dashboard captured at 1440, 768, and 390 in
  Arabic and browser-isolated English. Retained map/identity data is masked.
- Real Chromium concepts: 24 decodable PNGs cover all required A/B/C surfaces,
  responsive 360/768 checks, and reduced-motion variants.
- Focused Design Lab suite: 27 passed, including every concept at
  360/390/768/1440, Arabic/English, distinct Today/My Truck content, reduced
  motion, static-data isolation, and production-entry-point isolation.
- Full Flutter suite: 122 passed. Analyzer: no issues.
- Development-only Design Lab Web release build: passed in 20.16 seconds.
- Normal Pilot Web release build: passed in 28.32 seconds; artifact inspection
  found no Design Lab marker or concept name.
- Format check: the same five pre-existing Sprint 4.4 files remain the only
  formatter findings; all Sprint 4.4.1 files are formatted.
- Backend baseline remains 106/106 with zero-warning Release build and no EF
  drift; Phase A has no backend/schema diff.
- API/PostgreSQL remain healthy, `pg_is_in_recovery()` is false, `.env` SHA-256
  remains `65d1ae1ee7f3abcd65d6bf29797ea04c4e833c4109c426a34820f656a52ce6f0`,
  and retained volume identities remain unchanged.
- Current counts are 3 companies, 13 users, 120 trucks, 141 Drivers, and 147
  trips. The older Sprint 4.4 evidence recorded 146 trips, but the newest trip
  predates this Phase A start by about 41 minutes and zero trips have a
  `CreatedAt` at or after `07:17:15 +03:00`; Design Lab/browser work made no
  mutation API calls.
- No commit or push occurred.

## Phase B placeholder

No Phase B file list, implementation status, or completion claim will be added
until the user explicitly approves a concept. The production redesign, wheel
arbitration repair, real full-screen map, dedicated My Truck screen, migration
of live surfaces, final goldens, and full acceptance all remain pending.
