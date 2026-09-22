# Sprint 1 Prompt — Transport Management System Foundation

You are acting as a **Senior Software Architect** and **Senior Full-Stack Engineer**.

I want you to begin implementing a real, production-ready **Transport Management System** for road freight and trucking companies.

Do **not** attempt to build the entire system in this sprint.

This is **Sprint 1**, and its goal is to establish the project foundation, architecture, authentication, tenancy model, database, frontend shell, testing setup, and development infrastructure before implementing operational business features.

---

## 1. Project Overview

The system is an **Internal Transport Management System** intended initially for small and medium-sized trucking companies.

The first expected customer is a company with approximately **7 trucks** that is contracted by factories and other companies to transport goods.

This system is **not a marketplace**.

There is currently no customer-facing portal where external customers request trucks or book trips.

The transport company's own employees manage operations internally.

In the future, the product should evolve into a **multi-tenant SaaS platform** serving multiple transport companies.

Therefore, the architecture must be designed from the beginning to support multi-tenancy.

Each company's data must be completely isolated from every other company's data.

---

# 2. Required Technology Stack

## Backend

Use:

- C#
- .NET 10 LTS
- ASP.NET Core Web API
- Entity Framework Core 10
- PostgreSQL

## Frontend

Use:

- Flutter latest stable version
- One Flutter codebase targeting:
  - Android
  - Web

## Infrastructure

Use:

- Docker
- Docker Compose for local development
- PostgreSQL running in a container

## API

Use:

- REST API
- OpenAPI / Swagger

## Authentication

Use:

- JWT Access Token
- Refresh Token
- Role-Based Authorization

---

# 3. Architecture

Use a:

**Modular Monolith**

combined with:

- Clean Architecture
- DDD-lite
- CQRS-lite

Do **not** use Microservices.

Do **not** use Event Sourcing.

Avoid unnecessary complexity and overengineering.

The architecture should be simple enough for a small product today, but structured enough to support future growth.

---

# 4. Backend Modules

Prepare the overall project structure so it can eventually support modules such as:

- Identity
- Companies
- Clients
- Fleet
- Trips
- Finance
- Maintenance
- Documents
- Reporting

In Sprint 1, do **not** implement all business features for these modules.

The goal is to establish an architecture that allows these modules to be added later without requiring a major rewrite.

---

# 5. Multi-Tenancy

This is a critical requirement.

Future business entities such as:

- Truck
- Driver
- Client
- Trip
- Expense
- Payment

must belong to a specific company through a field such as:

`CompanyId` or `TenantId`

Each user must belong to exactly one company.

A user from **Company A** must never be able to access data belonging to **Company B**, even if they manually modify IDs in API requests.

Tenant isolation should be implemented centrally where possible.

Do not rely on manually repeating `CompanyId` checks throughout random controllers.

You may use:

- EF Core Global Query Filters
- Tenant-aware DbContext mechanisms
- A better centralized design if justified

Document the architectural decision you choose.

The frontend must **not** be trusted to provide the current `CompanyId`.

The backend must determine the current tenant from the authenticated user/session/token.

---

# 6. Initial Domain Entities

For Sprint 1, implement only the core entities required for the foundation:

## Company

Suggested initial fields:

- Id
- Name
- Slug
- IsActive
- CreatedAt
- UpdatedAt

## User

The User entity must belong to a Company.

## RefreshToken

Implement a secure refresh token model.

You may add additional entities or Value Objects if they are genuinely required for authentication, tenancy, or architecture.

Do not begin implementing Trips, Trucks, Finance, or other operational modules yet.

---

# 7. Roles

Prepare the system for the following initial roles:

- Owner
- Operations
- Accountant
- Employee

A Driver user account is **not required yet**.

Design authorization in a way that allows us to move later from simple Role-Based Authorization to more granular Permissions without rewriting the entire authorization layer.

---

# 8. Authentication Flow

Implement:

- Login
- Refresh Token
- Logout
- Get Current User

The access token should have a relatively short lifetime.

Refresh tokens must be stored securely.

Use appropriate JWT claims such as:

- UserId
- CompanyId
- Role

or another clean equivalent.

Do not trust a `CompanyId` submitted by the frontend to determine tenancy.

Tenant identity must come from the authenticated user.

---

# 9. API Structure

Create clear REST endpoints.

A possible starting structure is:

```text
/api/auth/login
/api/auth/refresh
/api/auth/logout
/api/auth/me

/api/companies/me
```

You may improve the API structure if you have a stronger design.

Use DTOs.

Do not return EF Core entities directly from controllers.

Use request validation.

Use a consistent API error format.

Prefer ASP.NET Core `ProblemDetails` or an equivalent standardized structure.

Controllers should remain thin.

Business logic must not live inside controllers.

---

# 10. Database

Use PostgreSQL.

Use Entity Framework Core migrations.

Create an initial migration.

Support an easy local development setup.

Do not create unsafe automatic production migration behavior.

Add development seed data containing:

- One demo company
- One Owner user

Do not commit real passwords or secrets into the repository.

Use a secure development configuration or documented initialization approach.

---

# 11. Backend Project Structure

Create a clear and maintainable solution structure.

A conceptual example is:

```text
src/
  Api/
  Application/
  Domain/
  Infrastructure/
  Modules/
```

This exact structure is not mandatory.

You may choose a better modular structure if appropriate.

However, the following principles are mandatory:

- Domain must not depend on Infrastructure
- Business logic must not live in Controllers
- Controllers must be thin
- Persistence concerns must not leak into Domain logic
- Infrastructure details must remain replaceable where practical

Briefly document why you selected the final structure.

---

# 12. Flutter Application

Create one Flutter application supporting:

- Web
- Android

Use responsive design from the beginning.

Sprint 1 does not require a complete production UI.

Implement only:

- Login Screen
- Application Shell
- Responsive Navigation
- Dashboard Placeholder
- Logout
- Authentication State Management

Use a maintainable routing structure.

Use secure token storage appropriate to each platform.

For Android, use a secure storage solution suitable for tokens.

For Web, handle authentication carefully and do not rely on an obviously insecure storage approach solely for convenience.

---

# 13. Flutter Architecture

Do not put the entire app inside a single `screens/` directory.

Use a scalable structure such as:

```text
core/
features/
shared/
```

or another clean Feature-First architecture.

Separate concerns such as:

- API Client
- Authentication
- Models
- Repositories
- State
- UI

Choose exactly one primary state management solution.

You may use something such as:

- Riverpod
- Bloc

Choose one and briefly document why.

Do not introduce multiple competing state management patterns.

---

# 14. Flutter API Client

Create a centralized API client.

It must support:

- Configurable Base URL
- JWT Authorization Header
- Refresh Token Flow
- Handling HTTP 401
- Common Error Handling

Networking logic must not be duplicated throughout screens or widgets.

---

# 15. Configuration

Use environment-specific configuration.

The application should support at least:

- Development
- Production

without manually editing source code every time.

Do not place the following inside source code:

- Database passwords
- JWT signing secrets
- Production credentials
- Other secrets

Provide an example configuration file such as:

`.env.example`

or the appropriate equivalent for the chosen technologies.

---

# 16. Docker

Create a development Docker setup.

Docker Compose should run at minimum:

- PostgreSQL
- ASP.NET Core Backend

Flutter may run separately during development.

Create an appropriate Dockerfile for the backend.

Add a backend Health Check endpoint.

---

# 17. Logging

Use structured logging.

Prepare the logging architecture so it can later be connected to an external monitoring platform.

Do not add a complex monitoring stack in Sprint 1.

---

# 18. Testing

Create testing projects from the beginning.

Implement at least basic tests for:

- Authentication
- Tenant Isolation

Create an important integration test proving that:

A user belonging to **Company A** cannot access a resource belonging to **Company B**.

If an appropriate business resource does not exist yet, create a minimal company-owned test resource or use another clean integration testing strategy to prove tenant isolation.

Do not leave tenant isolation as an assumption.

It must be tested.

---

# 19. Future GPS Integration

Do **not** implement GPS tracking in Sprint 1.

However, do not design future Truck functionality in a way that is tightly coupled to one GPS vendor.

In the future, we may use an abstraction such as:

```csharp
ITrackingProvider
```

with implementations such as:

```text
TraccarTrackingProvider
WialonTrackingProvider
OtherTrackingProvider
```

Do not implement these providers now.

Only ensure the architecture does not prevent this extension later.

---

# 20. Engineering Rules

Follow these rules:

- Write clean and maintainable code
- Avoid overengineering
- Do not create interfaces for every class without a real reason
- Do not automatically add a Repository Pattern on top of EF Core unless it solves a real architectural problem
- Use Dependency Injection appropriately
- Use `async/await` for I/O operations
- Use `CancellationToken` where appropriate
- Enable Nullable Reference Types
- Use UTC timestamps in the backend
- Prefer `Guid` / UUID identifiers unless there is a strong reason not to
- Use `CreatedAt` and `UpdatedAt` where appropriate
- Avoid magic strings for roles, states, or other critical values where possible
- Keep the codebase compilable throughout implementation

---

# 21. Documentation

Create a root `README.md` containing:

- Project overview
- Architecture overview
- Prerequisites
- How to start PostgreSQL
- How to run the backend
- How to run Flutter Web
- How to run Flutter Android
- How to run migrations
- How to create or access development credentials
- Required environment variables
- Main project structure
- Important architectural decisions

The project should be understandable by another engineer opening the repository for the first time.

---

# 22. Definition of Done

Sprint 1 is considered complete when I can successfully:

1. Start PostgreSQL
2. Start the backend
3. Open Swagger
4. Log in using the development user
5. Receive a JWT access token
6. Refresh the access token
7. Open Flutter Web
8. Log in successfully
9. Reach the Dashboard Placeholder
10. Run Flutter Android and complete the same login flow
11. Log out
12. Run all automated tests successfully
13. Confirm through automated testing that tenant isolation works correctly

---

# 23. Implementation Instructions

If the repository is empty:

- Create the complete project structure from scratch.

If the repository already contains files:

- Inspect the existing repository first.
- Preserve important existing work.
- Do not delete or overwrite unrelated files without a clear reason.

Implement the project for real.

Do not respond only with code snippets, pseudo-code, or architectural examples.

Create the files and working implementation.

After each major implementation stage:

- Run the build
- Run relevant tests
- Fix errors before continuing

Do not leave the repository in a non-compiling state.

Do not implement the operational business modules yet, including:

- Trips
- Fleet management
- Finance
- GPS tracking
- Full Dashboard
- Driver Application

Focus only on establishing a strong project foundation.

---

# 24. Final Report

When Sprint 1 is complete, provide a concise implementation report containing:

1. What was implemented
2. The final architecture used
3. The main project/file structure
4. How to run the system
5. Important engineering decisions made
6. Tests implemented and their results
7. Anything intentionally deferred to Sprint 2

Do not continue into Sprint 2 unless explicitly requested.
