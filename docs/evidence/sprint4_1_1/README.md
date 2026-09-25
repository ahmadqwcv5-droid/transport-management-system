# Sprint 4.1.1 Evidence

This directory records the Sprint 4.1.1 validation performed on
`2026-09-25`. It contains no passwords, tokens, private headers, database
dumps, or password hashes.

## Evidence index

- [Data-safety diagnosis](data-safety-diagnosis.md) — retained tenant,
  Compose project, volume, and before-count investigation.
- [Retained-data after-check](retained-data-after.md) — unchanged aggregate
  counts after every disposable acceptance attempt.
- [Validation report](validation.md) — build, test, migration, Docker, browser,
  Web, and platform results, including limitations.
- [Browser assertions](browser-assertions.json) — machine-readable status for
  the attempted real-browser workflow.
- [Map operation counts](map-operation-counts.json) — deterministic operation
  counts from the passing ten-poll Flutter test.
- [Notification deduplication](notification-deduplication.json) — deterministic
  hydration, overlay, mute, burst, and sound-request assertions.

## Important evidence boundary

The disposable API/PostgreSQL workflow and automated backend/Flutter suites
passed. The single Firefox workflow did not complete end-to-end: its latest run
stopped in the UI driver-list phase with multiple Flutter test-framework
exceptions after earlier isolated runs had exercised later API/driver-workspace
and notification paths. Therefore this directory deliberately contains no
claimed passing screenshots, no claim of two independent browser contexts, and
no claim that a real rendered map or physical speaker was verified.

Screenshots were also excluded because Firefox WebDriver screenshot capture
blocked the integration runner during investigation. Deterministic tests are
recorded as automated evidence, not presented as a substitute for the missing
real-browser acceptance.
