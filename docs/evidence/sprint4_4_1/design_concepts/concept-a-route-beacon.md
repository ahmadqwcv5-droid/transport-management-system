# Concept A — Route Beacon / منارة المسار

**Identity:** directional, grounded, warm, decisive, human.

Route Beacon treats each operational screen as a journey with one continuous
spine and a small number of unmistakable beacon moments. Warm mineral surfaces
reduce the sterile admin-tool feeling; rust red is reserved for primary
direction and teal for live/healthy movement. The code-native mark is an
abstract route bending toward a destination beacon and is intentionally easy
to replace.

## Palette and type

| Role | Name | Hex |
|---|---|---|
| Canvas | Dune | `#F3EDE2` |
| Surface | Cargo paper | `#FFFBF3` |
| Strong surface | Packed sand | `#E8DED0` |
| Ink | Basalt | `#29231F` |
| Muted | Weathered stone | `#71665D` |
| Border | Dry clay | `#D8CABC` |
| Primary/route | Signal rust | `#B7432A` |
| Secondary/live | Wayfinding teal | `#24756F` |
| Warning | Beacon amber | `#D39A32` |
| Danger | Brake red | `#9F2E2E` |
| Success | Arrival green | `#2E7651` |

- Arabic: bundled Noto Sans Arabic, regular 400 and bold 700.
- Latin: bundled Noto Sans, regular 400 and bold 700.
- Numerals and operational references stay high-contrast and compact.

## Interaction language

- Narrow dark route rail on desktop; destination labels remain short.
- Warm layered cards with a route-spine hierarchy rather than equal tiles.
- Fleet list is a calm manifest beside a dominant map.
- Inputs and buttons use compact 6 px geometry and strong directional color.
- Empty/error states use a route interruption plus one explicit recovery
  action.
- Motion: selection travels in 240 ms, trip progress resolves in 320 ms, and
  notifications rise/fade in 160–240 ms. Reduced motion settles immediately.
- Mobile uses a fixed four-destination bar and route-first Today card.

## Evidence

- [Dashboard Arabic 1440](concept_a_dashboard_1440_ar.png)
- [Dashboard English 1440](concept_a_dashboard_1440_en.png)
- [Driver Today Arabic 390](concept_a_driver_today_390_ar.png)
- [Driver My Truck Arabic 390](concept_a_driver_truck_390_ar.png)
- [Components and motion](concept_a_components_motion_ar.png)
- [Reduced motion](concept_a_components_reduced_motion_ar.png)
- [Tablet Arabic 768](concept_a_dashboard_768_ar.png)
- [Narrow Arabic 360](concept_a_dashboard_360_ar.png)

## Accessibility and implementation risk

Status always combines label, icon, and color. Rust on cargo paper and basalt
body text have deliberate contrast; minimum controls remain 48 px. Risk is
**low–medium** because this direction can extend the current light foundation
without making map rendering or information density exotic.
