# Sprint 4 — Customer and Fleet Operations

## Role

You are a senior product engineer extending an existing multi-tenant transport-management system after its architecture-stabilization sprint.

Act as:

- Senior ASP.NET Core engineer
- Senior Flutter engineer
- Domain-driven design reviewer
- Fleet operations product designer
- PostgreSQL and EF Core engineer
- Multi-tenant SaaS security reviewer
- QA and browser-acceptance engineer

Your task is to turn the current basic Clients and Trucks CRUD areas into useful operational modules while preserving the validated trip, routing, tracking, and architecture behavior.

This is not a finance sprint.

---

## Repository and Expected Baseline

Repository:

`https://github.com/ahmadqwcv5-droid/transport-management-system`

Expected starting baseline:

`a2b0208 refactor: stabilize sprint 3.5 architecture`

Before editing:

1. Fetch the latest remote state.
2. Record the actual starting commit and current branch.
3. Inspect the worktree and preserve unrelated user changes.
4. Read the current README, architecture decisions, Sprint 3.5 plan, evidence, security review, and quality-gate workflow.
5. Verify the latest GitHub quality-gate status.
6. Run the existing local quality gate before implementing changes.
7. Inspect existing Client, Truck, Driver, Trip, assignment-options, dashboard, tracking, and localization code.

Do not assume the repository still exactly matches the expected commit. Adapt to the real code while preserving its architectural rules.

---

## Sprint Goal

Deliver operationally useful Client and Truck modules that support this workflow:

```text
Client
  -> Contacts
  -> Saved pickup/delivery sites
  -> Trip history

Truck
  -> Operational profile
  -> Current availability
  -> Default driver suggestion
  -> Current position and trip history

Trip Planner
  -> Select client
  -> Reuse a saved client site
  -> Select an eligible truck
  -> Suggest its default driver
  -> Continue through the existing validated route and assignment workflow
```

The sprint must also eliminate stale screens after mutations. After create, edit, archive, restore, deactivate, delete, status change, assignment, or a trip moving between operational groups, every affected list, detail screen, dashboard summary, assignment option, and map view must refresh correctly without requiring a manual browser reload.

---

## Product Principles

1. Client and Truck records are operational master data, not simple form rows.
2. Historical trips must remain readable after a client or truck is archived.
3. Saved client sites must reduce repetitive map selection and coordinate mistakes.
4. A default driver is a suggestion, never a permanent reservation.
5. Operational truck state must have one server-authoritative source.
6. Do not persist duplicate status concepts when they can be safely derived from active trips.
7. Backend authorization, tenant isolation, and database constraints remain authoritative.
8. Flutter must refresh affected state after every successful mutation.
9. Do not use full browser reload as state management.
10. Every new user-visible string must support English and Arabic/RTL.

---

## Mandatory Planning and Time Record

Before implementation, create:

`SPRINT4_IMPLEMENTATION_PLAN.md`

Place it under the repository's established sprint-documentation structure and update the sprint index.

The plan must include:

- Baseline commit and GitHub quality-gate result
- Existing Client and Truck behavior
- Confirmed data-model decisions
- Migration strategy
- Backend use-case ownership
- Flutter screen and state ownership
- Mutation refresh/invalidation matrix
- Multi-tenant and authorization risks
- Testing strategy
- Browser acceptance plan
- Documentation plan
- Task start/end times and active elapsed time
- Final changed-file summary

Update it throughout implementation. Do not reconstruct or invent timing afterward.

---

# 1. Client Operational Profile

## 1.1 Client fields

Preserve existing client fields and add only fields needed for an operational profile.

Support, where not already present:

- Display/trading name
- Optional legal name
- Primary phone
- Primary email
- Main address
- Notes
- Lifecycle state
- Created and updated timestamps

Use explicit lifecycle semantics such as:

- `Active`
- `Suspended`
- `Archived`

Do not maintain contradictory `IsActive`, `Status`, and `ArchivedAt` sources without a documented compatibility strategy. Inspect the current model and choose one authoritative representation.

Required behavior:

- Active clients may be selected for new trips.
- Suspended clients remain visible but cannot receive new trips until reactivated.
- Archived clients are hidden from default lists but retain all history.
- Archived/suspended clients remain visible on historical trips.
- Status changes are audited.

## 1.2 Client detail page

Create a dedicated Client Details page rather than relying only on an edit dialog.

It must show:

- Core profile
- Lifecycle badge
- Primary contact information
- Contacts
- Saved sites
- Active/planned trips
- Recent completed/cancelled trips
- Basic non-financial operational counts
- Activity timeline
- Edit/archive/reactivate actions according to authorization and state

No financial balance, revenue, payment, or profitability information belongs in this sprint.

## 1.3 Contacts

Add tenant-owned client contacts.

Suggested contract:

```text
ClientContact

Id
CompanyId
ClientId
Name
JobTitle
Phone
WhatsApp
Email
IsPrimary
Notes
CreatedAt
UpdatedAt
```

Rules:

- Contact name is required.
- Phone/email remain optional unless product validation proves otherwise.
- At most one primary contact per client.
- Setting a new primary contact demotes the old primary atomically.
- Contacts are tenant-scoped through both CompanyId and client resolution.
- A foreign-tenant client or contact must return safe not-found behavior.
- Deleting a contact must not delete the client or trips.
- Prefer archive/deactivate if a contact becomes historically referenced; otherwise safe deletion is acceptable.

Do not build a user account or login for contacts.

## 1.4 Saved client sites

Add tenant-owned reusable locations for each client.

Suggested contract:

```text
ClientSite

Id
CompanyId
ClientId
Name
Type
Address
Latitude
Longitude
ContactName
ContactPhone
Instructions
IsActive
CreatedAt
UpdatedAt
```

Supported site types:

- Factory
- Warehouse
- Pickup
- Delivery
- Office
- Other

Requirements:

- Name and valid coordinates are required.
- Coordinates use the same validated precision/range rules as trip stops.
- A site can be selected through location search, map click, or manual coordinates using the existing location-picker infrastructure.
- Map click immediately places the marker at the clicked point.
- Site type is a stable internal identifier with localized labels.
- Inactive sites remain visible in historical references but are not offered by default for new trips.
- Site edits do not mutate historical trip-stop snapshots.
- Deleting/archiving a site must not rewrite past trips.
- The site list must be searchable and understandable in Arabic/RTL.

Historical trip stops remain immutable snapshots. A future edit to a saved ClientSite must never move an already planned or executed trip.

---

# 2. Client Activity and Trip History

## 2.1 Trip history

The Client Details page must provide paginated or bounded trip views for:

- Planned/Draft
- Active
- Completed
- Cancelled
- Archived, when explicitly requested

Reuse the server's existing operational grouping and trip query semantics. Do not load all tenant trips into Flutter and filter them locally.

The page should show at least:

- Trip number
- Pickup and delivery labels
- Planned start
- Current status
- Assigned truck/driver when available
- Navigation to trip details

## 2.2 Client activity timeline

Add an append-only client activity timeline or a focused projection from authoritative events.

Record meaningful events such as:

- Client created
- Client details changed
- Contact added/updated/removed
- Primary contact changed
- Site added/updated/archived/restored
- Client suspended/reactivated/archived
- Trip created for client

Avoid noisy events for unchanged saves or list refreshes.

Store stable event codes and localized rendering in Flutter. Do not store translated event text as the source of truth.

---

# 3. Truck Operational Profile

## 3.1 Truck identity and specifications

Extend the truck profile with practical optional fields while preserving existing data:

- Internal fleet number/code
- Plate number
- VIN/chassis number
- Manufacturer/make
- Model
- Year
- Truck type
- Payload capacity
- Payload unit, using one documented unit strategy
- Fuel type
- Current odometer in kilometers
- Notes
- Default driver ID
- Created and updated timestamps

Truck types may include:

- BoxTruck
- Flatbed
- Refrigerated
- Tanker
- TractorTrailer
- DumpTruck
- Other

Fuel types may include:

- Diesel
- Petrol
- Electric
- Hybrid
- Other

Use stable identifiers and localized labels.

Validation:

- Plate number remains unique per tenant using normalized comparison.
- VIN, when provided, is normalized and unique per tenant.
- Internal fleet code, when provided, is unique per tenant.
- Year must be reasonable and bounded.
- Payload cannot be negative.
- Odometer cannot be negative.
- A normal update must not reduce the odometer without an explicit authorized correction flow and audit reason.

Do not hard-block trip assignment by payload because the current Trip model does not yet have authoritative structured cargo weight. Display capacity only.

## 3.2 Default driver

Add an optional default driver relationship.

Rules:

- The driver must belong to the same tenant.
- The driver should be active when newly assigned as default.
- A default driver is not a reservation.
- One driver may be the default for more than one truck unless the current company's validated workflow later requires a one-to-one restriction.
- Actual trip assignment remains authoritative.
- Changing the default driver must not alter existing trip assignments.
- Archiving/deactivating a driver removes or marks the default suggestion safely without corrupting truck history.

When a user selects a truck in the Trip Planner:

- Suggest its default driver only if that driver is currently eligible.
- Never overwrite a driver the user already selected.
- Show why the default driver cannot currently be used.

## 3.3 Truck lifecycle and operational state

Inspect the existing TruckStatus and trip lifecycle before adding anything.

Separate:

- Manual/base fleet state, such as Available, Maintenance, OutOfService, Inactive/Archived.
- Derived operational state, such as Reserved, EnRouteToPickup, AtPickup, OnTrip.

Do not persist two competing status values that can diverge.

Prefer a server-owned operational projection derived from:

- Truck lifecycle/base status
- Current resource-reserving trip
- Current trip status
- Latest tracking state

Example projection:

```text
TruckOperationalStatus

BaseStatus
OperationalState
CurrentTripId
CurrentTripNumber
CurrentDriverId
CanBeAssigned
IneligibilityReasonCode
```

Rules:

- A truck in Maintenance, OutOfService, Inactive, or Archived cannot be assigned.
- A truck reserved by an active trip cannot be assigned again.
- A user cannot manually set a reserved/on-trip truck to Available and bypass the trip lifecycle.
- Entering Maintenance while the truck is reserved must be rejected with an actionable code unless a future explicit emergency workflow is designed.
- Completing, cancelling, or safely unassigning the trip updates the derived operational state.
- Existing database double-assignment protection remains intact.

Do not add a new persisted `Ready` trip status merely because the UI uses a word such as Ready. Reuse the current server-defined readiness/assignment/lifecycle model and document how the UI label maps to it.

---

# 4. Truck Details and History

Create a dedicated Truck Details page.

It must show:

- Identity and specifications
- Base and derived operational status
- Default driver
- Current assigned driver
- Current active trip, if any
- Latest known position
- Online/current/stale/offline state
- Last update time
- Small map with the latest location
- Current route when relevant
- Upcoming/planned assignments when available under current rules
- Recent trip history
- Activity timeline
- Edit/status/archive actions

Do not embed a separately polling map for every truck in the list. Only the details page should show the truck-specific map.

Reuse the existing tracking controller/provider architecture where practical. Do not create a second tracking model.

## Truck activity timeline

Record meaningful stable events such as:

- Truck created
- Profile updated
- Default driver changed
- Odometer updated/corrected
- Base status changed
- Assigned to trip
- Dispatched to pickup
- Cargo trip started
- Trip completed/cancelled/unassigned
- Truck archived/restored

Avoid writing duplicate timeline events for polling or unchanged saves.

---

# 5. Archive and Delete Semantics

## Clients

- A client with trips must not be hard-deleted.
- Archive preserves contacts, sites, events, and trip history.
- An archived client cannot be selected for new trips.
- Restore/reactivate is explicit and audited.
- Hard delete may be supported only for a never-used client with no dependent records, and only if the existing product convention supports it.

## Trucks

- A truck with trip or tracking history must not be hard-deleted.
- A truck reserved by an active trip cannot be archived/deactivated.
- Archive preserves trip and tracking history.
- Archived trucks are hidden by default and excluded from assignment.
- Restore is explicit and audited.
- Hard delete is allowed only for a truly unused record if safe and consistent with the project.

Return stable error codes for blocked operations. Flutter must localize them.

---

# 6. Trip Planner Integration

## 6.1 Client sites

When a client is selected in the Trip Planner:

- Load only that tenant-visible client's active saved sites.
- Offer saved sites in both pickup and delivery controls.
- Selecting a site copies its data into the trip-stop snapshot.
- The user may still search, click the map, or enter coordinates manually.
- After choosing a new map/search location, offer an explicit `Save as client site` action.
- Saving the site must not interrupt or reset the current Draft.
- A saved site update after selection must not mutate the existing Draft stop unless the user reselects it.

## 6.2 Truck enrichment and default driver suggestion

Assignment options must display:

- Plate number
- Internal fleet code, if present
- Truck type
- Payload capacity, if present
- Operational state
- Eligibility and reason

After the user selects an eligible truck:

- Suggest the default driver when eligible.
- Do not silently assign it before the user confirms.
- Do not overwrite a prior explicit driver choice.
- If unavailable, show the reason and keep the user in control.

## 6.3 Preserve existing route and assignment behavior

Do not regress:

- Four-step planner
- Draft resume
- Map-click markers
- Route calculation and route-idempotency
- Assignment options
- Assignment race recovery
- Repositioning preview
- Dispatch to pickup
- Cargo route separation

---

# 7. Mutation Consistency and Automatic Refresh

This is a primary sprint requirement, not optional polish.

The current UI must never require the user to manually reload the browser after a successful mutation.

## 7.1 Mutations covered

At minimum, implement correct refresh after:

- Create client
- Edit client
- Suspend/reactivate client
- Archive/restore client
- Delete unused client
- Add/edit/delete/archive/restore contact
- Add/edit/archive/restore client site
- Create truck
- Edit truck
- Change base truck status
- Set/change/remove default driver
- Update/correct odometer
- Archive/restore truck
- Delete unused truck
- Create/update/archive driver when truck/default-driver views are affected
- Create/update/cancel/archive/delete trip
- Calculate/recalculate route
- Assign/reassign/unassign trip
- Dispatch to pickup
- Arrive at pickup
- Start/mark in transit/deliver/complete trip
- Any transition that moves a trip between Planned, Ready/Assignable, Active, Completed, Cancelled, or Archived UI groups

Do not invent a new persisted Ready status. If the UI has a Ready group, derive membership from current server-authoritative readiness/status rules.

## 7.2 Affected views

After a mutation, refresh all affected projections, which may include:

- Current list
- Current detail page
- Client details and trip tabs
- Truck details and trip tabs
- Assignment options
- Trip list and operational tabs
- Trip details and allowed actions
- Dashboard counters
- Fleet-map truck status and current-trip panel
- Recent trips
- Saved-site selectors
- Default-driver suggestions

Create and document a mutation-to-invalidation matrix in the implementation plan.

Example:

| Mutation | Must refresh |
|---|---|
| Archive client | Client list, client detail/navigation, trip planner client choices, dashboard if counts exist |
| Archive truck | Truck list, truck details/navigation, assignment options, dashboard, fleet map |
| Assign trip | Trip detail/list, truck detail/list, client trip history, assignment options, dashboard, fleet map |
| Complete trip | Trip tabs/detail, truck operational state, client/truck history, dashboard, map |

## 7.3 Flutter consistency design

Use Riverpod consistently.

Implement one explicit invalidation/refresh strategy rather than scattering arbitrary `ref.invalidate` calls with no ownership.

Acceptable approaches include:

- A focused mutation coordinator that declares affected providers.
- Feature controllers that own invalidation of their dependent query providers.
- Repository mutation results followed by awaited authoritative refetches.

Requirements:

- A success message must not appear while the visible screen still shows known stale data.
- Await the necessary refresh/refetch for the current screen.
- Preserve current search, filters, sorting, tab, and pagination when possible.
- If deleting/archiving the final item on a page leaves it empty, move to the previous valid page.
- If the current detail item becomes inaccessible after archive/delete under the current filter, navigate safely back to its list with a success message.
- Back navigation must not reveal cached stale data.
- Concurrent requests must use generation/cancellation/latest-wins protection so an older response cannot overwrite a newer mutation.
- Duplicate taps must not send duplicate mutations.
- A failed mutation must keep the prior UI state and show a localized error.
- Do not use `window.location.reload`, full browser reload, arbitrary delays, or timer-based refresh as the solution.
- Polling may update tracking state, but CRUD/lifecycle correctness must not depend on waiting for the next polling interval.

## 7.4 Backend mutation responses

Where useful and compatible, mutation endpoints should return the updated authoritative representation and version.

However, do not make Flutter depend on optimistic guesses alone. Lists and aggregate projections may still require targeted refetch.

Preserve optimistic concurrency and stable Problem Details codes.

---

# 8. List and Detail UX

## Client list

Support:

- Server-side search
- Lifecycle filters
- Sort by name/recent activity where supported
- Pagination or a bounded scalable list
- Clear empty states
- Archived view
- Direct navigation to details

Display concise information only:

- Name
- Primary contact
- Number of active sites
- Active trip count
- Lifecycle status

## Truck list

Support:

- Search by plate, internal number, VIN, make/model
- Base/operational state filters
- Truck type filter
- Default-driver filter where useful
- Archived view
- Server-side paging where needed

Display:

- Plate and internal fleet number
- Make/model/type
- Operational state
- Current trip
- Current/default driver
- Tracking freshness

Use responsive cards on narrow layouts and a readable table/list on wide layouts.

---

# 9. Backend Architecture

Respect Sprint 3.5 boundaries.

Requirements:

- Keep client use cases behind focused client services/stores.
- Keep fleet use cases behind focused fleet services/stores.
- Do not recreate `IOperationsStore`.
- Do not add a new catch-all `CustomerFleetService`.
- Keep controllers thin.
- Keep EF Core inside Infrastructure.
- Keep tenant identity derived from authentication.
- Do not expose `IQueryable` outside Infrastructure.
- Use one clear owner for lifecycle and operational-status rules.
- Use database constraints for uniqueness and race-sensitive invariants.
- Add reviewed indexes for new common tenant/client/truck queries.

If richer details need projections, prefer focused query contracts rather than loading every related entity and filtering in memory.

---

# 10. Migration and Data Safety

One reviewed EF Core migration is expected if the new entities/fields require it.

Requirements:

- Preserve every existing client, truck, driver, trip, route, event, and tracking row.
- Backfill lifecycle state from existing active/deactivated fields deterministically.
- Do not invent contacts, sites, coordinates, VINs, odometer values, default drivers, or timeline history.
- Existing clients and trucks must remain usable after migration.
- New nullable fields remain null when facts are unknown.
- Unique indexes must handle null optional values correctly in PostgreSQL.
- Foreign keys include tenant-safe resolution at the application level.
- Do not rewrite previous migrations.
- Apply and verify the migration against the retained development PostgreSQL volume without deleting it.
- Confirm no EF model drift afterward.

Review migration SQL for accidental data loss or table recreation.

---

# 11. Authorization and Tenant Isolation

Use existing named policies.

At minimum:

- Owner and Operations may manage clients, contacts, sites, and trucks according to current product policy.
- Read-only roles retain only their current allowed visibility.
- Foreign-tenant IDs return safe not-found behavior.
- Client details never expose another tenant's sites, contacts, trips, or events.
- Truck details never expose another tenant's drivers, trips, positions, or events.
- Default driver assignment resolves the driver under the current tenant filter.
- Saved client sites cannot be attached across tenants.
- Timeline queries remain tenant-filtered and bounded.

Extend architecture tests if new entity/store patterns create a structural rule worth enforcing.

---

# 12. Localization and Accessibility

All new text must use ARB localization.

Verify:

- English/LTR
- Arabic/RTL
- Contact and site forms
- Site-type labels
- Truck-type and fuel-type labels
- Lifecycle and operational-status badges
- Eligibility reason codes
- Empty states
- Archive/delete confirmation dialogs
- Mutation success/error messages
- Map selection instructions
- Long Arabic names and addresses
- Keyboard navigation and visible focus on Flutter Web

Do not use backend English messages as UI text.

---

# 13. Backend Tests

Add integration tests covering at least:

## Clients

- Create/update client profile
- Lifecycle transitions
- Archived/suspended client cannot be selected for a new trip
- Historical trip remains readable
- Search/filter/pagination
- Foreign-tenant access rejection

## Contacts

- Add/update/remove or archive contact
- Atomic primary-contact replacement
- Maximum one primary contact
- Tenant isolation
- Validation

## Sites

- Add/update/archive/restore saved site
- Coordinate validation
- Tenant isolation
- Inactive site excluded from new-trip choices
- Historical trip stop remains unchanged after site edit
- Saved site selection produces a snapshot, not a live reference

## Trucks

- Extended profile validation
- Normalized plate/VIN/internal-code uniqueness per tenant
- Default-driver tenant and active validation
- Default driver does not reserve the driver
- Odometer cannot decrease without correction flow
- Operational projection for available/reserved/en-route/at-pickup/on-trip
- Manual status cannot bypass an active reservation
- Archive/delete rules
- Tracking and trip history retained

## Mutation/lifecycle projections

- Assignment immediately changes truck projection
- Unassignment/cancellation/completion immediately changes projection
- Client and truck detail counts/history reflect the mutation
- Planned/ready/active group membership follows authoritative rules

Keep all existing tests passing.

---

# 14. Flutter Tests

Add focused tests for:

- Client list refresh after create/edit/archive/restore/delete
- Client details contacts/sites/history
- Primary-contact UI
- Saved-site map click places the marker immediately
- Saved-site selection populates trip stop
- Site edit does not alter an existing Draft stop automatically
- Truck list refresh after create/edit/status/archive/restore/delete
- Truck details operational state and latest position
- Default driver suggestion
- Default driver not overwriting explicit selection
- Ineligible default driver reason
- Trip list/tab refresh after lifecycle transition
- Dashboard and assignment-option refresh after assignment/completion/archive
- Search/filter/tab/page preserved after mutation
- Final-page deletion moves to a valid page
- Failed mutation preserves prior state
- Duplicate-tap protection
- Older requests cannot overwrite newer mutation results
- Arabic/RTL and English/LTR

Tests must prove no manual page reload is required.

Do not assert only that repository methods were called; verify the visible updated state.

---

# 15. Mandatory Browser Acceptance

Use a dedicated Development/Testing tenant with known smoke credentials. Preserve the user's retained owner and PostgreSQL volume.

Run in Firefox if Chrome is unavailable.

## Client workflow

1. Login in Arabic/RTL.
2. Create a client.
3. Confirm it appears immediately without reload.
4. Open Client Details.
5. Add two contacts and set one primary.
6. Add a Factory site by clicking the map.
7. Confirm the marker matches the click.
8. Add a Warehouse site through search/manual fallback.
9. Edit the client and confirm details/list refresh immediately.
10. Start a new trip for the client.
11. Select saved Factory and Warehouse sites.
12. Confirm the route step receives snapshot coordinates and calculates normally.

## Truck workflow

13. Create a truck with extended profile.
14. Confirm it appears immediately without reload.
15. Set an active default driver.
16. Open Truck Details and verify profile, status, map/latest-location state, and history.
17. Select the truck in the Trip Planner.
18. Verify the eligible default driver is suggested but not silently confirmed.
19. Assign the trip.
20. Confirm trip details, truck details, truck list, client trip history, dashboard, and assignment options reflect the assignment without browser reload.

## Lifecycle refresh workflow

21. Move the trip through at least one operational transition that changes its UI group, such as Draft/planned to assignable/assigned/active according to existing semantics.
22. Verify it leaves the old tab and appears in the correct new tab immediately.
23. Complete or cancel a disposable trip and verify truck operational availability updates immediately.
24. Archive and restore a disposable client and verify list/detail/planner choices refresh.
25. Archive and restore an unused truck and verify list/dashboard/assignment choices refresh.
26. Delete an unused disposable record and verify it disappears without reload.
27. Switch to English/LTR and repeat one mutation.
28. Logout.

Capture screenshots and machine-readable results under:

`docs/evidence/sprint4/`

Do not claim browser acceptance from widget tests or direct API calls.

---

# 16. Quality Gates

Run:

- Repository local quality-gate script
- .NET Release build with zero warnings/errors
- Architecture tests
- Full backend integration suite
- EF migration apply and drift check
- Flutter formatting verification
- Flutter analyzer
- Full Flutter tests
- Flutter Web production release build
- Flutter Web Development/Testing build if required
- Docker Compose health checks
- Real PostgreSQL validation
- Mandatory authenticated Firefox workflows

Ensure the GitHub Actions workflow includes all new test projects/files automatically or update it safely.

After the changes are pushed by the user, distinguish local validation from actual GitHub-hosted CI status.

Android:

- Build/run only if a valid SDK and device/emulator exist.
- Otherwise report the precise blocker without claiming success.

---

# 17. Documentation

Update:

- `README.md`
- `docs/architecture.md`
- Sprint index
- `SPRINT4_IMPLEMENTATION_PLAN.md`
- `docs/evidence/sprint4/README.md`

Document:

- Client lifecycle
- Contacts and primary-contact rule
- Saved-site snapshot semantics
- Truck profile fields
- Default-driver suggestion semantics
- Base versus derived truck operational state
- Archive/delete rules
- Mutation invalidation/refresh matrix
- Provider ownership in Flutter
- New APIs and error codes
- Migration/backfill decisions
- Browser acceptance procedure
- Known limitations

Add or supersede ADRs when architecture decisions change. Do not leave contradictory current ADRs.

---

# 18. Explicitly Out of Scope

Do not implement:

- Revenue
- Expenses
- Payments
- Receivables
- Profitability
- Contracts or pricing rules
- Tax/VAT/accounting
- Full maintenance work orders
- Maintenance costs
- Document upload/storage
- Insurance/registration expiry workflows
- Driver or truck profile photos
- Excel/CSV import
- Custom fields
- Real GPS provider integration
- SignalR
- Route optimization
- Cargo-capacity hard enforcement
- Subscription billing

Do not turn this sprint into Finance, Maintenance, or Document Management.

---

# 19. Definition of Done

Sprint 4 is complete only when:

- Clients have operational detail pages.
- Multiple contacts and one primary contact work safely.
- Saved client sites support map/search/manual selection.
- Saved sites integrate with the Trip Planner as immutable stop snapshots.
- Client lifecycle/archive behavior preserves history.
- Trucks have extended operational profiles.
- Default driver suggestion works without creating a reservation.
- Truck base and derived operational state have one authoritative design.
- Truck details show current trip, tracking freshness, and history.
- Archive/delete rules protect historical and active data.
- Every covered mutation refreshes affected visible state without manual browser reload.
- Trip movement between operational tabs/groups appears immediately.
- Search/filter/tab/page state is preserved where appropriate.
- Stale older responses cannot overwrite a newer mutation.
- Multi-tenant isolation is tested for every new entity and query.
- Existing trip, route, tracking, simulator, and map workflows remain intact.
- .NET build passes with zero warnings/errors.
- Architecture tests pass.
- All backend integration tests pass.
- Flutter analyzer is clean.
- All Flutter tests pass.
- Flutter Web release build passes.
- EF migration applies successfully and no drift remains.
- Docker Compose API/PostgreSQL are healthy.
- Real Firefox client/truck/trip refresh workflows pass.
- Arabic/RTL and English/LTR evidence exists.
- Documentation and evidence are complete.

---

# 20. Git and Safety Constraints

- Do not commit.
- Do not push.
- Do not create or merge a pull request.
- Do not reset or discard unrelated user changes.
- Do not overwrite `.env`.
- Do not reset retained credentials.
- Do not delete or recreate the retained PostgreSQL volume.
- Do not rewrite previous migrations.
- Do not fabricate screenshots, CI results, or test results.
- Recreate only the minimum required containers if Compose repair is necessary.
- Leave all Sprint 4 changes uncommitted for user review.

---

# 21. Required Final Report

Provide:

## Implemented

- Client profile, contacts, sites, lifecycle, details, and timeline
- Truck profile, default driver, operational state, details, and timeline
- Trip Planner integration
- Mutation refresh architecture
- Migration and compatibility work

## Refresh evidence

Provide a mutation-to-refreshed-views table and explicitly report evidence for:

- Delete
- Archive/restore
- Status change
- Default-driver change
- Trip assignment
- Trip transition between operational groups
- Trip completion/cancellation and truck release

State whether any tested workflow required a manual page reload. The required answer for completion is `No`.

## Validation

- .NET build result
- Architecture test count
- Backend integration test count
- Flutter analyzer result
- Flutter test count
- Web build result
- EF migration/drift result
- PostgreSQL/Compose result
- Browser acceptance result
- GitHub CI status, only if actually executed after a push
- Android result or exact blocker

## Evidence and timing

- Evidence directory
- Implementation plan
- Task-level active elapsed times
- Total active elapsed time

## Git status

Confirm that no commit, push, or PR was performed and summarize changed files.

If any mandatory refresh workflow, tenant-isolation test, quality gate, or browser workflow fails, report Sprint 4 as incomplete rather than weakening the acceptance criteria.
