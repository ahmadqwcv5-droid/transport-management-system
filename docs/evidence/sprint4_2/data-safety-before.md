# Sprint 4.2 Retained Data Safety — Before

Recorded `2026-09-26 11:33 +03:00`. Both retained `tms-smoke` containers were stopped at sprint start. PostgreSQL was temporarily started alone for this read-only snapshot and returned to stopped. Retained volumes are `tms-smoke_postgres_data` and `tms-smoke_truck_photo_data`.

| Owner | Company | Users | Clients | Trucks | Drivers | Trips | Positions | Notifications | Photos | Trip statuses |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `owner@demo.local` | Demo Transport | 4 | 5 | 11 | 9 | 41 | 141647 | 32 | 2 | Draft 10; Cancelled 9; Completed 20; InTransit 1; AtDelivery 1 |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 3 | 83 | 104 | 127 | 95 | 47283 | 36 | 19 | Draft 19; Assigned 26; EnRouteToPickup 1; AtPickup 19; InTransit 3; AtDelivery 10; Completed 17 |
| `sprint321@demo.local` | Sprint321Smoke | 1 | 4 | 4 | 4 | 4 | 13003 | 0 | 0 | InTransit 4 |

No identifiers, credentials, tokens, connection strings, or `.env` values are recorded. Runtime acceptance must use a distinct disposable project and volumes.
