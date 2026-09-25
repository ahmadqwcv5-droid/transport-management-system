# Sprint 4.1.2.1 Acceptance Evidence

Sprint 4.1.2.1 passed its mandatory assignment-to-moving-truck acceptance on
2026-09-25 using the isolated `tms-s4121` PostgreSQL/API stack, a release
Flutter Web build, Firefox/GeckoDriver, OpenFreeMap, and separate Firefox
profiles for Owner and Driver.

The Owner assigned the disposable truck and linked Driver in the UI. The
Driver saw the persisted assignment notification, pressed **Open trip**, and
confirmed departure in the UI. No Owner approach preview, manager override,
direct departure API call, or simulator step was used. The backend created an
OSRM approach plan, transitioned the trip to `EnRouteToPickup`, and appended
`DriverDepartedToPickup`. With the Owner profile closed, persisted trail points
increased from 5 to 9 during an eight-second interval with no intervening
acceptance read.

Primary artifacts:

- `browser-result.json`: machine-readable pass and persisted observations.
- `browser-acceptance.md`: scenario narrative and boundaries.
- `driver-assignment-notification.png`: explicit Driver confirmation alert.
- `driver-assignment-en.png` and `driver-workspace-ar.png`: English/LTR and
  Arabic/RTL workspaces.
- `driver-moving-ar.png`: Driver approach route and moving truck.
- `owner-approach-route.png`: Owner approach route, trail, remaining distance,
  ETA, and active trip from the same persisted state.
- `automated-validation.md`: backend, Flutter, migration, build, and Android
  environment results.
- `data-safety-before.md` and `data-safety-after.md`: retained-data isolation
  and restoration comparison.

Disposable credentials and tokens were kept only in `/tmp` during execution
and are not stored in this directory.
