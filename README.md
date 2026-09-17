# Transport Management System

A production-oriented foundation for an internal road-freight Transport Management System. Sprint 1 establishes authentication, company isolation, the backend architecture, responsive Flutter shell, local infrastructure, and automated tests. Operational modules such as trips, fleet, finance, maintenance, documents, and GPS are intentionally not implemented yet.

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

The backend tests cover login, current-user lookup, token refresh/rotation, reuse rejection, logout, standardized authentication failures, and an ID-tampering test proving a Company A user cannot retrieve Company B.

### Live Flutter Web smoke test

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

The smoke test signs in through the real API, verifies the dashboard, signs
out, and verifies that routing returns to the login screen. Credentials are
provided at runtime and are not stored in source control.

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
- `GET /health`

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

## Sprint boundary

Deferred to later sprints: trips, trucks, drivers, fleet, finance, maintenance, documents, reporting, GPS providers, granular permissions, full dashboard metrics, and a driver application.
