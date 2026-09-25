# Sprint 4.1.2 Retained Data Safety — Before

Recorded at `2026-09-25 11:38:52 +03:00`. This evidence excludes passwords,
hashes, tokens, connection strings, and internal user/company identifiers.

## Retained environment

- Compose project: `tms-smoke`.
- PostgreSQL container: `tms-smoke_postgres_1`.
- PostgreSQL volume: `tms-smoke_postgres_data` mounted at
  `/var/lib/postgresql`.
- Photo volume: `tms-smoke_truck_photo_data`.
- API environment: Development; the API container was stopped during the
  before-count query, preventing application migration or simulator writes.
- PostgreSQL alone was started against the already-confirmed retained volume
  for the read-only aggregate query and was healthy.
- No Sprint 4.1.2 acceptance container or volume existed or mounted the
  retained volume.
- The older `transport-management-system_postgres_data` and photo volume remain
  separate and untouched.

## Retained aggregate baseline

| Owner | Company | Trucks | Clients | Drivers | Trips | Photos |
|---|---|---:|---:|---:|---:|---:|
| `owner@demo.local` | Demo Transport | 11 | 5 | 9 | 34 | 2 |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 104 | 83 | 127 | 95 | 19 |
| `sprint321@demo.local` | Sprint321Smoke | 4 | 4 | 4 | 4 | 0 |

The active manual-testing tenant is Demo Transport under
`owner@demo.local`. Sprint 4.1.2 runtime and browser acceptance must use a new
disposable Testing project and must reproduce these retained counts exactly
afterward.
