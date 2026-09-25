# Sprint 4.1.1 Validation Report

Validation date: `2026-09-25` (Europe/Istanbul).

## Environment and data isolation

| Check | Result |
|---|---|
| Retained Compose project | `tms-smoke` |
| Retained PostgreSQL | Healthy; `tms-smoke_postgres_data` mounted at `/var/lib/postgresql` |
| Disposable Compose project | `tms-s411-acceptance` |
| Disposable API environment | `Testing` |
| Disposable PostgreSQL | Healthy; `tms-s411-acceptance_sprint411_postgres_data` mounted at `/var/lib/postgresql` |
| Disposable API health | `Healthy` |
| Retained-volume overlap | None |
| Retained counts after acceptance | Exact match with before-counts |
| Recovery-related mutation | None; backup therefore not required |
| Disposable teardown | Passed; only the acceptance containers, network, and two acceptance volumes were removed |

The disposable database contained one company and acceptance-only runtime data
after the attempts. Its latest migration was
`20260924232116_Sprint411DriverOnboardingMapNotifications`. No acceptance row
was written to the retained database.
After evidence capture, the disposable stack and its two volumes were removed;
the retained PostgreSQL container remained running on
`tms-smoke_postgres_data`.

## Backend

| Validation | Result |
|---|---|
| `dotnet restore` | Passed; all projects up to date |
| Repository build | Passed; 0 warnings, 0 errors |
| Architecture tests | 11/11 passed |
| Integration tests | 59/59 passed |
| EF migration applied to disposable PostgreSQL | Passed |
| EF pending-model check | Passed; no model changes since latest migration |

The integration suite covers owner-only user management, tenant boundaries,
one-to-one link rules, transactional create-and-link behavior, refresh-token
revocation, assignment account state, driver workspace isolation/states,
notification preference scoping, deduplication, and legacy migration validity.

## Flutter and Web

| Validation | Result |
|---|---|
| Localization generation | Passed |
| Dart formatting | Passed |
| Static analysis | Passed; no issues |
| Flutter tests | 52/52 passed |
| Development Web release build | Passed with simulator controls enabled |
| Production Web release build | Passed with simulator controls omitted |

Both Web builds emitted only the known WebAssembly dry-run advisory for
`flutter_secure_storage_web`; the JavaScript Web release builds succeeded.

## Real-browser acceptance

Firefox WebDriver connected to the real Flutter Web build on the configured
acceptance origin and the browser communicated with the containerized API.
Exploratory disposable runs observed UI-created Driver POSTs, UI company-user
create-and-link POSTs, temporary-credential presentation, trip route,
assignment and dispatch requests, Driver login/workspace requests, scoped photo
delivery, simulator tracking, notification polling, and an offline alert path.

The complete workflow did **not** pass. The final run stopped in the Drivers
UI after the disposable tenant accumulated enough prior drivers to exercise its
lazy list; a viewport-aware retry then ended with multiple Flutter
test-framework exceptions that Firefox did not expand. Screenshot capture had
also blocked the runner in earlier attempts and was removed. Consequently:

- two independent browser profiles were not proven;
- real rendered MapLibre style/circular marker inspection was not proven;
- real drag and wheel behavior across three live polls was not proven;
- the full saved-site and English/Arabic browser workflow was not proven;
- physical audio playback was not tested;
- a complete browser notification ID/display/sound count is unavailable.

Passing deterministic map and notification tests are recorded separately and
must not be read as a passing real-browser result.

## Android and audio limitations

The local Android SDK directory contains no installed platform/toolchain, and
Flutter detects only the Linux desktop device; there is no Android device or
emulator. Android build/run validation is therefore unavailable in this
environment. Headless Firefox has no reliable physical audio device, so only
the injectable audio invocation behavior was validated.
