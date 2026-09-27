# Automated validation

| Check | Result |
|---|---|
| `dotnet build TransportManagement.slnx --no-restore` | Passed; 0 warnings, 0 errors |
| `dotnet test TransportManagement.slnx --no-build --no-restore` | Passed; 78/78 |
| Focused `Sprint421ReliabilityTests` | Passed; 4/4 |
| `dotnet ef migrations has-pending-model-changes ...` | No pending model changes |
| `flutter analyze` | No issues found |
| `flutter test` | Passed; 69/69 |
| Focused map/assignment/notification/RTL tests | Passed; 32/32 before final full suite |
| `api_client_test.dart` stale concurrent 401 regression | Passed; one refresh, two successful retries |
| `flutter build web --release` | Passed |
| Docker API/PostgreSQL health | Healthy on isolated ports 5180/55432 |

The Web build's Wasm dry run reported the existing `flutter_secure_storage_web`
`dart:html`/`dart:js_util` compatibility warnings. The JavaScript release build
completed successfully; this sprint does not claim a Wasm build.

Chrome was not installed. No `adb`, Android platform, emulator executable, or
connected device was available, so Android execution was not claimed.
