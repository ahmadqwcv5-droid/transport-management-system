# Sprint 4.4 visual baseline

Captured from committed Sprint 4.4 at
`dd16677273b95ae2b596ee6139aba23e74ddc0a9` in real Playwright Chromium.
The retained Owner remained Arabic; the English captures changed only the
browser's intercepted login-response locale and never updated the account or
database.

The live MapLibre platform view, retained vehicle identifiers, and account
identity were masked. Layout, navigation, KPI sizing, whitespace, and the map
container remain visible for comparison.

## Matching Owner viewports

| Viewport | Arabic | English |
|---|---|---|
| 1440×900 | [image](owner_dashboard_1440_ar.png) | [image](owner_dashboard_1440_en.png) |
| 768×900 | [image](owner_dashboard_768_ar.png) | [image](owner_dashboard_768_en.png) |
| 390×844 | [image](owner_dashboard_390_ar.png) | [image](owner_dashboard_390_en.png) |

The captures confirm the audit: nine equal KPI cards consume three desktop
rows, the map starts too low, visual hierarchy is mostly generic Material, and
the mobile Owner view requires substantial vertical travel before reaching the
map. Source inspection additionally confirms the current full-screen height
toggle and `/my-trip`/`/my-truck` alias.

`login_1440_en.png` is an additional sanitized entry-surface reference.

No Driver screenshot is presented as a live baseline because no disposable
Driver credential was available without mutating retained accounts. Phase A
concept Driver surfaces therefore use explicit static sanitized fixtures.
