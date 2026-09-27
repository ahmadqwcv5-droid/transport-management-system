# Sprint 4.2.1 — Operational UX Reliability, Map Stabilization, and Arabic Basemap Labels

## Role

Act as a senior full-stack engineer, Flutter/MapLibre specialist, ASP.NET Core architect, QA engineer, and logistics product engineer.

Work directly in the existing `transport-management-system` repository. This is a focused corrective sprint built on top of the latest Sprint 4.2 implementation. Do not redesign the product, start a finance module, or introduce unrelated features.

## Mission

Close the remaining operational reliability and usability gaps before the product is demonstrated to a real transport-company owner.

The sprint has six tightly bounded goals:

1. Stop the live map from failing or being recreated during trip-phase transitions.
2. Render Arabic basemap labels correctly on Flutter Web.
3. Make operational notifications specific, localized, audible, and useful.
4. Show complete trip information when a driver receives or confirms an assignment.
5. Unify truck/driver assignment behavior across every entry point.
6. Finish localization and remove obvious scalability problems in the active-operations query.

Reliability and truthful validation are more important than feature count.

---

## Mandatory working rules

### Repository and data safety

- Inspect the current branch, latest commits, `git status`, existing Sprint plans, README, architecture documentation, migrations, and test suites before editing.
- Preserve all existing user changes. Do not reset, discard, overwrite, or reformat unrelated work.
- Do not commit or push anything.
- Do not modify `.env`, replace credentials, reset PostgreSQL, delete Docker volumes, or recreate the database.
- Never add test trucks, drivers, clients, trips, or users to an existing real/user tenant.
- Prefer integration-test fixtures and isolated test databases.
- If browser acceptance absolutely requires a tenant, create a uniquely named isolated smoke-test tenant and remove all of its data after evidence collection. Record what was created and prove that the pre-existing tenant row counts and records were unchanged.
- Do not silently repair or rewrite legacy business data.
- Any migration must be additive, safe, nullable where necessary, tenant-safe, and compatible with existing rows.

### Planning and time records

Before implementation, create:

`SPRINT4_2_1_IMPLEMENTATION_PLAN.md`

It must contain:

- baseline findings;
- reproduced defects and their root causes;
- chosen design and rejected alternatives;
- task checklist with acceptance criteria;
- risks and rollback considerations;
- actual active elapsed time for every task;
- final validation matrix;
- deferred work.

Update the plan throughout the work. Do not invent elapsed times after the fact.

### Scope discipline

Do not add finance, maintenance, route optimization, SignalR, a new GPS provider, chat, document management, or unrelated dashboard features.

Continue using the existing polling architecture, routing abstractions, OpenFreeMap configuration, MapLibre integration, localization system, notification infrastructure, and tenant model unless a narrowly scoped compatibility fix is required.

---

# 1. Diagnose before changing code

Reproduce and document the following issues first:

1. The map can show a fatal “failed to load map” state around arrival at the pickup point or another trip-phase transition.
2. Arabic place names inside the basemap are displayed reversed or incorrectly shaped, for example `حمص` appearing in the wrong visual order.
3. The prominent notification and/or audible popup still uses generic text instead of specific trip, truck, and location details.
4. The driver assignment/confirmation dialog does not show enough information about the assigned trip.
5. Assignment behavior differs between the trip planner and existing trip-detail assignment flow; one path may silently select the first eligible driver instead of respecting the truck’s linked/default driver.
6. Some active-operations UI text remains hardcoded in English.
7. The active-operations backend service may load broad tenant tables into memory before filtering/projecting.

For each defect, identify the exact call path, state transition, widget lifecycle, backend query, or renderer configuration responsible. Do not fix symptoms without recording the root cause.

Run the existing backend and Flutter tests before implementation and record the baseline.

---

# 2. Live map lifecycle and phase-transition reliability

## Required behavior

The same map instance must survive normal polling and trip transitions such as:

- dispatch to pickup;
- arrival at pickup;
- loading confirmation;
- departure toward delivery;
- arrival at delivery;
- delivery confirmation;
- completion.

Changing the active route, phase, route revision, trail segments, stop markers, selected truck, or notification state must not dispose and recreate the MapLibre platform view.

## Implementation requirements

- Audit conditional widgets above and around the map. Give the map stable widget identity and prevent unrelated state changes from replacing it.
- Separate these states explicitly:
  - map engine/style loading;
  - map ready;
  - recoverable annotation synchronization error;
  - tile/style/network degradation;
  - genuinely fatal renderer failure.
- Do not convert an annotation add/update/remove failure into a fatal basemap failure.
- Preserve the existing serialized, latest-wins annotation synchronization behavior.
- Preserve incremental annotation updates.
- Do not call global symbol, line, or circle clearing during polling or phase changes.
- Do not refit or move the camera during polling.
- Preserve manual pan and zoom.
- Preserve follow mode semantics: follow mode may move the camera; a user gesture must suspend follow mode until the user explicitly resumes it.
- Route changes must update the appropriate route/trail/stop annotations without reloading the style.
- Do not remove a route annotation and recreate the entire map just because its geometry or visibility changed.
- Categorize and log map errors with enough context to diagnose them: map lifecycle state, trip ID, tracking phase, route revision, annotation operation, and exception type. Do not silently swallow exceptions.
- The Retry action must retry only what failed. It must not destroy a healthy map because an overlay update failed.
- Keep OpenFreeMap attribution visible.

## Measurable acceptance criteria

During one continuous browser session:

- run at least 30 consecutive polling updates;
- cross at least one pickup-arrival transition and one departure-to-delivery transition;
- keep the same map instance throughout;
- style loads after initial startup: `1` unless the user explicitly presses Retry after a proven fatal style failure;
- global annotation clears: `0`;
- polling camera moves outside enabled follow mode: `0`;
- unexpected map disposals/recreations: `0`;
- fatal map error UI caused by annotation synchronization: `0`;
- route, trail, stop markers, and truck marker remain visible and synchronized.

Add focused regression tests for the root lifecycle/state bug, not only a screenshot test.

---

# 3. Correct Arabic basemap labels on Flutter Web

## Problem

Flutter application text is correctly RTL, but Arabic labels rendered inside the MapLibre/OpenFreeMap canvas are reversed or incorrectly shaped. This is a renderer/style/glyph problem, not an application `Directionality` problem.

## Non-negotiable requirements

- Do not reverse Arabic strings manually.
- Do not preprocess tile label strings with a custom character reversal function.
- Do not change Flutter’s global `Directionality` to compensate for canvas text rendering.
- Do not hide the defect behind a screenshot or switch back to the old country-only demo map.
- Continue using a configurable map-style URL and preserve OpenFreeMap attribution.

## Investigation and implementation

1. Determine and document the actual `maplibre-gl-js` version loaded at runtime in the browser, not only the Dart package version.
2. Determine whether the current Flutter MapLibre Web wrapper pins or injects an older JS renderer.
3. Inspect the active OpenFreeMap Liberty style, glyph URL, font stack, and label expressions used for Latin, local, and Arabic names.
4. Use the modern MapLibre built-in Arabic shaping and bidirectional behavior where the loaded renderer supports it.
5. Do not blindly add the deprecated RTL text plugin. Use an RTL plugin only if the verified runtime version genuinely requires it and the integration is compatible with the Flutter wrapper. Document that decision.
6. Upgrade or configure the Web renderer/wrapper as narrowly as possible if that is the root cause. Regression-test annotations, images, routes, camera behavior, and browser release builds after any upgrade.
7. If a custom OpenFreeMap style is required, keep it versioned/configurable and document how it is hosted and updated. Do not copy a remote style without understanding its glyph and source URLs.
8. Arabic application locale should produce correctly rendered Arabic or bilingual place labels according to the chosen style policy. English locale must remain readable.
9. If correct Arabic shaping is impossible on one supported renderer after a documented investigation, use a clearly documented Latin-label fallback on that renderer rather than displaying reversed Arabic. This is a last-resort compatibility fallback, not the primary outcome.

Reference the current official MapLibre guidance while implementing:

- <https://maplibre.org/maplibre-gl-js/docs/API/functions/setRTLTextPlugin/>
- <https://openfreemap.org/quick_start/>

## Visual acceptance cases

Verify on the real Web map at multiple zoom levels that these names are correctly ordered and shaped:

- `حمص`
- `دمشق`
- `حلب`
- `بيروت`

Also verify one mixed-direction label containing Arabic and Latin characters or a road number.

Expected characteristics:

- letters appear in the correct visual order;
- connected Arabic letters are shaped correctly;
- no double reversal;
- no separated glyphs caused by a missing font stack;
- no regression in English labels;
- no regression in truck icons, photos, route lines, stops, or attribution.

Capture real-browser before/after evidence. A Widget Test alone is not sufficient because the defect exists inside the rendered map canvas.

---

# 4. Operational notifications with immutable context

## Goal

Every notification must answer, without opening another screen:

- What happened?
- Which truck?
- Which trip?
- Where did it happen?
- When did it happen?

## Required notification context

For new operational events, persist or otherwise provide an immutable, tenant-safe event snapshot containing the relevant subset of:

- stable notification/event code;
- trip ID and human-readable trip reference;
- truck ID and plate/display name;
- driver display name when applicable;
- client display name when applicable;
- pickup and delivery display names;
- coordinate fallback when no human-readable location exists;
- cargo/load summary when applicable;
- operational phase/status;
- event timestamp in UTC, localized for display;
- navigation target/deep-link metadata if the application already supports it.

Do not rely on mutable current entity names to reconstruct the historical meaning of an old notification if the existing architecture supports snapshot payloads. Avoid N+1 queries when listing notifications.

## Required messages

Provide localized English and Arabic templates for at least:

- trip assigned to driver;
- driver accepted/started dispatch to pickup;
- truck reached pickup;
- loading confirmed;
- truck departed toward delivery;
- truck reached delivery;
- delivery confirmed;
- trip completed;
- off-route or other existing operational alerts.

Example Arabic meaning—not a required literal translation:

`وصلت الشاحنة ABC-123 للرحلة TR-104 إلى موقع الاستلام: مستودع العميل في حمص.`

The truck identifier must be prominent. Use a meaningful location name; fall back to formatted coordinates only when necessary.

## Popup, sound, bell list, and deduplication

- The prominent popup/toast and sound event must use the enriched localized content, not a generic `New notification` message.
- Preserve the notification center/bell badge and history list.
- A single backend event must produce one visible popup and one sound, not repeated sound on every poll or rebuild.
- Reconnecting, refreshing, or re-fetching notifications must not replay already acknowledged sounds.
- Old legacy notifications with missing snapshots must still render safely using a localized generic fallback.
- Opening a notification should navigate to the relevant trip/truck when the existing navigation architecture supports it.
- Preserve browser autoplay-safe behavior and the existing user-facing sound preference, if present.

Add idempotency/deduplication tests across retries and consecutive polls.

---

# 5. Driver assignment and confirmation details

When a driver receives an assigned trip, the visible dialog/card must show enough information to make an informed decision. A generic sentence and an OK button are not sufficient.

Display, when available:

- trip reference;
- client;
- assigned truck photo/avatar, plate, and display name;
- cargo/load summary;
- pickup name and address/coordinates fallback;
- delivery name and address/coordinates fallback;
- scheduled pickup/departure time;
- route distance;
- estimated travel duration;
- important notes/instructions;
- current assignment/dispatch state.

Use clear localized actions matching the real state machine, for example:

- `View trip`;
- `Confirm and depart to pickup`;
- `Decline` only if decline is already part of the approved workflow;
- `Close` without changing state.

Do not auto-start the simulator or trip merely because the dialog opened. The existing driver confirmation must remain the authoritative command that starts the appropriate operational leg.

The same complete summary must be available from the driver’s active-trip page after the initial popup is dismissed.

---

# 6. Unify truck and driver assignment

Audit every assignment entry point, including at minimum:

- trip creation/planner flow;
- existing trip-detail assignment dialog;
- any active-operations quick action.

Use one shared assignment policy and, where practical, one reusable UI/service component.

## Required rules

- When the manager selects a truck with an active, valid, linked/default driver, preselect that driver automatically.
- Show clearly that the driver was selected because they are linked to the truck.
- Revalidate eligibility at submission time on the backend.
- If the linked driver is inactive, unavailable, unauthorized, or already assigned to a conflicting active trip, do not silently replace them with the first eligible driver.
- Show the exact localized reason and require the manager to choose another eligible driver.
- Never select the first database/list item merely to make the form valid.
- If the manager overrides the linked driver, make the override explicit and preserve the truck’s permanent/default relation unless the manager separately chooses to update it.
- Prevent double assignment of trucks and drivers across conflicting active trips.
- Return stable backend error codes and localize them in Flutter.
- After assignment, update affected trip, truck, driver, dashboard, and active-operations state immediately without requiring a manual page refresh.

Add tenant-isolation and concurrency tests for assignment validation.

---

# 7. Localization completion

- Remove hardcoded user-facing English strings from active-operations cards, map states, assignment dialogs, notification overlays, confirmation dialogs, errors, filters, legends, and retry actions.
- Add every new string to the English and Arabic ARB files.
- Verify correct RTL layout, icon placement, number/time formatting, and truncation in Arabic.
- Do not display raw enum names, GUIDs, event codes, or untranslated backend messages when a human-readable localized value is expected.
- Keep stable backend error/event codes language-neutral.

The basemap label direction is independent from Flutter widget direction; validate both layers separately.

---

# 8. Bounded active-operations query hardening

While touching the active-operations backend service, remove obvious load-all-then-filter behavior without redesigning the entire dashboard.

- Filter by tenant and operational status in the database.
- Use `AsNoTracking` for read-only projections where appropriate.
- Select only fields required by the response.
- Avoid N+1 queries.
- Bound recent/completed lists and other collections.
- Keep authorization and tenant query filters intact.
- Do not cache data across tenants.
- Preserve the existing API contract unless a version-safe additive field is required.

Add tests proving tenant isolation and stable ordering. Document the generated query shape or other evidence showing that broad tenant tables are no longer materialized unnecessarily.

---

# 9. Automated validation

## Backend

Run and pass:

- full `.NET` build with zero warnings and zero errors;
- all existing backend integration tests;
- new tests for notification snapshots and localization inputs;
- notification idempotency/deduplication tests;
- assignment policy and conflict tests;
- owner/driver authorization tests;
- tenant-isolation tests;
- active-operations query tests;
- EF Core migration/model drift check.

If a migration is added, prove that legacy rows remain readable and no coordinates, names, or relationships were invented.

## Flutter

Run and pass:

- `flutter analyze` with zero issues;
- all existing Flutter tests;
- focused map lifecycle/state tests;
- assignment component tests;
- notification rendering and fallback tests;
- English LTR and Arabic RTL widget tests;
- Flutter Web release build.

Do not weaken, delete, or skip existing tests to obtain a green result.

---

# 10. Mandatory real-browser acceptance workflow

Automated unit/widget tests are necessary but not sufficient. Execute a real browser workflow using two independent authenticated browser contexts: manager and driver.

Use existing safe test data or an isolated disposable tenant only.

## Scenario A — unified assignment and driver details

1. Log in as manager.
2. Select a truck that has a valid linked driver.
3. Confirm that the linked driver is automatically selected with an explanation.
4. Assign the trip.
5. In the driver context, receive the visible and audible assignment notification.
6. Verify that the dialog shows trip, truck, cargo, pickup, delivery, distance, duration, and schedule data.
7. Confirm departure to pickup.
8. Verify that the correct simulator/tracking leg begins only after confirmation.

Repeat the assignment check through the other assignment entry point to prove both flows use the same policy.

## Scenario B — map stability across operational transitions

1. Keep the manager map open and select the moving truck.
2. Exercise manual pan/zoom and follow-mode suspension/resume.
3. Run at least 30 polls.
4. Reach pickup.
5. Confirm the arrival notification contains the truck, trip, and pickup location.
6. Confirm loading/departure to delivery from the driver context.
7. Verify the route/phase changes without map replacement or fatal reload UI.
8. Verify routes, trail segments, stops, truck avatar, selected state, and details remain correct.

## Scenario C — Arabic basemap labels

1. Switch the application to Arabic.
2. Navigate the real map to areas showing `حمص`, `دمشق`, `حلب`, and `بيروت` at useful zoom levels.
3. Capture screenshots proving correct order and glyph shaping.
4. Verify Flutter overlays remain RTL and the map controls remain usable.
5. Switch back to English and confirm no label or layout regression.

## Scenario D — legacy and duplicate notifications

1. Render at least one legacy notification lacking the new snapshot fields.
2. Confirm it uses a safe localized fallback.
3. Re-fetch/poll the same unread and read notification set several times.
4. Prove that the same event does not replay its popup or sound.

If Chrome or Android is unavailable in the environment, state that limitation precisely. Do not claim those platforms passed. Firefox evidence is acceptable for the available Web browser, but the Arabic shaping fix must still be implemented in a standards-compatible way.

---

# 11. Evidence and observability

Create:

`docs/evidence/sprint4_2_1/`

Include:

- before/after Arabic map screenshots;
- English LTR and Arabic RTL screenshots;
- manager assignment dialog screenshot;
- driver detailed assignment dialog screenshot;
- enriched pickup/delivery notification screenshots;
- map phase-transition sequence screenshots;
- browser acceptance log/JSON;
- notification deduplication evidence;
- tenant-isolation evidence;
- pre/post user-tenant data-count evidence if any browser test data was created;
- map operation counts;
- backend and Flutter test summaries;
- Web release build result;
- Docker health result.

Record at least these map counters for the continuous transition test:

- map instances created/disposed;
- style loads;
- image registrations;
- symbol additions/updates/removals;
- line additions/updates/removals;
- circle additions/updates/removals;
- global clears;
- polling camera moves;
- explicit follow/recenter camera moves;
- recoverable annotation errors;
- fatal renderer/style errors.

Evidence must correspond to the final code, not an intermediate build.

---

# 12. Documentation

Update:

- `README.md` with the verified Web map/Arabic-label configuration and development commands;
- architecture documentation with map lifecycle/error boundaries, notification snapshot design, assignment policy, and active-operations query behavior;
- environment-variable documentation if the renderer/style configuration changes;
- `SPRINT4_2_1_IMPLEMENTATION_PLAN.md` with final outcomes and actual elapsed times.

Document any compatibility fallback and why it exists.

Do not include secrets or real user credentials in documentation or evidence.

---

# 13. Definition of done

Sprint 4.2.1 is complete only when all of the following are true:

- The map remains alive through pickup arrival and departure-to-delivery transitions.
- Annotation failures cannot incorrectly trigger the fatal basemap failure screen.
- Arabic city labels are correctly ordered and shaped in the real Web map, or a documented renderer-specific Latin fallback prevents broken Arabic while the primary supported renderer passes.
- New operational notifications identify the truck, trip, event, location, and time.
- Popup, sound, bell list, and notification navigation use consistent event data.
- Duplicate polls do not replay the same sound or popup.
- Driver assignment/confirmation UI shows complete operational trip details.
- Every assignment entry point follows the same linked-driver and eligibility policy.
- No flow silently chooses the first available driver.
- Active-operations UI contains no new hardcoded user-facing English text.
- Backend filtering/projection is tenant-safe and no longer performs obvious broad in-memory loading.
- Existing data, credentials, `.env`, and PostgreSQL volume are preserved.
- No test data remains inside the user’s existing tenant.
- All available automated validation passes.
- Real-browser evidence proves the manager/driver workflow and Arabic map rendering.
- Documentation and the elapsed-time plan are complete.
- Changes remain uncommitted and unpushed.

---

# Final response format

When finished, report:

1. Root causes found.
2. Implementation summary grouped by map, Arabic labels, notifications, driver confirmation, assignment, localization, and backend query hardening.
3. Exact automated test totals and build results.
4. Real-browser scenarios completed.
5. Map-operation counters.
6. Arabic label examples verified.
7. Data-preservation and tenant-isolation evidence.
8. Migration details, if any.
9. Environment limitations.
10. Actual active elapsed time by task and total.
11. Paths to the plan and evidence.
12. `git status` summary confirming that no commit or push was performed.

Be explicit about anything not tested. Do not describe compilation alone as visual or browser validation.
