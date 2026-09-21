# Architecture Decisions

## ADR-001: Modular monolith with Clean Architecture

**Status:** Accepted

The first customer is small, while the product may grow into multi-tenant SaaS. A single deployable ASP.NET Core API minimizes operational cost. Domain/Application/Infrastructure/API dependency boundaries preserve modularity and keep future feature modules independently understandable. Microservices and event sourcing add no value at this stage.

Future modules should be vertical slices inside the monolith and may share only explicitly owned contracts. Domain never references EF Core or HTTP types.

## ADR-002: Tenant derived from authentication and enforced by EF Core

**Status:** Accepted

`CompanyId` is a signed JWT claim produced from the stored user. `ICurrentUser` exposes it to infrastructure. `AppDbContext` adds a global query filter to all `ITenantOwned` entities and to `Company`, so ordinary queries cannot accidentally cross company boundaries. An unauthenticated context resolves to `Guid.Empty` and therefore sees no tenant data.

Authentication must locate a user before a tenant is authenticated, and refresh must locate a hashed bearer credential. Those two store operations use `IgnoreQueryFilters` inside Infrastructure only. They never accept a frontend-provided company ID. All other business reads retain the global filter.

Every future tenant-owned entity must:

1. implement `ITenantOwned`;
2. have a required `CompanyId` foreign key and index;
3. receive `CompanyId` from `ICurrentUser` on creation;
4. include an integration test attempting a foreign-company ID.

Defense in depth can later add PostgreSQL row-level security if operational requirements justify its connection/session complexity.

## ADR-003: JWT access token and rotating refresh credential

**Status:** Accepted

Access tokens expire after 15 minutes and contain user, company, role, email, and unique token claims. Refresh credentials contain 512 random bits, are returned only once, are SHA-256 hashed in the database, expire after 14 days, and are rotated on every use. Logout revokes the supplied token or all current-user tokens when none is supplied.

Passwords use BCrypt with work factor 12. Signing secrets and seed passwords come from external configuration.

## ADR-004: Roles now, named policies as the permission seam

**Status:** Accepted

The initial roles are Owner, Operations, Accountant, and Employee. Controllers refer to named authorization policies instead of scattering role comparisons. Later, policy handlers can evaluate permissions without changing endpoints or business use cases.

## ADR-005: Riverpod and feature-first Flutter

**Status:** Accepted

Riverpod is the only state-management system. Code is grouped into `core`, `features`, and `shared`; each feature separates data, domain, and presentation where needed. Dio is centralized and performs authorization attachment, one-at-a-time refresh, a single retry, and common error mapping. GoRouter owns navigation and auth redirects.

The access token is memory-only. The refresh token uses platform secure storage. Web clients cannot fully protect browser-accessible secrets against XSS, so CSP, dependency hygiene, HTTPS, and a future HTTP-only cookie option remain important production controls.

## ADR-006: Explicit production migrations

**Status:** Accepted

Development seeding, when explicitly enabled, applies migrations for an easy local Compose startup. Non-Development environments never migrate at process startup. Deployment automation must run `dotnet ef database update` (or reviewed idempotent migration scripts) as a controlled release step.

## Tracking integration

Fleet location reads depend on the application-facing `ITrackingProvider`.
Vendor and simulator adapters live in Infrastructure; Domain truck models do
not reference Traccar, Wialon, MapLibre, or another provider SDK. Real GPS
ingestion remains deferred, but it can implement the existing port.

## ADR-007: Explicit trip state machine and resource lifecycle

**Status:** Accepted

Trip transitions are domain methods rather than arbitrary status setters:
`Draft → Assigned → Started → InTransit → Delivered → Completed`. Cancellation
is permitted before delivery. A truck and driver are selected at assignment,
change to `OnTrip` when the trip starts, and return to `Available` when it is
completed or an active trip is cancelled. The API publishes allowed next actions
so the Flutter client does not duplicate transition rules.

| Current status | Allowed next operation | Result |
|---|---|---|
| Draft | Assign; Cancel | Assigned; Cancelled |
| Assigned | Start; Cancel | Started; Cancelled |
| Started | Mark in transit; Cancel | InTransit; Cancelled |
| InTransit | Deliver; Cancel | Delivered; Cancelled |
| Delivered | Complete | Completed |
| Completed | None | Terminal |
| Cancelled | None | Terminal |

Assignment resolves the client, truck, and driver through the current tenant
filter. The client and both resources must be active; the truck and driver must
be `Available`; and neither resource may be reserved by another trip. Draft
editing is rejected after assignment, and every unsupported transition produces
a safe domain validation response.

## ADR-008: Database-backed double-assignment protection

**Status:** Accepted

The application checks that resources are active, available, tenant-visible,
and not reserved before assignment. PostgreSQL partial unique indexes on
`(CompanyId, TruckId)` and `(CompanyId, DriverId)` for reserving trip statuses
provide the concurrency backstop. Database update conflicts are translated into
safe HTTP 409 Problem Details responses.

## ADR-009: Sprint 2 module and authorization boundaries

**Status:** Accepted

Clients, fleet, and trips are separate Domain/Application/API/Flutter feature
areas but share one operational persistence port inside the modular monolith.
Every entity implements `ITenantOwned`; all foreign resources are resolved under
the global tenant filter. Owner and Operations can read and mutate operational
data, Accountant is read-only, and Employee has no operational access. Named
`operations.read` and `operations.manage` policies preserve the future permission
seam.

## ADR-010: Generated localization with server-backed locale

**Status:** Accepted

Flutter uses `flutter_localizations`, ARB sources, and generated localization
classes for English and Arabic. Internal enum/error values remain stable English
identifiers and a centralized UI mapping renders localized labels. Material's
locale-derived direction plus directional padding/positioning provides LTR/RTL
behavior. `User.PreferredLocale` stores only validated `en` or `ar`; login,
current-user, and the preference endpoint carry it so the setting follows the
user across devices.

## ADR-011: Stable API error codes in Problem Details

**Status:** Accepted

Domain, conflict, and not-found exceptions expose a stable machine code through
the `errorCode` Problem Details extension. Flutter localizes recognized codes
and uses a safe generic localized fallback for unknown codes. Human-readable
server details remain useful for logs and API clients but are never translated
or shown as the localization source of truth.

## ADR-012: Provider-neutral tracking with a gated simulator

**Status:** Accepted

Application owns `ITrackingProvider`; Infrastructure selects an implementation
from configuration. The deterministic simulator is registered only in
Development/Testing when both provider selection and the explicit enable flag
permit it. Its state is isolated by company, control is Owner-only, and tests
advance it through commands instead of timing-sensitive sleeps. Production
defaults to an unconfigured provider and cannot accidentally enable simulation.

## ADR-013: Tenant-owned current and historical positions

**Status:** Accepted

Every `TruckPosition` stores `CompanyId`, `TruckId`, numeric latitude/longitude,
speed/heading, source, online signal, and UTC recorded time. EF's tenant filter
applies to all reads. Indexes support company queries and per-truck newest/history
queries. The latest sample is online only when both the provider signal is online
and its age is within `Tracking:OfflineThresholdSeconds`. This append-only,
query-limited model is deliberately sufficient for the current fleet scale;
retention, partitioning, and high-volume telemetry ingestion are deferred.

## ADR-014: Polling before SignalR and one dashboard query

**Status:** Accepted

Flutter owns one Riverpod dashboard controller and polls at the compile-time
configured interval (five seconds by default), with explicit refresh after
simulator controls. The API exposes one tenant-scoped dashboard use case that
aggregates fleet totals, trip totals, tracking state/current positions, and
recent trips. This avoids a fan-out of unrelated client requests. SignalR would
add connection and deployment complexity without a current latency or scale
requirement; the provider/query seams allow it later.

## ADR-015: MapLibre with explicit lifecycle and externally selected styles

**Status:** Accepted

MapLibre renders maps on Flutter Web and Android without making a commercial
map vendor part of Domain or Application. `MAP_STYLE_URL` is a Flutter
compile-time setting and production is responsible for choosing and licensing
style/tile hosting. The UI models `unconfigured`, `loading`, `loaded`, `failed`,
and `fallback` explicitly. Only MapLibre's style-loaded callback enters loaded;
a configurable timeout enters failed and offers a genuine retry or an explicit
simplified fallback. The package does not provide a complete tile-rendered/error
signal, so style readiness is never documented as proof that all tiles rendered.
Fallback markers use distinct test identifiers, and real-map browser evidence
includes separate callback/annotation assertions and visual inspection.

## ADR-016: Event-aware tracking history writes

**Status:** Accepted

Provider polling refreshes current fleet state but is not itself a telemetry
event. `TrackingService` compares each sample with the latest tenant-filtered
row and appends only for coordinate movement, meaningful speed/heading change,
online/source change, or a configurable heartbeat. This bounds history growth
while paused without changing the provider or weakening tenant isolation.
High-volume retention, partitioning, and archival remain deferred.

## Sprint 3 authorization matrix

| Capability | Owner | Operations | Accountant | Employee |
|---|---:|---:|---:|---:|
| Read dashboard/tracking | Yes | Yes | Yes | No |
| Manage operational records | Yes | Yes | No | No |
| Control Development simulator | Yes | No | No | No |

Controllers enforce named policies/roles, while all dashboard, current-position,
history, and simulator truck resolution remains behind tenant-filtered stores.

## ADR-017: Application-owned route planning and immutable trip snapshots

**Status:** Accepted

`TripStop` stores tenant-owned ordered pickup/delivery data. `TripRoutePlan`
stores normalized GeoJSON road geometry, distance, duration, provider,
general-driving profile, timestamp, and stop fingerprint. Route-aware writes
derive compatibility origin/destination labels from the stops. Assignment
freezes the snapshot so an operational route cannot change under an active trip.

`IRoutingProvider`, `IGeocodingProvider`, and `ITrackingProvider` are separate
Application ports. Infrastructure owns OSRM-compatible and configurable
geocoder adapters; Flutter receives application contracts and no provider
credential. Preview/save calculations are cached by stop fingerprint, provider
timeouts are bounded, geocoding is rate-limited, and failures expose stable safe
codes.

The simulator interpolates by cumulative distance along each stored geometry.
Reads are observational; elapsed time or explicit controls change position.
Progress projects the latest sample onto the geometry and derives clamped
travelled/remaining distance, ETA only while moving, phase, and off-route state.
Planned geometry and actual history remain separate and are rendered together
only for the selected vehicle.

The migration preserves legacy text labels as nullable-coordinate stops without
inventing geography. Such trips remain readable but cannot be assigned until a
Draft is replanned. General OSRM driving is explicitly not an HGV routing model;
truck restrictions, traffic, rerouting, and optimization require a later
provider/product decision.

## ADR-018: Incremental MapLibre annotation coordination

**Status:** Accepted

The fleet map separates platform-neutral snapshot diffing from the MapLibre
adapter. The coordinator owns stable truck, status, planned-route, trail, and
stop identities; serializes asynchronous synchronization; and coalesces rapid
inputs so the latest pending snapshot wins. Ordinary tracking polls update only
changed symbol/status geometry and a growing trail. They never globally clear
annotations, recreate the planned route or stops, or move the camera.

A genuine style load is a distinct lifecycle event: the adapter discards stale
MapLibre handles, registers the project-owned truck PNG once, configures its
symbol layer for map-aligned rotation and overlap, and restores the current
snapshot. Camera movement is event-driven—initial fleet fit, filter/selection
change, or explicit recenter—so user pan and zoom remain authoritative between
those events. Stable atomic marker updates are preferred over browser
frame-by-frame interpolation because the current MapLibre Flutter Web annotation
bridge does not provide a cancellation-safe animation primitive.

## ADR-019: Trip-aware tracking context and discontinuity-safe trails

**Status:** Accepted

Tracking providers emit vendor-neutral telemetry and an optional provider run
identity; they do not load or persist transport-domain trips. `TrackingService`
correlates each sample with the active `TrackingTarget` and persists nullable
`TripId`/`RoutePlanId` plus the run identity. Existing rows are not backfilled,
because a truck assignment at migration time cannot prove historical ownership.
Null-trip samples remain valid latest fleet locations but cannot enter trip
history.

The tenant-filtered trip endpoint validates the trip and authoritative truck
assignment, performs one bounded company/trip/time-indexed query, normalizes the
newest bounded window to chronological order, and returns deterministic segments.
The backend owns segmentation so every client shares the same rule: run or route
changes, a configured timestamp gap, or a configured Haversine jump split the
trail. Flutter keys one MapLibre line per segment and diffs each line independently;
normal polling still performs no global clears and no camera movement.

```text
Provider telemetry
  -> application trip correlation
  -> persisted tenant/truck/trip/route/run context
  -> tenant-validated trip history
  -> chronological safe segments
  -> stable Flutter MapLibre line annotations
```

Simulator acceleration advances route distance using scaled simulated elapsed
time while telemetry continues to report physical configured speed. Reset and
route revision changes create a fresh run. Operational ETA uses remaining route
distance and physical speed; it intentionally does not represent accelerated
demo completion time.

## ADR-020: Explicit dispatch-to-pickup and independent movement legs

**Status:** Accepted

Trip execution is `Draft -> Assigned -> EnRouteToPickup -> AtPickup -> Started
-> InTransit -> Delivered -> Completed`. Assignment reserves resources but is
not movement. Dispatch requires a current tenant-owned, online, fresh position
and activates a server-calculated `TripRepositioningPlan`. Arrival is determined
geographically by the backend; `AtPickup` is an explicit waiting state, and
cargo Start revalidates pickup proximity.

Repositioning plans are immutable tenant-owned snapshots with their own origin,
pickup destination, provider metadata, geometry, planned metrics, and lifecycle.
They are never prepended to `TripRoutePlan`. Telemetry identifies
`CurrentLocation`, `Repositioning`, or `Cargo`; approach rows reference a
repositioning plan while cargo rows reference the commercial route. Progress
queries and Flutter layers preserve the same boundary.

```text
trusted latest position -> proposed approach snapshot -> dispatch -> AtPickup
                                                               |
                                                               v explicit Start
immutable cargo route -------------------------------------> cargo execution
```

The simulator receives only the currently executable leg. Assigned and AtPickup
have no moving geometry, eliminating route-origin samples. On process restart it
projects the latest persisted coordinate onto the active immutable geometry and
restores only within a configured tolerance; an unsafe projection never invents
a new coordinate. This mechanism belongs to the Development simulator. Provider
telemetry remains vendor-neutral, while arrival evaluation stays in Application
so future GPS ingestion can invoke the same rule.

Assigned, EnRouteToPickup, AtPickup, Started, and InTransit all reserve the
truck and driver, preventing a second trip from controlling them. EnRouteToPickup
and later execution states present those resources as operationally busy.
Cancellation from any permitted active state releases both consistently.
Completed and Cancelled trips cannot remain an active simulator target.

Planned repositioning distance and duration are retained as non-billable
deadhead metrics for Sprint 4 profitability; they do not alter quoted cargo
distance, cargo duration, or cargo completion percentage.

```text
Latest trusted truck position
  -> route proposal to pickup
  -> activate repositioning leg
  -> telemetry and backend arrival detection
  -> At Pickup
  -> explicit cargo start
  -> cargo route execution
```
