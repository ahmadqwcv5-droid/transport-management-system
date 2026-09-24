# Sprint 4.1 Acceptance Evidence

The authenticated headless-Firefox workflow passed against the containerized
API and retained PostgreSQL volume on 2026-09-24 UTC. It used dedicated
Development/Testing manager and linked-driver accounts. No retained password,
credential, migration history, or PostgreSQL volume was reset.

## Result

- Secure PNG upload, server-side decode/WebP processing, authenticated list,
  detail, card, and live-map photo rendering: passed.
- Real MapLibre style load and marker selection; Follow Selected Truck, manual
  pan pause, Resume Follow, and one-shot Route Overview: passed.
- Stable two-sample/20-second pickup and delivery geofences: passed, with one
  transition and one notification at each stop.
- Arabic/RTL manager workflow and English/LTR driver/manager workflow: passed.
- Linked driver confirmed loading/departure and delivery; the trip reached
  `Completed` and both truck and driver returned to `Available`: passed.
- A second linked driver could not see the first driver's trip: passed.
- Notification feed, unread badge, route refresh, and logout/login redirect:
  passed without a manual page reload.
- Machine-readable assertions: `browser_workflow.json`.
- Screenshots: `01-manager-arabic-live-dashboard.png` through
  `14-manager-english-notifications.png`; `03b-dashboard-return.png` records
  the map-style/accessible-selector regression check.

The run exposed and verified fixes for a root-owned Compose photo volume, an
accessible map selector that was incorrectly gated on an optional annotation
callback, stale notification data when opening the notification screen, and
programmatic camera callbacks being mistaken for manual gestures.

## Coverage boundaries

The browser workflow uploads a real valid PNG through the live authenticated
API and verifies the processed photo in the real Flutter Web UI. Automated
backend coverage additionally rejects invalid bytes and cross-tenant reads.
The browser does not automate the operating-system file picker itself.

The repository's deterministic map coordinator tests cover ten consecutive
selected-truck updates and prove that Follow moves the camera while Free and
Route Overview do not refit it. The browser evidence exercises the same
production adapter with a real loaded MapLibre style.

Android was not built or run because this machine has no usable Android SDK,
`adb`, emulator, or connected Android device. This is an environment
limitation, not a failed application build.
