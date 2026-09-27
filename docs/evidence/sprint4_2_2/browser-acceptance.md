# Real-browser acceptance

Two independent Firefox profiles ran against the disposable API on port 5180
and Web app on port 3000.

## Owner

- Configured, previewed, saved, reloaded, and cleared/re-saved the operational
  area in English and Arabic. The initial/Fleet overview used persisted bounds.
- Selected the moving truck and confirmed visible follow state.
- Three wheel zooms preserved follow.
- Five subsequent live positions preserved follow and the chosen zoom.
- A real MapLibre drag exposed Resume follow.
- A later position update left Resume follow visible, proving polling did not
  steal the free camera.
- Fleet overview returned to operational bounds. Route overview behavior is
  covered by coordinator tests and was not repeatedly refit by polling.
- Real Arabic canvas captures show the four required cities, connected shaping,
  Arabic roads, M1/M5 references, and attribution; matching English was captured.

## Driver

- A unique default-linked truck appeared without an active trip, with identity,
  status, last position, and map. No route, ETA, progress, or trip action was
  fabricated.
- The already-open Driver profile converged after Owner assignment.
- After isolated lifecycle completion, the vehicle session retained the truck
  map in `POST_TRIP_VEHICLE`.
- Thirty position updates were observed across Owner and Driver profiles; frames
  01, 15, and 30 are retained for each.

For disposable lifecycle setup, the manager API advanced the isolated trip to
completion after a Driver delivery call encountered a legacy status mismatch.
This is not claimed as proof of the Driver delivery button; the tested claim is
workspace polling convergence and post-trip vehicle-map retention.

## Default Driver

Focused product regression tests pass. Real Selenium dropdown manipulation
remained unreliable for Flutter Web. No API fallback is presented as UI proof;
the user had already manually verified correct default-Driver selection.
