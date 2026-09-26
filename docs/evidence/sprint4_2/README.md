# Sprint 4.2 evidence

Sprint 4.2 implementation and automated validation completed on 2026-09-26,
but the sprint is **not marked complete** because the mandatory real-browser
workflow did not finish. The real release Flutter Web app, API, PostgreSQL,
Firefox, and two isolated browser profiles were used. Owner and Driver login,
identity rendering, the no-default-Driver state, API assignment fallback, and
the live Driver workspace were reached. Selenium could not reliably activate
the Flutter Web truck dropdown in the default-Driver scenario, and the later
workflow was stopped rather than representing a partial run as passing.

Implemented behavior includes:

- a tenant-scoped active-operations endpoint and Dashboard/Active Trips cards;
- non-overlapping three-second Active Trips and trip-detail convergence;
- last-good data preservation and stale feedback;
- terminal detail polling shutdown;
- signed-in account, localized role, company, email, and linked Driver identity;
- contextual assignment, arrival, and confirmation notification snapshots;
- safe default-Driver selection with no arbitrary first-Driver fallback;
- completion removal from active operations and presence in Completed.

Evidence files:

- `automated-validation.md` — test/build/migration/runtime results;
- `browser-acceptance.md` — exact browser boundary and failure;
- `browser-result.json` — machine-readable failed result;
- `data-safety-before.md` / `data-safety-after.md` — retained-data proof;
- screenshots from the partial browser attempts are diagnostic only and are not
  presented as passing acceptance evidence.

No password, token, connection string, private header, retained database dump,
or real customer data is stored here.
