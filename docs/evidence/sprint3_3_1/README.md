# Sprint 3.3.1 Evidence

Captured on 2026-09-21 with the dedicated retained smoke tenant
`owner@sprint322.local`, containerized API/PostgreSQL, headless Firefox,
GeckoDriver, and the real OpenFreeMap MapLibre style. Existing credentials and
tenant records were not overwritten; each diagnostic run created uniquely named
smoke records.

The final passing workflow used truck `S331-3743747`
(`efb41e62-06f8-496c-b0be-3f16d895193d`) and trip
`7ed06b11-f3c6-4580-a18b-a58d54825cf6`.

- The new active truck appeared as **No location**.
- Missing route-preview location opened the English recovery dialog.
- The real picker rendered and its MapLibre click callback selected
  `40.120000, 31.650000`; confirmation through the visible dialog created the
  first position. No direct API location seed was used by the browser path.
- Route-to-pickup preview then succeeded.
- With a test-only 30-second dispatch freshness policy and 5-second simulator
  heartbeat, 36 seconds of stationary observation wrote 7 heartbeat rows. The
  coordinate remained exactly `40.12, 31.65` and state remained Current.
- Pause retained freshness without movement. Offline was visible and preview
  returned `TRUCK_OFFLINE`. Explicit Online restored freshness with no jump.
- A second confirmed picker selection moved the truck to `40.25, 33.10`; the
  persisted coordinate remained unchanged until confirmation.
- English/LTR and Arabic/RTL simulator/map rendering passed.
- The real trip-planner map showed pickup first, then both distinct stop
  markers, then an updated pickup marker, all before route calculation.

Flutter's widget-test pointer does not inject a native DOM click into MapLibre's
embedded Web platform view. The real Firefox workflow therefore invoked the
rendered `MapLibreMap.onMapClick` callback with deterministic click coordinates,
then used the visible dialog and confirmation controls. The map and its selected
marker were captured. This is distinct from a raw OS-level pointer injection and
is recorded here explicitly.

Files:

- `browser_workflow.json`: machine-readable final assertions.
- `postgres_heartbeat.txt`: retained database facts and bounded-row summary.
- `annotation_operation_counts.md`: deterministic incremental-map assertions.
- `01`–`14` PNG files: No location, recovery, real picker, selected point,
  fleet marker, preview, freshness, offline/online, move, Arabic, and immediate
  trip stop marker states.

The browser run also found and fixed a real integration race: a picker click
could arrive after controller creation but before MapLibre initialized its
circle manager. Marker synchronization now waits for the style-loaded callback.
