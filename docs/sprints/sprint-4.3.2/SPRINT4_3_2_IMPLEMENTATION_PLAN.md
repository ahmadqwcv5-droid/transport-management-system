# Sprint 4.3.2 Implementation Plan

## Baseline

- Started: `2026-09-28 19:24:55 +03:00` (Europe/Istanbul).
- Branch/HEAD: `main` at `473233a` (`feat(identity): stabilize sprint 4.3.1 workflows`).
- Initial worktree: only the user-provided Sprint 4.3.2 prompt and the two
  pre-existing SQL backup files. The backups are unrelated, untouched, and
  remain untracked.
- Actual retained Compose project: `tms-smoke`.
- Retained container IDs: API
  `93d012950a3dfdbb844f4c4caea89f713869bd92b801e810ed4791d3500189f2`;
  PostgreSQL
  `a44107485fb7c3a311ef8524a85f439b501356638f1840fc88d8b15b90ba6ace`.
- Retained volumes: `tms-smoke_postgres_data` and
  `tms-smoke_truck_photo_data`.
- Retained business counts: 3 companies, 11 accounts, 120 trucks, 140 Drivers,
  and 145 trips.
- Latest migration:
  `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`.
- `.env` baseline SHA-256:
  `65d1ae1ee7f3abcd65d6bf29797ea04c4e833c4109c426a34820f656a52ce6f0`.
  Its values were not copied and the file must remain unchanged.
- Baseline validation: .NET 91/91 passed; Flutter analyzer clean; Flutter
  85/85 passed.
- Android is unavailable: the configured SDK path does not exist and no
  Android device/emulator is connected. Firefox Web remains mandatory.

## Reproduction and root-cause assessment

No real-browser reproduction is claimed yet; it belongs to Task 6. These are
confirmed source-path findings and the observed reports to reproduce:

1. **Company users do not converge across sessions.** Mutation handlers
   invalidate local Riverpod providers, but Company Users is a stateless screen
   with no lifecycle observer, visible-only timer, serialized coordinator, or
   notification-driven refresh. Another profile's acceptance therefore cannot
   update the Owner screen until a local refresh/rebuild.
2. **Public routes start in English.** `MaterialApp.locale` reads only the
   authenticated account locale and otherwise forces `en`. Login and
   invitation screens expose no anonymous locale control or local persistence.
3. **Passwords cannot be revealed.** Login, invitation creation, and password
   change use separate raw `TextFormField(obscureText: true)` instances with
   no reusable visibility state or localized semantics.
4. **QR dialog can trap Web.** Credential generation opens an
   `AlertDialog` containing a layout-sensitive `QrImageView` and waits for
   dialog dismissal while the same busy flag drives the spinner. PNG export
   recaptures the dialog widget. A render/layout exception can leave the modal
   barrier and busy state unresolved. The fix must prepare deterministic PNG
   bytes before opening any dialog and retain the one-time response in memory.
5. **Notifications collapse to a false trip message.** Backend services emit
   many identity, membership, QR, session, Driver-link, handover, tracking, and
   trip types with ad-hoc JSON snapshots. Flutter handles only a small subset;
   unknown types use a generic trip-attention body. There is no canonical
   emitted-type fixture or exhaustive centralized presentation registry.

## Architecture and planned files

### Cross-session convergence

- Convert Company Users into a lifecycle-aware stateful shell.
- Add one serialized/latest-wins refresh coordinator that refreshes members,
  invitations, connections, and handovers while the screen is visible, on app
  focus restoration, and immediately after mutations.
- Poll no slower than 10 seconds, cancel on disposal, retain tab/scroll state,
  and never replace newer results with stale responses.
- Primary areas:
  `features/company_users/presentation/company_users_screen.dart`,
  controllers/providers, and focused tests.

### Anonymous locale ownership

- Add a locally persisted anonymous locale provider/service with resolution:
  saved supported locale, then supported platform locale, then English.
- Public language controls update MaterialApp immediately without a backend
  call. After authentication, the account `PreferredLocale` is authoritative;
  after logout, the anonymous preference resumes. Invitation-created local
  accounts deliberately send the current public locale.
- Primary areas: app bootstrap, auth/login, membership acceptance, storage,
  l10n resources, and tests.

### Password component

- Add one reusable stateful application password field with independent
  visibility, autofill support, stable focus/value, touch-sized localized
  toggle, tooltip, and semantics.
- Replace every password-entry field found in login, invitation acceptance, and
  Settings.

### QR state machine

- Introduce explicit idle/generating/preparing/ready/failed state.
- Encode the exact backend `qrPayload` with `QrPainter.toImageData` before
  showing a dialog; render fixed-size `Image.memory`; use the same validated
  PNG bytes for download.
- Retain the returned one-time credential in memory after rendering failure,
  allowing render retry and manual-code copy without another backend mutation.
- Guarantee cleanup on API/render/download/dialog/disposal failures.
- Primary area: truck details plus isolated encoder/model and tests.

### Notification contract

- Inventory all emitted types and normalize safe snapshot fields where missing.
- Check in a canonical type fixture consumed/enforced by backend and Flutter
  tests.
- Add one exhaustive presentation registry supplying category, localized
  title/body, identity, severity/icon/color, navigation, and attention policy.
- Use it everywhere current notification UI renders alerts. Unknown remains a
  neutral System event and never claims a trip.
- No notification snapshot may contain a token, password, reusable QR secret,
  or raw JSON in the UI.

### Documentation/evidence

- Update README and architecture documentation.
- Add sanitized evidence under `docs/evidence/sprint4_3_2`, including only
  screenshots that contain no secrets/tokens.
- Keep this plan current after every task.

## Risks and rollback

- Polling can overlap or reset UI state: serialize requests, use generations,
  poll only while visible, and preserve widget/controller identity.
- Anonymous/account locale can fight after login: authenticated server locale
  wins; anonymous choice remains local for the next public session.
- Invitation locale contract changes can break old clients: add an optional
  validated field with a safe English fallback if backend extension is needed.
- A QR render failure occurs after an irreversible credential mutation: never
  regenerate automatically; retain the response and expose retry/copy recovery.
- Notification snapshots can leak secrets or drift: use an allowlisted
  structured presentation and a canonical emitted-type contract.
- Application rollback is a code revert. No database migration is planned.
- Never run `docker compose down -v`, replace `.env`, reset credentials, or
  remove retained volumes/data.

## Test matrix

| Area | Automated proof | Real Firefox proof |
|---|---|---|
| Convergence | immediate invalidation, serialized/latest-wins, distinct pending/member states | Owner and isolated invitee converge within 10 seconds without reload |
| Locale | resolution, persistence, reconciliation, EN/LTR and AR/RTL widgets | switch invitation to Arabic before authentication and retain it |
| Password | hidden default, toggle/back, independent fields, EN/AR semantics | login and invitation controls |
| QR | payload-to-PNG, decodable bytes, real dialog, failure recovery, no duplicate mutation | image/code/download/close/regenerate/old-code rejection |
| Notifications | backend emitted-type fixture equals exhaustive EN/AR registry | distinct events across People, Fleet, Trip, Security |
| Regression | full .NET/Flutter, analyzer, EF drift, Web builds | local/Google auth, logout isolation, console clean |
| Safety | hashes, IDs, volumes, counts, tenant tests | no secret-bearing evidence |

## Task checklist

- [x] 0. Baseline assessment, source-path root causes, validation, and plan.
- [x] 1. Company-member and invitation convergence.
- [x] 2. Public Arabic/English localization.
- [x] 3. Reusable show/hide password fields.
- [x] 4. Deterministic QR rendering state machine and recovery.
- [x] 5. Complete notification contract and centralized presentation.
- [x] 6. Real Firefox acceptance matrix and sanitized evidence.
- [x] 7. Full validation, retained-data comparison, documentation, and final audit.

## Task timing

Times use Europe/Istanbul. Active elapsed excludes explicit user/environment
pauses; concurrent validation is not double-counted.

| # | Task | Start | End | Active elapsed | Status |
|---:|---|---|---|---:|---|
| 0 | Baseline assessment and implementation plan | 2026-09-28 19:24:55 +03:00 | 2026-09-28 19:26:52 +03:00 | 1m 57s | Completed |
| 1 | Company-member and invitation convergence | 2026-09-28 19:26:52 +03:00 | 2026-09-28 19:32:00 +03:00 | 5m 08s | Completed |
| 2 | Public Arabic/English localization | 2026-09-28 19:32:00 +03:00 | 2026-09-28 19:37:00 +03:00 | 5m 00s | Completed |
| 3 | Reusable password fields | 2026-09-28 19:37:00 +03:00 | 2026-09-28 19:39:00 +03:00 | 2m 00s | Completed |
| 4 | QR rendering state machine | 2026-09-28 19:39:00 +03:00 | 2026-09-28 19:45:00 +03:00 | 6m 00s | Completed |
| 5 | Notification contract and presentation | 2026-09-28 19:45:00 +03:00 | 2026-09-28 19:58:00 +03:00 | 13m 00s | Completed |
| 6 | Firefox acceptance matrix | 2026-09-28 20:00:47 +03:00 | 2026-09-29 01:38:05 +03:00 | 2h 14m 05s cumulative across resumed work | Completed: all isolated workflows plus nine exact notification routes/tile taps passed |
| 7 | Validation, safety, documentation, final audit | 2026-09-28 20:01:00 +03:00 | 2026-09-29 01:38:05 +03:00 | 36m 23s active, concurrent time not double-counted | Completed: full gates, recovery audit, exact cleanup, evidence, and docs passed |

## Final result and deviations

All mandatory non-human acceptance scenarios passed in real isolated Firefox.
The invitation workflow proved pending-before-member behavior, Arabic RTL,
password show/hide, linked-Driver correctness, and no-reload convergence within
10 seconds. The QR workflow proved real PNG rendering/download/decoding,
recoverable rendering failure without duplicate mutation, dialog cleanup,
explicit regeneration, old-code rejection, and new-code resolution. The
notification workflow exercised People Access, Security, Fleet, and Trip events
with localized distinct content, exact route assertions, successful real tile
taps, safe snapshots, and silent initial hydration. Simultaneous Owner/Driver
profiles remained independent and
both completed logout-to-login regression.

Acceptance exposed one product defect: repeated membership suspension reused a
notification event key and violated its unique index. The key now includes the
membership version, a focused regression test was added, the API rebuilt, and
the affected browser scenario plus all automated/build gates passed again.

The earlier host-root exhaustion produced one PostgreSQL automatic recovery.
Final audit found 15 GB root free, `pg_is_in_recovery() = false`, normal later
checkpoints, no corruption or repeated I/O/checkpoint errors, the expected
migration, unchanged retained volume/PostgreSQL identities and `.env` hash,
and exact restored counts of 3 companies, 11 accounts, 120 trucks, 140 Drivers,
and 145 trips. All explicitly marked Sprint 4.3.2 fixtures and secret-bearing
downloads were removed; retained volumes and original records were untouched.

Final gates: .NET 95/95; Flutter 92/92; analyzer clean; Release .NET build 0
warnings/0 errors; EF drift clean; local and production-style Web release
builds successful; Compose API/PostgreSQL healthy. Android remained unavailable
from the baseline environment. Google provider/control readiness is not a real
Google login: the headless run could not perform human account selection and
consent, so that conditional human-only verification is explicitly not claimed.
