# Retained Data After Acceptance

Recorded after the disposable Sprint 4.1.1 acceptance attempts on
`2026-09-25`. The query selected only owner email, company name, and aggregate
resource counts. It did not select credentials, tokens, hashes, or row IDs.

| Owner | Company | Trucks | Clients | Drivers | Trips | Compared with before |
|---|---|---:|---:|---:|---:|---|
| `owner@demo.local` | Demo Transport | 11 | 5 | 9 | 28 | Unchanged |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 104 | 83 | 127 | 95 | Unchanged |
| `sprint321@demo.local` | Sprint321Smoke | 4 | 4 | 4 | 4 | Unchanged |

The retained PostgreSQL container remained healthy and mounted
`tms-smoke_postgres_data` at `/var/lib/postgresql`. The acceptance PostgreSQL
container instead mounted
`tms-s411-acceptance_sprint411_postgres_data` at the same in-container
destination. The retained volume was never mounted by the acceptance project.

No backup was required or created because no recovery, remount, import, merge,
or retained-database mutation was attempted. The older unmounted candidate
volume was left untouched.
