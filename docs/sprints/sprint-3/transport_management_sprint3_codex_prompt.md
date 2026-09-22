# Sprint 3 Prompt — Localization, Fleet Map, Tracking Simulator, and Operational Dashboard

You are acting as a **Senior Software Architect**, **Senior Full-Stack Engineer**, and **Senior Flutter Engineer**.

This repository already contains a completed and locally verified Transport Management System through Sprint 2.

Sprint 1 established the technical foundation:

- .NET 10
- ASP.NET Core Web API
- PostgreSQL + EF Core
- JWT authentication with refresh-token rotation
- Multi-tenant company isolation
- Flutter Web + Android
- Riverpod
- GoRouter
- Docker + Docker Compose
- Integration tests
- Structured logging
- ProblemDetails
- Modular Monolith
- Clean Architecture
- DDD-lite
- CQRS-lite

Sprint 2 established the operational core:

- Clients
- Trucks
- Drivers
- Trips
- Explicit Trip state machine
- Truck/driver assignment rules
- Double-assignment protection
- Tenant isolation for all operational entities
- Role/policy authorization
- Responsive Flutter operational screens
- Full browser smoke test

Do not redesign or replace working Sprint 1 or Sprint 2 architecture unless a serious defect is discovered.

Before implementation:

1. Inspect the repository.
2. Read the root `README.md`.
3. Read `docs/architecture.md`.
4. Read `docs/sprints/sprint-1/SPRINT1_IMPLEMENTATION_PLAN.md`.
5. Read `docs/sprints/sprint-2/SPRINT2_IMPLEMENTATION_PLAN.md`.
6. Run the existing backend build/tests.
7. Run Flutter analyze/tests.
8. Establish a clean baseline before changing code.

---

## 1. Sprint 3 Goal

Sprint 3 has four primary goals:

1. Add proper Arabic/English localization.
2. Support full RTL/LTR UI switching from application settings.
3. Add a fleet map and a tracking abstraction without integrating real GPS hardware yet.
4. Add a local tracking simulator and upgrade the dashboard into a useful operational fleet dashboard.

The purpose of this sprint is to make the product visually and operationally closer to a real transport-company system while keeping GPS vendor integration deferred.

---

## 2. Mandatory Sprint Documentation and Time Tracking

This requirement is mandatory and part of the Definition of Done.

Create a new root-level file:

```text
docs/sprints/sprint-3/SPRINT3_IMPLEMENTATION_PLAN.md
```

Before implementation begins, create the initial execution plan.

For every major task record:

- Task number
- Task name
- Deliverables
- Status
- Start time in UTC
- Finish time in UTC
- Real elapsed wall-clock time

Use statuses:

- Pending
- In Progress
- Complete
- Blocked

Use a table similar to:

```text
| # | Task | Deliverables | Status | Started (UTC) | Finished (UTC) | Elapsed |
```

Elapsed time must reflect actual wall-clock execution time including implementation, debugging, test execution, fixes, and documentation.

Do not fabricate timing values.

Record actual timestamps when tasks begin and finish.

Update `docs/sprints/sprint-3/SPRINT3_IMPLEMENTATION_PLAN.md` continuously during execution, not only at the end.

Also include:

### Decisions and Notes
Record all significant implementation and architecture decisions.

### Verification Record
Record important validation events with timestamps, including where applicable:
- Sprint 2 baseline validation
- backend build
- EF migration creation
- backend tests
- Flutter analyze
- Flutter tests
- Flutter Web release build
- localization tests
- RTL/LTR visual validation
- fleet-map validation
- simulator validation
- browser smoke test
- Docker Compose validation
- Android validation if tooling exists

### Final Validation Limitations
Document any environment/tooling limitations.

### Sprint Timing Summary
Include:
- sprint start
- sprint finish
- total wall-clock time
- per-task elapsed time
- verification/fix time
- blocked/environment-dependent time where identifiable

Sprint 3 is not complete until this file is fully updated.

---

## 3. Sprint 3 Scope

Implement:

1. Localization infrastructure
2. Arabic language support
3. English language support
4. RTL/LTR switching
5. User language preference
6. Localized frontend validation and backend-error mapping
7. Tracking abstraction
8. Simulated tracking provider
9. Fleet map
10. Current truck positions
11. Basic position history support where practical
12. Operational fleet dashboard
13. Development-only simulator controls
14. Sprint 3 browser smoke test
15. Full documentation

Do not implement:

- real GPS hardware integration
- Traccar integration
- Wialon integration
- Teltonika direct protocol integration
- geofencing alerts
- route optimization
- CAN Bus
- fuel sensors
- advanced telematics
- Finance
- Expenses
- Payments
- Profitability
- Driver mobile app
- advanced Maintenance
- Documents

---

## 4. Localization Architecture

Implement proper Flutter localization using standard Flutter localization mechanisms.

Preferred approach:
- `flutter_localizations`
- generated localization classes
- ARB resource files

Use a structure similar to:

```text
lib/l10n/
  app_en.arb
  app_ar.arb
```

Do not hardcode user-visible strings directly inside widgets unless there is a strong reason.

Replace relevant existing UI text with localized keys.

At minimum localize:
- authentication screens
- application shell/navigation
- dashboard
- Clients
- Trucks
- Drivers
- Trips
- forms
- buttons
- empty states
- status labels
- validation messages
- error messages
- settings
- map labels
- simulator labels
- confirmation dialogs

Do not attempt to translate raw backend exception text.

---

## 5. Arabic and RTL Support

Arabic must be a first-class supported language.

When Arabic is selected:
- application direction must become RTL
- navigation layout must adapt correctly
- text alignment must follow RTL
- forms must remain usable
- tables/lists must remain readable
- dialogs must remain visually correct
- icons that imply direction should mirror where appropriate
- spacing and layout must not be based on hardcoded left/right assumptions

Use directional Flutter APIs where possible:
- `EdgeInsetsDirectional`
- `AlignmentDirectional`
- `BorderRadiusDirectional` where appropriate

Avoid hardcoded left/right positioning where a directional equivalent exists.

English must remain LTR.

---

## 6. Language Settings

Add an application settings area.

At minimum support:

```text
Language
  - English
  - العربية
```

The user's selected locale should be persisted.

Prefer server-backed user preference persistence so the preference follows the user across devices.

Suggested field:

```text
PreferredLocale
```

Allowed values initially:

```text
en
ar
```

The backend must validate supported locale values.

After login, the app should resolve the user's preferred locale.

Changing locale should update the UI immediately where practical.

---

## 7. Localized Status and Enum Labels

Backend enums should remain stable internal/domain values.

Do not store Arabic text inside domain enums.

Example:

```text
TruckStatus.Available
TripStatus.InTransit
```

Flutter localization should render them as:

English:
```text
Available
In transit
```

Arabic:
```text
متاحة
قيد النقل
```

Use a centralized mapping from enum/domain value to localization key.

---

## 8. Backend Error Codes

Improve API/business errors so Flutter does not depend on English backend text.

For important domain errors, provide stable machine-readable error codes.

Examples:

```text
TRUCK_ALREADY_ASSIGNED
DRIVER_ALREADY_ASSIGNED
INVALID_TRIP_TRANSITION
CLIENT_NOT_FOUND
TRUCK_NOT_AVAILABLE
DRIVER_NOT_AVAILABLE
```

Continue using ProblemDetails.

Add an extension field or equivalent structured mechanism for an error code.

Flutter should map known error codes to localized messages.

Unknown errors should fall back to a safe generic localized message.

---

## 9. Tracking Architecture

Introduce tracking as a separate application-facing abstraction.

Do not tie the Domain model to a specific tracking vendor.

Use an abstraction conceptually similar to:

```csharp
public interface ITrackingProvider
{
    Task<IReadOnlyList<TruckPositionDto>> GetCurrentPositionsAsync(...);
    Task<TruckPositionDto?> GetCurrentPositionAsync(...);
}
```

The exact API may be improved.

The rest of the application must not know whether positions come from:
- simulator
- Traccar
- Wialon
- direct GPS device integration
- another provider

Vendor-specific implementations must live outside the Domain.

---

## 10. Simulated Tracking Provider

Implement a development/testing tracking provider.

Suggested name:

```text
SimulatedTrackingProvider
```

The simulator should produce moving truck positions without real hardware.

At minimum simulate:
- Latitude
- Longitude
- Speed
- Heading
- Timestamp
- Online/Offline state

Simulated trucks should move along predefined routes or route segments.

A deterministic route interpolation approach is sufficient.

---

## 11. Simulator Scope and Safety

The simulator is a development/testing capability.

It must not accidentally become the default provider in Production.

Use explicit configuration such as:

```text
Tracking__Provider=Simulator
```

Require appropriate environment/configuration to enable simulator controls.

Production should fail safely or use a no-op/unconfigured provider until a real provider is implemented.

Document this behavior.

---

## 12. Development Simulator Controls

Add a development-only simulator control surface.

It may be:
- a development-only API
- a protected admin/development screen
- or a clean combination

Support useful actions such as:
- Start simulation
- Pause simulation
- Resume simulation
- Stop simulation
- Reset simulation
- Set truck Offline
- Bring truck Online
- Change simulation speed where practical
- Start all simulated trucks
- Stop all simulated trucks

Do not expose simulator controls to ordinary production users.

---

## 13. Tracking Persistence

Introduce a clean model for truck-position data.

Possible model:

```text
TruckPosition
  Id
  CompanyId
  TruckId
  Latitude
  Longitude
  Speed
  Heading
  RecordedAt
  Source
```

All stored positions must be tenant-owned.

Add appropriate indexes.

At minimum support efficient access to:
- latest position per truck
- recent positions for a selected truck

Do not design a massive time-series architecture yet.

---

## 14. Latest Position API

Provide APIs suitable for the fleet map.

Conceptually:

```text
GET /api/tracking/positions
GET /api/tracking/trucks/{truckId}/position
```

Optional recent history:

```text
GET /api/tracking/trucks/{truckId}/history
```

Each result should contain enough data for the UI:
- truck ID
- truck plate/name
- latitude
- longitude
- speed
- heading
- timestamp
- online/offline state
- current trip if available
- driver if available

Do not leak cross-tenant position data.

---

## 15. Map Technology

Use a map implementation that supports Flutter Web and Android.

Preferred option:

**MapLibre**

Keep the tile/style provider configurable.

Do not hardcode provider credentials.

Use configuration such as:

```text
MAP_STYLE_URL
```

Document clearly that MapLibre is the rendering layer and that production tile/style hosting/provider selection remains configurable.

If another map library is significantly better for the existing repository, document the reason before deviating.

---

## 16. Fleet Map

Add a Fleet Map screen or dashboard section.

Display all trucks for the current tenant that have a current position.

Each truck should have a marker.

Marker interaction should show useful information:
- plate number
- truck status
- tracking state
- speed
- last update
- assigned driver
- active trip if any

---

## 17. Polling Strategy

For Sprint 3, use simple polling instead of introducing real-time infrastructure unless there is a concrete reason not to.

A reasonable default is:

```text
Refresh positions every 3–5 seconds
```

Make the interval configurable or centrally defined.

Avoid duplicate polling loops.

Stop/reduce unnecessary polling when the relevant screen is not active where practical.

Do not introduce SignalR only for architectural appearance.

---

## 18. Online / Offline Logic

Define a simple configurable tracking connectivity rule.

Example:

```text
Online:
latest position age <= configured threshold

Offline:
latest position age > threshold
```

Do not confuse:
- Truck operational status
- Tracking online/offline status

These are separate concepts.

---

## 19. Operational Dashboard

Upgrade the current dashboard into a useful fleet-operations dashboard.

Display at least:
- Total Trucks
- Available Trucks
- Trucks On Trip
- Trucks in Maintenance
- Trucks Out of Service
- Active Trips
- Completed Trips today or recent period
- Online tracked trucks
- Offline tracked trucks
- Fleet Map
- Recent Trips

Do not add Finance metrics in Sprint 3.

All values must come from real application data.

---

## 20. Dashboard Backend/API

Add an efficient tenant-scoped dashboard query/use case.

Avoid making Flutter call many unrelated endpoints if one dashboard endpoint/query is more appropriate.

A possible response can group:

```text
FleetSummary
TripSummary
TrackingSummary
RecentTrips
```

---

## 21. Dashboard UX

Desktop/Web:
- map should have useful prominence
- summary cards should be readable
- recent trips/status should not overwhelm the map

Mobile:
- map remains usable
- cards stack/wrap appropriately
- no desktop-only fixed layouts

Support both RTL and LTR.

---

## 22. Authorization

Preserve current role/policy architecture.

Suggested behavior:

Owner:
- full Sprint 3 access
- settings
- tracking views
- simulator controls only when environment permits

Operations:
- tracking/map access
- operational dashboard access

Accountant:
- read-only operational dashboard access if appropriate
- no simulator controls

Employee:
- conservative access consistent with current policy

Document the final matrix.

---

## 23. Tenant Isolation

All tracking data must be tenant-isolated.

Add tests proving:
- Company A cannot retrieve Company B truck positions
- Company A cannot retrieve Company B position history
- Company A cannot control simulation for Company B trucks
- tracking dashboard data is tenant-scoped

---

## 24. Localization Testing

Add tests verifying:
- English locale renders English labels
- Arabic locale renders Arabic labels
- Arabic direction is RTL
- English direction is LTR
- locale preference persists
- localized validation/error mapping works for at least one representative error code

---

## 25. Simulator Testing

Add backend/integration tests verifying:
- simulated truck obtains a position
- position changes over simulation steps
- pause stops movement
- resume restarts movement
- offline state is represented correctly
- reset returns to expected route/start state
- tenant isolation remains enforced

Prefer deterministic tests over timing-fragile sleeps.

---

## 26. Map / Flutter Testing

Add meaningful Flutter tests.

At minimum:
- fleet map screen loads
- empty state when no tracked trucks exist
- localized Arabic map/dashboard labels render
- RTL dashboard layout initializes correctly
- truck selection/details display
- tracking refresh updates UI state where practical

Avoid brittle pixel-perfect tests.

---

## 27. Sprint 3 Browser Smoke Test

Create a Sprint 3 end-to-end smoke test covering:

```text
Login
Switch language to Arabic
Verify RTL
Open Fleet Dashboard
Start simulator
Verify tracking data/truck markers appear
Select a truck
Verify truck/driver/trip tracking details
Pause or stop simulator
Switch language back to English
Logout
```

Run entirely against local development infrastructure.

Do not depend on real GPS hardware or real telematics services.

If external map tiles are required, the smoke test should still robustly verify the tracking/UI state even if tile rendering is unavailable, and this dependency must be documented.

---

## 28. Database Migration

If new entities/preferences/position storage are added:

- create a Sprint 3 EF Core migration
- inspect it
- apply it locally
- confirm no pending model drift afterward

Add appropriate indexes.

Use UTC timestamps.

Use appropriate numeric precision for latitude/longitude and speed.

---

## 29. Configuration

Add documented configuration for Sprint 3.

Examples:

```text
Tracking__Provider
Tracking__PollingIntervalSeconds
Tracking__OfflineThresholdSeconds
Tracking__SimulatorEnabled
MAP_STYLE_URL
```

Use the existing configuration pattern.

Do not commit secrets.

Update `.env.example` or equivalent where appropriate.

---

## 30. README Updates

Update the root `README.md`.

Add:
- localization support
- how to switch language
- RTL support
- tracking architecture overview
- simulator setup
- simulator controls
- fleet map setup
- required map configuration
- dashboard overview
- Sprint 3 smoke-test instructions
- new environment variables
- migration information
- known limitations

Preserve Sprint 1 and Sprint 2 documentation.

---

## 31. Architecture Documentation

Update:

```text
docs/architecture.md
```

Document:
- localization strategy
- user locale persistence
- backend error-code strategy
- tracking abstraction
- simulator provider
- tracking persistence model
- map integration
- polling decision
- online/offline rule
- dashboard query design
- tenant isolation for tracking

Add ADR sections for significant decisions.

Suggested ADR topics:
- Localization and RTL strategy
- Tracking provider abstraction
- Polling before SignalR
- Simulator as non-production provider
- MapLibre/configurable map provider
- Position storage strategy

---

## 32. Engineering Constraints

Continue following:
- Modular Monolith
- Clean Architecture
- DDD-lite
- CQRS-lite
- thin controllers
- tenant isolation
- structured logging
- UTC timestamps
- environment-based configuration
- no secrets in source control
- Flutter feature-first architecture
- Riverpod only
- GoRouter only

Do not introduce:
- Microservices
- Event Sourcing
- Kafka
- RabbitMQ
- unnecessary SignalR
- unnecessary simulator complexity

---

## 33. Sprint Boundary

Sprint 3 stops after:
- English/Arabic localization
- RTL/LTR support
- user language preference
- tracking abstraction
- tracking simulator
- fleet map
- basic current positions
- operational dashboard
- tests
- smoke tests
- documentation

Do not continue automatically into:
- Finance
- Expenses
- Payments
- Profitability
- Real GPS provider integration
- Advanced Maintenance
- Documents
- Advanced Alerts
- Route Optimization
- Driver Application
- AI functionality

---

## 34. Definition of Done

Sprint 3 is complete only when:

1. Sprint 1 and Sprint 2 functionality remains working.
2. Existing backend tests still pass.
3. Existing Flutter tests still pass.
4. English localization works.
5. Arabic localization works.
6. Arabic renders RTL.
7. English renders LTR.
8. Language can be changed from Settings.
9. Preferred language persists.
10. Major user-visible existing screens are localized.
11. Known backend domain errors use stable error codes.
12. Flutter maps known error codes to localized messages.
13. Tracking provider abstraction exists.
14. Simulator provider exists.
15. Simulator can start/pause/resume/stop/reset as designed.
16. Simulated truck locations change predictably.
17. Current positions are tenant-isolated.
18. Fleet map displays tracked trucks.
19. Truck tracking details can be inspected.
20. Online/offline tracking status works.
21. Operational dashboard displays real system data.
22. Dashboard works in English/LTR.
23. Dashboard works in Arabic/RTL.
24. Backend build passes with 0 errors.
25. Backend tests pass.
26. EF model has no unintended drift.
27. Flutter analyze is clean.
28. Flutter tests pass.
29. Flutter Web release build succeeds.
30. Sprint 3 browser smoke test succeeds.
31. Docker Compose remains healthy.
32. README is updated.
33. `docs/architecture.md` is updated.
34. `docs/sprints/sprint-3/SPRINT3_IMPLEMENTATION_PLAN.md` is complete.
35. Per-task actual elapsed times are documented.
36. Total actual sprint elapsed time is documented.
37. Any Android/tooling limitations are documented.

---

## 35. Final Implementation Report

When Sprint 3 is complete, return a concise report containing:

1. What was implemented
2. Localization implementation
3. RTL/LTR behavior
4. User language preference implementation
5. Tracking architecture
6. Simulator capabilities
7. Map implementation
8. Dashboard implementation
9. Backend/API changes
10. Database migration changes
11. Tests added
12. Backend test results
13. Flutter test/analyzer results
14. Flutter Web build result
15. Browser smoke-test result
16. Docker validation result
17. Architecture decisions
18. Documentation updated
19. Environment/tooling limitations
20. Total sprint wall-clock time
21. Per-task elapsed times
22. Reference to `docs/sprints/sprint-3/SPRINT3_IMPLEMENTATION_PLAN.md`
23. Anything intentionally deferred to Sprint 4

Do not continue into Sprint 4 unless explicitly requested.
