# Sprint 3.3 Map Operation Counts

Deterministic Flutter coordinator test over ten ordinary polling snapshots:

| Operation | Count |
|---|---:|
| Approach-route additions | 1 |
| Approach-route updates | 0 |
| Approach-route removals | 0 |
| Cargo-route additions | 1 |
| Cargo-route updates | 0 |
| Cargo-route removals | 0 |
| Truck updates | 10 |
| Trail updates | 10 |
| Global symbol clears | 0 |
| Global line clears | 0 |
| Global circle clears | 0 |
| Poll-triggered camera moves | 0 |

The approach is a stable amber dashed GeoJSON source/layer. Cargo remains a
separate stable blue annotation, actual trails remain green, and normal polling
does not override manual camera movement.
