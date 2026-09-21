# Sprint 3.2.2 Evidence

Final capture refreshed on 2026-09-21 against the Docker Compose PostgreSQL/API stack and a
headless Firefox Flutter Web session. The workflow used the dedicated local
tenant owner `owner@sprint322.local`; no existing demo credentials or tenant
records were changed.

## Browser workflow

`browser_workflow.json` is emitted by the integration-test driver. It records
the IDs created for two trips on one truck, the Trip A point count, every
ordered Trip B segment/run, physical speed, and deterministic 1x/10x progress.
The successful run reported:

- physical speed at 10x: `65 km/h`;
- 1x step progress: approximately `1,001.6 m`;
- 10x step progress: approximately `10,013.5 m`;
- multiple Trip B segments with different tracking-run IDs after reset;
- Trip A and Trip B history remaining independently addressable for the reused
  truck.

`postgres_trip_isolation.txt` is a later read-only query of the preserved
PostgreSQL volume. It confirms that both trip IDs use the same truck ID but have
separate persisted position groups, timestamps, and run counts.

The screenshots show the real MapLibre path rather than the fallback map:

1. `01-trip-b-isolated-10x-physical-speed.png` — selected Trip B, route/trail
   legend, and the physical `65 km/h` speed.
2. `02-post-reset-independent-segments.png` — travelled trail after reset and
   the visibility control exercised off/on.
3. `03-manual-pan-after-10-polls.png` — map state retained after a manual drag
   and ten one-second polling intervals.
4. `04-arabic-rtl-trail-legend.png` — Arabic/RTL dashboard and localized route
   versus trail semantics.

The final integration driver finished with `All tests passed`. It normalizes the
dedicated account to English before launch, captures the first three images in
English/LTR, switches through the settings UI, and captures the fourth in
Arabic/RTL. The same labels and directionality are covered by Flutter widget
tests.

## Stable annotation evidence

`annotation_operation_counts.md` records the focused coordinator-test counts
for ten moving polls. The same test asserts serialized latest-wins updates,
stable independent segment IDs, no global clears, and no polling camera moves.
