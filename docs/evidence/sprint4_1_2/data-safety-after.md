# Sprint 4.1.2 Retained Data Safety — After

Recorded on 2026-09-25 after stopping the isolated `tms-s412` containers and
restarting only the retained `tms-smoke` PostgreSQL service. The retained API
remains stopped, matching its pre-acceptance state. Disposable volumes were
preserved and never mounted by the retained project.

| Owner | Company | Trucks | Clients | Drivers | Trips | Photos |
|---|---|---:|---:|---:|---:|---:|
| `owner@demo.local` | Demo Transport | 11 | 5 | 9 | 34 | 2 |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 104 | 83 | 127 | 95 | 19 |
| `sprint321@demo.local` | Sprint321Smoke | 4 | 4 | 4 | 4 | 0 |

Every count exactly matches the before snapshot. No migration or acceptance
write was applied to retained data, and no backup was required because retained
migration was never attempted.
