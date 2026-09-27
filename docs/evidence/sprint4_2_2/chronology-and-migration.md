# Chronology, migration, and rollback

## Current-position rule

History remains append-only. A tenant-scoped `truck_current_positions`
projection is updated inside a serializable transaction only when
`incoming.RecordedAt > current.RecordedAt`.

- Exact packet equality across run, timestamp, coordinates, motion, online,
  trip/route/repositioning/phase, and source is idempotent and not inserted.
- An older valid packet is stored in history but cannot advance current.
- A conflicting packet at the same timestamp is stored in history but cannot
  advance current. The already-accepted packet therefore wins.
- A new tracking run is explicit through `TrackingRunId`; it advances current
  only with a newer authoritative timestamp.
- A cross-tenant truck/position attempt is rejected before storage.
- Clock-skewed older packets remain auditable history and do not affect live
  speed, heading, freshness, ETA, or geofence processing.

Focused integration outcomes: 2 accepted-current packets, 1 older-history
packet, 1 ignored duplicate, 1 equal-time conflict stored without advance, and
1 rejected cross-tenant attempt. In isolated PostgreSQL, inserting a valid older
packet increased history from 693 to 694 while the projection ID and coordinates
remained unchanged.

## Migration

`20260927071807_Sprint422MapOperationsChronology` adds:

- `company_map_preferences`, unique per company, with ISO code, label snapshot,
  validated bounds, optional center/zoom, timestamps, and updating user.
- `truck_current_positions`, primary-keyed by truck, with tenant, position,
  recorded time, optional tracking run, and timestamps.
- tenant, user, and position indexes/foreign keys.

Legacy companies receive no invented operational geography. Current projection
is backfilled deterministically per company/truck from the newest
`RecordedAt`, then highest position ID. Runtime equal timestamps never replace
the accepted projection. The isolated migration applied successfully and EF
reported no pending model changes.

Rollback drops only the two new tables. It does not delete immutable
`truck_positions`, companies, trucks, users, trips, or media.
