# Transport Management System

A production-oriented internal road-freight Transport Management System. Sprint 1 established authentication and tenant isolation, Sprint 2 added operational management, and Sprint 3 adds English/Arabic localization, RTL support, simulated fleet tracking, a MapLibre-ready fleet map, and an operational dashboard.

## Architecture

The backend is a modular monolith using Clean Architecture with lightweight DDD and CQRS principles:

- **Domain** contains entities and business invariants with no infrastructure dependency.
- **Application** contains use cases, DTOs, and narrow ports for external concerns.
- **Infrastructure** owns EF Core/PostgreSQL, JWT generation, password hashing, tenant context, and persistence implementations.
- **API** contains only HTTP concerns and thin controllers.
- **Flutter** is feature-first, with Riverpod as its single state-management solution.

Tracking is accessed through the application-owned `ITrackingProvider`; the
Development simulator is an Infrastructure adapter and can later be replaced by
a real telematics adapter without coupling Domain entities to a vendor.

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

Sprint 3 is represented by `20260917073102_Sprint3LocalizationTracking`. It
adds the persisted user locale and tenant-owned truck-position history with
coordinate precision and tenant/latest-position indexes.

## Run Flutter Web

```bash
cd apps/transport_management_app
flutter pub get
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://demotiles.maplibre.org/style.json \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=5
```

Port `3000` matches the development CORS configuration. If you use another
Web port, add that exact origin to `Cors__AllowedOrigins`.

Open **Settings → Language** to select English or العربية. The preference is
validated and stored on the server, follows the user between devices, and
updates the entire app between LTR and RTL. MapLibre is the rendering layer;
`MAP_STYLE_URL` selects the style/tile provider. If it is omitted or tiles are
unavailable, the dashboard keeps its deterministic local map surface, markers,
details, and tracking controls so operations are not hidden by a tile outage.

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

For the complete Sprint 3 workflow, use:

```text
--target=integration_test/sprint3_smoke_test.dart
```

It logs in, normalizes any preference left by an interrupted local run, creates
a unique truck, switches to Arabic and verifies RTL, opens the dashboard, starts
the simulator, selects a truck marker and verifies its truck/driver/trip details,
pauses the simulator, switches back to English/LTR, and logs out. The test does
not require real GPS hardware or external map tiles.

### Tracking simulator and dashboard

The simulator is available only when the API environment is Development (or
Testing), `Tracking__Provider=Simulator`, and
`Tracking__SimulatorEnabled=true`. An Owner can Start, Pause, Resume, Stop, and
Reset it from the dashboard. Each dashboard poll advances a deterministic route
while running and persists a UTC position sample. Stop marks trucks offline;
samples older than `Tracking__OfflineThresholdSeconds` are also presented as
offline. Do not enable this provider in Production.

The dashboard uses one tenant-scoped endpoint for fleet status totals, active
and completed-today trip totals, online/offline tracking totals, current
positions, and recent trips. Flutter has one centralized polling controller;
pull-to-refresh remains available.

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
| `Tracking__Provider` | API | `Simulator` in local Development; unconfigured by default elsewhere |
| `Tracking__SimulatorEnabled` | API | Explicit Development simulator gate |
| `Tracking__PollingIntervalSeconds` | API/Compose | Documented polling default for clients |
| `Tracking__OfflineThresholdSeconds` | API | Age after which the latest sample is reported offline |
| `MAP_STYLE_URL` (`--dart-define`) | Flutter | Optional MapLibre style URL; blank uses the resilient local surface |
| `TRACKING_POLLING_INTERVAL_SECONDS` (`--dart-define`) | Flutter | Dashboard refresh interval, default 5 seconds |

Never commit `.env`, signing keys, database passwords, or production credentials. The committed values are non-secret placeholders.

## API endpoints

- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `PUT /api/auth/me/preferences` — persist `en` or `ar`
- `GET /api/companies/me`
- `GET /api/companies/{id}` (tenant-filtered; used to prove ID-tampering resistance)
- `/api/clients` — list/get/create/update, plus `POST /{id}/deactivate`
- `/api/trucks` — list/get/create/update, status update, and deactivate
- `/api/drivers` — list/get/create/update, status update, and deactivate
- `/api/trips` — list/get/create/update Draft, assign, start, mark in transit, deliver, complete, and cancel
- `GET /api/dashboard` — tenant-scoped operational summary, positions, and recent trips
- `GET /api/tracking/positions`
- `GET /api/tracking/trucks/{id}/position`
- `GET /api/tracking/trucks/{id}/history?limit=50`
- `POST /api/tracking/simulator/control` — Development simulator, Owner only
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
- `/settings` — persisted English/Arabic language selection

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
SPRINT3_IMPLEMENTATION_PLAN.md
```

## Key engineering decisions

- GUID identifiers and UTC `DateTimeOffset` timestamps.
- Short-lived access tokens (15 minutes); random 512-bit refresh tokens stored only as SHA-256 hashes and rotated on use.
- BCrypt work factor 12 for passwords.
- Policy names provide a seam for later permission-based authorization while roles remain simple today.
- `ProblemDetails` is the common error shape, including a trace ID.
- Important domain failures also expose a stable `errorCode`; Flutter maps known codes to localized text and never translates raw server exceptions.
- Serilog produces structured console logs suitable for later shipping to an external platform.
- Access tokens remain in Flutter memory. Refresh tokens use `flutter_secure_storage` (Android Keystore and the plugin's WebCrypto-backed web implementation). A production web threat-model review may move refresh tokens to same-site HTTP-only cookies.
- EF Core is already the unit-of-work/query abstraction; no generic repository layer is added.
- Trips use explicit domain transitions: `Draft → Assigned → Started → InTransit → Delivered → Completed`, with cancellation only before delivery.
- `Assigned`, `Started`, `InTransit`, and `Delivered` reserve resources. Application checks return useful conflicts, while PostgreSQL partial unique indexes prevent concurrent double assignment.
- Standard generated Flutter ARB localizations own visible English/Arabic text; directional layout APIs allow Material to mirror the shell, forms, and dialogs.
- MapLibre is the vendor-neutral rendering layer. Style/tile hosting is externally configurable and is not a backend/domain concern.
- Polling is intentionally used before SignalR: current fleet scale does not justify persistent real-time connections, and the provider/dashboard contracts preserve a future upgrade path.

## Authorization matrix

| Role | Read Clients/Fleet/Trips | Manage Clients/Fleet/Trips |
|---|---:|---:|
| Owner | Yes | Yes |
| Operations | Yes | Yes |
| Accountant | Yes | No |
| Employee | No | No |

Named policies remain the extension point for future granular permissions.

Owner alone can control the Development simulator. Owner, Operations, and
Accountant can read the operational dashboard and tenant-scoped tracking data;
Employee cannot.

## Sprint boundary

Known Sprint 3 limitations: the simulator is process-local and development-only;
polling is used instead of push; map style/tile availability belongs to the
configured provider; stored position history is intentionally simple and has no
retention/partitioning pipeline yet. Android execution requires a local Android
SDK and emulator/device.

Deferred to later sprints: finance, expenses, payments, profitability, advanced maintenance, documents, reporting, real GPS providers, granular permissions, advanced dashboard analytics, route optimization, AI features, and a driver application.
