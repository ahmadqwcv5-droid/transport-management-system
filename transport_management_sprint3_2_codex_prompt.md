# Codex Implementation Prompt — Sprint 3.2: Route-Aware Trips and Professional Fleet Operations Map

## Role

Act as a senior transportation-management product engineer, GIS engineer, software architect, ASP.NET Core engineer, and Flutter engineer.

Work inside the existing `transport-management-system` repository. Inspect the current implementation before changing anything. Preserve its architecture, tenant isolation, localization, tests, and existing Sprint 3/3.1 behavior unless this sprint deliberately replaces a documented limitation.

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected baseline commit at the time this prompt was prepared:

```text
81571c1 feat: harden Sprint 3 map and tracking
```

Do not assume the repository still matches that commit. Record the actual HEAD and working-tree state before implementation.

---

# Sprint Name

**Sprint 3.2 — Route-Aware Trips and Professional Fleet Operations Map**

## Product Goal

Transform the current tracking demonstration into a route-aware transport workflow:

```text
Choose pickup location
        ↓
Choose delivery location
        ↓
Calculate a road-following route
        ↓
Preview distance and estimated duration
        ↓
Create and assign the trip
        ↓
Start the trip
        ↓
Move the simulated truck along the planned road geometry
        ↓
Show progress, remaining distance, ETA, and actual trail
        ↓
Reach the delivery location
```

This sprint must make a fundamental product and domain improvement. It is not a visual-only map redesign.

---

# Why This Sprint Is Necessary

The current simulator generates synthetic coordinates along a fixed straight interpolation and offsets each truck by index. It is not driven by a trip's pickup location, delivery location, or road geometry.

The current trip stores `Origin` and `Destination` primarily as free-text strings. It therefore cannot reliably:

- draw the planned route,
- calculate distance or duration,
- move a vehicle along roads,
- determine route progress,
- estimate arrival,
- compare planned and actual movement,
- or distinguish a real location from an arbitrary label.

The current fleet map uses circles for trucks. Multiple vehicles placed on the same synthetic line can look like a trail of points even when each point represents a different truck.

Sprint 3.2 must correct these root causes.

---

# Product Patterns to Learn From

Use the following global fleet-management patterns as product guidance, not as a request to clone a vendor UI or implement enterprise-scale complexity.

## Geotab patterns

Geotab models routes as paths made from stops/waypoints. Users can select real-world addresses or click the map, reorder stops, distinguish planned routes from templates, and analyze arrival/departure, stop duration, and route adherence.

References:

- https://support.geotab.com/help/mygeotab/fleet-activity/routes/routes
- https://www.geotab.com/fleet-management-solutions/routing-dispatching/
- https://www.geotab.com/blog/routing-and-optimization-updates/

## Samsara patterns

Samsara emphasizes live vehicle location, route progress, stops, dispatch, ETA, and operational visibility from one fleet view.

References:

- https://www.samsara.com/products/routing-and-dispatch
- https://developers.samsara.com/docs/routes

## Webfleet patterns

Webfleet connects order scheduling and dispatch with route visualization, real-time progress, ETA, rescheduling, and driver-facing order details.

References:

- https://www.webfleet.com/en_us/webfleet/products/webfleet/features/order-dispatching-optimisation/
- https://www.webfleet.com/en_us/webfleet/products/mobile-apps/work-app/

## Patterns to adopt now

- Locations are structured geographic data, not only strings.
- A planned route is a stored snapshot, distinct from actual tracking history.
- Stops are first-class and ordered.
- Managers see one current marker per truck.
- Selecting a truck or trip reveals its planned route and actual progress.
- ETA and remaining distance are derived from the selected route and current position.
- Planned versus actual movement can be compared.
- Map and operational information work together in one screen.

## Patterns explicitly deferred

- Multi-vehicle optimization
- Automatic stop reordering
- Live-traffic rerouting
- Driver mobile workflow
- Customer public tracking links
- Proof of delivery
- Route cost optimization
- Complex time windows and vehicle-capacity constraints

---

# Mandatory Planning and Documentation

Create and continuously update:

```text
SPRINT3_2_IMPLEMENTATION_PLAN.md
```

It must contain:

- Actual repository HEAD and worktree state
- Baseline analysis
- Existing limitations confirmed from code
- Proposed domain model and rationale
- Migration/backfill strategy
- Provider strategy
- UI flow and wire-level description
- Task breakdown
- Risks and mitigations
- Test plan
- Acceptance-criteria checklist
- Actual elapsed time per task
- Total actual sprint time
- Deferred work

Do not present estimates as actual elapsed time.

Also update:

```text
README.md
docs/architecture.md
```

Add an ADR if that matches the existing architecture-document style.

---

# Required Architecture

## 1. Separate Location, Routing, and Tracking

The implementation must preserve three distinct responsibilities:

```text
IGeocodingProvider
    Answers: Where is this address or selected point?

IRoutingProvider
    Answers: What road-following route connects these stops?

ITrackingProvider
    Answers: Where is this truck now?
```

Do not let Flutter call a routing or geocoding vendor directly if that would expose credentials, bypass tenant policy, or tightly couple the UI to a vendor contract. Prefer backend application abstractions and infrastructure adapters.

The Domain and Application layers must not depend on MapLibre, OSRM, Google Maps, Mapbox, OpenRouteService, Nominatim, or another vendor SDK/type.

## 2. Geocoding abstraction

Introduce an abstraction capable of:

- forward search from a query,
- reverse lookup from latitude/longitude where supported,
- returning a stable application-owned result shape,
- cancellation and timeout,
- provider-unavailable and no-results outcomes.

Suggested application contract:

```text
GeocodingResult
- ProviderPlaceId (optional, never a domain identity)
- DisplayName
- Address
- Latitude
- Longitude
- BoundingBox (optional)
```

Requirements:

- Search input must be debounced.
- Stale search responses must not replace newer results.
- Minimum query length must be configurable or sensible.
- Manual map selection must work even when no geocoding provider is configured.
- Public geocoding endpoints must not be abused or treated as production infrastructure.
- Do not implement autocomplete against a provider whose policy prohibits it.
- Provider keys, if any, remain server-side and out of source control.

## 3. Routing abstraction

Introduce an `IRoutingProvider` abstraction capable of accepting ordered stops and returning:

```text
RouteResult
- Ordered route coordinates or encoded geometry
- Geometry format/version
- DistanceMeters
- EstimatedDurationSeconds
- ProviderName
- ProviderRouteId (optional)
- CalculatedAt
- RouteProfile
- Warnings
```

Requirements:

- Support at least pickup and delivery.
- Design the contract to support future intermediate waypoints without redesign.
- Accept a route profile/vehicle profile through an application-owned model.
- Do not claim HGV/truck-aware routing if the configured provider only offers general driving routes.
- Return deterministic application errors for no route, provider timeout, provider failure, invalid coordinates, and unsupported profile.
- Use resilient HTTP behavior: timeout, cancellation, bounded retry only where safe, and clear logging without secrets.
- Add a deterministic fake provider for automated tests.
- A development HTTP provider may be implemented using an OSRM-compatible API or another documented service, but public demo infrastructure must be labeled development-only.
- Provider base URL and credentials must be configurable.

## 4. Provider caching and route snapshots

Do not call the external routing provider on every map render or tracking poll.

- Calculate when a draft's geographic stops change or when the user explicitly requests recalculation.
- Store the accepted route as a trip-owned immutable snapshot once the trip starts.
- Cache safe duplicate calculations where appropriate.
- Record provider name, profile, calculation timestamp, distance, duration, and geometry version.
- Editing a draft stop must invalidate or replace its previous route plan transactionally.

---

# Domain and Data Model

## 5. Make trip stops first-class

Replace the assumption that origin and destination are only strings with structured trip stops.

Prefer a future-safe model such as:

```text
TripStop
- Id
- CompanyId
- TripId
- Sequence
- Type: Pickup | Delivery | Waypoint
- Name
- Address
- Latitude
- Longitude
- PlannedArrivalAt (optional)
- PlannedServiceDurationMinutes (optional; may remain unused in this sprint)
```

For Sprint 3.2, the UI must require exactly one pickup and one delivery for a new route-aware trip. The domain should not block future intermediate waypoints.

Coordinates must be validated:

- Latitude: -90 through 90
- Longitude: -180 through 180
- Pickup and delivery cannot be effectively identical

Keep tenant ownership explicit and enforced.

## 6. Store the planned route separately

Use a distinct route-plan model, for example:

```text
TripRoutePlan
- Id
- CompanyId
- TripId
- Geometry
- GeometryFormat
- GeometryVersion
- DistanceMeters
- EstimatedDurationSeconds
- ProviderName
- RouteProfile
- CalculatedAt
- StopsFingerprint or route revision
```

The exact model may differ, but it must preserve these concepts.

Planned route geometry and actual truck-position history are different datasets. Never mix them in one table or return shape.

## 7. Safe migration of existing trips

Create a real migration only if required by the final model.

Requirements:

- Do not destroy existing trip labels or history.
- Backfill existing `Origin`/`Destination` text into stop labels where practical.
- Existing trips without coordinates must remain readable.
- Mark legacy drafts/trips as requiring location selection before route calculation rather than inventing coordinates.
- New route-aware trips must require valid pickup/delivery coordinates.
- If legacy columns remain temporarily for compatibility, document the transition and keep one authoritative write path.
- Migration must be tenant-safe and reversible according to the repository's normal migration practice.

## 8. Route immutability rules

- Draft trip: stops and route may be edited/recalculated.
- Assigned trip: choose and document whether route editing is forbidden or requires explicit unassign/replan behavior. Prefer a simple safe rule.
- Started/InTransit/Delivered/Completed trip: planned-route snapshot must not silently change.
- Route calculation failure must not leave a half-updated trip.

---

# Backend Application Behavior

## 9. Trip planner APIs

Add or adapt tenant-scoped APIs for:

- Location search
- Optional reverse geocoding
- Route preview before save
- Create/update a draft with structured stops
- Retrieve a trip with stops and planned route
- Retrieve route progress for an active trip

Suggested flow:

```text
POST /api/locations/search or GET with encoded query
POST /api/routes/preview
POST /api/trips
PUT  /api/trips/{id}
GET  /api/trips/{id}
GET  /api/trips/{id}/route-progress
```

Follow the repository's established API style rather than forcing these exact paths.

Requirements:

- Authentication required.
- Company/tenant is derived from the authenticated context.
- Do not trust client-supplied CompanyId.
- Validate coordinate ranges and ordered stops.
- Apply request limits to geocoding searches.
- Never expose provider secrets or raw vendor error payloads.
- Use stable error codes for Flutter localization.

## 10. Route progress model

Provide an application-owned progress result with at least:

```text
TripRouteProgress
- TripId
- TruckId
- PlannedDistanceMeters
- TravelledDistanceMeters
- RemainingDistanceMeters
- ProgressPercent
- EstimatedArrivalAt
- DistanceFromPlannedRouteMeters
- IsOffRoute
- CurrentSegmentIndex
- OperationalPhase
- LastPositionAt
```

Use defensible geographic calculations. For a fleet of seven trucks, an in-memory calculation over the selected route geometry is acceptable if tested and bounded; PostGIS is not required merely for fashion.

Requirements:

- Project the current position onto the planned route rather than using straight-line distance to the destination as total progress.
- Clamp progress to a valid range.
- Remaining distance follows the route geometry.
- ETA uses remaining route distance and a documented speed assumption/current simulated speed; it must handle zero speed gracefully.
- Off-route threshold is configurable.
- The result must distinguish unavailable tracking from zero progress.
- Never automatically mutate the commercial trip status solely because a simulated/GPS point entered a radius.

## 11. Operational phases

Compute display-oriented phases such as:

```text
Awaiting start
At pickup
In transit
Approaching delivery
At delivery
Off route
Tracking unavailable
Completed
```

These phases support the dashboard UX. They must not bypass the existing trip-state transition rules.

---

# Simulator Redesign

## 12. Remove polling-driven movement

The current simulator must no longer advance merely because `GET /positions` was called.

HTTP reads must be observational and idempotent with respect to simulation progress.

Requirements:

- Movement is based on elapsed simulated time or explicit deterministic step commands.
- Changing frontend polling from 3 seconds to 10 seconds must not change simulated travel speed.
- Repeated simultaneous reads must not accelerate a vehicle.
- Pause freezes the current route distance.
- Resume continues from the same location.
- Reset returns the selected truck to the route origin.
- Stop follows the existing documented simulator semantics or is revised consistently and documented.
- Speed multiplier accelerates simulated time; it must not produce impossible jumps beyond the destination.
- Offline state affects availability without corrupting route progress.

## 13. Route-aware movement

Simulator state must be keyed safely by tenant, truck, and active trip/route revision.

For a truck assigned to a route-aware active trip:

1. Load the stored planned-route geometry.
2. Calculate cumulative distance across its segments.
3. Advance by travelled distance, not by array index alone.
4. Interpolate within the current segment.
5. Calculate heading from the active segment.
6. Stop exactly at the delivery location.

Requirements:

- A truck without an eligible route-aware trip remains stationary; it must not be placed on a global synthetic line.
- Different trucks on different trips follow different route geometries.
- All trucks must not share the same fixed Ankara–Istanbul-style route.
- At most one active route can drive a truck at a time under current assignment rules.
- Simulator state is development-only.
- If simulator state remains in memory, document restart behavior honestly.
- Do not duplicate route calculations inside Flutter.

## 14. Arrival behavior

When the simulated truck reaches delivery:

- set speed to zero,
- retain the final position,
- report an `At delivery` operational phase,
- do not automatically mark the business trip Delivered or Completed,
- allow the manager to perform the existing domain transition manually.

---

# Flutter Product Experience

## 15. Replace the small trip dialog with a real trip planner

The current cramped modal form is no longer sufficient.

Create a responsive full-page or large structured trip-planning experience.

Recommended desktop layout:

```text
┌───────────────────────────┬──────────────────────────────────┐
│ Trip details              │                                  │
│                           │                                  │
│ Client                    │             MAP                  │
│ Pickup search             │                                  │
│ Pickup result/card        │       pickup ●──────● delivery  │
│ Delivery search           │                                  │
│ Delivery result/card      │                                  │
│ Cargo                     │                                  │
│ Planned start             │                                  │
│ Price                     │                                  │
│                           │                                  │
│ Distance / duration       │                                  │
│ [Recalculate] [Save]      │                                  │
└───────────────────────────┴──────────────────────────────────┘
```

On narrow Android/mobile layouts, stack the map and form vertically without losing functionality.

## 16. Location selection UX

For both pickup and delivery, support:

- Search by place/address when a geocoder is configured.
- Select a search result.
- Click/tap the map to place the active stop.
- Drag or reselect the stop if the map library supports it reliably.
- Display selected name/address and coordinates.
- Clear and replace the selection.
- Visually distinguish pickup and delivery.
- Fit the camera to both selected stops and route preview.

The UI must remain functional in manual map-selection mode when geocoding is unavailable.

## 17. Route preview UX

After valid pickup and delivery are selected:

- Calculate the route explicitly or automatically with debouncing/cancellation.
- Draw a road-following polyline.
- Display total distance in km and estimated duration in a localized friendly form.
- Show routing profile/provider limitation if the route is not truck-aware.
- Display clear localized errors for no route, timeout, unsupported profile, and provider unavailable.
- Never draw a straight line and label it as a calculated road route.
- Do not save a new route-aware trip until a valid route snapshot exists, unless the user explicitly chooses a documented legacy/manual workflow.

## 18. Professional fleet map

Redesign the operational fleet map while preserving the robust Sprint 3.1 lifecycle states.

Requirements:

- Use a road-detailed, configurable map style appropriate for fleet operations.
- Keep map-style configuration replaceable and do not hard-code a paid key.
- Show one current icon per truck, not a circle for every historical point.
- Use a locally owned/licensed truck icon asset or a code-native vector asset.
- Rotate the icon according to heading.
- Visually distinguish online, offline, selected, moving, stationary, maintenance, and out-of-service states without relying on color alone.
- Selected truck receives a visible halo or emphasis.
- Fit camera bounds intelligently.
- Provide a small map legend.
- Keep the fallback mode truthful and usable.
- Do not present nine trucks aligned on one synthetic route.

## 19. Selected trip/truck map detail

When the user selects an active truck or trip, show:

- Pickup marker
- Delivery marker
- Planned route polyline
- Actual travelled trail from tracking history
- Current truck icon
- Driver name
- Plate number
- Speed
- Tracking status
- Trip status
- Operational phase
- Progress percentage
- Remaining distance
- ETA
- Last update time
- Off-route warning if applicable

Suggested visual distinction:

```text
Planned route: blue
Travelled portion/history: darker green or another accessible contrasting style
Remaining route: lighter blue
Pickup: green pin
Delivery: red pin
Current truck: directional truck icon
```

Do not render all fleet history by default. Fetch/display the actual trail only for the selected truck/trip and keep limits bounded.

## 20. Fleet list and filters

Beside or over the map, provide a compact responsive list/filter experience:

- All trucks
- On trip
- Available/stationary
- Offline
- Maintenance/out of service

Selecting a row must select and focus the corresponding marker. Selecting a marker must select the corresponding row/card.

Do not build enterprise clustering unless needed for correctness. Seven vehicles do not require complex clustering.

## 21. RTL/LTR and localization

All new user-facing strings must use ARB localization.

Verify:

- Arabic/RTL trip planner
- English/LTR trip planner
- Search results
- Route errors
- Distance/duration/ETA
- Map legend
- Operational phases
- Progress cards
- Simulator controls

Map compass/zoom controls and overlays must remain usable in both directions.

---

# Map and Geometry Quality

## 22. Road visibility

The current demonstration style emphasizes country boundaries and may not visually communicate roads at the initial zoom.

Requirements:

- Use a configurable development style that visibly includes roads at useful city/regional zoom levels.
- Set sensible min/max/default zoom.
- Fit to route bounds after route preview and selection.
- Avoid defaulting to an entire-country view when the relevant trip is local.
- Document that MapLibre is the renderer and the configured style/tile source determines cartographic detail.
- Do not imply that a map-style change creates routing capability.

## 23. Geometry handling

- Use a documented geometry format.
- Parse and validate provider geometry safely.
- Avoid sending unnecessarily huge geometry payloads.
- Preserve enough precision for road-following display and interpolation.
- Handle antimeridian/invalid geometry defensively if the chosen libraries expose such cases.
- Do not assume route coordinates are latitude/longitude if a provider returns longitude/latitude; normalize at the adapter boundary and test this explicitly.

---

# Security, Multi-Tenancy, and Reliability

## 24. Tenant isolation

Every new stop, route plan, route preview, progress query, history query, and simulator state must remain tenant-scoped.

Add integration tests proving:

- Tenant A cannot read Tenant B's trip route.
- Tenant A cannot preview or mutate using Tenant B's trip/truck IDs.
- Tenant A cannot retrieve Tenant B's actual trail.
- Simulator state does not leak between companies.

## 25. Provider safety

- Store provider secrets in configuration/environment only.
- Never return provider keys to Flutter.
- Never log secrets or full sensitive provider URLs.
- Validate outbound base URLs through configuration; do not accept an arbitrary provider URL from the client.
- Apply timeouts and cancellation.
- Normalize provider errors into stable application error codes.
- Rate-limit or otherwise bound geocoding search endpoints using the project's appropriate mechanism.

## 26. Failure behavior

The product must remain understandable when:

- geocoding is unconfigured,
- routing is unconfigured,
- the provider is slow,
- no route exists,
- map style fails,
- tracking is unavailable,
- a legacy trip has labels but no coordinates.

Never replace a failed road route with an unlabeled straight line.

---

# Testing Requirements

## 27. Backend unit tests

Test at least:

- Coordinate validation
- Stop ordering/type validation
- Pickup and delivery cannot be identical
- Route-plan replacement for a draft
- Route immutability after start
- Provider adapter coordinate order normalization
- Geometry distance calculation
- Projection of a position onto the route
- Progress percentage and clamping
- Remaining distance
- ETA behavior at moving, stationary, and destination states
- Off-route threshold
- Route-aware interpolation
- Heading calculation
- Pause/resume/reset
- Polling/read idempotency
- Multiple trucks on different routes
- Arrival stops exactly at delivery

## 28. Backend integration tests

Test at least:

- Location search through a fake provider
- Route preview through a deterministic fake provider
- Route-aware trip creation
- Migration/backward compatibility for legacy trips
- Authentication and role behavior
- Tenant isolation
- Simulator uses the assigned trip route
- Unassigned/no-route truck remains stationary
- Position history is not duplicated by repeated unchanged reads
- Movement persists meaningful new positions
- Progress endpoint reflects movement

## 29. Flutter tests

Test at least:

- Trip planner validation
- Pickup selection from map
- Delivery selection from map
- Search stale-response protection
- Route preview loading/success/failure
- Road-route polyline layer receives geometry
- Truck icon selection and details
- Heading/rotation mapping
- Fleet filters
- Planned route versus actual trail visibility
- Arabic RTL and English LTR
- Legacy trip without coordinates
- Provider unavailable states

## 30. Browser smoke test

Perform a real browser workflow where the environment permits:

1. Login.
2. Switch to Arabic and verify RTL.
3. Create a new trip through the full trip planner.
4. Select pickup on the map or by search.
5. Select delivery on the map or by search.
6. Calculate a road-following route.
7. Visually verify the route follows visible roads rather than a straight chord.
8. Verify distance and duration are shown.
9. Save and assign the trip.
10. Start/mark the trip in transit through the existing valid state transitions.
11. Start the simulator.
12. Verify one truck icon moves along the planned polyline.
13. Verify icon heading changes with route direction.
14. Verify progress increases and remaining distance decreases.
15. Verify ETA is present and reasonable for the simulation.
16. Pause and confirm repeated polling does not move the truck.
17. Resume and confirm movement continues from the same location.
18. Verify the actual trail appears only for the selected trip/truck.
19. Verify a second truck can follow a different route.
20. Switch to English and verify LTR.
21. Logout.

Capture screenshot evidence for:

- Planner with two selected stops
- Road-following route preview
- Fleet map with directional truck icons
- Selected trip with planned route and actual trail
- Arabic/RTL view

Do not claim visual verification if only widget-state assertions were performed.

---

# Data and API Compatibility

## 31. Update all consumers

Update consistently:

- Domain entities/value objects
- EF configurations and migrations
- Application contracts/services
- API endpoints
- Flutter domain models
- Flutter repository/data layer
- Forms and details screens
- Dashboard/fleet map
- Integration tests
- Seed/test data
- README and architecture documentation

Do not leave a split model in which some screens write only text while others expect geographic stops.

## 32. API evolution

Prefer an explicit contract change or versioned compatibility path over fragile optional-field guessing.

If the existing API contract must remain temporarily compatible:

- document which fields are legacy,
- define the authoritative fields,
- add tests for old and new payloads,
- and avoid permanent duplication.

---

# Acceptance Criteria

Sprint 3.2 is complete only when all applicable criteria are proven:

- [ ] New trips store structured pickup and delivery coordinates.
- [ ] Existing legacy trips remain readable without invented coordinates.
- [ ] User can select pickup and delivery by clicking/tapping the map.
- [ ] Search-based place selection works when a geocoder is configured.
- [ ] A backend routing abstraction calculates a road-following route.
- [ ] Route provider credentials/configuration do not leak to Flutter.
- [ ] Planned geometry, distance, duration, provider, profile, and calculation time are stored.
- [ ] Route is immutable once the trip has started.
- [ ] The route preview visibly follows roads and is not a disguised straight line.
- [ ] Fleet map uses one directional truck icon per current truck.
- [ ] Truck icons rotate according to heading.
- [ ] Active trip selection shows pickup, delivery, planned route, current position, and actual trail.
- [ ] Simulator movement is driven by the selected trip's planned geometry.
- [ ] Trucks without route-aware active trips do not move on a global synthetic line.
- [ ] Different trucks can follow different routes.
- [ ] GET/polling does not advance simulation.
- [ ] Pause/resume/reset behave deterministically.
- [ ] Progress and remaining distance follow route geometry.
- [ ] ETA handles movement and zero-speed states honestly.
- [ ] Arrival stops at the delivery point without auto-completing the business trip.
- [ ] Off-route display logic is tested.
- [ ] Arabic/RTL and English/LTR are verified.
- [ ] Tenant isolation is enforced and tested for all new data and endpoints.
- [ ] Backend build succeeds with no new warnings.
- [ ] Backend tests pass.
- [ ] EF migration drift check passes.
- [ ] Flutter analyzer is clean.
- [ ] Flutter tests pass.
- [ ] Flutter Web release build passes.
- [ ] Compose services are healthy.
- [ ] Browser smoke test and screenshot evidence verify the real user flow.
- [ ] Documentation matches actual behavior and limitations.
- [ ] Actual elapsed time is recorded per task and in total.

If a required criterion is blocked, mark Sprint 3.2 as **Blocked/Partially Complete**, identify the exact blocker, and do not substitute synthetic success.

---

# Explicitly Out of Scope

Do not implement these in Sprint 3.2:

- Finance, expenses, invoices, payments, receivables, or profitability
- Real GPS hardware integration
- Traccar/Wialon/Teltonika integration
- SignalR/WebSockets
- Live traffic
- Automatic rerouting
- Multi-vehicle route optimization
- Automatic stop-order optimization
- Truck restriction routing unless a configured provider genuinely supports it
- Driver application/navigation
- Customer public tracking links
- Proof of delivery
- Geofence alerts beyond the minimum route-progress/arrival calculation
- Maintenance and documents
- Route templates/import
- Multi-stop UI beyond pickup and delivery
- Automatic commercial trip state mutation from tracking
- Large-scale telemetry partitioning/archival

Preserve extensibility for these features without partially implementing them.

---

# Engineering Constraints

- Inspect `AGENTS.md` and repository instructions first if present.
- Preserve unrelated changes.
- Do not run destructive Git commands.
- Do not commit or push unless the user explicitly requests it.
- Follow existing Clean Architecture/domain conventions.
- Keep MapLibre in the presentation layer.
- Keep provider-specific DTOs in Infrastructure.
- Use application-owned contracts across boundaries.
- Use ARB for every new user-facing string.
- Keep tests deterministic; automated tests must not depend on public internet services.
- Do not hard-code production keys, tenant IDs, machine paths, or paid-provider URLs.
- Do not hide provider failures or downgrade tests merely to pass.
- Prefer reviewable components over a single oversized map/widget/service file.
- Document any architectural compromise.

---

# Required Final Report

Provide a concise, evidence-based final report with these sections.

## Baseline

- Actual starting commit
- Working-tree state
- Confirmed root limitations

## Global Product Patterns Applied

- Which Geotab/Samsara/Webfleet patterns were adopted
- Which were deferred and why

## Architecture Implemented

- Stop/location model
- Route-plan model
- Geocoding abstraction and configured adapter
- Routing abstraction and configured adapter
- Progress calculation
- Simulator redesign

## User Experience Implemented

- Trip planner
- Map location selection
- Route preview
- Professional truck markers
- Selected trip details
- Planned versus actual route
- RTL/LTR

## Migration and Compatibility

- Migration name
- Existing-data backfill behavior
- Legacy-trip behavior
- Migration drift result

## Validation Results

List exact commands and PASS/FAIL/BLOCKED results for:

- Backend build
- Backend unit/integration tests
- EF migration drift
- Flutter generation/format/analyze/tests
- Flutter Web release build
- Android build if SDK exists
- Compose health
- Browser smoke test

## Map and Route Proof

Report separately:

```text
Road-detailed map style visibly loaded: PASS/FAIL/BLOCKED
Pickup/delivery selected on map: PASS/FAIL/BLOCKED
Road-following route returned by provider: PASS/FAIL/BLOCKED
Route visibly followed roads: PASS/FAIL/BLOCKED
Truck icon moved along stored route geometry: PASS/FAIL/BLOCKED
Planned and actual paths were visually distinct: PASS/FAIL/BLOCKED
Polling did not control simulation speed: PASS/FAIL/BLOCKED
```

## Simulator Evidence

For a fixed scenario, provide:

- Planned route distance
- Simulated speed/multiplier
- Position before polling burst
- Position after polling burst while paused
- Position after resume/step
- Progress before and after movement
- Final position at delivery

## Tests Added

- Important test names
- What each proves
- What remains outside their proof

## Screenshots

List the saved evidence paths for:

- Planner
- Route preview
- Moving truck
- Planned versus actual route
- Arabic/RTL

## Changed Files

Group by:

- Domain
- Application
- Infrastructure
- API
- Flutter
- Tests
- Documentation

## Timing

- Actual time per task
- Total actual sprint time

## Environment Limitations

- Browser
- Android SDK/device
- Provider credentials/network
- Map style/tile limitations

## Deferred Items

List all intentionally deferred features and any incomplete acceptance criteria.

## Git Status

State whether changes are uncommitted, committed, or pushed. Do not commit or push unless explicitly requested.
