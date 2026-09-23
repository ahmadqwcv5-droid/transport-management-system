# Sprint 3.5 Evidence

This directory records the behavior-preserving architecture-stabilization run.
It contains no password, token, `.env` content, or database export.

## Browser evidence

- `baseline/`: ten screenshots and `browser_workflow.json` from the untouched
  Sprint 3.4.1 authenticated Firefox workflow.
- `final/`: the equivalent ten screenshots and machine-readable result after
  refactoring. It proves Arabic/RTL, map stop selection, authoritative routing,
  eligible/ineligible assignment reasons, review, assigned and unassigned
  details, unchanged-route preservation, assignment-race recovery, and
  English/LTR. The baseline and final machine results both report `true`.
- `final/dispatch/`: seven screenshots and a machine result for actual
  dispatch-to-pickup, separate approach/cargo routes, API-only restart with
  zero coordinate jump, geographic `AtPickup`, explicit cargo start, physical
  speed at `10x`, dashboard selection, ten polling cycles after manual pan, and
  Arabic/RTL map rendering.
- A separate real-Firefox authentication smoke passed login, dashboard arrival,
  logout, and redirect to the two-field login form. It emits no screenshot or
  credential artifact.

Runtime GUIDs in JSON are local disposable fixture identifiers, not secrets.
The retained PostgreSQL volume was not deleted or reset.

## Hotspot comparison

Generated localization and EF migration designer files are excluded.

| Concern | Before | After | Outcome |
|---|---:|---:|---|
| Trip application service | `TripService.cs`, 681 | Six use-case services, 57–162 each; mapper/collaborators 140 | Original hotspot removed; command/query ownership is explicit |
| Operational persistence port | `IOperationsStore.cs`, 53 broad members | Four ports, 12–26 each | Consumers receive only client, fleet, trip mutation, or trip query capabilities |
| Planner screen | `trip_planner_screen.dart`, 1,564 | 14-line shell; controller 656; state/validation 59; step composition 420; focused widgets 102/179/242 | UI composition, orchestration, and focused rendering are separated |
| Fleet map host | `fleet_map.dart`, 1,011 | host 477; adapter 171; panels 368; unchanged coordinator 485 | Platform adapter and presentation panels are separated from coordination |
| Operational models | `operations_models.dart`, 494 mixed | client 29; fleet 58; trip 410; shared data 16 | Models follow feature ownership; no catch-all barrel remains |

Two handwritten files remain above approximately 500 lines:

- `trip_planner_controller.dart` (656) contains the cohesive persisted-Draft
  orchestration/state lifecycle for one four-step workflow. All step rendering,
  map/stop widgets, validation, and immutable public state are already outside
  it; splitting one transaction sequence further would obscure ordering.
- `trip_details_screen.dart` (687) is unchanged by this sprint and owns one
  details page plus its contextual action dialogs. It is a future presentation
  extraction candidate, but changing it was outside the planner/map boundary
  stabilization and would have increased regression surface without improving
  the requested ownership rules.

## Quality-gate result

| Gate | Final result |
|---|---|
| .NET restore / Release build | Pass; 0 warnings, 0 errors |
| Architecture tests | 11/11 pass |
| Integration tests | 48/48 pass |
| EF pending-model check | Pass; no changes since the last migration |
| Dart format | 78 files checked; 0 changed |
| Flutter analyzer | Pass; no issues |
| Flutter unit/widget tests | 36/36 pass |
| Flutter Web release and debug builds | Pass |
| Workflow YAML / shell syntax | Pass locally |
| Compose full build/start | Image build passed; legacy Compose recreation issue repaired by replacing only the stopped API container |
| Compose health | API and PostgreSQL healthy; database already up to date |
| Firefox planner workflow | Pass; result `true`, ten screenshots |
| Firefox dispatch/dashboard workflow | Pass; result `true`, seven screenshots, API restart covered |
| Firefox logout redirect | Pass |
| Android | Not run: configured `/home/pc/Android/Sdk` is absent, `.tooling/android-sdk` has no SDK tools/platforms, and no Android device/emulator is available |

The Web compiler reports the existing `flutter_secure_storage_web` WebAssembly
compatibility advisory during its dry run. JavaScript Web builds complete; this
sprint does not claim a Wasm build.

## CI status

`.github/workflows/quality-gate.yml` was parsed locally and its underlying
commands were executed locally. Its .NET 10/xUnit v3 TRX arguments were also
executed directly. GitHub-hosted Actions has not run this uncommitted workflow,
so this evidence does not claim remote CI success. Mandatory jobs use disposable
PostgreSQL and non-provider build configuration; real browser/provider checks
remain the documented release gate.
