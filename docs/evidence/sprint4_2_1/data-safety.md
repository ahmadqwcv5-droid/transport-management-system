# Data-safety evidence

Acceptance used Compose project `tms-s421`, API port `5180`, PostgreSQL port
`55432`, owner `owner@sprint421.local`, and dedicated volumes:

- `tms-s421_postgres_data`
- `tms-s421_truck_photo_data`

The retained `tms-smoke` stack was read only for before/after counts. Counts are
ordered as companies, users, clients, trucks, drivers, trips, notifications:

```text
before: 3|8|92|120|140|141|93
after:  3|8|92|120|140|141|93
```

Before final cleanup the isolated database contained `1|2|1|2|1|2|2` for the
same entity order. The isolated API was stopped, its `transport_management`
database was dropped and recreated, and public-table count was verified as
zero. `docker compose ... down` removed only disposable containers/network;
both dedicated volumes remain and no Docker volume was deleted.
