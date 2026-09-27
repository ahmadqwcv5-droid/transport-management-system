# Data-safety and cleanup proof

The retained project was `tms-smoke`. Acceptance used only
`tms-sprint422` with API 5180, PostgreSQL 55432, independent Firefox profiles,
and isolated volumes.

## Retained state

| Snapshot | Companies | Users | Trucks | Drivers | Trips | Position history |
|---|---:|---:|---:|---:|---:|---:|
| Sprint baseline | 3 | 8 | 120 | 140 | 141 | 446177 |
| Immediately before isolated cleanup | 3 | 8 | 120 | 140 | 141 | 493952 |
| Immediately after isolated cleanup | 3 | 8 | 120 | 140 | 141 | 494188 |

Business counts are identical. The retained RouteSimulator was already running
and independently appended 236 immutable position rows during the immediate
comparison; it was not paused or mutated. No acceptance fixtures were inserted
into the retained tenant.

Retained mounts were identical before and after:

- `tms-smoke_postgres_data:/var/lib/postgresql`
- `tms-smoke_truck_photo_data:/data/truck-photos`

After cleanup both retained containers were running and
`http://127.0.0.1:5080/health` returned `Healthy`.

## Removed disposable resources

The following were removed after evidence capture:

- `tms-sprint422-api-1` and `tms-sprint422-postgres-1`;
- `tms-sprint422_postgres_data` and
  `tms-sprint422_truck_photo_data`;
- the isolated Compose network;
- Firefox WebDriver sessions, GeckoDriver listeners, and the port-3000 server;
- temporary isolated env/override/state/session files and vector inspection
  tooling under `/tmp`.

Post-cleanup checks found no `tms-sprint422` containers or volumes and no
listeners on 3000, 4444, 4445, 5180, or 55432. The repository `.env`,
credentials, retained PostgreSQL volumes, and retained records were not edited.
