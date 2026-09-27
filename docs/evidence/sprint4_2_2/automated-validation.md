# Automated validation

Recorded on 2026-09-27 (Europe/Istanbul).

| Check | Result |
|---|---|
| `dotnet build TransportManagement.slnx --no-restore` | Passed; 0 warnings, 0 errors |
| `dotnet test TransportManagement.slnx --no-restore` | Passed; 81/81 |
| Focused map/camera/assignment tests | Passed; 34/34 |
| `dotnet ef migrations has-pending-model-changes ...` | No pending model changes |
| `flutter analyze` | Passed; no issues |
| `flutter test` | Passed; 78/78 |
| `flutter build web --release ...` | Passed |
| Isolated Compose build/migration/health | Passed on API 5180 and PostgreSQL 55432 |
| Firefox Owner and Driver profiles | Passed; see `browser-result.json` |
| Retained-data comparison and isolated cleanup | See `data-safety.md` |

The Web build completed as JavaScript. Flutter's Wasm dry run reported the
existing `flutter_secure_storage_web` use of `dart:html`, `dart:js_util`, and
`package:js`; no Wasm build is claimed.

Firefox through GeckoDriver was the available real-browser path. Chrome was not
installed. `flutter doctor -v` reported that `ANDROID_HOME` points to
`/home/pc/Android/Sdk`, but no Android SDK exists there; `adb`, an emulator,
and an Android device were unavailable. Android build/run is therefore an
environment limitation and is not claimed. The only detected Flutter device was
Linux desktop, whose toolchain also lacked `clang++`.
