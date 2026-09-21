# Annotation operation counts

Source: `fleet_map_coordinator_test.dart`, test
`ten moving polls produce stable operation-count evidence`.

| Operation | Initial load | Ten polls | Total |
|---|---:|---:|---:|
| Marker image registrations | 1 | 0 | 1 |
| Truck symbol additions | 1 | 0 | 1 |
| Truck symbol updates | 0 | 10 | 10 |
| Truck symbol removals | 0 | 0 | 0 |
| Planned-route additions | 1 | 0 | 1 |
| Planned-route updates/removals | 0 | 0 | 0 |
| Trail additions | 1 | 0 | 1 |
| Trail in-place updates | 0 | 10 | 10 |
| Trail removals | 0 | 0 | 0 |
| Stop additions | 2 | 0 | 2 |
| Stop removals | 0 | 0 | 0 |
| Global symbol/line/circle clears | 0 | 0 | 0 |
| Camera moves caused by polling | 0 | 0 | 0 |

The adjacent independent-segment test starts with two stable run IDs and
updates both lines in place without additions, removals, or global clearing.
