# Sprint 4 Acceptance Evidence

The authenticated browser workflow ran against the containerized API and the
retained PostgreSQL service using the dedicated `owner@sprint322.local`
Development/Testing tenant. The retained demo owner, its password, and the
database volume were not reset.

## Result

- Headless Firefox workflow: passed.
- Arabic/RTL login and English/LTR mutation view: passed.
- Client creation and immediate filtered-list refresh: passed.
- Two contacts, primary selection, map-selected Factory site, and manual
  Warehouse site: passed.
- Extended truck creation, default-driver persistence, detail/history view, and
  immediate filtered-list refresh: passed.
- Logout and redirect to login: passed.
- Machine-readable output: `browser_workflow.json`.
- Screenshots: `01-arabic-login-dashboard.png` through
  `07-logout-login-redirect.png`.

Existing current-code browser evidence in `docs/evidence/sprint3_4_1/` and
`docs/evidence/sprint3_5/` covers earlier planner and lifecycle behavior. The
planner suite was also rerun against the final Sprint 4 build; its ten
screenshots and machine-readable result are in `planner/`. It covers saved stop
coordinates, route calculation, assignment eligibility, persisted route
idempotency, conflict recovery, and Arabic/English layouts. Sprint 4 backend
and Flutter suites additionally cover lifecycle, tenant isolation, safe delete,
saved-site snapshot semantics, refresh state, and fleet invariants.

The test first used the retained demo-owner address and received the expected
401 because the retained credential differs from the current seed value. It
then used the dedicated smoke tenant; no retained credential was changed.
