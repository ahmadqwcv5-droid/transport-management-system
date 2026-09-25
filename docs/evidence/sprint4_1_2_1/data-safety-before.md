# Sprint 4.1.2.1 Retained Data Safety — Before

Recorded on `2026-09-25` after the user resumed manual testing. The retained
Compose project was `tms-smoke`; its PostgreSQL and API containers were healthy.
The PostgreSQL volume was `tms-smoke_postgres_data` and the private photo volume
was `tms-smoke_truck_photo_data`. The active manual-testing account was
`owner@demo.local` in Demo Transport.

The API was stopped immediately after this snapshot so the development
simulator could not produce retained writes during isolated acceptance.
PostgreSQL remains healthy. No secret, credential, token, connection string,
internal identifier, or `.env` value is recorded here.

| Owner | Company | Users | Clients | Trucks | Drivers | Trips | Positions | Notifications | Photos |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `owner@demo.local` | Demo Transport | 3 | 5 | 11 | 9 | 40 | 132189 | 21 | 2 |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 3 | 83 | 104 | 127 | 95 | 16908 | 32 | 19 |
| `sprint321@demo.local` | Sprint321Smoke | 1 | 4 | 4 | 4 | 4 | 699 | 0 | 0 |

All Sprint 4.1.2.1 browser/runtime writes must use a distinct Compose project
and named volumes that do not reference either retained volume.
