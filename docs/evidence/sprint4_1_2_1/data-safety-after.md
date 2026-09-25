# Sprint 4.1.2.1 Retained Data Safety — After

The `tms-s4121` disposable containers were removed without removing their
isolated volumes. The retained `tms-smoke` PostgreSQL and API services were
restored healthy. Legacy Compose 1.29.2 raised its known `ContainerConfig`
recreation error; only the stopped, stateless API container was removed and
recreated. Neither retained volume was removed or mounted by acceptance.

| Owner | Company | Users | Clients | Trucks | Drivers | Trips | Positions | Notifications | Photos |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `owner@demo.local` | Demo Transport | 3 | 5 | 11 | 9 | 40 | 132200 | 21 | 2 |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 3 | 83 | 104 | 127 | 95 | 16908 | 32 | 19 |
| `sprint321@demo.local` | Sprint321Smoke | 1 | 4 | 4 | 4 | 4 | 699 | 0 | 0 |

All business-resource, notification, and photo counts exactly match the before
snapshot. Demo Transport has 11 additional position rows, written only after
the retained API was restored to its original running state and its existing
development simulator resumed. The retained API stayed stopped throughout
implementation and disposable acceptance, so no Sprint 4.1.2.1 test record or
migration entered retained storage.
