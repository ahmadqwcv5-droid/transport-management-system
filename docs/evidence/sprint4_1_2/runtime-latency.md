# Sprint 4.1.2 Runtime and Latency Evidence

## Isolation and migration

- Compose project: `tms-s412`.
- API/PostgreSQL ports during validation: 5080/5432.
- Dedicated volumes: `tms-s412_postgres_data` and
  `tms-s412_truck_photo_data`.
- The Sprint 4.1.2 migration was the latest applied migration.
- At final sampling the disposable database contained 369 position rows,
  4 Driver–Truck sessions, and 8 operational notifications.

## Browser-independent ingestion

No browser or WebDriver process was running during this measurement. A direct
read-only database sample observed 361 position rows with latest sample time
`2026-09-25 09:21:46.467366+00`. Ten seconds later it observed 369 rows with
latest sample time `2026-09-25 09:22:04.467461+00`. The backend worker therefore
continued ingestion without manager or Driver polling.

## Arrival and notification latency

Four isolated pickup observations produced these database-measured values:

| Qualifying dwell | Notification persistence after confirmation |
|---:|---:|
| 10.001 s | 0.010 s |
| 8.003 s | 0.011 s |
| 8.002 s | 0.012 s |
| 8.002 s | 0.016 s |

The configured minimum is two qualifying samples and eight seconds of dwell.
Arrival and notification persistence stayed within the planned 10–15 second
normal simulator budget. UI visibility in two independent clients was not
proven because the mandatory browser run failed; these values are backend
runtime evidence only.

After validation the disposable containers were stopped without deleting their
volumes, so the evidence remains recoverable for diagnosis.
