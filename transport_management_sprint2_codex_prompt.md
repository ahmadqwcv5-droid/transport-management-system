# Sprint 2 Prompt — Operational Core

You are acting as a **Senior Software Architect** and **Senior Full-Stack Engineer**.

This repository already contains a completed and validated Sprint 1 foundation for a multi-tenant Transport Management System.

Sprint 1 established:

- .NET 10 backend
- ASP.NET Core Web API
- PostgreSQL + EF Core
- JWT authentication with refresh-token rotation
- Multi-tenant company isolation
- Flutter Web + Android project
- Riverpod state management
- Docker + Docker Compose
- Integration testing
- Structured logging
- ProblemDetails
- Clean Architecture
- Modular Monolith
- DDD-lite
- CQRS-lite

Do not redesign or replace the existing architecture unless a serious defect is discovered.

Before starting implementation:

1. Inspect the repository.
2. Read the existing README.
3. Read `docs/architecture.md`.
4. Read `SPRINT1_IMPLEMENTATION_PLAN.md`.
5. Preserve all working Sprint 1 functionality.
6. Run the existing build/tests first and establish a clean baseline.

---

## 1. Sprint 2 Goal

Sprint 2 introduces the first real operational business functionality.

The objective is to allow a transport company employee to perform this end-to-end workflow:

```text
Login
  ↓
Create Client
  ↓
Create Truck
  ↓
Create Driver
  ↓
Create Trip
  ↓
Assign Truck + Driver
  ↓
Start Trip
  ↓
Mark In Transit
  ↓
Mark Delivered
  ↓
Complete Trip
```

This sprint should produce a usable operational core for a small transport company.

Do not implement Finance, GPS, advanced Maintenance, Documents, or a full analytics dashboard yet.

---

## 2. Mandatory Sprint Documentation and Time Tracking

This requirement is part of the Definition of Done.

Create a new root-level file:

```text
SPRINT2_IMPLEMENTATION_PLAN.md
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

Elapsed time must reflect actual wall-clock time spent on the stage, including implementation, debugging, tests, fixes, and documentation.

**Do not fabricate timing values.**

Record timestamps when tasks actually begin and finish.

Update the file continuously throughout the sprint, not only at the end.

Also include these sections:

### Decisions and Notes

Record important engineering and product decisions made during the sprint.

### Verification Record

Record important validations with timestamps, including where applicable:

- baseline build/tests
- backend build
- EF migration creation
- integration tests
- Flutter analyze
- Flutter tests
- Flutter Web release build
- browser smoke test
- Docker Compose validation
- Android validation if tooling exists

### Final Validation Limitations

Document anything that could not be verified because of environment/tooling limitations.

### Sprint Timing Summary

At the end include:

- total elapsed sprint wall-clock time
- per-task elapsed time
- blocked/environment-dependent time where identifiable
- verification/fix time where identifiable

The sprint is not considered complete until this document is fully updated.

---

## 3. Product Context

The product is an internal Transport Management System for small and medium-sized trucking companies.

The first real use case is a small company with approximately 7 trucks.

The company is contracted by factories and other companies to transport goods.

There is no customer self-service booking portal.

Transport company staff internally manage:

- clients
- trucks
- drivers
- trips
- operational trip status

The application must remain ready to evolve into a multi-tenant SaaS product.

All new business entities introduced in Sprint 2 must be tenant-owned.

---

## 4. Sprint 2 Modules

Implement:

1. Clients
2. Fleet / Trucks
3. Fleet / Drivers
4. Trips

Do not implement:

- GPS tracking
- Finance
- Expenses
- Customer payments
- Profitability
- Advanced maintenance
- Document management
- Driver mobile application
- Route optimization
- AI features
- Full dashboard analytics

---

## 5. Multi-Tenancy

All new tenant-owned entities must:

- implement the existing tenant ownership abstraction such as `ITenantOwned`
- contain required `CompanyId`
- receive `CompanyId` from the authenticated tenant context
- never trust `CompanyId` submitted by the frontend
- remain protected by the existing tenant-filter architecture
- include an index on `CompanyId` where appropriate

Every new module must include integration coverage proving that a Company A user cannot access a Company B resource by manually changing the resource ID.

Do not weaken the Sprint 1 tenant-isolation mechanism.

---

## 6. Clients Module

Implement a Client entity representing companies/factories that contract the transport company.

Suggested fields:

- Id
- CompanyId
- Name
- ContactPerson
- Phone
- Email
- Address
- Notes
- IsActive
- CreatedAt
- UpdatedAt

Required use cases:

- Create Client
- Update Client
- Get Client
- List Clients
- Deactivate Client

Do not physically delete clients by default if historical trips may reference them.

Validation examples:

- Name is required
- email format validation if provided
- reasonable field length constraints

---

## 7. Trucks Module

Implement a Truck entity.

Suggested fields:

- Id
- CompanyId
- PlateNumber
- Make
- Model
- Year
- Status
- Notes
- IsActive
- CreatedAt
- UpdatedAt

Initial statuses:

```text
Available
OnTrip
Maintenance
OutOfService
```

Plate number should be unique per company, not globally.

Required use cases:

- Create Truck
- Update Truck
- Get Truck
- List Trucks
- Change Truck Status where allowed
- Deactivate Truck

Do not add GPS fields tied to a specific vendor.

---

## 8. Drivers Module

Implement a Driver entity.

Suggested fields:

- Id
- CompanyId
- FullName
- Phone
- LicenseNumber
- LicenseExpiryDate
- Status
- Notes
- IsActive
- CreatedAt
- UpdatedAt

Initial statuses:

```text
Available
OnTrip
Unavailable
```

Required use cases:

- Create Driver
- Update Driver
- Get Driver
- List Drivers
- Change Driver Status where allowed
- Deactivate Driver

License uniqueness should be tenant-aware where appropriate.

---

## 9. Trips Module

Trip is the primary domain entity in Sprint 2.

Suggested fields:

- Id
- CompanyId
- ClientId
- TruckId
- DriverId
- Origin
- Destination
- CargoDescription
- PlannedStartAt
- ActualStartAt
- DeliveredAt
- CompletedAt
- Price
- Notes
- Status
- CreatedAt
- UpdatedAt

Use an appropriate decimal type for monetary values.

Never use floating-point types for money.

---

## 10. Trip State Machine

Implement explicit state transitions.

Initial statuses:

```text
Draft
Assigned
Started
InTransit
Delivered
Completed
Cancelled
```

At minimum support:

```text
Draft -> Assigned
Assigned -> Started
Started -> InTransit
InTransit -> Delivered
Delivered -> Completed
```

Cancellation must only be allowed from valid pre-completion states.

Forbidden examples:

```text
Draft -> Completed
Completed -> InTransit
Cancelled -> Started
```

Status must not be a freely editable property.

Transitions must happen through explicit domain/application operations.

Invalid transitions must return a clear error.

Document the final transition table/rules in `docs/architecture.md`.

---

## 11. Trip Assignment Rules

A Truck cannot be assigned to two simultaneously active trips.

A Driver cannot be assigned to two simultaneously active trips.

Define explicitly which trip statuses reserve a truck/driver.

When assigning a trip:

- Client must exist in the same tenant
- Truck must exist in the same tenant
- Driver must exist in the same tenant
- Truck must be active
- Driver must be active
- Truck must be available
- Driver must be available
- neither may already be reserved by another active trip

Enforce these rules in the backend.

Do not trust frontend filtering alone.

---

## 12. Resource Status Synchronization

When a trip starts:

```text
Truck.Status = OnTrip
Driver.Status = OnTrip
```

When a trip completes:

```text
Truck.Status = Available
Driver.Status = Available
```

If cancellation occurs before the trip starts and resources were reserved, release them appropriately.

Prevent inconsistent states.

Where concurrency could cause double assignment, implement an appropriate database/application concurrency strategy and document the decision.

---

## 13. Domain Design

Keep meaningful business invariants in Domain or appropriate Application use cases.

Do not place domain rules inside controllers.

Avoid unrestricted setters where they permit invalid states.

Avoid excessive DDD complexity.

Use DDD-lite.

---

## 14. API Design

Create REST endpoints for Clients, Trucks, Drivers, and Trips.

Example conceptual routes:

```text
/api/clients
/api/clients/{id}

/api/trucks
/api/trucks/{id}

/api/drivers
/api/drivers/{id}

/api/trips
/api/trips/{id}

/api/trips/{id}/assign
/api/trips/{id}/start
/api/trips/{id}/mark-in-transit
/api/trips/{id}/deliver
/api/trips/{id}/complete
/api/trips/{id}/cancel
```

Improve naming if justified.

Use DTOs.

Do not expose EF entities directly.

Use validation.

Use the existing ProblemDetails strategy.

Use appropriate HTTP status codes.

Keep controllers thin.

---

## 15. Listing and Filtering

Support lightweight useful filtering.

Clients:

- active/inactive
- name search

Trucks:

- status
- active/inactive
- plate search

Drivers:

- status
- active/inactive
- name search

Trips:

- status
- client
- truck
- driver
- planned date range

Do not build a generic query framework.

Use pagination if justified, and keep pagination conventions consistent.

---

## 16. Database

Add EF Core mappings and migrations for Sprint 2 entities.

Add appropriate:

- foreign keys
- indexes
- uniqueness constraints
- decimal precision for money
- UTC date/time handling

Use tenant-aware uniqueness where appropriate, for example:

```text
(CompanyId, PlateNumber)
(CompanyId, LicenseNumber)
```

Do not create globally unique constraints for tenant-specific values.

---

## 17. Authorization

Continue the existing role/policy architecture.

Suggested access:

### Owner

Full Sprint 2 access.

### Operations

Can manage:

- Clients
- Trucks
- Drivers
- Trips

### Accountant

Read-only access to relevant client/trip operational data for now.

### Employee

Use conservative/minimal access.

Document the final authorization matrix.

Preserve named policies as the future permission seam.

---

## 18. Flutter Screens

Implement clean, practical operational screens.

Do not spend excessive time on visual polish.

### Clients

- Client List
- Create Client
- Edit Client
- Client Details if useful

### Trucks

- Truck List
- Create Truck
- Edit Truck
- Truck Details

### Drivers

- Driver List
- Create Driver
- Edit Driver
- Driver Details

### Trips

- Trip List
- Create Trip
- Edit Draft Trip where appropriate
- Trip Details
- Assign Truck and Driver
- Trip Status Actions

Trip Details should clearly show:

- client
- origin
- destination
- cargo
- truck
- driver
- planned date
- price
- current status
- relevant timestamps
- allowed next actions

---

## 19. Responsive UX

Continue supporting one Flutter codebase for:

- Web
- Android

Web should work well as a desktop management interface.

Android layouts should remain usable on phone-sized screens.

Do not create duplicated Web and Android applications.

Do not create a Driver App.

---

## 20. Frontend Architecture

Preserve the existing feature-first Flutter architecture.

A possible structure:

```text
features/
  clients/
  fleet/
    trucks/
    drivers/
  trips/
```

Keep:

- centralized API client
- Riverpod as the primary state-management system
- GoRouter for routing
- clean feature boundaries

Do not add another competing state-management library.

---

## 21. Flutter UX States

Every feature must handle:

- loading
- empty state
- validation errors
- authorization failure
- network/general failure
- successful save/update

Show user-friendly errors.

Never expose backend stack traces.

---

## 22. Backend Testing Requirements

Testing is mandatory.

Keep all Sprint 1 tests passing.

Add meaningful integration/domain coverage.

### Clients

Test:

- create
- update
- list
- tenant isolation

### Trucks

Test:

- create
- duplicate plate within same tenant rejected
- same plate in a different tenant handled according to tenant-scoped uniqueness
- tenant isolation

### Drivers

Test:

- create
- license uniqueness behavior
- tenant isolation

### Trips

Test:

- create Draft
- assign
- start
- mark InTransit
- deliver
- complete
- valid cancellation
- invalid state transition rejection
- truck double-assignment rejection
- driver double-assignment rejection
- cross-tenant Client assignment rejection
- cross-tenant Truck assignment rejection
- cross-tenant Driver assignment rejection
- trip tenant isolation

Test business behavior, not only controller happy paths.

---

## 23. Flutter Tests

Add a small number of meaningful Flutter tests.

At minimum:

- navigation to each new main module
- list loading or empty state
- create-form validation scenario
- Trip status actions based on current state

Avoid creating large numbers of shallow tests.

---

## 24. Browser Smoke Test

Extend the reusable browser smoke-test approach created in Sprint 1.

Add a Sprint 2 end-to-end browser smoke test covering:

```text
Login
Create Client
Create Truck
Create Driver
Create Trip
Assign Truck + Driver
Start Trip
Advance Trip status
Complete Trip
Logout
```

Use only the local test/development environment.

Do not depend on external services.

Document exactly how to run the smoke test.

---

## 25. Build and Verification

After each major implementation stage:

- run backend build
- run relevant backend tests
- run Flutter analyze
- run relevant Flutter tests

At the end run:

- full .NET build
- full backend test suite
- EF migration/model validation
- Flutter analyze
- Flutter tests
- Flutter Web release build
- Sprint 2 browser smoke test
- Docker Compose validation

If Android SDK becomes available:

- build Android APK/app bundle
- run Android validation where practical

If Android tooling remains unavailable, record it as an environment limitation.

Record all major verification events and elapsed times in `SPRINT2_IMPLEMENTATION_PLAN.md`.

---

## 26. README Updates

Update the existing root `README.md`.

Add:

- Sprint 2 operational features
- API endpoints
- migration information
- new Flutter routes/screens
- updated project structure if changed
- browser smoke-test instructions
- known limitations

Preserve valuable Sprint 1 documentation.

---

## 27. Architecture Documentation

Update:

```text
docs/architecture.md
```

Document:

- Clients module boundary
- Fleet module boundary
- Trips module boundary
- Trip aggregate/domain design
- Trip state transition rules
- resource assignment rules
- concurrency/double-assignment protection
- authorization decisions
- tenant isolation of new entities

Add ADR sections for significant architectural decisions.

Do not hide important architecture decisions only in code comments.

---

## 28. Sprint Boundary

Sprint 2 stops after Clients, Trucks, Drivers, and Trips work reliably.

Do not continue into:

- Finance
- Expenses
- Payments
- Profitability
- GPS
- Advanced Maintenance
- Documents
- Alerts
- Full Dashboard
- Driver Application

These belong to later sprints.

---

## 29. Definition of Done

Sprint 2 is complete only when:

1. Sprint 1 functionality remains working.
2. Existing authentication and tenant-isolation tests pass.
3. Clients can be created, updated, listed, viewed, and deactivated.
4. Trucks can be created, updated, listed, viewed, and deactivated.
5. Drivers can be created, updated, listed, viewed, and deactivated.
6. Trips can be created.
7. Trucks and drivers can be assigned.
8. Invalid assignments are rejected.
9. Trip state transitions are enforced.
10. Invalid state transitions are rejected.
11. Truck and Driver statuses remain synchronized with Trip lifecycle.
12. Double assignment is prevented.
13. Cross-tenant assignment is prevented.
14. Flutter Web supports the complete Sprint 2 workflow.
15. Responsive Android-targeted Flutter UI remains valid.
16. Backend builds without errors.
17. Automated backend tests pass.
18. Flutter analyzer is clean.
19. Flutter tests pass.
20. Flutter Web release build succeeds.
21. Sprint 2 browser smoke test succeeds.
22. Docker Compose remains valid.
23. README is updated.
24. `docs/architecture.md` is updated.
25. `SPRINT2_IMPLEMENTATION_PLAN.md` is complete.
26. All task start/finish timestamps and elapsed times are recorded.
27. The final timing summary is recorded.
28. Environmental validation limitations are documented.

---

## 30. Final Implementation Report

When Sprint 2 is complete, return a concise report containing:

1. What was implemented
2. Major domain/business rules implemented
3. Database migrations added
4. API endpoints added
5. Flutter screens/features added
6. Tests added
7. Final backend test result
8. Flutter analysis/test result
9. Flutter Web build result
10. Browser smoke-test result
11. Docker validation result
12. Architecture decisions made
13. Documentation files updated
14. Environment/tooling limitations
15. Total sprint wall-clock elapsed time
16. Per-task elapsed times
17. Reference to `SPRINT2_IMPLEMENTATION_PLAN.md`
18. Anything intentionally deferred to Sprint 3

Do not continue into Sprint 3 unless explicitly requested.
