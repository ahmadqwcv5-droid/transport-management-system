# Sprint 4.3.2 — Onboarding, QR, and Notification UX Stabilization

## Role

Act as a senior product engineer, Flutter architect, ASP.NET Core engineer, QA engineer, and security reviewer working on the existing Transport Management System repository.

Do not redesign unrelated modules. This is a focused stabilization sprint intended to close the user-facing gaps discovered after Sprint 4.3.1.

## Repository and baseline

- Repository: `https://github.com/ahmadqwcv5-droid/transport-management-system`
- Expected reviewed baseline commit: `473233a`
- Before changing anything:
  1. Inspect the current branch, HEAD, and working-tree status.
  2. Pull/fetch only if it is safe and explicitly consistent with the current workspace.
  3. Preserve all existing user changes and unrelated uncommitted files.
  4. Read the current `README.md`, architecture documentation, Sprint 4.3/4.3.1 plans, and evidence.
  5. Run the relevant baseline tests before implementation.

Do not commit or push unless explicitly requested. Leave the final changes ready for review.

## Sprint objective

Make invitations, anonymous localization, password entry, truck QR generation, and notifications reliable and understandable in real browser workflows.

The sprint must solve the following observed problems:

1. Company users and invitations do not converge automatically across separate browser sessions. The Owner currently needs to refresh the page after an invited person accepts.
2. The public invitation-acceptance page opens in English and offers no language switch.
3. Password fields do not provide a show/hide control.
4. Generating a truck QR credential succeeds on the backend, but the Flutter Web UI can become trapped behind a dim modal barrier with a permanent spinner and no visible dialog.
5. New identity, membership, QR, connection, and handover notifications all fall back to the same generic trip-related message.

This sprint is complete only when the real workflows pass in Firefox using separate browser profiles/sessions. Passing unit tests alone is not sufficient.

---

## Non-negotiable domain semantics

### Invitations are not memberships

- Creating an invitation must not create a company account or membership prematurely.
- A newly created invitation must appear immediately under **Pending invitations**.
- Only after the invitation is accepted may the person appear under **Company members**.
- After acceptance, the accepted invitation must disappear from the pending view and the new member must appear automatically without a manual browser reload.

### QR security

- QR/manual secrets must remain one-time-display material.
- Status/list endpoints must never expose the complete reusable secret.
- Never put a raw invitation token, access token, refresh token, password, Google token, complete QR code, or complete manual QR secret into logs, notifications, evidence, screenshots, or test reports.
- Regeneration must revoke the previous credential exactly as it does now.
- A rendering failure must not silently regenerate another credential.

### Tenant isolation

- Every membership, invitation, notification, truck, driver, QR, and handover operation must remain tenant-isolated.
- Cross-tenant resources must not be discoverable through IDs, QR codes, notification payloads, or refresh behavior.

---

## Task 0 — Baseline assessment and implementation plan

Create `SPRINT4_3_2_IMPLEMENTATION_PLAN.md` before implementation.

It must contain:

- Baseline commit and working-tree state.
- Reproduction notes for all five reported problems.
- Root cause for each problem.
- Planned files and architectural decisions.
- Risks and rollback notes.
- Test matrix.
- A task-by-task elapsed-time table using actual active time.
- Final deviations from the original plan.

Do not claim a reproduction or browser pass unless it was actually observed.

---

## Task 1 — Company-member and invitation convergence

### Required behavior

1. After an Owner creates an invitation:
   - The pending invitation appears immediately without a full page refresh.
   - The newly invited email must not appear as a member before acceptance.
   - Repeated invalidation must not create duplicate rows.

2. When the invitee accepts in another Firefox profile/private session:
   - The Owner's already-open Company Users screen must converge automatically.
   - The pending invitation disappears.
   - The accepted member appears with the correct roles, membership state, and linked Driver record when applicable.
   - No manual browser reload is allowed in the acceptance test.

3. Refresh behavior must also cover:
   - invitation revoked, declined, or expired;
   - membership suspended, reactivated, or revoked;
   - connection request approved/rejected;
   - Driver account linked/unlinked;
   - handover request state changes where those lists are visible on this screen.

### Implementation guidance

- Preserve immediate Riverpod invalidation after mutations.
- Add cross-session convergence using the smallest reliable mechanism compatible with the current architecture:
  - refresh on page visibility/focus restoration; and
  - lightweight polling only while the Company Users screen is visible, or notification-driven invalidation if the existing notification poll can reliably provide it.
- A 10-second maximum convergence target is acceptable for this sprint.
- Do not add SignalR solely for this task.
- Cancel timers/subscriptions on disposal.
- Prevent overlapping requests and stale responses from replacing newer state.
- Preserve the user's selected tab and scroll position when refreshing.
- Display explicit states such as Pending, Accepted, Declined, Revoked, and Expired using localized labels.

### Required tests

- Provider/controller tests for immediate mutation refresh.
- Tests for serialized/latest-wins refresh behavior.
- Widget test proving a pending invitation is distinct from a member.
- Browser test with Owner and invitee in separate storage contexts proving automatic convergence without reload.

---

## Task 2 — Public Arabic/English localization

### Required behavior

Add a reusable public language control to:

- Login.
- Invitation preview/acceptance.
- Any public invitation error/expired/already-used state.

Language behavior:

- Offer `العربية` and `English` visibly.
- Switch all text and layout direction immediately.
- Arabic must render RTL; English must render LTR.
- Persist the anonymous choice locally so opening another public route keeps it.
- On first anonymous visit, use the locally saved choice; otherwise use a supported browser/device locale; otherwise fall back to English.
- Do not require authentication or a backend call to change the public language.
- Once authenticated, preserve the existing server-backed `PreferredLocale` behavior and define a deterministic reconciliation policy between anonymous local preference and the account preference.
- If invitation acceptance creates a new account, ensure its initial preferred locale is deliberate rather than accidentally hard-coded to English. Extend the acceptance contract safely if required.

All invitation roles, statuses, validation messages, Google actions, errors, and success states must be localized. Do not display raw role/status identifiers when a localized label exists.

### Required tests

- Anonymous locale resolution tests.
- Local persistence tests.
- Invitation page widget tests in English/LTR and Arabic/RTL.
- Browser proof that an English invitation URL can be switched to Arabic before authentication and remains Arabic during acceptance.

---

## Task 3 — Reusable show/hide password fields

Create a reusable application password-field component and use it everywhere a password is entered or created.

At minimum cover:

- Login password.
- Invitation account-creation password.
- Current password in Settings.
- New password in Settings.
- Confirm-new-password in Settings.
- Any other password entry discovered during repository inspection.

### Requirements

- Passwords remain hidden by default.
- Provide a localized eye icon/button to show and hide the value.
- Each field owns independent visibility state.
- Provide localized accessibility semantics/tooltips for “Show password” and “Hide password.”
- Preserve password-manager/autofill hints.
- Toggling visibility must not clear the value, move focus unexpectedly, submit the form, or alter validation.
- Never log or expose password contents.
- Ensure the control works by mouse, keyboard, and touch-sized interaction.

### Required tests

- Widget tests for hidden-by-default behavior.
- Toggle visibility and toggle-back tests.
- Independent current/new/confirm visibility tests.
- English and Arabic semantics/tooltip tests.
- Real browser verification on login and invitation acceptance.

---

## Task 4 — Replace the fragile QR dialog workflow

### Known failure

The backend successfully creates a truck QR credential and the status card updates, but Flutter Web can show only the modal barrier while the QR dialog fails to render. The generation method then waits forever for a dialog result, leaving the page dimmed and the Generate button spinning.

The current implementation places `QrImageView` inside an `AlertDialog`/intrinsic-layout path. Treat this as a likely root cause and confirm it using Firefox console evidence or a focused reproduction. Do not merely add a timeout around the broken dialog.

### Required architecture

Implement an explicit UI state machine, for example:

- idle;
- generating credential;
- preparing QR image;
- ready/displayed;
- failed with retry/copy recovery.

Generate validated QR image bytes before opening the dialog. Prefer using `QrPainter` (or another deterministic repository-compatible encoder) to create PNG bytes and display those bytes using a fixed-size `Image.memory`, rather than placing a layout-sensitive QR widget directly inside `AlertDialog`.

Use the same generated bytes for the PNG download. Do not recapture the dialog widget to create the file unless there is a proven reason.

### Required behavior

- One explicit Generate/Regenerate action performs at most one backend mutation.
- Validate that `code`, `qrPayload`, and generated image bytes are non-empty before showing the success dialog.
- The QR encodes the exact backend-provided `qrPayload`.
- Show:
  - truck plate/fleet identity;
  - QR image;
  - manual code;
  - Copy code;
  - Download PNG;
  - Done/Close.
- Printing is explicitly out of scope.
- If QR rendering fails after the credential was generated:
  - remove every loading/modal barrier safely;
  - keep the returned credential in memory for retrying the render during that page session;
  - allow copying the manual code;
  - show a localized actionable error;
  - do not call the regeneration endpoint again automatically.
- Escape/Close and normal dismissal must restore an interactive page.
- `finally` cleanup must run for API errors, rendering errors, download errors, dialog errors, and widget disposal.
- Add bounded error handling; no infinite spinner or permanently blocked route is allowed.
- Preserve the existing confirmation before replacing an active QR credential.
- Preserve old-code invalidation and current-code resolution semantics.

### Required tests

- Unit test QR payload-to-bytes generation.
- Widget test for the real QR dialog content, not a mocked placeholder.
- Rendering-error recovery test proving the barrier and busy state clear.
- Test that retrying display does not call regenerate again.
- Test that manual code remains available after a render failure.
- Browser test that generates a QR, sees the image, copies/views the manual code, downloads the PNG, closes the dialog, and can continue using the page.
- Browser test for Regenerate and rejection of the previous credential.
- Verify the generated PNG is non-empty and decodable.

---

## Task 5 — Complete notification contract and presentation

### Root problem

The backend now emits identity, membership, connection, QR, session, Driver-link, and handover events. The Flutter notification formatter only understands a small set of trip/tracking types. Unknown events incorrectly fall back to a generic message saying that a trip-related operational event needs attention.

### Required backend work

Inventory every `OperationNotification` type currently emitted by the backend. Include, at minimum, all existing variants in these families:

- Trip assignment and lifecycle.
- Pickup/delivery geofence arrivals.
- Truck offline/stale health.
- Company invitation created, accepted, declined, revoked, and expired.
- Company connection requested, approved, rejected, and cancelled.
- Membership suspended, reactivated/activated, and revoked.
- Driver account linked/unlinked when notifications exist or should exist.
- Truck QR generated/regenerated.
- Truck session started, ended, or switched.
- Default Driver changed.
- Driver handover requested, pending, approved, and rejected.
- External login linked/unlinked and other current security notifications.

For every current type, define a stable structured snapshot sufficient for display without live joins. Add safe fields where currently missing, such as:

- event code and category;
- invitation/member email or display name;
- localized role inputs as stable role codes;
- company name where useful;
- Driver name;
- truck plate/fleet code;
- trip number;
- stop/location snapshot;
- actor display name where appropriate;
- event timestamp;
- safe navigation target.

Do not include secrets or reusable credentials. Preserve tenant isolation and existing visibility rules.

### Required Flutter work

Introduce one centralized, exhaustive notification presentation registry/model used by:

- notification bell preview;
- notification list;
- toast/banner;
- sound/attention policy;
- notification detail view;
- navigation action.

Each notification presentation must provide:

- category: Trip, Fleet, People & Access, Security, or System;
- localized title;
- localized specific body;
- severity/icon/color policy;
- identity text such as trip number or plate when applicable;
- destination route when available;
- sound/high-visibility policy for actionable events.

Examples of the desired Arabic meaning:

- “قبل محمد دعوة الانضمام إلى الشركة بصفة سائق.”
- “تم إنشاء رمز QR جديد للشاحنة ABC-123 بواسطة أحمد.”
- “طلب السائق خالد استلام الشاحنة ABC-123 للرحلة TR-102.”
- “تم تعليق عضوية user@example.com.”
- “وصلت الشاحنة ABC-123 إلى موقع الاستلام للرحلة TR-102.”

The unknown-type fallback must be neutral and system-related, never falsely claim that the event concerns a trip. It may include a safe event reference for diagnostics, but must not display secrets or raw JSON.

Avoid repeated duplicate attention to the same `eventKey`. Preserve read/unread state. Do not play a sound again for old notifications loaded during initial hydration.

### Contract enforcement

- Add a test/fixture that enumerates every backend-emitted notification type and proves Flutter has a presentation mapping for it.
- If a fully shared compile-time contract is impractical across .NET and Dart, maintain a checked-in canonical fixture and fail tests when either side diverges.
- Test all current types in both Arabic and English.

---

## Task 6 — Browser acceptance matrix

Run real Firefox Web acceptance against the actual rebuilt application. Use separate Firefox profiles or truly isolated browser storage contexts. Two normal tabs in the same profile do not count.

### Scenario A — Invitation creation and automatic convergence

1. Owner logs in.
2. Owner opens Company Users and creates a disposable Driver invitation.
3. The pending invitation appears immediately without reload.
4. Invitee opens the link in another profile.
5. Invitee switches the page to Arabic and verifies RTL.
6. Invitee verifies password show/hide and accepts the invitation.
7. Without manually refreshing the Owner browser, verify within the documented convergence limit that:
   - the pending invitation disappears;
   - the member appears;
   - roles and linked Driver are correct.

### Scenario B — QR generation

1. Owner opens a truck with no active credential or explicitly confirms regeneration.
2. Generate the QR.
3. Verify the actual QR image is visible.
4. Verify the manual code is visible and copyable.
5. Download and decode the PNG.
6. Close the dialog and verify the page is fully interactive.
7. Regenerate once, verify the old credential is rejected and the new one resolves.
8. Confirm there is no permanent overlay and no infinite spinner.

### Scenario C — Notification clarity

Produce representative events from at least these categories:

- invitation accepted;
- membership state change;
- QR generated/regenerated;
- handover requested/approved or rejected;
- trip assignment or arrival;
- truck offline/stale.

Verify that titles and bodies are distinct, localized, contain the appropriate identity details, navigate correctly, and do not expose secrets.

### Scenario D — Regression

- Local email/password login.
- Google login remains functional with the already configured OAuth credentials.
- Google invitation acceptance remains functional when applicable.
- Logout stops the current profile's polling without logging out another profile.
- Arabic and English both work.
- No repeated unauthorized errors after logout.

Record browser console errors. Zero uncaught Flutter/rendering exceptions are allowed in the tested workflows.

---

## Task 7 — Validation and data safety

Run all applicable validation:

- `.NET` build with zero warnings and zero errors.
- Full backend integration test suite.
- Focused Sprint 4.3.2 backend tests.
- Flutter analyzer with zero issues.
- Full Flutter test suite.
- Focused widget/unit tests for localization, passwords, QR, refresh, and notification mappings.
- EF migration drift check.
- Flutter Web release build with the real runtime defines used by the project.
- Production Web build proving development-only simulator mutations remain absent.
- Real Firefox acceptance matrix above.
- Docker Compose API/PostgreSQL health checks.

### Existing environment protection

- Detect the actual Compose project name before running commands; do not assume the default project name.
- Preserve the existing PostgreSQL volume, photo volume, users, trucks, drivers, trips, credentials, and `.env`.
- Never run destructive volume or database commands.
- Do not reset the existing Owner password.
- Do not overwrite retained business data with demo fixtures.
- Use a disposable isolated tenant/project for automated browser data when practical, then remove only resources created by this sprint.
- If a migration is truly required, explain why, make it nullable/backward-safe, back up first, and prove no drift. Prefer no migration for purely presentational changes.

Android validation may be reported as blocked only after checking the SDK/device availability. Web acceptance remains mandatory.

---

## Documentation and evidence

Update:

- `README.md` with the user-visible invitation, language, password, and QR workflow.
- Architecture documentation with:
  - anonymous/authenticated locale ownership;
  - cross-session membership convergence;
  - QR one-time secret and rendering pipeline;
  - notification contract and presentation registry.
- `SPRINT4_3_2_IMPLEMENTATION_PLAN.md` with actual elapsed times and final results.
- `docs/evidence/sprint4_3_2/README.md` with an honest evidence index.

Evidence must include:

- English/LTR and Arabic/RTL invitation screenshots.
- Owner/invitee convergence evidence without manual reload.
- QR dialog visible, PNG validation, and post-close interaction evidence.
- Distinct notifications from multiple categories.
- Test/build outputs and browser console summary.

Do not store raw passwords, invitation URLs/tokens, QR secrets, OAuth credentials/tokens, personal Google screenshots, or access/refresh tokens in evidence.

---

## Out of scope

Do not add:

- Finance features.
- Maintenance features.
- SignalR solely for this sprint.
- Printing QR codes.
- Production camera scanning beyond preserving the existing supported behavior.
- New trip-planning or map features unrelated to regressions.
- Broad visual redesigns.
- New OAuth providers.

Fix adjacent defects only when they directly block the required workflows, and document them.

---

## Definition of done

Sprint 4.3.2 is complete only when all of the following are true:

- A pending invitation appears immediately after creation.
- A separately accepted invitation becomes a member in the Owner's open page without manual reload.
- Public login/invitation pages can switch between Arabic/RTL and English/LTR before authentication.
- Every password field has a reliable accessible show/hide control.
- Generating/regenerating a truck QR shows a usable dialog and never traps the page behind a modal barrier or infinite spinner.
- The QR PNG downloads and decodes successfully.
- Current backend notification types have specific English and Arabic presentations.
- Identity/security/QR events never use the generic trip-event message.
- No secrets appear in notification payload displays, logs, or evidence.
- Full automated validation passes.
- The stated real Firefox acceptance scenarios pass.
- Existing retained data and volumes remain intact.
- Documentation and elapsed-time records are complete.

## Final response format

At completion, report:

1. Root cause and fix for each of the five reported problems.
2. Files/areas changed.
3. Automated test counts and build results.
4. Exact real-browser scenarios completed.
5. QR operation evidence, including that the page remained interactive after close/failure.
6. Notification-type coverage count and any intentionally unsupported legacy types.
7. Data-safety and tenant-isolation evidence.
8. Environment limitations.
9. Actual active elapsed time per task and total.
10. Git status and confirmation that no commit/push was performed unless separately requested.

Do not describe a mocked/widget-only result as real browser proof. Do not mark the sprint complete if any mandatory acceptance scenario was skipped.
