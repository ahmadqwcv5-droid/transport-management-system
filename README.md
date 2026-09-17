# Transport Management System

A production-oriented internal road-freight Transport Management System. Sprint 1 established authentication and tenant isolation; Sprint 2 adds operational management for clients, trucks, drivers, and trips in the ASP.NET Core API and the responsive Flutter Web/Android application.

## Architecture

The backend is a modular monolith using Clean Architecture with lightweight DDD and CQRS principles:

- **Domain** contains entities and business invariants with no infrastructure dependency.
- **Application** contains use cases, DTOs, and narrow ports for external concerns.
- **Infrastructure** owns EF Core/PostgreSQL, JWT generation, password hashing, tenant context, and persistence implementations.
- **API** contains only HTTP concerns and thin controllers.
- **Flutter** is feature-first, with Riverpod as its single state-management solution.

Every tenant-owned entity implements `ITenantOwned`. `AppDbContext` applies a global company filter, reading the company exclusively from a signed JWT claim through `ICurrentUser`. The client never selects or submits the active company. Login and refresh are the only narrowly scoped persistence operations that bypass filters because no authenticated tenant exists yet. See [docs/architecture.md](docs/architecture.md).

## Prerequisites

- Docker Engine with Docker Compose, or PostgreSQL 18+
- .NET 10 SDK
- Flutter stable with Android and/or Chrome tooling

## Quick start with Docker

```bash
cp .env.example .env
# Replace every placeholder in .env with local random values.
docker compose up --build
```

The development-only API startup applies committed migrations and creates the configured demo company/owner. Production startup never migrates or seeds automatically.

- API: `http://localhost:5080`
- OpenAPI document: `http://localhost:5080/openapi/v1.json`
- Scalar API UI: `http://localhost:5080/scalar/v1`
- Health: `http://localhost:5080/health`

The development login email is `owner@demo.local`; its password is the value of `DEMO_OWNER_PASSWORD` in your uncommitted `.env` file.

Stop services without deleting data:

```bash
docker compose down
```

## Run PostgreSQL and backend separately

Start PostgreSQL:

```bash
cp .env.example .env
docker compose up -d postgres
```

Set configuration using environment variables (double underscores map to nested .NET keys):

```bash
export ConnectionStrings__Database='Host=localhost;Port=5432;Database=transport_management;Username=transport_app;Password=YOUR_LOCAL_PASSWORD'
export Jwt__SigningKey='YOUR_RANDOM_SECRET_AT_LEAST_32_BYTES_LONG'
export DevelopmentSeed__Enabled=true
export DevelopmentSeed__OwnerPassword='YOUR_DEVELOPMENT_PASSWORD'
dotnet run --project src/TransportManagement.Api
```

## Database migrations

Restore the repository-pinned EF tool:

```bash
dotnet tool restore
```

Apply committed migrations:

```bash
dotnet tool run dotnet-ef database update \
  --project src/TransportManagement.Infrastructure \
  --startup-project src/TransportManagement.Api
```

Create a future migration:

```bash
dotnet tool run dotnet-ef migrations add DescriptiveName \
  --project src/TransportManagement.Infrastructure \
  --startup-project src/TransportManagement.Api \
  --output-dir Persistence/Migrations
```

Production migrations are an explicit deployment step. The application never applies them automatically outside Development.

Sprint 2 is represented by the committed
`20260917030406_Sprint2OperationalCore` migration. It creates tenant-owned
client, truck, driver, and trip tables, tenant-scoped uniqueness constraints,
and active-trip resource reservation indexes.

## Run Flutter Web

```bash
cd apps/transport_management_app
flutter pub get
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080
```

Port `3000` matches the development CORS configuration. If you use another
Web port, add that exact origin to `Cors__AllowedOrigins`.

## Run Flutter Android

With an emulator/device available:

```bash
cd apps/transport_management_app
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

`10.0.2.2` is the Android emulator alias for the host. Use the workstation's LAN address for a physical device. Development Android permits cleartext traffic only for local HTTP development; production should use HTTPS.

## Tests and static analysis

```bash
dotnet test TransportManagement.slnx
cd apps/transport_management_app
flutter analyze
flutter test
```

The backend tests cover authentication and refresh-token rotation plus operational CRUD, tenant-scoped plate/license uniqueness, cross-company ID tampering, valid and invalid trip transitions, cancellation, resource synchronization, and truck/driver double-booking prevention.

### Live Flutter Web smoke tests

With PostgreSQL and the API running, start GeckoDriver in one terminal:

```bash
geckodriver --port 4444
```

Then run the browser test from `apps/transport_management_app`:

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_smoke_test.dart \
  -d web-server \
  --browser-name=firefox \
  --driver-port=4444 \
  --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=E2E_EMAIL=owner@demo.local \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD
```

The authentication test signs in through the real API, verifies the dashboard,
signs out, and verifies the login redirect. For the complete Sprint 2 workflow,
change the target to:

```text
--target=integration_test/sprint2_smoke_test.dart
```

That test creates a client, truck, driver, and trip, assigns the resources,
advances the trip through `Completed`, logs out, and verifies the login redirect.
It uses unique runtime values, so it is safe to rerun against a local development
database. Credentials are runtime-only and are not stored in source control.

## Configuration

| Variable | Required | Purpose |
|---|---:|---|
| `ConnectionStrings__Database` | Yes | PostgreSQL connection string |
| `Jwt__SigningKey` | Yes | Minimum 32-byte JWT HMAC secret |
| `Jwt__Issuer` / `Jwt__Audience` | Production | Token issuer and audience |
| `DevelopmentSeed__Enabled` | Development only | Enables migration and demo seed |
| `DevelopmentSeed__OwnerPassword` | When seed is enabled | Demo owner password, minimum 12 characters |
| `Cors__AllowedOrigins__0` | Web deployments | First allowed Flutter web origin |
| `API_BASE_URL` (`--dart-define`) | Flutter | Backend base URL |

Never commit `.env`, signing keys, database passwords, or production credentials. The committed values are non-secret placeholders.

## API endpoints

- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `GET /api/companies/me`
- `GET /api/companies/{id}` (tenant-filtered; used to prove ID-tampering resistance)
- `/api/clients` — list/get/create/update, plus `POST /{id}/deactivate`
- `/api/trucks` — list/get/create/update, status update, and deactivate
- `/api/drivers` — list/get/create/update, status update, and deactivate
- `/api/trips` — list/get/create/update Draft, assign, start, mark in transit, deliver, complete, and cancel
- `GET /health`

List endpoints support the Sprint 2 filters documented in OpenAPI. Enum values
are serialized as readable strings. All operational endpoints require the named
`operations.read` or `operations.manage` policy.

## Flutter routes

- `/dashboard` — authenticated landing screen
- `/clients` — searchable client list and create/edit/deactivate flow
- `/trucks` — truck list, details, create/edit, status, and deactivate flow
- `/drivers` — driver list, details, create/edit, status, and deactivate flow
- `/trips` — trip list and Draft creation
- `/trips/:id` — details, Draft edit, resource assignment, and allowed status actions

## Project structure

```text
src/
  TransportManagement.Domain/          entities and invariants
  TransportManagement.Application/     use cases, DTOs, abstractions
  TransportManagement.Infrastructure/  EF Core, PostgreSQL, auth, tenancy
  TransportManagement.Api/             REST host and controllers
tests/
  TransportManagement.IntegrationTests/
apps/
  transport_management_app/            Flutter Web + Android client
docs/
  architecture.md
compose.yaml
Dockerfile
SPRINT1_IMPLEMENTATION_PLAN.md
SPRINT2_IMPLEMENTATION_PLAN.md
```

## Key engineering decisions

- GUID identifiers and UTC `DateTimeOffset` timestamps.
- Short-lived access tokens (15 minutes); random 512-bit refresh tokens stored only as SHA-256 hashes and rotated on use.
- BCrypt work factor 12 for passwords.
- Policy names provide a seam for later permission-based authorization while roles remain simple today.
- `ProblemDetails` is the common error shape, including a trace ID.
- Serilog produces structured console logs suitable for later shipping to an external platform.
- Access tokens remain in Flutter memory. Refresh tokens use `flutter_secure_storage` (Android Keystore and the plugin's WebCrypto-backed web implementation). A production web threat-model review may move refresh tokens to same-site HTTP-only cookies.
- EF Core is already the unit-of-work/query abstraction; no generic repository layer is added.
- Trips use explicit domain transitions: `Draft → Assigned → Started → InTransit → Delivered → Completed`, with cancellation only before delivery.
- `Assigned`, `Started`, `InTransit`, and `Delivered` reserve resources. Application checks return useful conflicts, while PostgreSQL partial unique indexes prevent concurrent double assignment.

## Authorization matrix

| Role | Read Clients/Fleet/Trips | Manage Clients/Fleet/Trips |
|---|---:|---:|
| Owner | Yes | Yes |
| Operations | Yes | Yes |
| Accountant | Yes | No |
| Employee | No | No |

Named policies remain the extension point for future granular permissions.

## Sprint boundary

Deferred to later sprints: finance, expenses, payments, profitability, advanced maintenance, documents, reporting, GPS providers, granular permissions, full dashboard analytics, route optimization, AI features, and a driver application.
