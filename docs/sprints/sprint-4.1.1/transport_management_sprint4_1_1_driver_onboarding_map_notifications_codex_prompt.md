# Sprint 4.1.1 — Driver Onboarding, Live Map UX, and Audible Operational Alerts

## Role

Act as a senior product engineer, logistics-domain analyst, UX engineer, Flutter engineer, ASP.NET Core engineer, security reviewer, and test engineer.

Work directly in the existing repository. First read the repository instructions, architecture documentation, current Sprint 4.1 implementation plan, and relevant tests. Inspect the current implementation before changing anything. Do not assume that the Sprint 4.1 report proves the real user workflow.

This is a focused stabilization sprint. Do not broaden it into finance, maintenance, real GPS integration, push notifications, or a general redesign.

---

# Repository and Baseline

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected baseline at the beginning of this sprint:

```text
3f741a5 feat(operations): add live fleet driver workflow
```

Confirm the actual checked-out commit and working-tree state before implementation. Preserve all unrelated user changes. Never reset, discard, overwrite, or reformat unrelated work.

The current system already includes:

- ASP.NET Core backend.
- PostgreSQL and EF Core migrations.
- Flutter Web client with Arabic/English localization and RTL/LTR.
- Multi-tenant company isolation.
- Clients, client sites, trucks, drivers, and trips.
- Route calculation, approach-to-pickup routing, and simulator tracking.
- Fleet dashboard and MapLibre map.
- Persisted geofence arrivals and operation notifications.
- Driver workflow endpoints.
- Truck photo upload, processing, storage, and authenticated delivery.
- Manager lifecycle overrides.
- Polling-based live updates.

Do not rebuild these features from scratch.

---

# Why This Sprint Exists

Sprint 4.1 added valuable backend foundations, but manual acceptance testing exposed four product-level gaps:

1. Truck photos are circular in normal Flutter cards but appear as full rectangular images on MapLibre.
2. Follow mode can reclaim the camera after a real mouse drag, wheel zoom, touch drag, or pinch zoom.
3. Saved client locations appear to have disappeared because their control is conditionally hidden and load failures become silent empty lists.
4. The driver workflow passed tests only because test users were inserted directly into the database and linked through APIs. A real owner cannot create and link a driver login from the product UI.

Additionally, the current driver screen has no live map or truck position, and operational notifications are easy to miss because they are represented mainly by a bell badge.

This sprint must close the complete manager-to-driver operational loop from the real UI.

---

# Product Outcome

At the end of Sprint 4.1.1, an owner must be able to:

1. Create a Driver user account from the UI.
2. Link that account to a Driver record.
3. See the link clearly while assigning a trip.
4. Assign a trip to that exact driver and a truck.
5. Open a second independent browser session and log in as the driver.
6. See the assigned trip, current truck location, route, next stop, and allowed action.
7. Receive visible in-app operational alerts with an audible sound when a new relevant event occurs.
8. Pan or zoom the manager map without the next poll forcing the camera back.
9. Explicitly resume following the selected truck.
10. Select a saved client site during trip creation and immediately see its marker.

The acceptance workflow must not insert users directly into PostgreSQL and must not call hidden setup APIs outside the product UI.

---

# Mandatory Planning and Time Record

Before implementation, create:

```text
docs/sprints/sprint-4.1.1/SPRINT4_1_1_IMPLEMENTATION_PLAN.md
```

It must contain:

- Baseline commit and dirty-worktree assessment.
- Findings from the existing implementation.
- Architectural decisions.
- Database and migration design.
- API changes.
- Flutter changes.
- Security and tenant-isolation analysis.
- Browser-audio constraints and decisions.
- Test matrix.
- Acceptance workflow.
- Risks and intentionally deferred work.
- Start time, end time, and actual elapsed active time for each task.
- Total active sprint time.

Update the plan throughout implementation. Do not invent elapsed times at the end.

---

# Non-Negotiable Engineering Rules

- Preserve the existing layered architecture and tenant query filters.
- Keep business rules in Domain/Application layers, not Flutter widgets or API controllers.
- Use stable machine-readable error codes.
- Localize all user-facing English and Arabic text through ARB resources.
- Preserve correct RTL and LTR behavior.
- Do not expose another tenant's users, drivers, trips, photos, locations, positions, or notifications.
- Do not weaken Driver role isolation to make the map easier.
- Do not expose all fleet tracking endpoints to Driver users.
- Do not introduce full-page reloads after mutations.
- Do not clear and recreate every MapLibre annotation on each poll.
- Do not move the camera on a poll while the map is in Free or Route Overview mode.
- Do not treat screenshots alone as functional acceptance evidence.
- Do not insert acceptance users directly into the database.
- Do not commit, push, create a branch, or open a pull request.

---

# Workstream 0 — Data Safety, Tenant Identity, and Test Isolation

This workstream must be completed before any schema mutation, seeding, browser test, or feature implementation.

## 0.1 Investigate the unexpected data switch

Manual testing reported that previously entered trucks disappeared and unfamiliar test trucks appeared after reopening the application.

Known repository evidence shows that earlier smoke workflows used a dedicated test owner:

```text
owner@sprint322.local
```

The Sprint 4.1 workflow also created test trucks, drivers, clients, and trips under that smoke tenant. Determine whether the current browser session is authenticated as the smoke owner rather than the user's original owner account.

Also inspect whether Docker Compose was started with a different project name or from a differently named checkout, causing a different physical named volume to be mounted behind the logical `postgres_data` declaration.

Before changing anything, record privately and report:

- Current authenticated user email, user ID, company ID, company name, and role.
- All local owner accounts and their company IDs, without exposing password hashes.
- Truck/client/driver/trip counts grouped by company.
- Current Compose project name.
- Current PostgreSQL container ID/name.
- Exact mounted PostgreSQL volume name and mount destination.
- Other local volumes whose names plausibly contain the previous PostgreSQL data.
- Whether the original trucks still exist under another tenant or another volume.

Do not assume missing UI data means deleted database rows.

## 0.2 Strictly non-destructive recovery rules

- Do not delete any container or volume during investigation.
- Do not run `docker compose down -v`.
- Do not prune Docker volumes.
- Do not recreate PostgreSQL to obtain a clean test environment.
- Do not reassign or merge tenant data automatically.
- Do not edit company IDs directly in PostgreSQL.
- Do not change the Compose project name or volume declaration before identifying the volume that contains the user's original data.
- Do not overwrite `.env`, retained credentials, or the active database.

If the original data is found under the original owner tenant, preserve it and ensure the user can reach it by logging into the correct account.

If the original data is found in another PostgreSQL volume, stop before switching volumes and document a safe recovery plan. Take a timestamped `pg_dump` backup of both the currently mounted database and the candidate original database before any remount, migration, import, or merge. Store backups outside tracked repository content and never include credentials or database dumps in Git evidence.

If the data cannot be found, report the evidence and stop. Never fabricate replacement rows.

## 0.3 Make environment identity visible

Add a small, non-intrusive identity surface so a user can understand which account/company is active.

At minimum, Settings must clearly show:

```text
Signed-in email
Company name
Role
Environment when Development/Testing
```

It may also appear in the account menu. Do not expose internal tenant GUIDs in the normal production UI unless placed in an advanced diagnostics section.

Development/Testing must display a visually clear non-production indicator so smoke-test sessions are not mistaken for the user's real company data.

## 0.4 Isolate all automated acceptance data

No Sprint 4.1.1 browser test may create data in the retained user database.

Create a documented disposable acceptance environment using one of these safe patterns:

- A dedicated disposable PostgreSQL database and API instance; or
- A dedicated Compose override/project with a new explicitly named test volume; or
- A fully disposable Testing environment controlled by the test harness.

Requirements:

- It must never mount the retained development PostgreSQL volume.
- Test owner, driver, trucks, trips, notifications, and photos exist only in the disposable environment.
- Test teardown may remove only resources whose exact disposable identity was created by that test run.
- Production/development retained data counts must be unchanged after acceptance tests.
- The test report must record the disposable database/project identity without exposing secrets.
- Tests must fail closed if they detect the retained volume or a non-test environment.

Do not rely on email naming alone for isolation. `owner@sprint322.local` inside the retained database is still retained-database pollution.

## 0.5 Prevent future Compose volume confusion

Document one canonical local startup command and project identity.

If introducing an explicit Compose project name or explicit external volume name, do so only after safely mapping the existing retained volume. Do not make a configuration change that causes Docker to silently attach an empty volume.

Add a read-only diagnostic command or script that prints:

- Compose project.
- Active API environment.
- Database host/database name.
- Mounted PostgreSQL volume.
- Current company/user after login where feasible.

The diagnostic must not print passwords, JWT keys, access tokens, refresh tokens, or connection-string secrets.

---

# Workstream 1 — Company User and Driver Account Management

## 1.1 Preserve the domain distinction

Keep these concepts separate:

```text
User Account
    Authentication, role, email, password, locale, notification preferences

Driver Record
    Driver identity, license, phone, operational status, trip assignment
```

A Driver record may exist without an app account because some companies may initially use manager-only operations. However, the UI must make that limitation explicit.

## 1.2 Owner-only company user management

Add an Owner-only company users capability.

At minimum support:

- List users in the current company.
- Filter by role and active state.
- Create a user with the Driver role.
- View user email, display name, role, active state, and driver-link state.
- Deactivate/reactivate a user safely.
- Reset a temporary password or issue a new temporary password.
- Never return password hashes.
- Never allow an owner to access users from another tenant.

Do not add public registration.

For this sprint, use an owner-created temporary credential flow rather than email invitations because no email delivery service exists.

Security requirements:

- Generate a strong temporary password server-side, or accept a policy-compliant temporary password through a deliberately designed contract.
- Prefer returning a generated temporary password only once in the create/reset response.
- Store only the password hash.
- Require the Driver to change a temporary password on first login if this can be implemented cleanly within the current authentication architecture.
- If forced password change is implemented, tokens must not grant normal application access until the password is changed.
- Record create, deactivate, reactivate, link, unlink, and password-reset events in an audit trail.
- Revoke active refresh tokens when a user is deactivated or their password is reset.

Use stable error codes such as:

```text
USER_EMAIL_ALREADY_EXISTS
USER_NOT_FOUND
USER_ROLE_INVALID
USER_DEACTIVATED
TEMPORARY_PASSWORD_CHANGE_REQUIRED
DRIVER_USER_ALREADY_LINKED
DRIVER_ROLE_REQUIRED
DRIVER_LINK_REQUIRED
```

## 1.3 Driver account linking UI

Add account management to the Driver details/edit experience.

The owner must be able to:

- See whether the Driver record has an app account.
- See the linked account email and active state.
- Create a new Driver user and link it in one understandable workflow.
- Link an existing unlinked Driver user.
- Unlink an account after a confirmation dialog.
- Replace the link safely.
- Copy or reveal a newly generated temporary password only in the immediate creation result.

Never silently create duplicate Driver records or duplicate User accounts.

Enforce at the database and application levels:

```text
One User -> zero or one Driver
One Driver -> zero or one User
```

The operation that creates a new account and links it to a Driver must be transactional.

## 1.4 Assignment visibility

Extend driver assignment projections so the manager can distinguish:

- Driver is linked to an active app account.
- Driver is linked to an inactive account.
- Driver has no app account.
- Driver is already reserved by another active trip.
- Driver is operationally unavailable.

Show a compact localized badge in the trip assignment step:

```text
App account linked
No app account
Account inactive
Already on TRP-...
```

Do not necessarily block assigning an unlinked driver. Some companies may operate without a driver app. Instead:

- Show a clear warning that the driver will not receive or confirm the trip in the app.
- Require deliberate manager confirmation if assigning an unlinked/inactive-account driver.
- Keep all existing operational eligibility rules.

---

# Workstream 2 — Driver Workspace and Scoped Live Map

## 2.1 Replace ambiguous empty/error behavior

The current driver endpoint and screen do not adequately distinguish:

- Driver account is not linked to a Driver record.
- Linked Driver has no current trip.
- Linked Driver has a current trip.
- Current trip exists but truck telemetry has not started.
- Current truck position is stale or offline.

Return a stable driver-workspace projection rather than relying on a generic 404 or a nullable trip alone.

Recommended conceptual response:

```text
DriverWorkspace
  state
  driver
  currentTrip
  truck
  currentPosition
  trackingState
  activeRoute
  approachRoute
  nextStop
  allowedActions
```

Recommended state/error codes:

```text
ACCOUNT_NOT_LINKED
NO_ACTIVE_TRIP
TRIP_ASSIGNED_NO_TELEMETRY
TRUCK_POSITION_STALE
TRUCK_OFFLINE
ACTIVE_TRIP_READY
```

Do not expose other drivers, trucks, trips, or positions.

## 2.2 Driver map

Add a real MapLibre map to the Driver My Trip screen when a current trip exists.

The map must show only what the driver needs:

- Current assigned truck marker.
- Current truck position.
- Pickup marker.
- Delivery marker.
- Approach-to-pickup route while traveling to pickup.
- Cargo route after loading/departure.
- Current trail only if it is operationally useful and does not create clutter.
- Next stop emphasis.

The card below or above the map must show:

- Trip number.
- Truck plate/fleet code, not only an internal GUID.
- Current operational phase.
- Next stop name and address.
- Remaining distance.
- ETA when available.
- Last position update time.
- Online/current/stale/offline status.
- Allowed driver action.

Keep Confirm Loaded visible only at the valid pickup lifecycle state and Confirm Delivery visible only at the valid delivery lifecycle state.

When no trip exists, show an intentional empty state with refresh and explanatory text. When the account is unlinked, tell the user to contact the company owner rather than showing a generic failure.

## 2.3 Live refresh

Use the existing configurable polling architecture.

- Refresh the driver workspace without a page reload.
- Preserve the last good data during transient polling failures.
- Show stale/offline transitions clearly.
- Do not reset the driver's map camera on every poll after manual interaction.
- Do not create duplicate route or marker annotations.

---

# Workstream 3 — Circular Photo Markers on MapLibre

## 3.1 Root cause to fix

The normal Flutter `TruckAvatar` clips images through `CircleAvatar`, but MapLibre receives the original rectangular authenticated thumbnail and renders it directly as `iconImage`.

A status circle behind a rectangular image does not clip the image.

## 3.2 Required marker pipeline

Create a dedicated map-marker image representation.

It must:

- Use a fixed square canvas.
- Crop the source image with cover semantics around the center.
- Clip it to a circle.
- Leave transparent pixels outside the circle.
- Use a predictable image size and pixel ratio.
- Avoid stretching wide or tall source images.
- Include a neutral border that remains visible on light and dark map areas.
- Preserve the existing truck-icon fallback when no photo exists or loading fails.

Choose one clean implementation:

1. Server-generated dedicated map-marker bytes and authenticated endpoint; or
2. Deterministic Flutter-side decode/crop/circular-mask/PNG generation before MapLibre image registration.

Document the decision. Do not reuse the raw rectangular thumbnail as the final MapLibre symbol.

## 3.3 Marker semantics

The visual system must support:

- Moving.
- Stationary.
- Offline.
- Maintenance/out of service.
- Selected.

Use separate stable layers where appropriate:

- Circular photo/icon symbol.
- Status ring.
- Selection ring/halo.
- Small heading indicator if needed.

The photo itself must stay upright. Do not rotate the driver's or truck's photo with heading. Rotate only a separate direction indicator.

Marker size must remain visually close to the previous circular truck marker and must not become a large rectangular overlay.

Cache marker images by:

```text
truckId + photoVersion + marker-format-version
```

Replace them only when the photo version changes. Preserve serialized latest-wins annotation updates and zero global annotation clears.

---

# Workstream 4 — Correct Map Follow and Manual Interaction

## 4.1 Explicit camera states

Preserve or clarify the explicit modes:

```text
Free
FollowSelectedTruck
RouteOverview
```

Required behavior:

### Selecting a truck

- Enter FollowSelectedTruck.
- Center on the truck at a useful local zoom.
- Do not automatically fit the entire route.

### Following

- New positions may update the camera center for the selected truck.
- Do not continuously reset bearing, pitch, or zoom unless explicitly intended and documented.

### Manual interaction

Any real user interaction must pause follow immediately:

- Mouse button drag.
- Touch drag.
- Mouse wheel zoom.
- Trackpad zoom/pan.
- Pinch zoom.
- Manual rotation if supported.

Once paused:

- Polls must never recenter the camera.
- Route and marker annotations must continue updating.
- A visible `Resume follow` button must remain available.
- Follow resumes only after the user presses that button or reselects the truck deliberately.

### Route overview

- `Show full route` fits the relevant approach and/or cargo route once.
- Later polls do not fit it again.
- A separate action returns to FollowSelectedTruck.

## 4.2 Do not infer user intent only from camera motion

Programmatic camera animations and user gestures both trigger camera callbacks. The current timer-based guard can ignore a real gesture if it occurs during or shortly after an automatic camera move.

Use real input signals around the map where supported:

- Pointer down.
- Pointer signal/wheel.
- Touch/scale gesture start.

Pause follow before MapLibre processes the interaction. Keep a programmatic-camera guard only for camera callbacks, not as the sole source of user-intent detection.

## 4.3 Required real-input test

Do not pass this sprint by manually calling `onCameraMove` from a widget test.

The browser acceptance test must perform an actual drag and actual wheel/zoom interaction against the rendered map. Then allow at least three tracking polls and verify the map remains in Free mode and does not snap back.

After pressing Resume Follow, verify that it follows again.

---

# Workstream 5 — Saved Client Sites UX Restoration

The existing model is client-scoped `ClientSite`. Preserve it in this sprint. Do not introduce a new company-wide location domain unless a blocking requirement proves it necessary.

## 5.1 Always-visible state after client selection

After selecting a client, show the Saved Client Site control for pickup and delivery in one of these states:

```text
Loading saved sites...
Saved sites available
No saved sites for this client
Failed to load saved sites — Retry
```

Do not hide the complete control when the list is empty. Do not silently convert a network failure into an empty state.

## 5.2 Selection behavior

When a saved site is selected:

- Populate name.
- Populate address.
- Populate latitude and longitude.
- Display or move the pickup/delivery marker immediately.
- Mark any old calculated route as stale.
- Require recalculation before confirmation.
- Preserve the marker while moving between planner steps.

When no saved sites exist, provide an obvious Add Site action using the current location picker.

Preserve:

- Search.
- Manual coordinates.
- Click-on-map location selection.
- Immediate clicked marker.
- Save current stop as a client site.
- Arabic RTL behavior.

---

# Workstream 6 — Visible and Audible Operational Notifications

## 6.1 Product objective

The bell badge is not sufficient for time-sensitive fleet events.

When a new relevant operational notification arrives while the application is open, the user must receive:

1. A clearly visible in-app alert.
2. A short audible sound when notification sounds are enabled.
3. A direct action to open the related trip, truck, or Driver My Trip screen.

The bell center and unread counter must remain. The new alert supplements them; it does not replace persisted notifications.

## 6.2 Event importance and audience

Define a small explicit severity model, for example:

```text
Information
Success
Warning
Critical
```

At minimum, surface these events prominently:

- Truck arrived at pickup.
- Driver confirmed loaded/departure.
- Truck arrived at delivery.
- Driver confirmed delivery/trip completed.
- Truck became offline during an active trip.
- Truck position became stale during an active trip.
- Driver account received a new trip assignment.
- Operational exception requiring manager action.

Respect recipient scope:

- Owners/Operations see company operational alerts they are authorized to see.
- Drivers see only alerts associated with their linked Driver identity and current/assigned work.
- Never leak tenant or other-driver information.

## 6.3 In-app alert presentation

Implement a reusable application-shell alert layer rather than screen-specific SnackBars.

The alert must contain:

- Localized title.
- Short localized message.
- Severity icon/color.
- Truck plate/fleet code or trip number where relevant.
- Relative or absolute event time.
- `View` action.
- Dismiss action.

Behavior:

- Alerts appear above the current screen without requiring navigation to the notification center.
- They must be visible in both LTR and RTL.
- Do not obscure critical controls permanently.
- Queue alerts rather than replacing an alert mid-read.
- Coalesce or rate-limit bursts safely.
- Critical/warning alerts remain visible longer than informational alerts.
- Dismissing the overlay does not delete the persisted notification.
- Decide and document whether viewing/dismissing marks it read. Keep behavior consistent.

## 6.4 Sound behavior

Add one or more short original or properly licensed local sound assets. Do not load alert sounds from an external URL.

Requirements:

- Add `Notification sounds` setting per user.
- Persist the preference so it follows the user across sessions/devices.
- Provide a `Test sound` action in Settings.
- Use a sensible default and explain it in the implementation plan.
- Play sound only for genuinely new notifications received after the live session has initialized.
- Do not play sounds for the entire historical unread backlog at login or refresh.
- Never play the same notification sound twice because of polling.
- Deduplicate by persisted notification ID/event key, not only timestamp.
- Do not loop sound.
- Rate-limit sound during event bursts.
- Do not play sound after logout.
- Respect mute/disabled preference immediately.
- Handle audio load/play failures without crashing the app.

Browser audio policy:

Web browsers can block audio until a user gesture has occurred. Implement this honestly:

- Initialize/unlock audio after a legitimate user interaction.
- If sound is enabled but blocked, show a localized one-time banner/action such as `Enable notification sound`.
- Do not claim sound is active when the browser has blocked it.
- Provide a visible sound-enabled/muted indicator in Settings.

Foreground audible alerts are in scope. Browser push notifications, service workers, background audio, SMS, email, and native OS push are out of scope.

## 6.5 Notification polling correctness

Use persisted notification IDs and the existing notification feed.

The client must distinguish:

```text
Initial hydration
New notification after hydration
Previously seen notification
```

Recommended client behavior:

- Fetch initial unread/feed state without playing sound.
- Store the highest seen creation sequence or a bounded set of recently observed IDs for the active authenticated session.
- On later polls, enqueue only unseen notifications.
- Server-side event-key uniqueness remains authoritative.
- Client-side deduplication protects the visual/audio experience.

Do not derive alerts independently from raw trip polling when a persisted OperationNotification already exists.

---

# Workstream 7 — Refresh and State Consistency

All relevant views must update without manual page refresh:

- User creation/linking updates Driver details and assignment options.
- User deactivation updates badges and warnings.
- Trip assignment appears in the driver's workspace within the polling interval.
- Driver confirmation updates manager dashboard, trip details, notifications, and resource availability.
- Saved-site creation updates the planner selector.
- Truck photo replacement updates list, detail, assignment avatar, and map marker using the new version.
- Notification unread count, overlay queue, and notification center stay synchronized.

Use the existing refresh/mutation coordination patterns. Avoid broad invalidations that cause the whole application to flicker.

---

# Backend Requirements

Implement or extend the backend cleanly.

Expected areas include:

- Owner-only company-user endpoints and application service.
- Tenant-scoped user query/store abstraction.
- Temporary credential/password reset rules.
- Refresh-token revocation on security-sensitive mutations.
- Transactional create-and-link workflow.
- Driver link projection and assignment metadata.
- Driver-scoped workspace/tracking projection.
- Notification sound preference persistence.
- Any required notification event additions with stable event keys.
- Audit events for user management and linking.

Database migration requirements:

- Use one safe forward migration for Sprint 4.1.1 if schema changes are needed.
- Preserve all existing company, user, driver, trip, tracking, notification, and photo data.
- Do not invent links for legacy drivers.
- Do not invent notification preference history.
- Use nullable/default-safe additions where appropriate.
- Add database-level unique constraints for one-to-one user/driver linking.
- Verify no pending EF model changes after the migration.

Concurrency and idempotency:

- User create/link cannot create duplicates under concurrent requests.
- Repeated link to the same valid pair should be safe or return a clear deterministic response.
- Notification delivery polling must not create new database notifications.
- Driver confirmations remain idempotent and lifecycle-guarded.

---

# Flutter Requirements

Implement coherent UI rather than isolated buttons.

Required surfaces:

- Company Users screen for Owner.
- Driver details account-link section.
- Trip assignment account-status badges/warnings.
- Driver My Trip workspace with scoped map.
- Correct circular photo map marker.
- Stable camera interaction and explicit Resume Follow.
- Saved-site loading/empty/error/available UI.
- Application-shell operational alert overlay.
- Notification sound settings and Test Sound.

Every new string must be translated in:

```text
app_en.arb
app_ar.arb
```

Verify:

- Arabic RTL alignment.
- Logical icon/text ordering.
- Dialog direction.
- Alert overlay direction.
- Map controls remain usable in RTL.
- Long Arabic messages do not overflow.
- Responsive behavior at desktop and practical mobile widths.

---

# Test Requirements

## Backend tests

Add integration coverage for at least:

1. Owner creates a Driver user in their tenant.
2. Duplicate email is rejected.
3. Cross-tenant user listing/read/update/link is impossible.
4. Non-owner cannot manage company users.
5. Create-and-link is transactional.
6. One User cannot link to two Drivers.
7. One Driver cannot link to two Users.
8. Inactive/wrong-role users cannot be linked as active Driver accounts.
9. Password reset revokes refresh tokens.
10. Driver workspace returns ACCOUNT_NOT_LINKED state safely.
11. Linked driver with no trip returns NO_ACTIVE_TRIP.
12. Linked driver sees only their own active trip and truck position.
13. Driver cannot access fleet-wide tracking.
14. Assignment projection returns app-account state.
15. Notification preferences are tenant/user scoped.
16. Operation notification deduplication remains intact.
17. Legacy records remain valid after migration.

## Flutter unit/widget tests

Add coverage for at least:

- Circular map-marker processing for wide, tall, square, transparent, and invalid images.
- Fallback icon when photo processing/loading fails.
- Marker cache invalidates only on photo version change.
- Pointer down pauses follow.
- Pointer wheel/signal pauses follow.
- Three polling updates do not move the camera after follow is paused.
- Resume Follow explicitly restarts camera tracking.
- Route Overview fits once.
- Saved-site loading, empty, error, retry, and populated states.
- Saved-site selection fills coordinates and moves marker state immediately.
- Driver workspace states.
- Notification initial hydration is silent.
- One new notification produces one overlay and at most one sound.
- Repeated polls do not replay sound.
- Sound-disabled preference prevents playback.
- Arabic and English alert rendering.

Use an injectable audio player abstraction so sound behavior can be tested deterministically without relying on actual speakers.

## Real browser acceptance workflow

Run a real Firefox or Chrome browser workflow against the containerized API and PostgreSQL.

Use two independent browser profiles/contexts:

```text
Manager Session
Driver Session
```

The workflow must:

1. Start only against the verified disposable acceptance database/API and prove that the retained PostgreSQL volume is not mounted.
2. Log in as the disposable acceptance owner.
3. Create a Driver record from the UI if needed.
4. Create a Driver user account from the UI.
5. Link the user to the Driver from the UI.
6. Create or use a truck with a deliberately wide or tall photo.
7. Confirm the map marker is circular and approximately the expected size.
8. Create a saved client site.
9. Create a trip and select that saved site.
10. Confirm the map marker appears immediately at the saved coordinates.
11. Assign the linked Driver and truck.
12. Log in through the second browser context as the Driver.
13. Confirm the Driver sees the correct trip and scoped live map.
14. Confirm the Driver does not see other fleet data.
15. Select/follow the truck on the manager map.
16. Perform a real mouse drag.
17. Perform a real wheel/zoom action.
18. Allow at least three tracking polls.
19. Confirm the camera does not snap back.
20. Press Resume Follow and confirm tracking resumes.
21. Trigger a pickup-arrival notification.
22. Confirm a visible manager alert appears without opening the bell.
23. Confirm exactly one sound-play request occurs for the new event.
24. Confirm the driver receives only the appropriate driver alert.
25. Confirm old unread notifications do not all play at login.
26. Complete the loaded/departure and delivery workflow.
27. Confirm manager and driver views refresh without manual page reload.
28. Repeat relevant checks in Arabic/RTL and English/LTR.
29. Confirm retained-database company/resource counts remain unchanged.

Do not satisfy manual-pan acceptance by invoking Flutter callbacks directly. Use actual browser input events.

Because headless environments may not expose a physical audio device, browser evidence may verify the real UI event plus an instrumented audio-play invocation. Also perform a non-headless/manual sound check when the environment permits, and document any limitation honestly.

---

# Evidence Requirements

Store Sprint 4.1.1 evidence under:

```text
docs/evidence/sprint4_1_1/
```

Include:

- Redacted data-safety diagnosis identifying the active tenant and mounted volume.
- Proof that the user's original data was preserved or a documented recovery blocker.
- Proof that browser acceptance used a disposable database that did not mount the retained volume.
- Before/after retained resource counts with no test-data increase.
- Manager company-users screen.
- Driver account linked in Driver details.
- Assignment option showing linked-account state.
- Correct circular map photo marker using a non-square source photo.
- Follow active.
- Real manual pan/zoom with Follow paused.
- Same camera view after at least three polls.
- Route Overview and Resume Follow.
- Saved-site loading/empty/populated behavior.
- Saved-site selection and immediate marker.
- Driver trip map with current position and next stop.
- Visible pickup/delivery notification overlay.
- Notification sound setting and Test Sound.
- Arabic RTL and English LTR screenshots.
- Machine-readable browser assertions.
- Map camera-operation counts.
- Notification IDs received, displayed, and sound-play deduplication counts.
- Tenant-isolation results.

Do not store credentials, passwords, access tokens, refresh tokens, or private headers in evidence.

---

# Required Validation

Run and report:

## Backend

```text
dotnet restore
dotnet build with repository warning policy
architecture tests
integration tests
EF migration applied to disposable PostgreSQL
EF pending-model-change check
```

## Flutter

```text
flutter pub get
flutter gen-l10n
dart format verification
flutter analyze
flutter tests
Flutter Web release build with simulator enabled for development acceptance
Flutter Web production release build with simulator mutations excluded
```

## Runtime

```text
Docker Compose API healthy
PostgreSQL healthy
existing volume preserved
active tenant/account verified
retained database backed up before any recovery-related mutation
browser acceptance isolated from retained database
retained company/resource counts unchanged by tests
real map style loaded
manager and driver independent sessions passed
audible-alert invocation verified
```

Do not delete or recreate the retained PostgreSQL volume merely to make tests pass. Do not overwrite `.env` or retained credentials.

If Android cannot be built because the SDK/device is unavailable, report it as an environment limitation only after all available Web validation succeeds.

---

# Documentation Updates

Update:

```text
README.md
docs/architecture.md
docs/sprints/README.md
```

Document:

- Canonical Compose project/volume identity and safe startup command.
- How to diagnose the active user, company, environment, and mounted database volume.
- Disposable acceptance database workflow.
- User Account versus Driver Record.
- Owner user-management and link flow.
- One-to-one identity constraints.
- Driver-scoped workspace projection.
- Driver map data boundary.
- Circular map-marker pipeline.
- Camera modes and real manual-interaction rules.
- Saved client site UI states.
- Persisted notification feed versus ephemeral alert overlay.
- Sound preference, browser autoplay limitation, and deduplication.
- Development acceptance setup without direct database user insertion.
- Intentionally deferred functionality.

---

# Explicitly Out of Scope

Do not add:

- Finance, expenses, payments, or profitability.
- Maintenance management.
- Real GPS provider integration.
- SignalR/WebSockets.
- Route optimization for multiple vehicles.
- Public user registration.
- Email invitation delivery.
- SMS notifications.
- Browser push/service-worker notifications.
- Native mobile background push.
- Driver profile photos.
- Proof-of-delivery signatures or document uploads.
- Return-to-base workflow.
- A second independent driver application codebase.

Use the existing Flutter application with role-aware navigation.

---

# Definition of Done

Sprint 4.1.1 is complete only when all of the following are true:

- The unexpected-data incident has been diagnosed without deleting or overwriting any volume.
- The user's original trucks remain accessible under the correct account/database, or an evidence-backed recovery blocker is reported before feature work continues.
- The active account/company/environment is visible to the user in Settings or the account menu.
- Automated acceptance never writes to the retained user database.
- Retained company/resource counts are unchanged by acceptance tests.
- The owner can create and link a Driver login entirely through the product UI.
- The owner can clearly identify linked and unlinked drivers during assignment.
- A separately logged-in Driver sees the assigned trip and a scoped live map.
- The Driver never receives fleet-wide data.
- Truck photos render as small circular MapLibre markers, not rectangular images.
- Real mouse/touch interaction pauses Follow mode immediately.
- Polling never steals the camera while Follow is paused.
- Follow resumes only through an explicit user action or deliberate reselection.
- Saved client sites have loading/empty/error/populated states and can be selected again.
- Selecting a saved site moves the correct marker immediately.
- New important operational notifications appear visibly without opening the bell.
- Enabled notification sound plays once for a genuinely new event.
- Initial historical notification loading is silent.
- Repeated polling never replays the same alert sound.
- Sound can be disabled and tested from Settings.
- Manager and Driver workflows pass in two real independent browser sessions.
- English/LTR and Arabic/RTL pass.
- Backend build and tests pass with zero warnings/errors under repository policy.
- Flutter analyzer and tests pass.
- EF migration drift is absent.
- Web release builds pass.
- Documentation and evidence are complete.
- No unrelated files are changed.
- No commit or push is performed.

---

# Final Report Format

When finished, return a concise report containing:

## Implemented

- Data/tenant/volume safety diagnosis and isolated acceptance environment.
- User/account management.
- Driver linking and assignment visibility.
- Driver workspace/map.
- Circular map photo markers.
- Camera-follow repair.
- Saved-site restoration.
- Visible and audible notification behavior.

## Validation

- Active account, company, Compose project, and mounted-volume verification.
- Retained-database before/after counts and backup status.
- Disposable acceptance environment identity.
- Backend build/test counts.
- Flutter analysis/test counts.
- Migration status.
- Web build status.
- Docker health.
- Two-session manager/driver acceptance result.
- Real pan/zoom result across at least three polls.
- Notification display/sound deduplication counts.
- Arabic/English result.

## Evidence

- Exact evidence directory.
- Important screenshot and machine-readable evidence filenames.

## Limitations

- Android or audio-device limitations, if genuinely present.
- Deferred background push and email invitations.

## Timing

- Per-task active elapsed time.
- Total active elapsed time.

## Git Status

Explicitly confirm that changes remain uncommitted and unpushed.
