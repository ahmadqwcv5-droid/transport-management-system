# Sprint 3.5 Implementation Plan and Execution Log

## Objective

Stabilize the existing modular monolith without changing its public behavior:
give trip use cases and persistence ports cohesive ownership, turn the Flutter
planner into a controller-backed composition shell, separate large map/model
presentation concerns, enforce dependency rules automatically, add a disposable
CI quality gate, and consolidate the current architecture record.

## Baseline

- Required remote fetch completed on 2026-09-22. Local `main` and
  `origin/main` both resolve to `c479fecf921c6e7a2f5de903c2fa283ba37633e0`.
- Initial worktree contained only the user-supplied untracked Sprint 3.5 prompt.
  It is preserved under this Sprint folder. `.env`, retained credentials, and
  PostgreSQL volumes are excluded from all edits.
- Repository-local toolchains are .NET SDK 10.0.100 and Flutter 3.47.4 / Dart
  3.13.3. The global shell does not expose `dotnet`; commands use
  `.tooling/dotnet/dotnet` and `.tooling/flutter/bin/flutter`.
- Untouched backend baseline: restore passed, build passed with 0 warnings and
  0 errors, and 48/48 integration tests passed.
- Untouched Flutter baseline: dependency resolution passed, analyzer reported
  no issues, and 36/36 unit/widget tests passed. Pub reported 17 newer package
  versions outside current dependency constraints; no upgrade is part of this
  stabilization sprint.
- Existing `tms-smoke` API and PostgreSQL containers are healthy. The real
  authenticated baseline Firefox workflow passed on CORS-approved port 8080
  (the user's live Flutter process already owned port 3000): Arabic/RTL,
  route/assignment, unchanged-route preservation, race recovery, and
  English/LTR all passed with ten screenshots and machine-readable evidence.

## Baseline Hotspot Inventory

Generated localization and migration designer files are excluded.

| Handwritten file | Baseline lines | Current responsibilities |
|---|---:|---|
| `trip_planner_screen.dart` | 1,564 | UI, mutable form state, persistence orchestration, routing, assignment, navigation, validation, map lifecycle |
| `fleet_map.dart` | 1,011 | map modes, polling presentation, MapLibre lifecycle, panels, controls, legend, fallback |
| `TripService.cs` | 681 | draft, route, queries, assignment, dispatch, lifecycle, mapping/readiness |
| `trip_details_screen.dart` | 687 | detail composition, every operational dialog/action, assignment and dispatch flows |
| `operations_models.dart` | 494 | client, fleet, trip, routing, assignment, pagination, timeline models |
| `fleet_map_coordinator.dart` | 485 | platform-neutral annotation diffing and camera intent; large but cohesive and behaviorally protected |
| `OperationsStore.cs` | 290 | implementation of all operational persistence concerns |
| `IOperationsStore.cs` | 53 | catch-all client, fleet, trip, reservation, event, user lookup, and save port |

## Dependency Graph and Ownership Assessment

```text
API controllers
  -> Application use-case services and transport contracts
      -> Domain aggregates/policies
      -> focused Application ports
          <- Infrastructure EF/provider adapters

Flutter screens/steps
  -> Riverpod controllers and immutable presentation state
      -> feature repositories
          -> shared authenticated API transport
```

Current erosion points are the single `TripService`, broad
`IOperationsStore`, direct repository calls from planner widgets, mixed feature
models, and UI panels embedded in the map host. Domain project references are
currently clean. `OperationsStore` may implement multiple focused interfaces,
but consumers must see only their owned port. The scoped `AppDbContext` plus one
`SaveChangesAsync` per use case remains the transaction boundary; no extra unit
of-work abstraction will be added unless extraction proves one is necessary.

## Refactoring Sequence

1. Preserve observable behavior with existing suites and focused architecture /
   characterization tests.
2. Introduce focused client, fleet, trip mutation, trip query, and trip-event
   ports; migrate consumers without exposing EF or `IQueryable`.
3. Extract trip query, draft, routing, assignment, dispatch, and lifecycle
   services. Keep shared mapping/readiness and externally dependent policies in
   focused collaborators rather than duplicate helpers.
4. Update the thin trip controller and internal tracking coordination to invoke
   one owning use case per action while preserving routes, contracts, policies,
   status codes, and scoped transaction semantics.
5. Split Flutter operational models by client/fleet/trip/routing ownership and
   update imports without a catch-all barrel.
6. Extract planner immutable state, validation, controller, four step widgets,
   and focused route/stop/review widgets. Stable browser keys and all four-step
   behavior remain unchanged.
7. Extract fleet-map panels, overlays, controls, and adapter boundary while
   leaving coordinator identity/camera behavior intact.
8. Add repository architecture tests and GitHub CI, then consolidate ADRs,
   ownership rules, Definition of Done, and local quality-gate commands.
9. Run every final quality gate, security/tenant review, Compose/PostgreSQL and
   authenticated browser regression; record evidence and exact limitations.

## Risk Controls and Compatibility Strategy

- Public API paths, JSON names, error codes, status values, Flutter routes,
  widget keys, database schema, and validated workflows are compatibility
  boundaries. No schema migration is planned.
- Each extraction is mechanical first, then compiled and tested before the next
  boundary moves. Tests assert observable results, not new class internals.
- Resource reservations, actor attribution, tenant filters, route freshness,
  audit events, and simulator gates remain authoritative on the server.
- New stores never accept a tenant ID from Flutter and never expose
  `IQueryable`. The existing global filter remains the default.
- `IgnoreQueryFilters` exceptions will be enumerated explicitly and limited to
  authentication/bootstrap identity paths.
- Map refactoring does not change the coordinator algorithm. Zero polling
  camera moves/global clears and stable annotation identity remain regression
  assertions.
- If a behavior or migration delta appears, implementation stops until it is
  documented and covered; the sprint does not use stabilization as feature
  permission.

## Architecture-Test Design

A lightweight .NET test project will inspect project references, controller
constructors/source boundaries, domain/application assembly references,
tenant-owned EF metadata, and approved `IgnoreQueryFilters` locations. It will
also scan Flutter presentation imports and `pubspec.yaml` for forbidden direct
network/state-management dependencies. Rules will use explicit allowlists and
actionable failure messages without adding a heavy architecture framework.

## CI Design

GitHub Actions will trigger for pull requests and pushes to `main` with:

- Backend job: pinned .NET setup, NuGet cache, restore/build, architecture and
  full integration tests against disposable PostgreSQL, plus EF drift check.
- Flutter job: pinned stable Flutter, pub cache, localization generation where
  required, format verification, analyzer, all tests, and non-secret release
  Web build.
- Failure artifacts: test result/log output only; no `.env`, tokens, retained
  data, or runtime secrets.
- Public OSRM, geocoding, and tile providers are excluded from mandatory jobs;
  deterministic Testing providers protect mandatory CI. The complete Firefox
  workflow remains a documented release/manual gate unless a reliable fully
  local browser job is proven during this sprint.

Workflow syntax and every underlying command will be validated locally. A
local validation is not a claim that GitHub-hosted Actions executed it.

## Browser Regression Workflow

Use the dedicated retained Development/Testing smoke tenant and runtime-only
credentials. Capture baseline and final authenticated Firefox outcomes for
login, Arabic/RTL, four-step Draft/route/assignment, detail navigation,
dispatch-to-pickup contract connectivity, dashboard markers/selection,
English/LTR, and logout. Preserve the database volume and avoid public-provider
dependency where deterministic substitutes are available. Store only safe
machine-readable results and representative screenshots in
`docs/evidence/sprint3_5/`.

## Documentation Plan

- Make `docs/architecture.md` the current authority.
- Repair duplicate ADR numbering while retaining history, add explicit
  `Superseded` links, and publish one canonical current trip lifecycle ADR.
- Add backend/Flutter module ownership, dependency rules, transaction boundary,
  observability baseline, quality guardrails, Definition of Done, local CI
  commands, and push-versus-release browser gates.
- Update README commands and Sprint/evidence indexes.

## Task Timing (Active UTC Time)

Active time is recorded at task boundaries during this run. Pauses and user
waits are not intentionally counted; rows are not reconstructed afterward.

| Task | Started (UTC) | Finished (UTC) | Active elapsed | Status | Result |
|---|---:|---:|---:|---|---|
| Baseline fetch, required reading, hotspot/dependency trace, and untouched automated gates | 2026-09-22 19:44:10 | 2026-09-22 19:53:04 | 00:08:54 | Complete | 48 backend and 36 Flutter tests passed; clean build/analyzer; healthy Compose; real Firefox baseline passed with ten screenshots |
| Characterization rules, backend use-case services, and focused persistence ports | 2026-09-22 19:53:04 | 2026-09-22 20:09:53 | 00:16:49 | Complete | 11 architecture rules pass; catch-all store and 681-line service removed; six cohesive services (57–162 lines); 48 integration tests still pass |
| Flutter model, planner, and fleet-map boundary extraction | 2026-09-22 20:09:53 | 2026-09-23 06:38:00 | 00:10:59 | Complete | 1,564-line planner became a 14-line shell with controller/state/steps/widgets; map adapter/panels and feature models split; analyzer and 36 tests passed |
| CI, architecture/ADR consolidation, guardrails, and evidence | 2026-09-23 06:38:00 | 2026-09-23 06:46:49 | 00:08:49 | Complete | Push/PR workflow and local gate added; ADR numbering/lifecycle/ownership/DoD repaired; workflow YAML, shell, and xUnit v3 report arguments validated locally |
| Full final quality gate, PostgreSQL/Compose, browser, and security review | 2026-09-23 06:46:49 | 2026-09-23 07:11:15 | 00:24:26 | Complete | 59 backend + 36 Flutter tests; clean build/analyzer/EF drift; debug/release Web; healthy Compose; planner, dispatch/restart/dashboard, RTL/LTR, and logout Firefox gates passed |

**Total active elapsed:** 01:09:57. The Flutter task crossed an overnight user
pause; its elapsed value is the sum of the recorded active command batches, not
the wall-clock difference between its start and finish timestamps.

## Final Changed-File Summary

- Backend: removed `TripService` and `IOperationsStore`; added six trip use-case
  services, focused mapping/policy collaborators, four persistence ports, thin
  controller delegation, and an 11-rule architecture-test project.
- Flutter: split mixed operational models, reduced the planner entry screen to
  composition, extracted immutable state/controller/steps/widgets, separated
  fleet-map adapter/panels, and repaired older browser fixtures for the current
  route-before-assignment and locale-independent contracts.
- Delivery: added the GitHub quality-gate workflow, local quality-gate script,
  ADR-024 and explicit supersession/numbering repairs, README guidance, this
  plan, original prompt, security review, hotspot comparison, JSON results, and
  27 baseline/final screenshots.
- Database/API behavior: no migration or schema delta, no endpoint/JSON/status
  change, and no retained-volume reset. EF reports no pending model change.

The full evidence and limitation record is in
`docs/evidence/sprint3_5/README.md`. No commit, push, or pull request is
authorized by the Sprint prompt; all changes remain in the working tree for
review.
