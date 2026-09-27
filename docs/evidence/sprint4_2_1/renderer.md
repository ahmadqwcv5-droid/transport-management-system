# Web renderer and Arabic labels

- Flutter dependency: `maplibre_gl 0.27.1`.
- Web wrapper: `maplibre_gl_web 0.27.1`.
- Actual injected runtime: MapLibre GL JS `6.4.1`, loaded by the wrapper's
  `js_loader.dart` from the versioned unpkg ESM URL.
- Style: configurable `MAP_STYLE_URL`; acceptance used OpenFreeMap Liberty.
- Style specification: version 8.
- Glyphs: `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`.
- Label policy: Liberty uses bilingual `name:latin,name:nonlatin` expressions
  with Noto Sans font stacks.

MapLibre GL JS 4 and newer includes bidirectional text and Arabic shaping. The
current 6.4.1 runtime therefore does not require the deprecated RTL plugin.
No application string reversal, tile-string preprocessing, or Directionality
workaround was added. This preserves mixed Arabic/Latin names and road numbers.

Primary references:

- https://maplibre.org/maplibre-gl-js/docs/API/functions/setRTLTextPlugin/
- https://openfreemap.org/quick_start/

The Arabic and English Firefox captures are `arabic-rtl-four-city-map.png` and
`english-ltr-four-city-map.png`. There was no reproducible broken-label
"before" state with the verified 6.4.1 runtime, so a fabricated before image was
not produced.
