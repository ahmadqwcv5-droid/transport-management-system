# Concept B — Night Dispatch / غرفة الترحيل

**Identity:** focused, technical, live, precise, confident.

Night Dispatch is a dedicated operations room rather than a conventional dark
theme. The quiet midnight grid recedes while live routes, state boundaries, and
exceptions glow. The code-native mark is a tracking sweep with one live point.
Panels dock over the map to preserve spatial attention.

## Palette and type

| Role | Name | Hex |
|---|---|---|
| Canvas | Midnight operations | `#061821` |
| Surface | Dispatch panel | `#0B2630` |
| Strong surface | Telemetry dock | `#103541` |
| Ink | Cool white | `#EAF7F4` |
| Muted | Instrument grey | `#8FAEB2` |
| Border/grid | Radar line | `#214953` |
| Primary/live | Pulse aqua | `#35D0C3` |
| Secondary | Route blue | `#71A7FF` |
| Warning | Beacon amber | `#FFB45C` |
| Danger | Alert coral | `#F06772` |
| Success | Confirm green | `#52D68B` |

- Arabic: bundled Noto Sans Arabic with bold numeric instruments.
- Latin: bundled Noto Sans; uppercase is limited to small telemetry labels.

## Interaction language

- Narrow instrument rail and docked, bordered telemetry panels.
- Map occupies the full command canvas; KPIs float in one dense control band.
- Tables use luminous selection boundaries rather than filled generic rows.
- Controls have precise 3 px corners and high-visibility focus outlines.
- Loading uses quiet grid/skeleton segments, never continuous whole-page glow.
- Motion: a 200 ms radar selection shift, 280 ms telemetry progress, and
  140–200 ms alert entry. Polling never restarts the stage.
- Mobile becomes a cockpit: progress instrument, map, then one action.

## Evidence

- [Dashboard Arabic 1440](concept_b_dashboard_1440_ar.png)
- [Dashboard English 1440](concept_b_dashboard_1440_en.png)
- [Driver Today Arabic 390](concept_b_driver_today_390_ar.png)
- [Driver My Truck Arabic 390](concept_b_driver_truck_390_ar.png)
- [Components and motion](concept_b_components_motion_ar.png)
- [Reduced motion](concept_b_components_reduced_motion_ar.png)
- [Tablet Arabic 768](concept_b_dashboard_768_ar.png)
- [Narrow Arabic 360](concept_b_dashboard_360_ar.png)

## Accessibility and implementation risk

Semantic colors remain labeled and the cool-white/panel pairing provides
strong contrast. Risk is **medium–high**: every deeply migrated screen must be
reviewed for dark-surface contrast, map-style compatibility, print/download
surfaces, and third-party dialogs. Selecting it makes this the primary product
identity; it is not an extra optional dark mode.
