# Retained-data safety after Sprint 4.2

The browser/runtime work used only the disposable Compose project `tms-s42`.
Its resolved PostgreSQL mount was
`tms-s42_sprint411_postgres_data -> /var/lib/postgresql`; the retained
`tms-smoke_postgres_data` and `tms-smoke_truck_photo_data` volumes were never
mounted by the acceptance project.

The retained `tms-smoke` API and PostgreSQL containers remain stopped, matching
their initial state. Sprint 4.2 did not edit `.env`, migrate retained data, or
write acceptance records to retained storage. The before snapshot counts in
`data-safety-before.md` therefore remain the authoritative retained counts.

The disposable stack is removed after validation. No retained volume is
removed.
