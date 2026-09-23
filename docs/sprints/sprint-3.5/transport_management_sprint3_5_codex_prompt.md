# Sprint 3.5 — Architecture Stabilization and Quality Gate

## Role

You are a senior software architect and hands-on refactoring engineer responsible for stabilizing an existing multi-tenant transport-management system before major new product domains are added.

Act as:

- Senior .NET architect
- Senior Flutter architect
- Domain-driven design reviewer
- Test and CI engineer
- PostgreSQL and EF Core reviewer
- Multi-tenant SaaS security reviewer

This sprint is an architectural stabilization sprint. It is not a feature sprint and it is not permission to rewrite the application.

The primary goal is to make future agent-driven development safer, more predictable, and easier to review.

---

## Repository and Baseline

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Expected starting baseline:

`c479fec feat(trips): repair sprint 3.4.1 workflow`

Before editing:

1. Fetch the latest remote state.
2. Record the actual starting commit.
3. Inspect the worktree and preserve unrelated user changes.
4. Read all current architecture decisions and recent sprint documentation.
5. Run the baseline build and automated tests before refactoring.
6. Record baseline file sizes, test counts, and known warnings.

At minimum, inspect:

- `README.md`
- `docs/architecture.md`
- `docs/sprints/README.md`
- Sprint 3.4 and Sprint 3.4.1 plans and prompts
- Sprint 3.4.1 evidence
- Backend project references
- Application abstractions
- `TripService`
- `IOperationsStore`
- `OperationsStore`
- `Trip` aggregate
- Flutter trip planner and details screens
- Flutter fleet map and coordinator
- Flutter operations models and repositories
- Existing unit, widget, integration, and browser tests

Do not assume the repository still exactly matches the expected baseline. Adapt to the real current code.

---

## Why This Sprint Exists

The system has a sound foundation, but several handwritten files have become architectural hotspots:

- `trip_planner_screen.dart` is approximately 1,500 lines.
- `fleet_map.dart` is approximately 1,000 lines.
- `TripService.cs` is approximately 680 lines.
- `trip_details_screen.dart` is approximately 680 lines.
- `operations_models.dart` contains multiple unrelated operational models.
- `IOperationsStore` mixes clients, fleet, trips, reservations, timeline, and user lookup.

The application currently works, but continuing to add Finance, Maintenance, or real GPS integration directly on top of these hotspots would increase regression risk and agent confusion.

The architecture documentation also contains accumulated decisions that are partially superseded, including older trip-state descriptions that do not fully reflect the current dispatch-to-pickup lifecycle.

There is no repository-level CI workflow currently proving every pushed change against the same quality gates.

This sprint must reduce those risks without changing the product behavior that the user has already validated.

---

## Primary Outcome

At the end of Sprint 3.5:

- Existing product behavior remains unchanged.
- Trip backend use cases have clear ownership and smaller services.
- Persistence ports no longer form one broad operations interface.
- Flutter trip planning is separated into state/controller, steps, and reusable widgets.
- Large map code has explicit boundaries and lower presentation coupling.
- Automated architecture rules prevent dependency erosion.
- GitHub CI validates backend, Flutter, migrations, and architecture on every pull request and push.
- Documentation has one current authoritative architecture description.
- A future agent can identify where a change belongs without scanning thousand-line files.

---

## Non-Negotiable Constraints

1. No new business feature may be introduced.
2. No product redesign may be introduced.
3. No database schema change unless an unexpected correctness defect makes it unavoidable.
4. Do not replace the modular monolith with microservices.
5. Do not add event sourcing.
6. Do not introduce a framework such as MediatR merely to move methods into different files.
7. Do not create abstractions that have no real consumer or boundary.
8. Preserve all public API routes and JSON contracts unless a confirmed bug requires a backward-compatible extension.
9. Preserve all current Flutter navigation routes and validated user workflows.
10. Preserve tenant isolation, authorization, concurrency protection, and audit semantics.
11. Refactor in small, test-backed steps.
12. A green build alone is not proof of behavioral equivalence.

---

## Mandatory Implementation Plan and Timing

Before implementation, create:

`docs/sprints/sprint-3.5/SPRINT3_5_IMPLEMENTATION_PLAN.md`

It must include:

- Baseline commit and worktree state
- Baseline build/test results
- Hotspot inventory
- Dependency graph and ownership assessment
- Refactoring sequence
- Risk controls
- Compatibility strategy
- CI design
- Architecture-test design
- Browser regression workflow
- Documentation plan
- Task start/end times and active elapsed time
- Final changed-file summary

Update timing while working. Do not estimate or invent elapsed times afterward.

---

# 1. Establish Characterization Tests First

Before moving production code, identify the behavior that must remain stable and add focused characterization tests where coverage is missing.

At minimum preserve:

- Authentication and refresh behavior
- Tenant isolation
- Client, truck, and driver CRUD behavior
- Trip Draft creation and resume
- Route calculation and idempotent route preservation
- Assignment eligibility and assignment races
- Dispatch to pickup
- Arrival at pickup
- Cargo trip start and completion lifecycle
- Resource reservation and release
- Cancellation, archive, duplicate, and timeline behavior
- Dashboard and tracking summaries
- Simulator Development/Testing gates
- Flutter Arabic/RTL and English/LTR
- Four-step trip creation workflow
- Fleet-map annotation stability

Do not rewrite tests to mirror internal implementation. Prefer observable contracts and domain outcomes.

Record baseline test counts. If test names or locations move, the final number must not decrease without a documented reason.

---

# 2. Backend Application Refactoring

## 2.1 Split the Trip application hotspot

Refactor the current large trip application service into cohesive use-case services. Use names consistent with the repository, but the intended ownership is:

- `TripDraftService`
  - Create Draft
  - Update Draft details
  - Update stops
  - Delete never-executed Draft
  - Duplicate as Draft

- `TripRoutingService`
  - Calculate cargo route
  - Route freshness and readiness
  - Repositioning preview where appropriate

- `TripAssignmentService`
  - Assignment options
  - Assign
  - Reassign
  - Unassign
  - Resource reservation checks

- `TripDispatchService`
  - Dispatch to pickup
  - Arrival evaluation
  - Start from pickup

- `TripLifecycleService`
  - Mark in transit
  - Deliver
  - Complete
  - Cancel
  - Archive and unarchive

- `TripQueryService`
  - Get detail
  - Paginated list/search/filter
  - Timeline
  - Read-only projections

The exact grouping may be adjusted after inspection, but each service must have one understandable reason to change.

Do not duplicate shared business rules between services.

Shared rules should live in one of:

- The `Trip` aggregate when they are domain invariants
- A focused domain policy/value object
- A focused application policy when external data is required

Avoid a new `TripHelper` or `CommonService` dumping ground.

## 2.2 Keep controllers thin

Controllers must:

- Accept and validate transport contracts
- Invoke one application use case
- Return the result

Controllers must not:

- Query EF Core directly
- Reimplement readiness or lifecycle rules
- Perform tenant filtering manually
- Decide resource eligibility

Preserve existing routes and status codes.

## 2.3 Transaction boundaries

Make transaction ownership explicit for multi-step mutations such as:

- Assignment and reservation
- Reassignment
- Cancellation and resource release
- Route replacement/invalidation
- Lifecycle transition plus event creation

If the existing scoped DbContext and `SaveChanges` boundary already provides the required atomicity, document it rather than adding unnecessary infrastructure.

Do not add distributed transactions.

---

# 3. Split Persistence Ports by Ownership

Replace the broad `IOperationsStore` dependency with smaller application-facing ports.

A reasonable target is:

- `IClientStore`
- `IFleetStore`
- `ITripStore`
- `ITripQueryStore`
- `ITripEventStore`
- `IUnitOfWork` only if shared save coordination is genuinely needed

The exact interfaces should follow real consumers, not theoretical repository patterns.

Requirements:

- Each interface exposes only what its consumers need.
- Query-heavy read operations may use a dedicated query port.
- Domain/Application projects remain unaware of EF Core.
- Tenant identity never comes from Flutter request data.
- Infrastructure may implement several small interfaces in one class only if doing so remains readable; prefer separate files when responsibilities differ.
- Avoid generic repositories.
- Avoid exposing `IQueryable` outside Infrastructure.
- Preserve efficient SQL and existing indexes.

Add tests or architecture rules preventing a future return to a single catch-all store.

---

# 4. Domain Boundary Review

Review the `Trip` aggregate and related domain objects.

Keep genuine invariants inside the domain, including:

- Legal state transitions
- Resource reservation state
- Route immutability after assignment
- Route invalidation semantics
- Cancellation restrictions
- Completion semantics

Do not move orchestration or provider calls into the Domain project.

Extract focused domain policies or value objects only where they reduce duplicated logic. Do not split the aggregate merely to reduce line count.

Ensure:

- No EF Core references in Domain
- No HTTP/API contracts in Domain
- No localization strings in Domain
- No provider-specific GPS, MapLibre, OSRM, or geocoder types in Domain
- All state changes still pass through named methods

---

# 5. Flutter Trip Planner Refactoring

The trip planner must no longer be one large stateful screen owning UI, API orchestration, navigation rules, map state, and validation.

Refactor toward this responsibility structure:

```text
features/trips/
  data/
  domain/
  presentation/
    planner/
      trip_planner_screen.dart
      trip_planner_controller.dart
      trip_planner_state.dart
      trip_planner_validation.dart
      steps/
        trip_details_step.dart
        trip_route_step.dart
        trip_assignment_step.dart
        trip_review_step.dart
      widgets/
        ...focused reusable widgets...
```

Adapt names to the current project conventions.

## Controller responsibilities

- Load or resume a Draft
- Own the persisted Draft snapshot
- Own current step and reachability
- Coordinate Draft/stops/route/assignment requests
- Prevent duplicate submission
- Recover from assignment and concurrency conflicts
- Expose immutable UI state
- Provide explicit commands to the screen

## Screen responsibilities

- Compose layout
- Render state
- Forward user intent to the controller
- Handle navigation and dialogs that require `BuildContext`

## Step responsibilities

- Render fields for one step
- Show localized validation
- Emit user intent
- Avoid direct Dio/repository calls
- Avoid owning cross-step business state

Requirements:

- Preserve the exact validated four-step workflow.
- Preserve Draft resume and route idempotency.
- Preserve map-click selection.
- Preserve assignment eligibility reasons.
- Preserve review and final actions.
- Preserve all stable widget keys used by browser tests unless a deliberate compatibility update is made to the test in the same change.
- No network request may originate directly from a widget.
- Do not introduce a second state-management system; continue using Riverpod.

---

# 6. Flutter Models and Repository Boundaries

Split the broad `operations_models.dart` file by feature ownership.

Suggested ownership:

- Client models
- Fleet models
- Trip models
- Routing/location models
- Assignment-option models
- Shared pagination contracts only where truly shared

Requirements:

- Avoid circular imports.
- Avoid a `models.dart` barrel that recreates hidden global coupling.
- JSON decoding remains tested.
- Stable backend enum/error identifiers remain untranslated internally.
- Widgets consume domain/presentation models rather than raw JSON.
- Repositories remain behind Riverpod providers/controllers.

Preserve API compatibility.

---

# 7. Fleet Map Boundary Cleanup

Do not redesign the fleet map.

The existing coordinator/adapter split is valuable and must remain.

Refactor only clear presentation hotspots from `fleet_map.dart`, such as:

- Selected-truck panel
- Fleet list/filter panel
- Map status/error overlay
- Legend
- Camera action controls
- MapLibre adapter lifecycle, if still mixed with widgets

Requirements:

- Preserve incremental annotations.
- Preserve zero global clears during polling.
- Preserve zero polling camera moves.
- Preserve route, trail, stop, and truck marker identity.
- Preserve manual pan/zoom authority.
- Preserve Arabic/RTL.
- Do not introduce animation flicker.

Use the existing coordinator tests as behavioral protection.

---

# 8. Automated Architecture Tests

Add a small architecture-test suite for structural invariants.

It must fail when:

- Domain references Application, Infrastructure, or API.
- Application references Infrastructure or API.
- API controllers directly depend on `AppDbContext`.
- Domain types reference EF Core, ASP.NET Core, MapLibre, Dio, or Flutter.
- Infrastructure provider types leak into Application contracts.
- A tenant-owned persisted entity does not implement `ITenantOwned`.
- A tenant-owned entity lacks expected tenant configuration/indexing, where deterministically testable.
- `IgnoreQueryFilters` appears outside explicitly approved identity/bootstrap infrastructure files.
- Flutter presentation widgets import Dio or the concrete API client directly.
- A second Flutter state-management framework is introduced.

Prefer straightforward tests or reflection. A small, justified dependency is acceptable, but do not add a heavy architecture framework unnecessarily.

Keep the approved exception list explicit and minimal.

---

# 9. GitHub Continuous Integration

Add GitHub Actions under:

`.github/workflows/`

The CI must run on pull requests and pushes to the main development branch.

Create one readable workflow or a small number of purpose-specific workflows.

Required jobs:

## Backend

- Restore dependencies
- Build with warnings treated consistently with the repository policy
- Run architecture tests
- Run the full backend integration suite against PostgreSQL
- Confirm EF Core model/migration drift is absent

## Flutter

- Resolve dependencies
- Generate localization if required
- Run formatting verification without rewriting files
- Run analyzer
- Run unit/widget tests
- Build Flutter Web release using non-secret safe configuration

## Optional browser smoke job

If reliable within GitHub-hosted runners, add a focused deterministic browser smoke job using local containers and a dedicated test tenant.

If full MapLibre/browser integration is too flaky or expensive for every push:

- Keep the deterministic non-provider workflow in CI.
- Document the complete browser acceptance command as a release/manual gate.
- Do not call a manual-only test a CI test.

CI requirements:

- No production secrets in repository or workflow YAML.
- No dependency on public OSRM/geocoding/tile availability for mandatory unit/integration jobs.
- Provider calls must be replaced by deterministic test doubles where appropriate.
- Use dependency caching safely.
- Upload useful test logs/artifacts on failure.
- Avoid destructive access to retained development data.
- CI must start from its own disposable PostgreSQL instance.

Validate the workflow syntax locally where possible. If GitHub-hosted execution cannot be observed from the current environment, clearly distinguish local validation from actual GitHub execution.

---

# 10. Code Quality Guardrails

Add documented guardrails for future work.

They should include:

- One clear owner per business rule
- No business logic in Flutter widgets
- No EF Core in controllers or Application
- No frontend-supplied tenant ID
- No hard-coded user-visible strings
- Stable error codes
- Reviewed migration per schema change
- Regression test for every fixed production/user-reported defect
- Full browser test for cross-screen workflow changes
- Documentation update when a state machine or boundary changes
- No new catch-all service/store/model file

Do not enforce arbitrary line-count failure rules that encourage gaming. However, document and review unusually large handwritten files.

Target outcomes for this sprint:

- The planner screen itself becomes a small composition shell.
- No extracted planner step owns remote calls.
- Trip application use cases are no longer concentrated in one 600+ line service.
- New interfaces are cohesive and consumer-driven.

If a remaining handwritten file exceeds roughly 500 lines, explain why it is still cohesive in the implementation plan.

Generated localization and EF migration designer files are excluded from hotspot judgments.

---

# 11. Documentation Cleanup

Update the architecture documentation so there is one authoritative current description.

Requirements:

- Repair duplicate ADR numbering.
- Mark obsolete decisions as `Superseded` and link to the replacing ADR.
- Do not silently rewrite historical decisions as if they never existed.
- Publish the current trip state machine in one canonical ADR.
- Ensure older ADRs do not contradict the current lifecycle without a superseded notice.
- Add a module ownership map.
- Add backend and Flutter dependency rules.
- Add the standard Definition of Done for future sprints.
- Add instructions for running CI checks locally.
- Document which browser tests are mandatory for release versus every push.

Recommended current trip lifecycle:

```text
Draft
  -> Assigned
  -> EnRouteToPickup
  -> AtPickup
  -> Started
  -> InTransit
  -> Delivered
  -> Completed
```

Cancellation and archive behavior must be documented as orthogonal transitions where applicable.

---

# 12. Observability Baseline

Without building a complete monitoring platform, verify and standardize:

- Structured server logging
- Correlation/request ID propagation
- Safe exception mapping
- No sensitive token/password logging
- Health and readiness endpoints
- Startup configuration validation for required production settings
- Clear provider timeout/failure logging without leaking credentials

Add only the smallest changes required for a reliable baseline.

Do not add paid monitoring services during this sprint.

---

# 13. Security and Multi-Tenant Regression Review

Run a focused review after refactoring:

- Every new store query remains tenant-filtered.
- Foreign tenant IDs return safe not-found behavior.
- Assignment options never expose foreign resources or trip numbers.
- `IgnoreQueryFilters` remains limited to reviewed authentication/bootstrap operations.
- Named authorization policies remain on controllers.
- Simulator mutation remains Development/Testing-only and Owner-only.
- Refresh tokens remain hashed and rotated.
- No secret or `.env` content enters CI artifacts.

Add missing regression tests where the refactor creates a new risk surface.

---

# 14. Compatibility and Refactoring Strategy

Use incremental refactoring:

1. Capture behavior with tests.
2. Extract one responsibility.
3. Run focused tests.
4. Run the relevant integration suite.
5. Continue to the next responsibility.
6. Run the complete quality gate at the end.

Avoid a single giant rewrite commit in the working tree.

Preserve:

- API URLs
- Request/response JSON
- Error codes
- Trip status values
- Database schema
- Flutter routes
- User-visible workflow
- Existing Development simulator controls
- Existing test tenant behavior

If compatibility must change to fix a confirmed defect, document it before implementation and add a compatibility test.

---

# 15. Required Validation

Run all applicable checks:

- .NET restore
- .NET build with zero warnings and errors
- Architecture tests
- Full backend integration tests
- PostgreSQL-backed tests
- EF migration drift check
- Flutter format verification
- Flutter analyzer
- Full Flutter unit/widget suite
- Flutter Web production release build
- Flutter Web Development/Testing build when simulator compile-time flags apply
- Docker Compose health verification
- Real authenticated Firefox regression workflow

The browser regression must confirm at least:

1. Login.
2. Arabic/RTL.
3. Create a new Draft.
4. Select pickup and delivery on the map.
5. Calculate the route.
6. Select an eligible truck and driver.
7. Review and assign.
8. Open trip details.
9. Preview or execute the existing route-to-pickup workflow far enough to prove contracts remain connected.
10. Open the dashboard and verify map markers and selection.
11. Switch to English/LTR.
12. Logout.

This sprint changes architecture rather than features, so the same externally visible workflow must pass before and after.

Android:

- Build/run only when a valid SDK and device/emulator exist.
- Otherwise report the exact blocker without claiming Android validation.

---

# 16. Evidence

Create:

`docs/evidence/sprint3_5/`

Include:

- Baseline and final quality-gate summary
- Before/after hotspot inventory
- Before/after dependency diagram or table
- Architecture-test results
- CI workflow validation evidence
- Backend and Flutter test results
- EF drift result
- Browser regression result
- Representative Arabic/RTL and English/LTR screenshots
- Known limitations

Do not fabricate GitHub CI success. If the workflow is created but has not run on GitHub, say exactly that.

---

# 17. Explicitly Out of Scope

Do not implement:

- Finance
- Expenses
- Payments
- Receivables
- Profitability
- Maintenance management
- Document management
- Alerts
- Real GPS providers
- SignalR
- Route optimization
- Driver mobile app
- Driver profile photos
- Subscription/billing plans
- Microservices
- Event sourcing
- Kubernetes
- A new design system

Do not mix product expansion into this stabilization sprint.

---

# 18. Definition of Done

Sprint 3.5 is complete only when:

- Existing product behavior is preserved.
- Baseline and final browser workflows both have equivalent outcomes.
- Trip use cases have cohesive application ownership.
- The large `TripService` hotspot has been removed or reduced to a minimal compatibility facade with a documented removal plan.
- `IOperationsStore` is no longer a catch-all application dependency.
- The Flutter planner screen is a composition shell backed by one controller/state model.
- Each planner step is a focused widget with no direct network calls.
- Operations models are separated by feature ownership.
- Fleet-map presentation responsibilities are separated without annotation or camera regressions.
- Architecture tests enforce project dependency rules.
- CI workflows exist and their syntax/local commands are validated.
- Mandatory CI jobs do not require public routing/map provider availability.
- All existing backend tests pass and the count does not silently decrease.
- All existing Flutter tests pass and the count does not silently decrease.
- .NET build has zero warnings and errors.
- Flutter analyzer has zero issues.
- Flutter Web release build passes.
- EF model drift is absent.
- Compose services are healthy.
- Tenant isolation and authorization regressions pass.
- Architecture documentation is current and contradictions are marked superseded.
- No production secret, credential, or `.env` content is committed.
- The final report distinguishes verified GitHub CI runs from workflow files that were only validated locally.

---

# 19. Git and Safety Rules

- Do not commit.
- Do not push.
- Do not create or merge a pull request.
- Do not reset or discard unrelated user changes.
- Do not overwrite `.env`.
- Do not reset retained user passwords.
- Do not delete or recreate the retained PostgreSQL volume.
- Do not squash or rewrite existing migrations.
- Recreate only the minimum required containers if Compose repair is needed.
- Preserve all Sprint documentation and evidence.
- Leave changes uncommitted for user review.

---

# 20. Required Final Report

Provide a concise but complete final report containing:

## Architectural changes

- Backend services extracted
- Persistence ports created
- Flutter planner components extracted
- Fleet-map components extracted
- Model ownership changes
- Documentation/ADR corrections

## Behavioral compatibility

- APIs preserved
- Database schema status
- User workflow status
- Any intentional compatibility adjustment

## Quality gates

- .NET build result
- Backend integration test count
- Architecture test count
- Flutter analyzer result
- Flutter test count
- Web build result
- EF drift result
- PostgreSQL/Compose result
- Browser regression result
- Android result or exact blocker

## CI

- Workflow files added
- Jobs included
- Whether GitHub actually executed them
- Any manual release gate retained

## Hotspot comparison

Provide a before/after table for the major handwritten hotspots and explain any remaining file over approximately 500 lines.

## Evidence and timing

- Evidence directory
- Implementation plan
- Task-level active elapsed times
- Total active elapsed time

## Git status

Confirm that no commit, push, or PR was performed and summarize changed files.

If any mandatory quality gate or behavioral regression workflow fails, report Sprint 3.5 as incomplete rather than weakening the acceptance criteria.
