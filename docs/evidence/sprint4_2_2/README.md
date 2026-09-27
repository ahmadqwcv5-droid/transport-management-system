# Sprint 4.2.2 evidence

All browser images in this directory were captured from real Firefox profiles
through GeckoDriver against the isolated `tms-sprint422` tenant. The isolated
database, media volume, containers, browser sessions, and temporary credentials
were removed after capture.

## Results

- [Automated validation](automated-validation.md)
- [Baseline and root causes](baseline-and-root-causes.md)
- [Renderer and label investigation](renderer-and-labels.md)
- [Browser acceptance](browser-acceptance.md)
- [Chronology and migration](chronology-and-migration.md)
- [Data-safety proof](data-safety.md)
- [Browser result JSON](browser-result.json)
- [Owner camera interaction JSON](owner-camera-interaction-result.json)
- [Map and telemetry counters](map-and-telemetry-counters.json)

## Genuine map and browser captures

| Evidence | Actual contents |
|---|---|
| `owner-arabic-basemap-before-rtl-fix.png` | Real MapLibre dashboard before the RTL renderer fix; Arabic is reversed |
| `owner-arabic-basemap-after-rtl-fix.png` | Real Arabic dashboard map after the fix, including required cities and attribution |
| `owner-english-basemap-matching-area.png` | Matching English basemap area |
| `owner-arabic-road-and-ref.png` | Arabic road/place labels plus Latin M1/M5 references and attribution |
| `owner-operational-area-settings-en.png` | English operational-area search/preview/save UI |
| `owner-operational-area-settings-ar.png` | Arabic RTL operational-area UI |
| `owner-operational-overview-en.png` | Persisted fleet overview with configured area |
| `owner-follow-after-three-wheel-zooms.png` | Follow remains active after three wheel zooms |
| `owner-follow-after-five-updates.png` | Follow remains active after five position updates |
| `owner-pan-paused-follow-fixed.png` | Pan exposes Resume follow |
| `owner-pan-remains-paused-after-update.png` | A later position moves the marker without stealing the free camera |
| `driver-idle-vehicle-en.png` | Default-linked truck visible with no active trip |
| `driver-idle-vehicle-after-30-updates.png` | Idle Driver vehicle after the motion run |
| `driver-assigned-trip-converged.png` | Already-open Driver profile after Owner assignment |
| `driver-post-trip-vehicle-map.png` | Truck map retained after completion while the vehicle session remains active |
| `owner-motion-frame-01/15/30.png` | Timestamped Owner motion sequence |
| `driver-motion-frame-01/15/30.png` | Timestamped Driver motion sequence |

No failed, renamed non-map, or unrelated-page image is indexed. A video was not
necessary because six timestamped frames, thirty position updates, deterministic
interpolation tests, and operation counters provide reproducible proof.
