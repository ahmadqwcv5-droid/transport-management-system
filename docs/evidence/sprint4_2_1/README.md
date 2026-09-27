# Sprint 4.2.1 evidence

Recorded on 2026-09-27 in Europe/Istanbul against the isolated `tms-s421`
Compose project. No retained volume was mounted and `.env` was not edited.

## Result

- Backend build and all 78 tests passed; EF reports no pending model changes.
- Flutter analysis and all 69 tests passed; the release Web build passed.
- The isolated API and PostgreSQL containers became healthy.
- One complete two-profile Firefox run passed assignment through completion.
  It kept the same platform-view element across pickup and delivery transitions,
  observed 65 seconds of two-second dashboard polling, persisted completion,
  converged the already-open Owner view, and emitted one completion event.
- A real Firefox Arabic route view and matching English view were captured with
  OpenFreeMap Liberty. Arabic application content was present in the accessibility
  tree and the Arabic/Latin stop labels were not manually reversed.
- The disposable database was dropped/recreated empty and the stack stopped.
  Retained counts were identical before and after.

## Evidence index

- `browser-result.json`: successful two-profile run and convergence timings.
- `map-operation-counts.json`: deterministic 30-update coordinator counters.
- `automated-validation.md`: build, test, EF, Web, Docker, and platform results.
- `browser-acceptance.md`: scenarios, screenshots, and the Selenium limitation.
- `renderer.md`: actual renderer/style/glyph/font/RTL investigation.
- `data-safety.md`: isolated resources, cleanup, and retained counts.
- `active-to-pickup.png`, `pickup-arrival.png`, `active-to-delivery.png`, and
  `delivery-awaiting-confirmation.png`: stable-map phase sequence.
- `driver-identity-assignment.png` and `driver-post-trip-session.png`: Driver
  assignment context and post-completion session.
- `dashboard-after-completion.png`, `owner-detail-completed.png`, and
  `completed-trips.png`: Owner convergence without reload.
- `arabic-rtl-four-city-map.png` and `english-ltr-four-city-map.png`: real
  regional route map in both application locales.
- `no-default-driver.png`: no arbitrary Driver selection.

The later `browser-failure-*.png` files came from harness-only investigations
after the successful recorded run; they are not acceptance results and are not
retained in the final evidence set.

## Honest limitations

Firefox/Flutter semantics did not expose the selected truck dropdown reliably,
so `defaultDriverUi` is false in the browser JSON and the harness used its
tenant-scoped assignment API fallback. The shared default/no-default/manual
selection policy is covered by focused Flutter tests and the no-default browser
screenshot. Chrome and Android were unavailable on this machine. Firefox was
the supported real-browser path used here.
