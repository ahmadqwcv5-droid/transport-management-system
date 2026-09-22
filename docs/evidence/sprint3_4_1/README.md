# Sprint 3.4.1 Validation Evidence

## Result

The complete authenticated Firefox workflow passed on 2026-09-22 against the
rebuilt `tms-smoke` API and retained PostgreSQL database. The run used the
dedicated `owner@sprint322.local` Development/Testing tenant; no retained owner
password or database volume was reset.

The browser created and assigned one trip, created a second unassigned Draft,
reopened and recalculated it, saved unchanged data while retaining route ID
`b47c61f6-925a-4cc9-bb57-90ff238518a7`, then forced an assignment availability
race. The Draft survived, availability refreshed, and its cargo matched exactly
one trip. `browser_workflow.json` is the machine-readable result.

## Screenshots

1. `01-arabic-rtl-shell.png` — authenticated Arabic/RTL shell.
2. `02-map-selected-stops.png` — pickup and delivery selected on the real map.
3. `03-route-distance-duration-provider.png` — routed line and route facts.
4. `04-eligible-ineligible-reasons.png` — assignment controls and explanations.
5. `05-complete-review.png` — complete review step.
6. `06-assigned-trip-details.png` — successful navigation to assigned details.
7. `07-unassigned-draft-details.png` — intentional unassigned Draft.
8. `08-resumed-unchanged-route-valid.png` — resumed/recalculated Draft after
   unchanged save.
9. `09-assignment-race-draft-preserved.png` — conflict recovery at assignment.
10. `10-english-ltr-shell.png` — final English/LTR verification.

## Quality gates

- .NET integration suite: 48 passed, 0 failed.
- Flutter analyzer: no issues.
- Flutter unit/widget suite: 36 passed, 0 failed.
- Flutter Web release build: passed.
- Flutter Web profile Development/Testing build: passed.
- EF Core pending-model check: no drift.
- Compose API and PostgreSQL: healthy.
- PostgreSQL facts: see `postgres_verification.txt`.
- Real Firefox workflow: passed with `result=true`.

The web builds report the existing `flutter_secure_storage_web` WebAssembly
dry-run incompatibility; the JavaScript web build succeeds. Android was not
built or run because `/home/pc/Android/Sdk` is absent and no usable Android SDK
or device is available on this machine.
