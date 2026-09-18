# Map marker assets

`truck_top_down.png` is original project artwork generated for this repository
with OpenAI's built-in image-generation tool on 2026-09-18. The production
prompt requested a transparent, north/up-facing, top-down articulated lorry
with no logo, text, plate, road, or third-party brand. A second
background-extraction pass removed the backdrop and glow. The retained Flutter
asset is a 64×96 RGBA PNG derived from that result.

The marker's intrinsic forward direction is north/up, so the MapLibre tracking
heading offset is `0°`. The asset is project-owned and distributed under the
same license terms as this repository; it does not incorporate a third-party
icon pack.
