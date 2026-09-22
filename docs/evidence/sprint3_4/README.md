# Sprint 3.4 Validation Evidence

## Automated evidence

- .NET solution build: passed with 0 warnings and 0 errors.
- EF model drift: `No changes have been made to the model since the last migration.`
- Backend integration suite: rerun after final changes; see the implementation
  plan for the exact final count.
- Flutter analyzer: passed with no issues.
- Flutter widget/unit suite: 36 passed, 0 failed, 0 skipped.
- Flutter Web release build: succeeded in `build/web` with the documented local
  API/map/simulator compile-time settings.

## Live PostgreSQL and provider evidence

- Compose API and PostgreSQL containers: healthy.
- Applied migration: `20260922045016_Sprint34TripOperations`.
- Retained trips: 70; missing trip numbers: 0; distinct tenant/number pairs: 70.
- `ImportedBaseline` events: 70.
- Public OSRM request from inside the API container: HTTP 200 with `code=Ok`.
- A live PostgreSQL-only failure in number allocation was found after startup:
  EF rejected composition over `INSERT ... RETURNING`. The allocator now uses a
  parameterized atomic scalar command and the API image was rebuilt successfully.
- The user-driven browser workflow then exposed a false `409` while saving the
  first pickup/delivery stops on a new minimal Draft. A rolled-back EF probe
  against the retained PostgreSQL database identified both new `TripStop` rows
  as `Modified` because they already had GUID keys. Replacement stop rows are
  now explicitly registered as inserts. The real PostgreSQL probe reported
  `Added, Added` and `POSTGRESQL SAVE SUCCEEDED`; the full backend suite passed
  46/46 and both Compose services are healthy after rebuilding only the API.
  The wizard also retains the created Draft when a later stop request fails, so
  retrying cannot silently create another empty Draft. Flutter analysis remains
  clean and all 36 Flutter tests pass.

The primary authenticated Firefox workflow is still not marked complete. The
preserved database owner's existing password differs from the current `.env`
seed value, so an automated login could not reuse the user's active browser
session. No owner credentials were reset or overwritten.

Android is also not marked passed: Flutter reports
`ANDROID_HOME=/home/pc/Android/Sdk`, but no SDK exists at that path and no
Android device is available.

No screenshots have been fabricated from widget tests or direct API calls.
