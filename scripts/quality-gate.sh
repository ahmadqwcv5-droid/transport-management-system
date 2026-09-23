#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dotnet="$repository_root/.tooling/dotnet/dotnet"
flutter="$repository_root/.tooling/flutter/bin/flutter"
dart="$repository_root/.tooling/flutter/bin/cache/dart-sdk/bin/dart"

if [[ ! -x "$dotnet" ]]; then dotnet="$(command -v dotnet)"; fi
if [[ ! -x "$flutter" ]]; then flutter="$(command -v flutter)"; fi
if [[ ! -x "$dart" ]]; then dart="$(command -v dart)"; fi

"$dotnet" restore "$repository_root/TransportManagement.slnx"
"$dotnet" build "$repository_root/TransportManagement.slnx" --no-restore
"$dotnet" test "$repository_root/TransportManagement.slnx" --no-build --no-restore

(
  cd "$repository_root/apps/transport_management_app"
  "$flutter" pub get
  "$flutter" gen-l10n
  "$dart" format --output=none --set-exit-if-changed \
    lib test integration_test test_driver
  "$flutter" analyze
  "$flutter" test
  "$flutter" build web --release \
    --dart-define=API_BASE_URL=http://localhost:5080 \
    --dart-define=MAP_STYLE_URL=https://example.invalid/style.json \
    --dart-define=ENABLE_SIMULATOR_CONTROLS=false
)
