# Sprint 3.3 Evidence

Captured on 2026-09-21 with the retained `tms-smoke` PostgreSQL volume, the
containerized API, headless Firefox, GeckoDriver, and the real OpenFreeMap
MapLibre style.

The successful workflow reused one truck across two trips:

- Trip A completed at `39.924959, 32.859927`.
- Assigning distant Trip B and polling four times left the coordinate exactly
  unchanged. No assignment-time telemetry row was inserted.
- Starting cargo before arrival returned HTTP 409 with
  `TRUCK_NOT_AT_PICKUP`.
- The server created a separate 441,532.98 m repositioning plan and retained
  the independent 3,450.70 m cargo route.
- Repositioning reached 4.5% while cargo progress remained unstarted.
- The API container was restarted while the simulator was paused. Its first
  restored position remained exactly `39.971208, 32.663321` (0 m delta), with
  the same repositioning plan identity.
- Geographic arrival produced `AtPickup` without setting `ActualStartAt`.
  Cargo began only after the explicit Start action.
- At simulator `10x`, the reported physical speed remained 65 km/h.
- Ten normal polling updates after a manual pan caused no camera movement.
- The same real map was captured in English/LTR and Arabic/RTL.

Files:

- `browser_workflow.json`: machine-readable API and browser assertions.
- `postgres_phase_records.txt`: selected retained telemetry and migration facts.
- `annotation_operation_counts.md`: deterministic map-operation assertions.
- `01`–`07` PNG files: assignment stability, separate routes, active approach,
  AtPickup waiting, explicit cargo start, manual-pan stability, and Arabic RTL.

The first diagnostic browser attempt exposed an integration issue: public OSRM
could return a snapped approach endpoint outside the 50 m pickup radius. The
backend now pins the first and last coordinates of the approach snapshot to the
trusted truck position and exact pickup, while leaving the cargo route
immutable. The final workflow above passed after that correction.
