# Sprint 4.3.2 Acceptance Evidence

Acceptance completed on 2026-09-29 against Compose project `tms-smoke`, API
`http://127.0.0.1:5080`, and two genuinely isolated headless Firefox profiles
driven by separate geckodriver instances. Secrets were supplied through a
mode-0600 temporary `--dart-define-from-file` file, which was deleted after
the run. No password, access/refresh token, invitation token, QR payload, QR
secret, or raw notification JSON is retained here.

## Automated backend tests

- Complete .NET suite: **95 passed, 0 failed, 0 skipped**.
- Focused `Sprint432UxStabilizationTests`: **3 passed**. This includes the
  regression for repeated suspend/reactivate transitions using distinct
  notification event keys.
- Release build: **0 warnings, 0 errors**.
- EF model drift: no changes since migration
  `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`.

## Flutter widget and build tests

- Complete Flutter test suite: **92 passed**.
- Flutter analyzer: **no issues**.
- Local-runtime Web release build: passed with the acceptance API, map, and
  simulator defines.
- Production-style Web release build: passed with simulator controls omitted;
  the built JavaScript contained neither the simulator-control label nor the
  compile-time define marker.
- Flutter's WebAssembly dry run reported the existing
  `flutter_secure_storage_web` JavaScript-only dependency. This is advisory;
  both standard JavaScript Web release builds completed.

## Real Firefox evidence

### Invitation and convergence

The Owner created a disposable Driver invitation linked to a newly created
disposable Driver. The Owner profile immediately showed the invitation under
Pending Invitations and the acceptance harness proved that no membership was
created before acceptance. In the second Firefox profile, the public page was
switched to Arabic, rendered RTL, and its password reveal/hide control was
exercised before acceptance. Without reloading the Owner browser, its visible
screen converged within the documented 10-second interval: the pending row
disappeared and the active member appeared with the Driver role and the exact
linked Driver ID/name.

- [Pending invitation with no premature member](screenshots/invitation-pending-no-member.png)
- [Arabic RTL public invitation](screenshots/public-invitation-arabic-rtl.png)
- [Converged member and linked Driver](screenshots/invitation-converged-linked-driver.png)

### QR lifecycle

The real browser generated a truck credential, deliberately failed the first
PNG preparation, and proved the failure cleared busy/modal state while keeping
the same one-time response for retry. Backend `generatedAt` remained unchanged
and the encoder call count proved that retry did not create another credential.
The retry displayed the real QR and manual code with no invisible barrier or
infinite spinner. Firefox downloaded a non-empty 1024x1024 RGBA PNG, which was
decoded successfully. Closing the dialog left the truck page interactive.
After one explicit regeneration, the old code was rejected and the new code
resolved to the exact truck. The secret-bearing downloaded PNGs were deleted
after verification, so no QR screenshot or credential is retained.

### Notification categories

Real backend actions generated and Firefox rendered these event types:

| Event | Category | Context/navigation proof |
|---|---|---|
| Invitation accepted | People Access | account/invitation identity; Company Users target |
| Membership suspended/reactivated | People Access | member identity and state; Company Users target |
| Password changed | Security | disposable account/provider identity; Settings target |
| Truck QR generated/regenerated | Fleet | truck identity; Truck details target |
| Handover requested/approved | Trip | Drivers/truck/trip context; trip target |
| Trip assigned | Trip | Driver/truck/trip context; trip target |
| Truck became offline | Fleet | truck/trip/location context; active trip target |

Every selected event had a distinct non-empty English title/body and an Arabic
localized title/body after a real locale switch to RTL. Category, identity,
exact destination, and relevant entity details were asserted. Firefox then
tapped every selected real notification tile and reached its expected Company
Users, Settings, Truck details, or Trip route. Identity/security/QR events did
not use a generic trip message. Visible text and raw safe snapshots were checked
against the actual passwords and for secret-bearing password/token/QR keys,
reusable secrets, and raw JSON. Initial hydration queued no alert and requested
zero sound plays, so old notifications did not replay sound.

- [Arabic localized notification categories](screenshots/notifications-arabic-categories.png)

### Session regression

Two simultaneous isolated Firefox profiles logged in as Owner and Driver,
reached their role-specific homes, rendezvoused, and then revalidated their
own email/session after the other profile was active. Each performed a real
controller/API logout and independently redirected to login. Public Arabic
RTL and authenticated Arabic/English switching were also exercised by the
invitation and notification scenarios. The Flutter-driver SSE transport
occasionally logged out-of-order diagnostic lines, but every browser process
finished with `All tests passed` and no uncaught Flutter/render exception.

## Human-only Google verification

The configured Google control/provider readiness was previously exercised in
Firefox, but this run was headless and could not complete human account
selection, consent, or the returned Google identity-token flow. Therefore a
real Google login is **not claimed as completed**. It remains a human-only
follow-up when an interactive browser and Google account are available.

## PostgreSQL recovery and retained-data audit

The earlier root-filesystem exhaustion caused one recorded automatic recovery
at 2026-09-28 17:34 UTC. After acceptance:

- root had 15 GB free and the workspace volume had 116 GB free;
- `pg_is_in_recovery()` returned `false`;
- the latest migration was the expected Sprint 4.3 migration;
- later checkpoints completed normally, with no corruption or repeated I/O or
  checkpoint errors;
- retained counts returned exactly to **3 companies, 11 accounts, 120 trucks,
  140 Drivers, and 145 trips**;
- every scoped Sprint 4.3.2 disposable users/invitations/Drivers/clients/
  trucks/trips count returned zero;
- PostgreSQL container identity remained
  `a44107485fb7c3a311ef8524a85f439b501356638f1840fc88d8b15b90ba6ace`;
- volumes remained `tms-smoke_postgres_data` and
  `tms-smoke_truck_photo_data`;
- `.env` SHA-256 remained
  `65d1ae1ee7f3abcd65d6bf29797ea04c4e833c4109c426a34820f656a52ce6f0`;
- the original `owner@demo.local` login, Owner role, and retained client,
  truck, and trip API reads still worked.

Cleanup used one rollback-on-error transaction scoped to explicit Sprint
4.3.2 markers. No retained volume was deleted and no original record or Owner
password was overwritten.
