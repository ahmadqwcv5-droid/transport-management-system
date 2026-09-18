# Annotation operation evidence

Scenario: one selected moving truck, one planned route, pickup and delivery
markers, an existing two-point trail, then ten ordinary position/trail-growth
updates. Source: deterministic Flutter test
`ten moving polls produce stable operation-count evidence`.

| Operation | Count |
|---|---:|
| Style image registrations | 1 |
| Symbol additions | 1 |
| Symbol updates | 10 |
| Symbol removals | 0 |
| Status decoration additions | 1 |
| Status decoration updates | 10 |
| Status decoration removals | 0 |
| Planned-route additions | 1 |
| Planned-route updates | 0 |
| Planned-route removals | 0 |
| Trail additions | 1 |
| Trail updates | 10 |
| Trail removals | 0 |
| Pickup/delivery additions | 2 |
| Pickup/delivery removals | 0 |
| Global `clearSymbols` calls | 0 |
| Global `clearLines` calls | 0 |
| Global `clearCircles` calls | 0 |
| Camera moves caused by polling | 0 |

The single camera move produced by initial style readiness is intentionally not
a polling camera move. Every later marker/trail operation updates an existing
annotation handle in place; the planned route and stop markers are untouched.
