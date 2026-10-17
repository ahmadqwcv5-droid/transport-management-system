# Preview the Phase A concepts

From the Flutter application directory:

```bash
cd apps/transport_management_app
../../.tooling/flutter/bin/flutter run \
  -d web-server \
  --target=lib/design_lab_main.dart \
  --web-port=3001 \
  --dart-define=APP_PROFILE=development
```

The Design Lab is static and does not require Docker, login, or API access.
Open these URLs:

| Surface | Concept A | Concept B | Concept C |
|---|---|---|---|
| Dashboard AR | `http://localhost:3001/?concept=a&surface=dashboard&locale=ar` | `...?concept=b&surface=dashboard&locale=ar` | `...?concept=c&surface=dashboard&locale=ar` |
| Dashboard EN | `http://localhost:3001/?concept=a&surface=dashboard&locale=en` | `...?concept=b&surface=dashboard&locale=en` | `...?concept=c&surface=dashboard&locale=en` |
| Driver Today | `http://localhost:3001/?concept=a&surface=today&locale=ar` | `...?concept=b&surface=today&locale=ar` | `...?concept=c&surface=today&locale=ar` |
| Driver My Truck | `http://localhost:3001/?concept=a&surface=truck&locale=ar` | `...?concept=b&surface=truck&locale=ar` | `...?concept=c&surface=truck&locale=ar` |
| Components/motion | `http://localhost:3001/?concept=a&surface=components&locale=ar` | `...?concept=b&surface=components&locale=ar` | `...?concept=c&surface=components&locale=ar` |

The in-preview control in the upper corner switches concept, surface, and
locale. Append `&controls=0` for clean screenshot framing.

Do not run this preview with a Pilot/Production profile. Its separate entry
point is not imported by the production application and is absent from normal
Pilot/Production builds.
