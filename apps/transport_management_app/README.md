# Transport Management Flutter Client

The responsive Web/Android client for the Transport Management System. It uses a feature-first structure, Riverpod for authentication state, GoRouter for navigation, Dio for centralized HTTP/refresh behavior, and secure platform storage for the refresh credential.

Run Web:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5080
```

Run an Android emulator:

```bash
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

See the repository root `README.md` for complete setup, architecture, security, and backend instructions.
