# Sprint 4.4.2 evidence

## Result

Sprint 4.4.2 passed its automated, widget, release-build, real-browser, Driver
regression, and retained-data safety gates on 2026-10-17. Evidence was collected
against the real local `tms-smoke` API/PostgreSQL stack and a Flutter Web release
build. No credential, bearer token, invitation/QR secret, OAuth value, or
personal data is retained here.

## Automated validation

- Repository-local .NET Release build: passed with 0 warnings and 0 errors.
- Backend tests: 106 passed.
- EF Core model drift check: no pending model changes.
- Flutter analyzer: no issues.
- Full Flutter suite: 138 passed.
- Post-fix focused map/Atlas/regression group: 32 passed.
- Flutter Web release build: passed. The known
  `flutter_secure_storage_web` WASM dry-run advisory is not relevant to the
  generated JavaScript artifact.

## Widget and unit proof

The Atlas Pulse suite covers unavailable-versus-zero KPI semantics, fleet
filtering, synchronized and retained selection, idle-truck truthfulness,
RTL/LTR order and identifier isolation, 1440/1024/390 responsive layouts,
reduced motion, stable map/controller identity, wheel ownership, follow/zoom,
manual-pan/free-explore, and polling camera policy. Existing Driver and map
regression suites also pass. The locale-aware map-style test additionally proves
that a failed remote style load is evicted and a later explicit retry succeeds.

These are deterministic test results; they are not presented as substitutes for
the real-browser runs below.

## Real Chromium — Owner command center

The real retained Owner signed in, opened the Arabic RTL dashboard, switched the
actual UI to English LTR, and remained backed by live API state. To avoid
changing the retained account preference, the browser harness intercepted only
the preference-persistence request during the locale-switch check.

Verified in the browser:

- real KPI content plus truthful partial, empty, and unavailable presentation;
- truck selection from both map and fleet dock, with synchronized inspector,
  route/trail/stops, and lower rail;
- all six filters: all, online, moving, stopped, offline, and attention;
- wheel zoom without page scrolling, follow-preserving zoom, manual-pan pause,
  free explore, explicit recenter/follow, and route overview;
- 30 live tracking updates while free exploring without losing selection;
- one production map instance, no disposal/recreation, no global annotation
  clears, no polling camera move, no repeated image registration, and no fatal
  renderer/page error;
- explicit map-style failure followed by successful retry in the same UI;
- Arabic and English hierarchy at 1440 x 900, compact 1024 x 768, and narrow
  390 x 844 without overflow;
- Owner logout stopped only the Owner polling loop.

The captured lifecycle counters are in
[`browser-acceptance.json`](browser-acceptance.json). Highlights: 1 map create,
0 disposals, 1 image registration, 20/85/10 symbol adds/updates/removals,
20/85/10 status-ring adds/updates/removals, 0 global symbol/line/circle clears,
0 polling camera moves, 1 follow-preserving zoom, 1 manual-pan pause, and 0
fatal renderer errors. The console recorded two generic nonfatal resource 404s;
there were no page exceptions, map failure, or fatal renderer errors.

Screenshots:

- [`owner-dashboard-ar-1440x900.png`](owner-dashboard-ar-1440x900.png)
- [`owner-dashboard-en-1440x900.png`](owner-dashboard-en-1440x900.png)
- [`owner-dashboard-compact-1024x768.png`](owner-dashboard-compact-1024x768.png)
- [`owner-dashboard-narrow-390x844.png`](owner-dashboard-narrow-390x844.png)
- [`owner-selected-route-inspector.png`](owner-selected-route-inspector.png)
- [`owner-filter-attention.png`](owner-filter-attention.png)
- [`owner-partial-state.png`](owner-partial-state.png)
- [`owner-empty-state.png`](owner-empty-state.png)
- [`owner-map-failure.png`](owner-map-failure.png)
- [`owner-map-recovered.png`](owner-map-recovered.png)

## Reduced motion

[`browser-reduced-motion-preference.png`](browser-reduced-motion-preference.png)
proves that a real Chromium context exposed `prefers-reduced-motion: reduce` and
rendered the public UI. Authenticated dashboard transition behavior is proved by
the widget test because the headless reduced-motion context did not complete an
authenticated form submission. This limitation is explicit: the screenshot
alone is not claimed as an authenticated reduced-motion dashboard run.

## Real Chromium — isolated Driver regression

Two genuinely isolated Chromium storage contexts ran concurrently. A uniquely
identified disposable Driver account was linked through the real API, then the
Driver opened Today, My Truck, My Trips, and Profile/Settings. Logging out the
Driver stopped Driver polling without logging out the Owner or interrupting
Owner polling. The disposable membership, role, invitation, Driver, account,
refresh token, audit row, and notification rows were then removed by exact ID;
no retained business record or original credential was changed.

- [`driver-browser-acceptance.json`](driver-browser-acceptance.json)
- [`driver-today.png`](driver-today.png)
- [`driver-my-truck.png`](driver-my-truck.png)
- [`driver-my-trips.png`](driver-my-trips.png)
- [`driver-profile-settings.png`](driver-profile-settings.png)

## Post-recovery integrity and retained data

- Root filesystem: 5.1 GB free; project filesystem: 68 GB free.
- API and PostgreSQL containers: healthy.
- `pg_is_in_recovery()`: `false`.
- Latest migration: `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`.
- Retained counts before and after browser work: 3 companies, 13 users, 120
  trucks, 141 drivers, and 147 trips.
- Retained volumes remain `tms-smoke_postgres_data` (created
  2026-09-17T00:24:50+03:00) and `tms-smoke_truck_photo_data` (created
  2026-09-24T23:38:12+03:00).
- `.env` SHA-256 remained
  `65d1ae1ee7f3abcd65d6bf29797ea04c4e833c4109c426a34820f656a52ce6f0`;
  its contents were not copied into evidence.
- Recent PostgreSQL logs contain normal completed checkpoints and no recovery,
  corruption, repeated I/O, checkpoint-failure, or panic record. Four statements
  were cancelled when browser contexts closed. A final audit command also
  produced one harmless unknown-role error before being rerun with the configured
  role.
- The original Owner authenticated and loaded retained business/dashboard data.
- Exact post-cleanup checks found no remaining disposable Sprint 4.4.2 user,
  Driver, or invitation.

## Deliberate scope and limitations

Atlas Pulse remains scoped to Owner/Operations command surfaces. Light CRUD and
Driver UI, backend contracts, schema, operational rules, SignalR, and advanced
analytics are deliberately unchanged. Browser acceptance used available real
Chromium; Firefox was not required because Chromium was available. The two
nonfatal resource 404 console messages are retained above rather than hidden.
No commit or push is part of this sprint task.
