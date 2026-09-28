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

Sprint 3.5 stabilizes the same behavior behind focused Application use cases
and persistence ports, a controller-backed four-step planner, separated fleet
map/model boundaries, executable architecture rules, and a deterministic CI
quality gate. It introduces no API, lifecycle, or database-schema change.

Sprint 4.1.1 adds owner-managed Driver app-account onboarding, explicit
driver-workspace states and a scoped live map, circular versioned photo markers,
input-first Follow pausing, restored saved-site states, and persisted
foreground operational alerts with per-user notification sound settings.

Sprint 4.1.2 makes tracking ingestion backend-owned and independent of browser
polling, gives the Driver authority to depart to pickup, retains a scoped
Driver–Truck session after delivery, adds self-service password change with
refresh-token revocation, and standardizes responsive two-second live updates
and shared map interaction behavior.

## Architecture

The backend is a modular monolith using Clean Architecture with lightweight DDD and CQRS principles:

- **Domain** contains entities and business invariants with no infrastructure dependency.
- **Application** contains cohesive use cases, DTOs, and focused persistence or
  provider ports.
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

Sprint 4.1.1 is represented by
`20260924232116_Sprint411DriverOnboardingMapNotifications`. It adds the
default-enabled per-user notification-sound preference and tenant-owned Company
User audit events. Existing users remain valid and the prior unique nullable
Driver/User link index continues to enforce one-to-one linkage.

Sprint 4.1.2 is represented by
`20260925084826_Sprint412DriverOperationsTracking`. It adds tenant-owned
Driver–Truck sessions with filtered unique active-session constraints. Existing
trip, driver, truck, and telemetry rows remain unchanged; sessions are created
only by a future Driver departure or audited manager handoff.

## Run Flutter Web

```bash
cd apps/transport_management_app
flutter pub get
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=TRACKING_POLLING_INTERVAL_SECONDS=5 \
  --dart-define=MAP_FALLBACK_LATITUDE=20 \
  --dart-define=MAP_FALLBACK_LONGITUDE=0 \
  --dart-define=MAP_FALLBACK_ZOOM=2 \
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

From the repository root, the complete deterministic local gate also verifies
formatting and produces a release Web build:

```bash
./scripts/quality-gate.sh
```

GitHub Actions runs the equivalent backend/architecture/migration and Flutter
jobs on pushes and pull requests to `main`, using disposable PostgreSQL and no
runtime secrets or public routing/map provider. A green push gate is required;
the authenticated Firefox workflow below remains a release gate.

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
defaults to 8 seconds and is clamped below both the offline threshold and
`Dispatch__MaximumPositionAgeSeconds`. A backend hosted worker samples the
Development/Testing simulator every two seconds; dashboard and Driver reads are
strictly observational and cannot create movement. It preserves coordinate,
heading, movement phase, tracking run, and route progress. Freshness validation
remains enabled: genuine non-simulator or explicitly offline/stopped data can
still produce `TRUCK_POSITION_STALE` or `TRUCK_OFFLINE`. Future GPS adapters use
the same company-explicit ingestion boundary as the simulator worker.

Reading current positions no longer inserts a duplicate row merely because the
dashboard polled. History is appended when coordinates, online state, source,
speed (0.5 km/h tolerance), or heading (1 degree tolerance) changes, or when the
`Tracking__HistoryHeartbeatSeconds` heartbeat elapses. Latest/history queries
remain tenant-filtered. Long-term retention and partitioning remain deferred.

New writes correlate provider telemetry with the active trip and immutable route
plan in the canonical ingestion service. Selected-trip trails use the bounded
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
| `Tracking__PollingIntervalSeconds` | API/Compose | Documented client polling default, 2 seconds |
| `Tracking__SimulatorTickSeconds` | API | Backend simulator-worker interval, default 2 seconds |
| `Tracking__OfflineThresholdSeconds` | API | Age after which the latest sample is reported offline |
| `Tracking__HistoryHeartbeatSeconds` | API | Maximum unchanged interval before a heartbeat history row, default 300 |
| `Tracking__SimulatorHeartbeatSeconds` | API | Bounded stationary simulator heartbeat, default 8 seconds; clamped below dispatch freshness |
| `Tracking__TrailGapThresholdSeconds` | API | Time gap that starts a new trail segment, default 300 |
| `Tracking__TrailJumpThresholdMeters` | API | Geographic jump that starts a new trail segment, default 5000 |
| `Tracking__MaxTripHistoryPoints` | API | Maximum points returned by trip history, clamped to 10–2000, default 500 |
| `Dispatch__MaximumPositionAgeSeconds` | API | Maximum trusted-position age for preview/dispatch, default 300 |
| `Dispatch__PickupArrivalRadiusMeters` | API | Geographic pickup-arrival radius, default 50 |
| `Dispatch__ProposalOriginMovementToleranceMeters` | API | Allowed movement before a proposal becomes stale, default 100 |
| `Dispatch__SimulatorRestoreProjectionToleranceMeters` | API | Maximum distance for simulator restart projection, default 500 |
| `Geofence__MinimumSamples` | API | Consecutive qualifying persisted samples required for arrival, default 2 |
| `Geofence__MinimumDwellSeconds` | API | Required qualifying dwell before arrival, default 8 seconds |
| `MAP_STYLE_URL` (`--dart-define`) | Flutter | Optional MapLibre style URL; blank shows the intentional unconfigured state |
| `MAP_FALLBACK_LATITUDE` (`--dart-define`) | Flutter | Regional fallback latitude used only when no saved operational area or connected truck exists; default 20 |
| `MAP_FALLBACK_LONGITUDE` (`--dart-define`) | Flutter | Regional fallback longitude used only when no saved operational area or connected truck exists; default 0 |
| `MAP_FALLBACK_ZOOM` (`--dart-define`) | Flutter | Regional fallback zoom used only when no saved operational area or connected truck exists; default 2 |
| `TRACKING_POLLING_INTERVAL_SECONDS` (`--dart-define`) | Flutter | Live dashboard/workspace refresh interval, default 2 seconds |
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
- `PUT /api/auth/me/password` — verify current password, change it, revoke all refresh tokens, and require fresh login
- `GET /api/companies/me`
- `GET /api/companies/me/map-preference` — tenant operational-area preference or 204 when unconfigured
- `PUT /api/companies/me/map-preference` — Owner-only validated save
- `DELETE /api/companies/me/map-preference` — Owner-only clear
- `GET /api/companies/{id}` (tenant-filtered; used to prove ID-tampering resistance)
- `/api/clients` — list/get/create/update, plus `POST /{id}/deactivate`
- `/api/trucks` — list/get/create/update, status update, and deactivate
- `/api/drivers` — list/get/create/update, status update, and deactivate
- `GET /api/trips` — server-paginated trip search with operational group/status, archive, client, truck, driver, planned-date, and allowlisted sort filters (maximum page size 100)
- `POST/PUT /api/trips` — create a minimal resumable Draft or update Draft basics; neither operation calls the routing provider
- `PUT /api/trips/{id}/stops` and `POST /api/trips/{id}/calculate-route` — save stops independently, then calculate the authoritative route
- `/api/trips/{id}/assign|reassign|unassign` — pre-dispatch resource management
- `DELETE /api/trips/{id}/draft` — checked permanent deletion for never-executed Drafts only
- `/api/trips/{id}/cancel|archive|unarchive|duplicate` — reasoned cancellation, historical visibility, and duplicate-as-Draft
- `GET /api/trips/{id}/timeline` — bounded newest-first immutable event history
- `POST /api/trips/{id}/repositioning/preview` — persist a proposed approach from the latest trusted position
- `POST /api/trips/{id}/dispatch-to-pickup` — audited manager exception with a mandatory reason
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
- `GET /api/driver/my-trip` — linked Driver active/post-trip vehicle projection
- `POST /api/driver/my-trip/depart-to-pickup` — Driver-authorized departure from Assigned
- `POST /api/driver/my-trip/end-vehicle-session` — end post-trip vehicle access when no active trip reserves it
- `GET /health`

List endpoints support the Sprint 2 filters documented in OpenAPI. Enum values
are serialized as readable strings. All operational endpoints require the named
`operations.read` or `operations.manage` policy.

## Flutter routes

- `/dashboard` — authenticated landing screen
- `/clients` — searchable client list and create/edit/deactivate flow
- `/trucks` — truck list, details, create/edit, status, and deactivate flow
- `/drivers` — driver list, details, create/edit, status, and deactivate flow
- `/trips` — server-paginated Active/Planned/Completed/Cancelled/Archived views with search and filters
- `/trips/new` — resumable four-step Draft planner
- `/trips/:id/edit` — Draft wizard restored from the individual trip endpoint
- `/trips/:id` — trip number, readiness, route/assignment/tracking sections, timeline, and server-allowed contextual actions
- `/settings` — persisted English/Arabic language selection

## Project structure

```text
src/
  TransportManagement.Domain/          entities and invariants
  TransportManagement.Application/     use cases, DTOs, abstractions
  TransportManagement.Infrastructure/  EF Core, PostgreSQL, auth, tenancy
  TransportManagement.Api/             REST host and controllers
tests/
  TransportManagement.ArchitectureTests/ executable dependency/tenancy rules
  TransportManagement.IntegrationTests/
apps/
  transport_management_app/            Flutter Web + Android client
docs/
  architecture.md
  sprints/                             prompts and execution plans by Sprint
    README.md                           Sprint documentation index
    sprint-1/
    sprint-2/
    sprint-3/
    sprint-3.1/
    sprint-3.2/
    sprint-3.2.1/
    sprint-3.2.2/
    sprint-3.3/
    sprint-3.3.1/
    sprint-3.4/
    sprint-3.4.1/
    sprint-3.5/
  evidence/sprint3_5/                   baseline/final validation evidence
.github/workflows/quality-gate.yml      push/pull-request quality gate
scripts/quality-gate.sh                 equivalent deterministic local gate
compose.yaml
Dockerfile
```

Each Sprint folder contains its original implementation prompt and the
corresponding plan/execution log. See [`docs/sprints/README.md`](docs/sprints/README.md)
for direct links to every Sprint document.

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
- Trips use the canonical transitions `Draft → Assigned → EnRouteToPickup → AtPickup → Started → InTransit → Delivered → Completed`, with cancellation only where the server permits it.
- `Assigned`, `EnRouteToPickup`, `AtPickup`, `Started`, and `InTransit` reserve resources. Application checks return useful conflicts, while PostgreSQL partial unique indexes prevent concurrent double assignment.
- Standard generated Flutter ARB localizations own visible English/Arabic text; directional layout APIs allow Material to mirror the shell, forms, and dialogs.
- MapLibre is the vendor-neutral rendering layer. Style/tile hosting is externally configurable and is not a backend/domain concern.
- Polling is intentionally used before SignalR: current fleet scale does not justify persistent real-time connections, and the provider/dashboard contracts preserve a future upgrade path.
- Route-aware writes derive legacy origin/destination labels from ordered stops;
  assignment freezes the stored route snapshot. Legacy label-only trips remain
  readable and must be geographically replanned before assignment.

## Sprint 3.4 trip operations

Trip numbers use `TRP-{UTC creation year}-{six-digit sequence}`. The API allocates
the sequence from a PostgreSQL tenant/year counter with an atomic upsert; numbers
are immutable and are not reused after Draft deletion. The migration backfills
existing rows deterministically per company/year in `CreatedAt, Id` order and
seeds counters to the resulting maximum.

A first Draft requires only an active client and cargo description. Schedule,
price, stops, route, truck, and driver remain honestly nullable until supplied.
The API derives `canCalculateRoute`, `canAssign`, `canDispatch`, and stable missing
requirement codes. Saving basics/stops never invokes OSRM. Explicit route
calculation stores a server-authoritative fingerprinted snapshot; changing a
stop invalidates that Draft snapshot. Draft mutations carry a version and EF
optimistic concurrency token.

| State/condition | Manager action |
|---|---|
| Incomplete Draft | Resume/edit; save stops; calculate route |
| Ready Draft | Assign, duplicate, cancel, or permanently delete if never executed |
| Assigned before dispatch | Reassign, unassign, dispatch, or cancel with reason |
| Active execution | Follow the lifecycle or cancel where policy permits; never hard-delete |
| Completed/Cancelled | Archive/unarchive; never hard-delete |

Every important transition appends a stable-code, tenant-owned event with UTC
time, source, authenticated actor when applicable, and bounded JSON metadata.
Existing trips receive one honest `ImportedBaseline` event; the migration does
not invent historical actions. Duplicate-as-Draft copies planning fields and
stops, but not number, route, assignment, execution, tracking, cancellation,
archive state, or history.

Rollback after users create incomplete Drafts is data-incompatible because the
older schema requires schedule, price, and route labels. Back up the database
and resolve those Drafts before downgrading. Finance, recurring templates,
multi-vehicle optimization, real GPS ingestion, and telemetry retention remain
deferred.

### Sprint 3.4.1 corrective trip workflow

The trip planner now has four functional steps: Trip Details; Pickup, Delivery
and Route; Truck and Driver; and Review and Confirm. `Next` is gated by the
current step, assignment may be explicitly skipped to retain an unassigned
Draft, and a saved Draft resumes at its latest meaningful step. The final
assignment action operates on the same Draft, so an availability race returns
the user to assignment without creating another trip.

An unchanged stop submission is idempotent. The API compares the normalized
ordered coordinate/profile fingerprint and preserves the route ID, readiness,
and version when route inputs are unchanged. Names and addresses are
display-only. A genuine coordinate/order/profile change removes the route and
appends one `RouteInvalidated` event. Unrelated Draft edits also preserve it.

`GET /api/trips/{id}/assignment-options` returns all tenant trucks and drivers,
including ineligible resources, with stable reasons such as
`RESOURCE_INACTIVE`, `TRUCK_MAINTENANCE`, `TRUCK_ALREADY_ASSIGNED`,
`DRIVER_NOT_AVAILABLE`, and `DRIVER_ALREADY_ASSIGNED`. The assign command
always rechecks readiness, live status, and reservations.

To rerun the authenticated Firefox acceptance workflow, start the Compose stack
and geckodriver, then from `apps/transport_management_app` run:

```bash
flutter drive \
  --driver=test_driver/integration_test_sprint3_4_1.dart \
  --target=integration_test/sprint3_4_1_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 \
  --headless --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=E2E_EMAIL=YOUR_DEDICATED_SMOKE_OWNER \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD \
  --dart-define=MAP_STYLE_URL=https://demotiles.maplibre.org/style.json \
  --dart-define=TRACKING_SIMULATOR_ENABLED=true
```

Use a dedicated Development/Testing owner; never reset a retained user's
password or database volume. Evidence is written to
`docs/evidence/sprint3_4_1/`.

## Sprint 3.5 stabilization and quality gates

Trip HTTP actions now delegate to focused draft, routing, assignment, dispatch,
lifecycle, and query services. Consumers depend on `IClientStore`,
`IFleetStore`, `ITripStore`, or `ITripQueryStore`; Infrastructure still shares
one scoped EF implementation and transaction boundary. The planner screen is a
small composition shell around controller-owned orchestration and network-free
steps, while fleet-map adapter and panel code is isolated from coordination.

Architecture tests enforce project direction, thin controllers, tenant filters
and indexes, approved filter bypasses, Flutter transport isolation, and Riverpod
as the sole state-management package. See
[`docs/architecture.md`](docs/architecture.md) for ownership and Definition of
Done, and [`docs/evidence/sprint3_5/`](docs/evidence/sprint3_5/) for baseline and
final validation evidence. The authenticated browser command in Sprint 3.4.1
remains the primary planner regression command after this behavior-preserving
refactor.

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

## Sprint 4 customer and fleet operations

Sprint 4 adds client lifecycle, legal/profile fields, multiple contacts,
map-backed saved sites, bounded trip/activity history, extended truck profiles,
default-driver suggestions, independent base/operational truck state, odometer
corrections, and dedicated client/truck details. Mutations refresh related
lists, details, planner choices, trips, dashboard, and tracking without a page
reload.

With the Compose API healthy and `geckodriver --port 4444` running, execute the
Sprint 4 browser workflow from `apps/transport_management_app`:

```bash
flutter drive \
  --driver=test_driver/integration_test_sprint4.dart \
  --target=integration_test/sprint4_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 \
  --headless --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=E2E_EMAIL=YOUR_DEDICATED_SMOKE_OWNER \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD \
  --dart-define=MAP_STYLE_URL=https://demotiles.maplibre.org/style.json
```

Use a disposable Development/Testing tenant. The workflow writes screenshots
and JSON results to `docs/evidence/sprint4/`; it never resets the retained demo
owner or PostgreSQL volume.

## Sprint 4.1 live fleet and driver workflow

Sprint 4.1 adds restart-safe pickup/delivery geofences, persisted localized
notifications, linked-driver authorization and confirmations, secure processed
truck photos, and explicit Free/Follow/Route Overview map modes. The canonical
new-trip lifecycle is:

```text
Draft -> Assigned -> EnRouteToPickup -> AtPickup
      -> InTransit -> AtDelivery -> Completed
```

Start the stack without removing its retained volumes:

```bash
sudo docker-compose -p tms-smoke up -d --build
sudo docker-compose -p tms-smoke ps
```

Run the app from `apps/transport_management_app`:

```bash
../../.tooling/flutter/bin/flutter pub get
../../.tooling/flutter/bin/flutter run -d web-server --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://demotiles.maplibre.org/style.json \
  --dart-define=TRACKING_SIMULATOR_ENABLED=true
```

For the repeatable Firefox workflow, start `geckodriver --port 4444`, then run:

```bash
../../.tooling/flutter/bin/flutter drive \
  --driver=test_driver/integration_test_sprint4_1.dart \
  --target=integration_test/sprint4_1_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=E2E_EMAIL=YOUR_DEDICATED_SMOKE_OWNER \
  --dart-define=E2E_DRIVER_EMAIL=YOUR_LINKED_DRIVER_USER \
  --dart-define=E2E_DRIVER_USER_ID=YOUR_LINKED_DRIVER_USER_ID \
  --dart-define=E2E_SECOND_DRIVER_EMAIL=YOUR_SECOND_DRIVER_USER \
  --dart-define=E2E_SECOND_DRIVER_USER_ID=YOUR_SECOND_DRIVER_USER_ID \
  --dart-define=E2E_PASSWORD=YOUR_DEVELOPMENT_PASSWORD \
  --dart-define=MAP_STYLE_URL=https://demotiles.maplibre.org/style.json \
  --dart-define=TRACKING_SIMULATOR_ENABLED=true
```

The three accounts must belong to one disposable Development/Testing tenant;
the two driver users must have the `Driver` role. Evidence and exact coverage are documented in
[`docs/evidence/sprint4_1/`](docs/evidence/sprint4_1/).

## Sprint 4.1.1 isolated acceptance

Sprint 4.1.1 browser data must not be written to the retained development
database. Start its fail-closed Testing stack with runtime-only values:

```bash
export ACCEPTANCE_POSTGRES_PASSWORD='choose-a-disposable-password'
export ACCEPTANCE_JWT_SIGNING_KEY='choose-at-least-32-random-characters'
export ACCEPTANCE_OWNER_PASSWORD='choose-at-least-12-characters'
./scripts/sprint411-acceptance-environment.sh up
```

This uses API `http://localhost:5180`, PostgreSQL port `55432`, Compose project
`tms-s411-acceptance`, and dedicated disposable volumes. It refuses a resolved
configuration that references `tms-smoke_postgres_data`. Diagnose either stack
without printing secrets:

```bash
./scripts/sprint411-acceptance-environment.sh diagnose
./scripts/diagnose-local-environment.sh
```

Start `geckodriver --port 4444`, then from
`apps/transport_management_app` run:

```bash
../../.tooling/flutter/bin/flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/sprint4_1_1_smoke_test.dart \
  -d web-server --browser-name=firefox --driver-port=4444 --headless \
  --web-port=3100 \
  --dart-define=API_BASE_URL=http://localhost:5180 \
  --dart-define=E2E_EMAIL=owner@sprint411.local \
  --dart-define=E2E_PASSWORD="$ACCEPTANCE_OWNER_PASSWORD" \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true
```

The workflow creates and links the Driver account through product UI, uses a
non-square authenticated truck photo, exercises the scoped driver map, sends
real pointer/wheel input to pause Follow across three polls, and verifies that a
new persisted alert is shown and its sound request is not replayed. Remove only
the disposable environment afterward:

```bash
./scripts/sprint411-acceptance-environment.sh down
```

## Sprint 4.1.2 driver operations and tracking responsiveness

The simulator now advances in a backend hosted worker, not in response to a
dashboard read. All sources enter a company-explicit ingestion use case that
bounds unchanged position writes with an eight-second simulator heartbeat,
evaluates two-sample/eight-second geofence evidence, and persists deduplicated
operational notifications in the same backend flow. Dashboard, Driver
Workspace, and notification polling default to two seconds and reject
overlapping refreshes while retaining the last good projection.

Assignment does not mean departure. A linked Driver starts the approach leg,
confirms loading and departure at pickup, and confirms delivery after the
backend detects stable delivery arrival. Manager equivalents are exceptional,
require a reason, and are audited. A tenant-scoped Driver–Truck session starts
at departure and survives commercial trip completion, allowing a post-trip map
until the Driver explicitly ends the session; handoff removes the previous
Driver's access. ETA prefers current movement and falls back to stored route or
approach duration when speed is zero.

Manager and Driver maps share Follow, Free, and one-shot Route Overview
semantics. Pointer input pauses Follow before camera callbacks. Photo markers
keep the same `truck + photo version + marker pipeline` image identity during
coordinate/status updates, avoiding fallback-image swaps and symbol recreation.
Foreground alerts remain persisted/deduplicated; faster polling does not replay
hydrated alerts, and browser autoplay-blocked messaging remains explicit.

Settings now supports authenticated password change for all roles. The backend
verifies the current password, confirmation and policy, rejects reuse, hashes
the replacement, writes a security event, revokes refresh tokens, and forces a
fresh login. No password is logged or returned.

Acceptance must use a distinct Compose project and named PostgreSQL/photo
volumes—never `tms-smoke_postgres_data`. The 2026-09-25 implementation used
`tms-s412`; retained counts matched before and after. Automated and isolated
runtime checks pass, including background movement without a browser and
8.002–10.001 second pickup dwell. The mandatory two-profile real-browser run
did not complete because the existing Firefox/Flutter Drive harness failed with
aggregated client exceptions, so Sprint 4.1.2 acceptance remains incomplete.
See [`docs/evidence/sprint4_1_2/`](docs/evidence/sprint4_1_2/).

## Sprint 4.1.2.1 Driver activation repair

Sprint 4.1.2.1 closes that acceptance gap. Driver departure is now one
authoritative server operation: it validates linked identity and fresh trusted
telemetry, reuses or prepares a valid approach route, revalidates concurrency,
starts the Driver–Truck session, and transitions idempotently without requiring
Owner preview. The workspace exposes server-owned readiness and actionable
English/Arabic blocking guidance. The primary confirmation appears above the
map, assignment alerts explicitly open and refresh the trip, polling retains
the last good state, and map mutations are serialized/latest-wins.

The mandatory isolated Firefox workflow passed from Owner UI assignment through
Driver notification, Open trip, confirmation, persisted OSRM approach route,
and background movement after the Owner profile was closed. Manager preview,
override, direct departure calls, and simulator steps were not used. See
[`docs/evidence/sprint4_1_2_1/`](docs/evidence/sprint4_1_2_1/).

Deferred work remains real GPS provider integration, WebSocket/push delivery,
long-term telemetry retention/partitioning, visual non-headless marker-frame
recording, and the Android run until an SDK plus device/emulator are installed.

Known limitations: simulator state is process-local, backend-scheduled, and
development-only; client refresh polling is used instead of push; the current MapLibre Flutter
API exposes style readiness but no complete tile-rendered/error signal, so a
timeout supplies deterministic recovery and visual tile rendering is checked
separately; map availability belongs to the configured provider; stored
position history remains intentionally simple and has no retention/partitioning
pipeline. The Development route is general-driving, not HGV-aware; traffic,
rerouting, optimization, proof of delivery, GPS vendors, and high-volume
telemetry remain deferred. Android execution requires a local Android SDK and
emulator/device.

Deferred to later sprints: finance, expenses, payments, profitability, advanced maintenance, documents, reporting, real GPS providers, granular permissions, advanced dashboard analytics, route optimization, and AI features.


## Sprint 4.2 operational control center

Sprint 4.2 adds a server-owned, tenant-scoped `GET /api/dashboard/active-trips` projection. It returns operational phase, next milestone/stop, segment-specific progress, remaining distance, ETA, tracking health, attention priority, truck photo identity, and linked Driver context without route geometry or history. Assigned, approach, pickup waiting, cargo movement, and delivery-confirmation waiting are explicit phases; waiting states never fabricate progress.

Dashboard polling remains configurable through `TRACKING_POLLING_INTERVAL_SECONDS` (default 2 seconds). Active Trips and active trip detail use sequential, non-overlapping 3-second refresh. Repeated transient failures retain the last good projection and show stale feedback. Detail polling stops for Completed, Cancelled, and Archived trips. Active filters survive silent refresh.

The shell now displays account/Driver identity, localized role, company, and email. Operational notification JSON stores language-neutral trip/truck/fleet/Driver/stop snapshots and the client localizes presentation. Truck defaults are suggestions only: an eligible default is selected and explained; an unavailable or missing default leaves Driver empty; manual selection remains explicit and assignment never mutates the truck default.

The Sprint 4.2 implementation plan and validation boundary are under `docs/sprints/sprint-4.2` and `docs/evidence/sprint4_2`. Automated checks pass, but the mandatory browser workflow is recorded as incomplete and must not be treated as accepted.

## Sprint 4.2.1 operational reliability

Sprint 4.2.1 keeps one fleet-map platform view alive across polling and trip
phase changes. Annotation synchronization failures are recoverable and do not
replace a healthy renderer; route, trail, stop, and truck annotations are
incrementally diffed, while camera movement remains user-driven after initial
framing. The active-operations query is now a bounded, tenant-filtered,
database projection rather than broad in-memory aggregation.

Flutter Web uses `maplibre_gl 0.27.1`, whose Web implementation injects
MapLibre GL JS 6.4.1. The recommended development style remains configurable:

```bash
../../.tooling/flutter/bin/flutter run -d web-server --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true
```

OpenFreeMap Liberty uses its hosted glyph endpoint and bilingual
`name:latin,name:nonlatin` labels. Sprint 4.2.2 real-canvas inspection later
proved that this runtime left its RTL plugin in `requested` state and rendered
those mixed-direction expressions incorrectly. The current locale-aware style
and pinned local shaping plugin are documented below; Arabic strings are never
manually reversed. OpenFreeMap attribution remains enabled.

Operational notifications now render immutable truck, trip, location, and
event-time snapshots in English or Arabic, with a localized legacy fallback.
Driver assignment details include client, truck, cargo, stops, schedule,
distance, duration, notes, and status. Planner and existing-trip assignment use
the same linked/default-Driver selection policy. Concurrent expired requests
also share token rotation: a late 401 produced with the previous access token
retries with the already-rotated token instead of invalidating the session.

The implementation plan is in `docs/sprints/sprint-4.2.1`; automated, Docker,
Firefox manager/Driver, map-transition, Arabic/English map, and data-safety
evidence is in `docs/evidence/sprint4_2_1`.

## Sprint 4.2.2 unified map and live tracking

Sprint 4.2.2 makes the configured basemap locale-aware without changing its
provider. The style is fetched and cached by URL/locale, and only name-bearing
symbol layers are transformed. Arabic uses
`name:ar → name:nonlatin → name → name:latin → name_en`; English uses
`name:latin → name_en → name → name:nonlatin`. The original sources, sprites,
glyph URL, fonts, and attribution remain intact. Firefox showed MapLibre GL JS
6.4.1 reporting RTL status `requested` and drawing reversed Arabic even after
the mixed-direction expression was removed. Web therefore loads the pinned
local `@mapbox/mapbox-gl-rtl-text` 0.3.0 compatibility asset and its BSD-2-Clause
license before Flutter starts. This is a verified runtime-specific correction,
not manual string reversal.

Owners can configure the tenant operational area under **Settings →
Operational area**. Search uses the configured backend geocoder only during
explicit setup; save persists validated ISO alpha-2 code, label snapshot,
bounds, optional center/zoom, actor, and timestamps. The fleet overview starts
from those bounds, expands for connected trucks outside them, accounts for the
directional side panel, and exposes a localized outside-area indicator and
explicit **Fleet overview** action. If no preference exists, connected trucks
are fit at a regional scale; if neither preference nor connected truck exists,
the optional `MAP_FALLBACK_*` values are used. Dateline-crossing saved bounds
remain explicitly unsupported.

Owner and Driver maps share four camera modes: fleet overview, vehicle follow,
free explore, and route overview. Wheel/pinch zoom keeps follow and its chosen
zoom. A deliberate pan/rotate/tilt enters free explore. Programmatic moves are
guarded, stationary heartbeats do not recenter, follow updates change center
without forcing zoom 13.5, and route/fleet fits occur only on explicit actions.
Markers use latest-wins visual interpolation with bounded duration, shortest-arc
heading, large-jump snap, and stale/offline stop; interpolated frames are never
stored as telemetry.

The backend keeps immutable `truck_positions` and an additive
`truck_current_positions` projection. A serializable ingestion transaction
advances current only for a strictly newer `RecordedAt`; exact duplicates are
ignored, older and conflicting equal-timestamp packets remain history, and a
new tracking run advances only with a newer timestamp. Tenant mismatches fail
before persistence. Driver workspace resolution is active trip, then active
vehicle session, then one active default-linked truck, then no vehicle;
multiple defaults return an explicit ambiguity state rather than selecting the
first. Idle and post-trip Drivers retain truck identity, tracking quality, and
map without fabricated route, ETA, progress, or trip actions.

The additive `20260927071807_Sprint422MapOperationsChronology` migration creates
one optional map preference per company and one current-position row per truck.
It deterministically backfills the newest legacy history row by timestamp then
packet ID, invents no preference or telemetry, and its rollback drops only the
two new projection/preference tables.

The implementation plan is in `docs/sprints/sprint-4.2.2`; automated, isolated
Docker/PostgreSQL, genuine English/Arabic Firefox canvas, Owner camera, Driver
idle/assignment/post-trip, chronology, and data-safety evidence is in
`docs/evidence/sprint4_2_2`.
## Sprint 4.3 global accounts and safe handover

Sprint 4.3 separates the global personal account from tenant-owned business
data. An account can hold multiple company memberships and multiple roles;
signed access tokens select one active membership, and every request plus token
refresh revalidates that membership. The account header exposes active company,
roles, settings, and workspace switching. Company Driver records stay
tenant-owned and may exist without app access.

Owner/Operations access management now provides multi-role, expiring,
single-use invitation links; exact private company-code requests; explicit
Driver linking; suspend/reactivate/revoke; and durable audit/notification
events. Managers no longer set or see another person's permanent password.
Invitation and truck QR secrets are stored only as hashes.

Default truck, active Driver-truck session, and trip assignment remain distinct.
A free-truck QR/manual-code confirmation changes only the active session. An
occupied active-trip truck creates a pending handover; approval atomically
changes the current Driver while preserving Trip ID, truck, route/progress,
tracking/trail, events, and immutable participation boundaries.

Local login remains enabled. Google Sign-In is optional and uses the official
Google Identity Services Web button or native platform launcher. Configure only
public client identifiers in `.env`:

```dotenv
GOOGLE_WEB_CLIENT_ID=
GOOGLE_ANDROID_CLIENT_ID=
GOOGLE_SERVER_CLIENT_ID=
```

For Web, register the exact origin (for example `http://localhost:3000`) in
Google Cloud and run Flutter with
`--dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID`. For future Android,
also pass `GOOGLE_ANDROID_CLIENT_ID` and `GOOGLE_SERVER_CLIENT_ID`, and
register the application package plus signing SHA certificate. The backend
validates issuer, signature, expiry, verified email, and one of the configured
audiences. No OAuth client secret belongs in Flutter. When IDs are absent the
Google action is honestly unavailable.

The migration, verification commands, rollback guard, browser coverage, and
environment limitations are recorded in
`docs/sprints/sprint-4.3/SPRINT4_3_IMPLEMENTATION_PLAN.md` and
`docs/evidence/sprint4_3/README.md`.


## Sprint 4.3.1 account, Driver, QR, and invitation stabilization

Sprint 4.3.1 completes the user-facing management workflows around the Sprint
4.3 identity model. Owners can edit every membership role while last-Owner,
self-demotion, and linked-Driver safeguards preserve access and operations.
Owner and Operations users can link an accepted Driver-role membership to an
eligible tenant Driver without stealing another account's link, and unsafe
unlinking is rejected while a trip, vehicle session, or handover depends on it.

Truck details now shows non-secret QR status and provides explicit Generate or
Regenerate actions. The one-time dialog renders the QR, permits copying its
manual code, and exports a PNG. Historical raw codes remain unrecoverable by
design. Driver Web currently advertises **Enter truck code**, accepts either
the raw value or a full `tms-truck://qr/...` payload, and does not claim camera
support.

Invitation creation returns a directly usable Flutter hash URL based on
`FRONTEND_PUBLIC_BASE_URL`. Google controls are shown only when both the
platform client ID and backend provider are configured, and invitation
acceptance now includes Continue with Google. Local email/password login
remains supported.

### Run Sprint 4.3.1 locally

From the repository root, keep the retained project and volumes intact:

```bash
docker compose -p tms-smoke up -d --build
docker compose -p tms-smoke ps
curl --fail http://localhost:5080/health
```

Do not use `down -v`. The frontend invitation origin defaults to
`http://localhost:3000`; set this in `.env` when another public origin is
required:

```dotenv
FRONTEND_PUBLIC_BASE_URL=http://localhost:3000
```

Run Flutter Web on that same registered Google origin:

```bash
cd apps/transport_management_app
../../.tooling/flutter/bin/flutter pub get
../../.tooling/flutter/bin/flutter run \
  -d web-server \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty \
  --dart-define=ENABLE_SIMULATOR_CONTROLS=true \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"
```

Open `http://localhost:3000` in Firefox. Manual acceptance should cover role
editing, delayed Driver linking, blocked unsafe unlinking, invitation opening
in a private profile, QR generation/download and manual-code entry, local
login/logout, and Google login/invitation acceptance.

### Validate Sprint 4.3.1

Run the automated suites from the repository root:

```bash
.tooling/dotnet/dotnet build TransportManagement.slnx -c Release
.tooling/dotnet/dotnet test TransportManagement.slnx -c Release --no-build

cd apps/transport_management_app
../../.tooling/flutter/bin/flutter analyze
../../.tooling/flutter/bin/flutter test
../../.tooling/flutter/bin/flutter build web \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"
```

For fresh-profile Firefox smoke tests, start the driver in one terminal:

```bash
geckodriver --port 4444
```

Then run from `apps/transport_management_app`:

```bash
../../.tooling/flutter/bin/flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_smoke_test.dart \
  -d web-server \
  --browser-name=firefox \
  --driver-port=4444 \
  --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=E2E_EMAIL=owner@demo.local \
  --dart-define=E2E_PASSWORD="$DEMO_OWNER_PASSWORD"

../../.tooling/flutter/bin/flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/google_provider_smoke_test.dart \
  -d web-server \
  --browser-name=firefox \
  --driver-port=4444 \
  --headless \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:5080 \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"
```

The second test proves that the live configured backend and Google Web control
agree on availability. Completing account selection, consent, and the returned
identity token is intentionally a visible, human-driven Firefox step.

The full implementation record and sanitized evidence are in
`docs/sprints/sprint-4.3.1` and `docs/evidence/sprint4_3_1`.
