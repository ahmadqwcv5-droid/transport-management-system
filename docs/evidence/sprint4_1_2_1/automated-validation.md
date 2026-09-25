# Automated and platform validation

| Check | Result |
|---|---|
| `dotnet build TransportManagement.slnx --no-restore` | Passed; 0 warnings, 0 errors |
| Integration test project | Passed; 66/66 |
| Architecture test project | Passed; 11/11 |
| EF Core pending-model check | Passed; model matches latest migration |
| `flutter analyze` | Passed; no issues |
| Full `flutter test` suite | Passed; 60/60 |
| Flutter Web release build | Passed; only the documented `flutter_secure_storage` Wasm dry-run advisory |
| Docker image/build and isolated startup | Passed; API and PostgreSQL healthy |
| Mandatory Firefox two-profile workflow | Passed; see `browser-result.json` |
| Android build/run | Not attempted: `ANDROID_HOME=/home/pc/Android/Sdk`, but that directory does not exist; no Android device/emulator is available |

The browser workflow additionally exercised real OSRM approach generation,
OpenFreeMap rendering, English/LTR, Arabic/RTL, background simulator ingestion,
and Owner/Driver projections from the same disposable database.
