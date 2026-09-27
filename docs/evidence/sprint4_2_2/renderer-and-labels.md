# Renderer and locale-aware labels

## Runtime facts

- Browser: Firefox through GeckoDriver.
- Renderer: MapLibre GL JS 6.4.1 through `maplibre_gl 0.27.1`.
- Style: OpenFreeMap Liberty, Mapbox Style Specification version 8.
- Style endpoint: `https://tiles.openfreemap.org/styles/liberty`.
- Vector source: `https://tiles.openfreemap.org/planet`.
- Glyph template: `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`.
- Sprite root: `https://tiles.openfreemap.org/sprites/ofm_f384/ofm`.
- Relevant fonts: Noto Sans Regular and Noto Sans Bold.

The responsible Liberty layers included `label_city`,
`label_city_capital`, `highway-name-major`, and
`highway-shield-non-us`. The city and road expressions concatenated Latin and
non-Latin properties, which exposed the Firefox RTL shaping defect.

## Implemented policy

`LocaleAwareMapStyle` fetches and caches the configured style, then transforms
only symbol-layer name expressions once per locale/style:

- Arabic: `name:ar` → `name:nonlatin` → `name` → `name:latin` → `name_en`.
- English: `name:latin` → `name_en` → `name` → `name:nonlatin`.

It does not mutate style data during polling and leaves reference-only labels,
sprites, glyphs, tiles, and attribution intact. Locale change performs one
controlled style reload and rehydrates markers/routes without duplication.

MapLibre 6.4.1 normally contains RTL support, but this wrapper/browser path
stayed at `requested` and visibly reversed Arabic. The app therefore loads the
pinned local `mapbox-gl-rtl-text 0.3.0` asset once. The verified status after
the fix was `loaded`; no manual string reversal is used.

## Raw tile facts and visual proof

Decoded OpenFreeMap vector properties included:

- Homs: `name/name:ar/name:nonlatin = حمص`,
  `name:latin/name_en = Homs`.
- Damascus: `دمشق` / `Damascus`.
- Aleppo: `حلب` / `Aleppo`.
- Beirut: `بيروت` / `Beirut`.
- Motorway: `name:ar = حمص - اللاذقية`,
  `name:latin = Homs - Latakia`, `ref = M1`.
- Motorway: `name:ar = طريق حلب دمشق الدولي`,
  `name:latin = Aleppo-Damascus International Highway`, `ref = M5`.

The original-resolution before/after, matching English, and Arabic road/reference
screenshots are indexed in [README.md](README.md). They show the actual canvas,
surrounding geography, and OpenFreeMap/OpenMapTiles/OpenStreetMap attribution.
