# Sprint 4.1.1 Data-Safety Diagnosis

Recorded at `2026-09-25T02:11:40+03:00`. This report intentionally excludes passwords, hashes, tokens, connection strings, and full internal identifiers.

## Active local stack

- Compose project: `tms-smoke`
- API container: `tms-smoke-api-1` (healthy)
- API environment: `Development`
- PostgreSQL container: `tms-smoke-postgres-1` (healthy)
- PostgreSQL image: `postgres:18-alpine`
- Mounted database volume: `tms-smoke_postgres_data` -> `/var/lib/postgresql`
- Mounted truck-photo volume: `tms-smoke_truck_photo_data`
- Plausible older, currently unmounted database volume: `transport-management-system_postgres_data`
- No Flutter Web listener/browser session was active, so there was no current browser-authenticated identity to inspect. The API itself does not have one global active user.

## Owner tenants and retained counts

| Owner | Company | Trucks | Clients | Drivers | Trips |
|---|---|---:|---:|---:|---:|
| `owner@demo.local` | Demo Transport | 11 | 5 | 9 | 28 |
| `owner@sprint322.local` | Sprint 3.2.2 Smoke Tenant | 104 | 83 | 127 | 95 |
| `sprint321@demo.local` | Sprint321Smoke | 4 | 4 | 4 | 4 |

The query selected only email, company, role, active state, and aggregate resource counts. Password hashes were not selected.

## Finding

The unexpected fleet switch is explained by tenant/account selection. The same mounted database contains the user's `Demo Transport` fleet and two smoke tenants. The original-looking non-smoke trucks remain in `Demo Transport`; the large unfamiliar test fleet belongs to `Sprint 3.2.2 Smoke Tenant`. No evidence indicates deletion of the retained rows.

The older `transport-management-system_postgres_data` volume was identified from Compose labels but was not mounted, started, switched, imported, or modified. Because the required data is already present in the active retained volume, no recovery/remount operation is justified.

## Safety actions

- No container or volume was stopped, removed, pruned, or recreated.
- No SQL mutation, migration, reassignment, tenant merge, or credential change was performed.
- `.env` was read only as redacted key names; its values were not written to evidence.
- Sprint 4.1.1 schema validation and browser acceptance will use a new explicitly disposable Testing database/volume and will fail closed if the retained volume is detected.
- These counts form the retained before-test baseline and must match the after-test evidence.
