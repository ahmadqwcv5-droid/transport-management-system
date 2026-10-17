# Sprint 4.4 evidence index

Sprint status: **incomplete**. Automated implementation gates pass, but the
mandatory real-Firefox workflow is blocked before application startup by the
local Flutter/WebDriver toolchain. No screenshot or API-only substitute is
claimed as browser acceptance.

## Automated evidence

- Baseline SHA: `42b7576ff66e240a0b94e49465c2df2fe713ef5b`.
- .NET Release build: passed, 0 warnings/errors.
- Backend suites: 106 passed, 0 failed/skipped.
- Sprint 4.4 focused backend tests: 4 passed, including 105-record deterministic
  pagination, same-company tampering, handover interval trails, and
  Development/Pilot/Production endpoint/worker behavior.
- Flutter analyzer: no issues. Flutter tests: 95 passed.
- EF drift: no pending model changes; latest retained migration is
  `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`.
- Development and Pilot Web release builds passed in 31.18 s and 31.26 s.
  Artifact inspection found simulator semantic keys in Development and none in
  Pilot, even when the simulator request flag was passed to the Pilot build.
- Existing 30-update widget regression retained one map instance.
- Android: not run. `ANDROID_HOME=/home/pc/Android/Sdk`, but that SDK path does
  not exist; no Android device/emulator is available.

## Runtime and data safety

- Compose build/start passed; API and PostgreSQL are healthy.
- PostgreSQL `pg_is_in_recovery()` returned `false`; recent startup logs show a
  clean prior shutdown and no recovery, corruption, repeated I/O, or checkpoint
  errors. The one logged relation error came from an initial read-only count
  query using incorrect quoted names and did not mutate data.
- Current pre-browser counts are 3 companies, 13 users, 120 trucks, 141 Drivers,
  and 146 trips. These differ from the older Sprint 4.3.2 snapshot
  (3/11/120/140/145) before this sprint began; no Sprint 4.4 browser fixture was
  created. The final comparison remained exactly 3/13/120/141/146.
- Retained volumes remain `tms-smoke_postgres_data` and
  `tms-smoke_truck_photo_data`. `.env` SHA-256 remains
  `65d1ae1ee7f3abcd65d6bf29797ea04c4e833c4109c426a34820f656a52ce6f0`.
- The original `owner@demo.local` login and `/api/auth/me` Owner/company response
  passed without printing a password or token.
- Root free space fell to 2.3 GB during the classic Docker build. Only dangling
  image layers were pruned (2.463 GB reported); no container or named volume was
  deleted. Root free space then measured 9.8 GB.

## Real Firefox blocker

Two clean attempts used Firefox 157.0.1 and geckodriver on separate ports.
Firefox launched headlessly and Marionette returned a genuine new session, but
Flutter 3.47.4 then failed with `HttpException: Connection closed before full
header was received` on the WebDriver `/session` request. This occurred before
the integration test could interact with the app. The second attempt used an
automatically deleted temporary define file so no secret appeared in the crash
command; generated crash reports were deleted and are not evidence artifacts.

Consequently the required two-profile Owner/Driver workflow, 360/768/1440
screenshots, real map controls/20 updates, Arabic/English visual checks,
reduced-motion observation, Driver URL tampering, idle-truck map, profile
session independence, and human Google login are **not completed**. Google
control readiness is not described as a successful Google login.

No Sprint 4.4 commit or push has been performed.
