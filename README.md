# Transport Management System

A production-oriented internal road-freight Transport Management System. Sprint
3.2 adds structured pickup/delivery locations, stored road-route snapshots,
geometry-based progress and ETA, and route-aware simulation. Sprint 3.2.1 adds
a road-detailed development basemap, real directional truck artwork, stable
incremental map annotations, explicit camera modes, and selected-route /
travelled-trail fleet visualization to the earlier authentication, operations,
localization, and tracking foundation.

Sprint 3.2.2 makes persisted telemetry trip/route/run-aware, returns bounded
chronological trail segments, prevents cross-trip/reset connectors, and keeps
the simulator multiplier separate from displayed physical speed.

Sprint 3.3 prevents assignment-time position teleportation and introduces an
explicit `Assigned -> EnRouteToPickup -> AtPickup -> Started` workflow. Empty
repositioning geometry, metrics, progress, and telemetry remain independent
from the immutable commercial cargo route.

Sprint 3.3.1 makes that workflow usable without API or database tooling. The
Development simulator lists every active truck, offers a map/search/manual
location picker for the first coordinate, distinguishes Set/Move/Refresh, and
keeps stationary online simulator positions fresh with bounded heartbeats.

## Architecture

The backend is a modular monolith using Clean Architecture with lightweight DDD and CQRS principles:

- **Domain** contains entities and business invariants with no infrastructure dependency.
- **Application** contains use cases, DTOs, and narrow ports for external concerns.
- **Infrastructure** owns EF Core/PostgreSQL, JWT generation, password hashing, tenant context, and persistence implementations.
- **API** contains only HTTP concerns and thin controllers.
- **Flutter** is feature-first, with Riverpod as its single state-management solution.

Tracking, routing, and geocoding are accessed through separate application-owned
ports. Infrastructure adapters can be replaced independently without coupling
Domain entities or Flutter to OSRM, a geocoder, or a telematics vendor.

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

Sprint 3.2 is represented by `20260917182358_Sprint32RouteAwareTrips`. It adds
tenant-owned ordered stops and immutable route-plan snapshots. Existing trips
are backfilled with label-only pickup/delivery stops; coordinates remain null
and the migration does not invent historical locations.

Sprint 3.2.2 is represented by `20260918110252_Sprint322TripAwareTracking`.
It adds nullable trip/route-plan/run context to positions plus a tenant/trip/time
index. Existing rows remain unchanged with null context and are never guessed
into a historical trip.

Sprint 3.3 is represented by `20260921083330_Sprint33DispatchToPickup`. It adds
tenant-owned immutable repositioning snapshots and nullable movement-phase /
repositioning-plan context to telemetry. Existing trip, route, and position rows
remain unchanged; reservation indexes are extended for the new active states.

## Run Flutter Web

```bash
cd apps/transport_management_app
flutter pub get
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=5 \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=12 \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true
```

`MAP_STYLE_URL` and the other Flutter values above are compile-time
`--dart-define` values. OpenFreeMap Liberty provides the road and place detail
needed during development and retains OpenStreetMap/OpenFreeMap attribution.
It is external development infrastructure, not a production hosting guarantee
or SLA. Production must explicitly configure an appropriate style provider:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=MAP_STYLE_URL=https://your-provider.example/style.json \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=5 \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=12
```

To intentionally exercise the tile-independent fallback path, omit
`MAP_STYLE_URL`, launch the app, and choose **Use simplified fallback** from the
localized **Map not configured** state:

```bash
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=5 \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true
```

Port `3000` matches the development CORS configuration. If you use another
Web port, add that exact origin to `Cors__AllowedOrigins`.

Open **Settings → Language** to select English or العربية. The preference is
validated and stored on the server, follows the user between devices, and
updates the entire app between LTR and RTL. MapLibre is the rendering layer;
`MAP_STYLE_URL` selects the replaceable style/tile provider. A missing value is
shown as an intentional unconfigured state. A configured map remains loading
until MapLibre's genuine style-loaded callback fires. If it does not fire before
`MAP_LOADING_TIMEOUT_SECONDS`, the map shows a localized failure with **Retry
map** and **Use simplified fallback**. Retry creates a new MapLibre attempt.
Fallback remains clearly labeled as a simplified, non-geographic tracking view
and retains truck details.

The style callback proves that MapLibre accepted and loaded the style; it does
not prove that every geographic tile visibly rendered. Visual tile evidence is
therefore recorded separately from automated style-readiness assertions.
Docker Compose in this repository serves PostgreSQL and the API only—it does
not serve or inject runtime configuration into Flutter Web.

The basemap and route engine are independent: changing `MAP_STYLE_URL` changes
only rendered map context. It does not change OSRM route calculation or stored
route geometry. The map keeps MapLibre's attribution control visible; follow
the selected production style/data provider's attribution requirements.

### Route planning

Choose **Trips → New trip** to open the responsive planner. Select pickup and
delivery through a configured backend geocoder, click the map, or enter valid
coordinates manually. **Calculate route** calls the backend routing adapter and
shows the stored road geometry, distance, and duration; save stays disabled
until a valid preview exists. The default Development OSRM demo uses a general
driving profile only—no truck restrictions, live traffic, SLA, or production
capacity are implied. Leave geocoding disabled for manual/map selection, or
configure a policy-compliant managed service; the public Nominatim service must
not be used for client-side autocomplete.

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

For the complete Sprint 3.2 route workflow and five screenshots, run:

```bash
flutter drive \
  --driver=test_driver/integration_test_sprint3_2.dart \
  --target=integration_test/sprint3_2_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=30 \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD
```

Evidence is retained under `docs/evidence/sprint3_2_1/`. The workflow selects
locations, previews a real road route, saves/assigns/starts the trip, observes
ten live polling cycles, verifies the image marker and stable progress/trail/
stop overlays, checks manual pan plus explicit route fitting, and captures
Arabic RTL. Deterministic operation counts in the same directory prove that
ordinary polling performs no global annotation clears or camera moves.

For the Sprint 3.2.2 two-trip/reset/`10x` correctness workflow, use:

```bash
flutter drive \
  --driver=test_driver/integration_test_sprint3_2_2.dart \
  --target=integration_test/sprint3_2_2_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=30 \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=1 \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true \
  --dart-define=E2E_EMAIL=owner@sprint322.local \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD
```

It creates isolated runtime data, runs two trips on the same truck, validates
trip-scoped history and reset segments through the live API, verifies physical
speed at `10x`, observes ten polling cycles after manual pan, and captures
English/Arabic evidence under `docs/evidence/sprint3_2_2/`. Provision the named
owner in a dedicated local smoke tenant first, or replace `E2E_EMAIL` with a
different dedicated local owner. The password is supplied only at runtime.

For the Sprint 3.3 assignment/repositioning/restart workflow, use a dedicated
local development database and run:

```bash
flutter drive \
  --driver=test_driver/integration_test_sprint3_3.dart \
  --target=integration_test/sprint3_3_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=30 \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=1 \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true \
  --dart-define=E2E_EMAIL=owner@demo.local \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD
```

The driver pauses mid-approach and allows 45 seconds for an API-only restart.
When it prints the restart prompt, run this from the repository root:

```bash
docker-compose -p tms-smoke restart api
```

Do not restart PostgreSQL or remove its volume. The workflow proves no movement
on assignment, distant-start rejection, separate approach/cargo routes and
progress, exact geographic arrival, explicit cargo start, restart restoration,
physical speed at `10x`, manual-pan stability, and English/Arabic real-map
rendering. Evidence is written to `docs/evidence/sprint3_3/`.

For the complete Sprint 3 workflow, use:

```text
--target=integration_test/sprint3_smoke_test.dart
```

This is specifically the fallback workflow. It logs in, creates a truck,
verifies Arabic/RTL and English/LTR, explicitly selects fallback, checks fallback
markers/details, exercises every simulator command, and logs out. It does not
claim to verify MapLibre. Run the separate real-map and failure paths with the
commands below (the public development style has no production SLA):

```bash
# Real MapLibre style/callback/annotation path, with screenshot evidence.
flutter drive \
  --driver=test_driver/integration_test_screenshot.dart \
  --target=integration_test/maplibre_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=25 \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD

# Invalid style: timeout, genuine retry, then explicit fallback.
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/map_failure_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=http://127.0.0.1:9/missing-style.json \
  --dart-define=MAP_LOADING_TIMEOUT_SECONDS=2 \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD
```

### Tracking simulator and dashboard

The simulator is available only when the API environment is Development (or
Testing), `Tracking__Provider=Simulator`, and
`Tracking__SimulatorEnabled=true`. Flutter additionally requires the explicit
compile-time `ENABLE_SIMULATOR_CONTROLS=true` development flag; production builds
should omit it. An Owner can select every active truck, including one with no
tracking history. **Set simulated location** creates its first explicit
coordinate; **Move simulated truck** confirms a different coordinate;
**Refresh location** records the same coordinate without route/trip association
or movement; and **Online/Offline** explicitly controls device state. The
shared picker accepts a MapLibre click, configured geocoding result, or validated
manual latitude/longitude. Manual input remains available if map styling or
geocoding is unavailable. Existing Start, Pause, Resume, Stop, Reset, Step, and
speed controls remain available. Pause freezes movement but retains the online
GPS heartbeat. Stop marks trucks offline;
samples older than `Tracking__OfflineThresholdSeconds` are also presented as
offline. Do not enable this provider in Production.

Stationary simulator samples are generated centrally by the backend provider,
not by a Flutter coordinate timer. `Tracking__SimulatorHeartbeatSeconds`
defaults to 15 seconds and is clamped below both the offline threshold and
`Dispatch__MaximumPositionAgeSeconds`. It therefore produces at most 240 idle
rows per truck per hour at the default while sampled, rather than one row per
dashboard poll. It preserves coordinate, heading, movement phase, tracking run,
and route progress. Freshness validation remains enabled: genuine non-simulator
or explicitly offline/stopped data can still produce `TRUCK_POSITION_STALE` or
`TRUCK_OFFLINE`. Real GPS ingestion will eventually call this backend boundary
independently; the current Development simulator is sampled by dashboard/API
polling.

Reading current positions no longer inserts a duplicate row merely because the
dashboard polled. History is appended when coordinates, online state, source,
speed (0.5 km/h tolerance), or heading (1 degree tolerance) changes, or when the
`Tracking__HistoryHeartbeatSeconds` heartbeat elapses. Latest/history queries
remain tenant-filtered. Long-term retention and partitioning remain deferred.

New writes correlate provider telemetry with the active trip and immutable route
plan in `TrackingService`. Selected-trip trails use the bounded
`/api/tracking/trips/{tripId}/history` endpoint, which returns oldest-to-newest
segments. A run/route change, reset, excessive time gap, or Haversine-distance
jump starts a new segment. Unassigned and legacy null-trip rows may still supply
the latest fleet location, but never appear in a selected trip trail.

Movement is a function of route geometry, elapsed simulator time, and configured
speed. Polling current positions is observational and cannot move a truck.
Pause freezes distance, Step advances a configured distance, Reset returns to
pickup, and arrival clamps exactly to delivery with zero speed. Progress is
calculated by projecting the latest sample onto the stored route; stopped trucks
show no misleading ETA.

The multiplier accelerates simulated elapsed time and route progress only. A
truck configured at `65 km/h` therefore reports `65 km/h` at both `1x` and
`10x`; at `10x` it covers approximately ten times the distance per wall-clock
interval. Reset creates a new run boundary. Product ETA is operational
real-world ETA based on remaining distance and physical speed, not accelerated
demo completion time.

Assignment is observational: an Assigned trip supplies no movement leg and
cannot create a route-zero sample. Dispatch validates a fresh, online,
tenant-owned truck position, then activates a separately stored approach plan.
Arrival is a backend geographic decision. `AtPickup` waits without beginning
cargo, and Start rechecks pickup proximity before selecting the immutable cargo
leg. A new simulator process projects the latest persisted coordinate onto the
active leg within a bounded tolerance instead of resetting to its origin.

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
| `Tracking__HistoryHeartbeatSeconds` | API | Maximum unchanged interval before a heartbeat history row, default 300 |
| `Tracking__SimulatorHeartbeatSeconds` | API | Bounded stationary simulator heartbeat, default 15; clamped below offline and dispatch freshness thresholds |
| `Tracking__TrailGapThresholdSeconds` | API | Time gap that starts a new trail segment, default 300 |
| `Tracking__TrailJumpThresholdMeters` | API | Geographic jump that starts a new trail segment, default 5000 |
| `Tracking__MaxTripHistoryPoints` | API | Maximum points returned by trip history, clamped to 10–2000, default 500 |
| `Dispatch__MaximumPositionAgeSeconds` | API | Maximum trusted-position age for preview/dispatch, default 300 |
| `Dispatch__PickupArrivalRadiusMeters` | API | Geographic pickup-arrival radius, default 50 |
| `Dispatch__ProposalOriginMovementToleranceMeters` | API | Allowed movement before a proposal becomes stale, default 100 |
| `Dispatch__SimulatorRestoreProjectionToleranceMeters` | API | Maximum distance for simulator restart projection, default 500 |
| `MAP_STYLE_URL` (`--dart-define`) | Flutter | Optional MapLibre style URL; blank shows the intentional unconfigured state |
| `TRACKING_POLLING_INTERVAL_SECONDS` (`--dart-define`) | Flutter | Dashboard refresh interval, default 5 seconds |
| `MAP_LOADING_TIMEOUT_SECONDS` (`--dart-define`) | Flutter | Time to await the genuine MapLibre style callback, default 12 seconds |
| `ENABLE_SIMULATOR_CONTROLS` (`--dart-define`) | Flutter | Explicit development-only simulator panel gate, default false |
| `Routing__Provider` / `Routing__BaseUrl` | API | Backend routing adapter and endpoint; `Osrm` in Development |
| `Routing__UserAgent` | API | Identifying HTTP User-Agent required by shared/public providers |
| `Routing__TimeoutSeconds` | API | Bounded route-provider timeout |
| `Routing__OffRouteThresholdMeters` | API | Projection distance that marks a truck off route |
| `Geocoding__Provider` / `Geocoding__BaseUrl` | API | Optional backend geocoder; blank is intentionally unconfigured |
| `Geocoding__UserAgent` | API | Policy-compliant geocoder identification |

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
- `POST /api/trips/{id}/repositioning/preview` — persist a proposed approach from the latest trusted position
- `POST /api/trips/{id}/dispatch-to-pickup` — revalidate and activate the approach leg
- `POST /api/trips/{id}/arrive-pickup` — idempotently evaluate geographic arrival
- `GET /api/trips/{id}/repositioning-progress` — approach progress, separate from cargo
- `GET /api/trips/{id}/route-progress` — progress, remaining distance, ETA, phase, and off-route state
- `POST /api/routes/preview` — cached, provider-neutral road-route preview
- `GET /api/locations/search` and `/reverse` — rate-limited backend geocoding boundary
- `GET /api/dashboard` — tenant-scoped operational summary, positions, and recent trips
- `GET /api/tracking/positions`
- `GET /api/tracking/trucks/{id}/position`
- `GET /api/tracking/trucks/{id}/history?limit=50`
- `GET /api/tracking/trips/{id}/history?limit=500` — tenant-validated chronological trail segments
- `GET /api/tracking/simulator/trucks` — Owner-only Development inventory with optional latest-position state
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
- `/trips` — trip list
- `/trips/new` — full-page route planner
- `/trips/:id/edit` — Draft-only replanning
- `/trips/:id` — route details, resource assignment, and allowed status actions
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
SPRINT3_1_IMPLEMENTATION_PLAN.md
SPRINT3_2_IMPLEMENTATION_PLAN.md
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
- Route-aware writes derive legacy origin/destination labels from ordered stops;
  assignment freezes the stored route snapshot. Legacy label-only trips remain
  readable and must be geographically replanned before assignment.

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

Known Sprint 3.2 limitations: the simulator is process-local and
development-only; polling is used instead of push; the current MapLibre Flutter
API exposes style readiness but no complete tile-rendered/error signal, so a
timeout supplies deterministic recovery and visual tile rendering is checked
separately; map availability belongs to the configured provider; stored
position history remains intentionally simple and has no retention/partitioning
pipeline. The Development route is general-driving, not HGV-aware; traffic,
rerouting, optimization, proof of delivery, GPS vendors, and high-volume
telemetry remain deferred. Android execution requires a local Android SDK and
emulator/device.

Deferred to later sprints: finance, expenses, payments, profitability, advanced maintenance, documents, reporting, real GPS providers, granular permissions, advanced dashboard analytics, route optimization, AI features, and a driver application.
