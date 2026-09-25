# Real-browser acceptance

## Environment

- API/PostgreSQL: disposable Compose project `tms-s4121`, ports 5080/5432.
- Data: dedicated `tms-s4121` PostgreSQL and photo volumes, checked not to
  reference either retained `tms-smoke` volume.
- Client: Flutter Web release bundle on `http://localhost:3000`.
- Browser: headless Firefox controlled by GeckoDriver.
- Maps: real MapLibre with the OpenFreeMap style.
- Authentication: separate GeckoDriver-created Firefox profiles/storage for
  Owner and Driver. The Owner profile used for assignment was closed before
  Driver departure.

## Passed scenario

1. Supported owner APIs created disposable client, truck, linked Driver account,
   ready commercial route, and fresh online starting telemetry.
2. Owner logged in through Flutter, opened Planned trips, opened the disposable
   trip, selected the intended truck and linked Driver, and pressed Assign.
3. A separately created Driver browser profile displayed the unread assignment
   badge and actionable persisted notification with **Open trip**.
4. Driver pressed **Open trip**; the refreshed workspace showed the prominent
   departure action above the usable map in English/LTR and Arabic/RTL.
5. Driver pressed **Confirm departure to pickup** and confirmed the warning
   dialog. Test code did not call the departure endpoint.
6. Backend evidence showed `EnRouteToPickup`, an OSRM approach plan, and one
   `DriverDepartedToPickup` event with no override event.
7. With no Owner browser open, trail points advanced from 5 to 9 across an
   eight-second no-read interval.
8. A newly isolated Owner profile then displayed the same moving truck,
   approach route, travelled trail, progress, remaining distance, and ETA.

No manager preview/dispatch, manager override, direct departure API call, or
manual simulator step occurred. `browser-result.json` is the authoritative
machine-readable outcome.

## Harness note

Flutter's debug web server lost its single debug WebSocket attachment during
re-navigation. Acceptance therefore used the already validated release bundle
served locally, raw W3C WebDriver calls, and Flutter semantics/pointer input.
This removed the legacy Flutter Drive aggregation failure without suppressing
browser exceptions.
