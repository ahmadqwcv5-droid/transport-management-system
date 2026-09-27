# Firefox acceptance

The successful run used independent headless Firefox Owner and Driver profiles
from `2026-09-27T03:46:10Z` to `03:49:54Z`. Poll intervals were two seconds for
Dashboard and three seconds for Active Operations/detail.

## Verified

- A truck without a linked default left Driver empty.
- Driver received an assignment with trip/truck/client/cargo/stops/schedule/
  route context, then confirmed departure, loading, and delivery.
- Owner map stayed open for 65 seconds (at least 30 polls) and the same
  `flt-platform-view` element survived pickup and departure-to-delivery.
- Pickup and delivery notification snapshots identified truck, trip, stop, and
  event time; completion notification count was exactly one.
- Completion persisted in 2.047 seconds. The open Owner dashboard count
  converged in 2.070 seconds; detail and Completed-tab navigation also passed.
- Arabic and English screenshots use the real MapLibre/OpenFreeMap canvas. The
  Arabic accessibility tree contained localized RTL application content plus
  the `حلب Aleppo` and `بيروت Beirut` route endpoints; the regional viewport was
  chosen to include Homs and Damascus basemap labels as well.

The selected-truck Flutter dropdown was not reliably actionable through
Firefox's semantics DOM. The harness recorded `defaultDriverUi: false` and used
its isolated API fallback for that one action. It did not hide this limitation.
Default recommendation, no-default behavior, and manual-override preservation
all pass focused widget tests; `no-default-driver.png` is real-browser evidence.

The successful machine-readable record is `browser-result.json`. Subsequent
attempts to improve the Selenium dropdown/scroll mechanics did not change the
product and are excluded from the acceptance record.
