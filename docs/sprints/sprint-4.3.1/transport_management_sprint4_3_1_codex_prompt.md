# Sprint 4.3.1 — Account–Driver Linking, QR Lifecycle, Invitation Deep Links, and Google Sign-In Acceptance

## Role

Act as a senior product engineer responsible for safely stabilizing the existing multi-tenant transport-management system. Work across ASP.NET Core, EF Core/PostgreSQL, Flutter Web/Android-compatible code, authentication, authorization, localization, browser acceptance testing, and documentation.

This is a stabilization sprint, not a feature-expansion sprint. Diagnose the current implementation before changing it, preserve existing business data, and prove user-facing workflows in a real browser instead of treating backend or widget tests as UI proof.

## Repository and current baseline

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

The reviewed baseline at the time this prompt was prepared was:

```text
3ff880a feat(identity): complete sprint 4.3 accounts and handover
```

Record the actual starting commit in the implementation plan. Do not assume the tree is clean, do not discard unrelated user changes, and do not reset or overwrite `.env`.

The retained local environment uses the Compose project name:

```text
tms-smoke
```

Known-good runtime facts already verified manually:

- `GET http://localhost:5080/health` returns HTTP 200.
- Sprint 4.3 API routes are present in OpenAPI.
- The latest applied migration is `20260927152730_Sprint43GlobalAccountsMembershipsAndHandover`.
- `owner@demo.local` exists, is active, has an active membership, and has the `Owner` role.
- Direct Owner login through `POST /api/auth/login` returns HTTP 200.
- PostgreSQL and the API are healthy under `tms-smoke`.
- The Sprint 4.3 invitation works when its relative path is manually converted to a full Flutter hash URL.
- Google OAuth is now configured successfully in the retained local environment.
- A real Google account has successfully completed Google Sign-In through the current Web client and backend.
- Therefore, Google Firefox acceptance in this sprint is mandatory and must not be reported as blocked merely because an isolated test environment was created without forwarding the existing public client-ID configuration.

Do not reopen these resolved runtime questions without new evidence.

## Why this sprint exists

Sprint 4.3 introduced a strong global-account and multi-company membership foundation, but real manual use exposed important gaps:

1. An account invited with the Driver role but not linked to a Driver record cannot be linked later through the current UI. The backend and Flutter repository/controller contain linking operations, but the Members UI exposes only unlinking for already-linked accounts.
2. If an account does not yet have the Driver role, there is no safe role-management workflow that lets an Owner add the role and then link the account.
3. The current backend linking implementation must not silently replace another account already linked to the chosen Driver record.
4. Truck QR creation is unclear. The user cannot see whether a truck has an active QR credential, generation errors are not surfaced properly, and the raw secret disappears after the one-time dialog without an explicit explanation.
5. The current physical scanner adapter is unavailable. The UI must not imply that camera scanning works when only manual code entry is usable.
6. Invitation creation currently returns a relative route such as `/accept-invitation?token=...`, which is not directly usable in another browser profile. The user currently has to construct `http://localhost:3000/#/accept-invitation?...` manually.
7. Google Sign-In code exists, but it has not been accepted against a real OAuth configuration. The invitation flow also lacks a direct “Continue with Google” path.
8. Several mutations swallow `ApiException` and display only a generic error, making real failures impossible to diagnose.
9. Sprint 4.3 automated tests covered more than the real Firefox acceptance run. This sprint must close that evidence gap.

## Sprint outcome

At the end of Sprint 4.3.1, an Owner must be able to:

- invite a person with one or more permitted roles;
- open and share a complete invitation URL;
- link an accepted Driver-role membership to an existing unlinked Driver record at any later time;
- safely manage membership roles under explicit authorization rules;
- see whether a truck has an active QR credential;
- generate or regenerate the truck QR and receive a visible QR image plus manual code;
- copy the manual code and download the QR as a PNG;
- observe localized, actionable errors if an operation fails;
- verify the manual truck-code workflow from an independent Driver browser profile;
- use Google Sign-In when valid OAuth configuration is present, including invitation acceptance;
- retain email/password login as a supported sign-in method.

No printing feature is required in this sprint.

## Mandatory working rules

1. Create and continuously update:

   ```text
   docs/sprints/sprint-4.3.1/SPRINT4_3_1_IMPLEMENTATION_PLAN.md
   ```

2. Before implementation, document:
   - actual HEAD and git status;
   - current architecture and relevant endpoints;
   - current account/membership/Driver relationships;
   - current QR storage and security semantics;
   - current Google configuration boundary;
   - baseline build/test results;
   - retained Compose container IDs, volume names, and read-only business counts;
   - risks and rollback approach.
3. Record start time, end time, and active elapsed time for every task and for the complete sprint.
4. Use additive, tenant-safe changes. Avoid a migration unless it is genuinely required. If a migration is required, explain why, test upgrade and rollback in an isolated database, and never invent or reset business data.
5. Never delete or recreate retained PostgreSQL or photo volumes. Never run `docker compose down -v`.
6. Use an isolated Compose project and isolated ports for destructive fixtures and full acceptance setup. Do not seed Sprint fixtures into `tms-smoke`.
7. Do not overwrite `.env`, rotate existing credentials, reset the Owner password, or change retained company data.
8. Do not commit or push unless explicitly requested. Leave a clear git-status summary.
9. Do not claim browser proof for a workflow that was only tested through an API fixture, widget test, mocked provider, or direct database setup.
10. Preserve English and Arabic localization, LTR/RTL behavior, multi-tenancy, existing tracking, maps, trip workflows, and data isolation.

## Task 1 — Baseline audit and explicit state model

Inspect the current implementation before editing, including at minimum:

- `CompanyUserService`, `MembershipService`, their stores and controllers;
- `CompanyUsersScreen`, controllers, repositories, and localized error mappings;
- membership role persistence and JWT role revalidation;
- Driver `UserId` uniqueness and tenant filters;
- `QrHandoverService`, QR persistence/configuration, truck details UI, and Driver code-entry UI;
- invitation route generation and GoRouter hash behavior;
- Google external identity verifier, Flutter Google button, settings linking flow, and configuration variables;
- existing Sprint 4.3 tests and evidence limitations.

Document a concise state model separating:

- global personal account;
- company membership;
- membership roles;
- tenant-owned Driver record;
- default truck assignment;
- active Driver–truck session;
- trip assignment and participation;
- QR credential.

These concepts must remain distinct. Linking an account to a Driver must not create a trip, default truck assignment, or active vehicle session.

## Task 2 — Safe membership-role management

Implement an explicit role-management workflow rather than relying only on invitation-time role selection.

### Required behavior

- An Owner can view and edit the roles of a membership in the active company.
- The UI must show all current roles, not only a derived primary role.
- Role updates must be audited and tenant-isolated.
- Role changes must invalidate or reject stale authorization immediately. Preserve the existing per-request membership/role revalidation behavior.
- The system must never leave a company without at least one active Owner.
- A user must not be able to silently remove their own final Owner access.
- An Operations member must not be able to grant, remove, or impersonate the Owner role.
- Define and enforce the exact permissions for Operations. At minimum, Operations may manage operational Driver linking and truck QR actions, but must not escalate itself or another account to Owner.
- Removing the Driver role must be blocked while the membership is linked to a Driver record. The UI must explain that the Driver link must be resolved first.
- If an active trip, active Driver–truck session, or pending handover would make unlinking unsafe, reject the mutation with a stable error code and actionable message rather than silently mutating operational state.
- Do not silently add roles as a side effect unless the UI explicitly asks for and confirms that behavior.

Create stable ProblemDetails error codes and English/Arabic mappings for every new rule.

## Task 3 — Post-acceptance account-to-Driver linking

Complete the feature that is partially present but not exposed correctly.

### Members UI

For an active membership containing the Driver role:

- If no Driver is linked, show a clear **Link Driver** action.
- Open a dialog showing only active, tenant-local Driver records that are not linked to another account.
- Show enough Driver identity to avoid choosing the wrong person, such as full name, phone when available, and operational status.
- Require confirmation before linking.
- On success, refresh Members, Drivers, trip assignment options, and any affected Driver workspace providers without requiring a full page reload.
- If a Driver is linked, show the linked Driver clearly and retain **Unlink Driver** behind an explicit confirmation.
- If changing the link is supported, make it an explicit audited transfer. Never silently steal a Driver record from another account.

### Accounts without the Driver role

If an Owner selects **Link Driver** for a membership without the Driver role, use one of these explicit designs:

1. offer a confirmation to atomically add the Driver role and link the selected Driver; or
2. require the Owner to add the Driver role first and clearly guide them to do so.

Prefer an atomic application service if one user action is intended to do both operations. Do not leave a partially updated role/link state if the second operation fails.

### Backend invariants

- Both account membership and Driver record must belong to the active tenant.
- The membership must be active.
- One account may link to at most one Driver per company under the current model.
- One Driver may link to at most one account.
- Linking to an already-linked Driver returns a conflict; it must not automatically unlink the existing account.
- Idempotently linking the same account and Driver is safe.
- Every link, unlink, rejected conflict, and explicit transfer is auditable.
- Cross-tenant IDs reveal no data.

## Task 4 — Complete and understandable truck QR lifecycle

Use the existing hashed-secret model. Never persist or re-expose a raw historical QR/manual code.

### QR status API

Add or complete an Owner/Operations-authorized read model that returns non-secret metadata only, for example:

```text
truckId
hasActiveCredential
codeHint
generatedAt
generatedByDisplayName
```

It must not return the raw code, token hash, or another tenant's data.

### Truck details UI

Replace the ambiguous icon-only behavior with a clear QR section or labeled action that shows one of these states:

- **QR not generated** → **Generate QR**
- **QR active** with code hint and generated date → **Regenerate QR**

First generation does not need a destructive warning. Regeneration must explicitly warn that the previous QR and manual code will immediately stop working.

After successful generation/regeneration, show:

- the real rendered QR;
- truck plate/fleet identity;
- the manual code;
- **Copy code**;
- **Download QR image**;
- **Done**.

Do not implement printing in this sprint.

The downloaded PNG must:

- contain a valid, non-empty PNG;
- use a safe filename derived from the truck plate or fleet code;
- contain the QR itself at a scannable resolution;
- not embed access tokens or unrelated personal information.

Explain in the UI that the raw code is shown only during generation. Closing the one-time dialog requires regeneration if the code was not saved.

### Reliability and errors

- Prevent duplicate submits while generation is in progress.
- Surface localized `ApiException` messages and stable `errorCode` values.
- Test first generation, regeneration, concurrent requests, old-code invalidation, and exactly one active credential per truck.
- Preserve the active-credential uniqueness invariant transactionally.
- Keep audit events and notifications.

### Driver workflow

The current scanner provider is unavailable. Do not advertise physical camera scanning as working.

- On platforms without a supported scanner, label the action **Enter truck code** rather than **Scan truck QR**.
- Accept the raw manual code and, if practical, a complete `tms-truck://qr/...` payload pasted into the field.
- Trim whitespace and validate input before submission.
- Preserve preview-before-confirm semantics.
- Show plate, truck status, current Driver, current trip, and whether approval is required.
- Keep physical camera scanning deferred unless it can be implemented and proven on a real supported device. Android cannot be claimed without an Android SDK/device.

## Task 5 — Complete invitation URLs and reliable deep links

Introduce a configurable public frontend base URL, for example:

```text
FRONTEND_PUBLIC_BASE_URL=http://localhost:3000
```

Requirements:

- Invitation creation returns a complete, directly openable URL.
- For the current Flutter Web hash routing, local development should produce a URL equivalent to:

  ```text
  http://localhost:3000/#/accept-invitation?token=...
  ```

- Do not derive the public URL from an untrusted request Host header.
- Normalize slashes and URL-encode the token correctly.
- Configure production explicitly; do not silently emit localhost production links.
- Continue storing only the invitation token hash.
- Do not log invitation tokens.
- The copied link must open successfully in a clean Firefox private profile.
- Reopening an accepted single-use invitation must be rejected with the correct localized error.
- Update `.env.example`, Compose configuration, README, and architecture documentation. Do not modify the real `.env`.

## Task 6 — Google Sign-In and invitation acceptance

Keep local email/password login fully supported. Google is an additional sign-in method, not a replacement.

### Security boundary

Continue using the official Google client integration and backend ID-token verification. The backend must verify:

- supported provider;
- Google signature/JWKS;
- issuer;
- audience against configured allowed client IDs;
- expiry;
- verified email;
- nonce when supplied;
- required subject and email claims.

Never accept a Google access token as identity proof. Never put a Google client secret in Flutter, git, `.env.example`, logs, screenshots, or evidence.

### Required user flows

#### A. Existing Google-linked account

- **Continue with Google** signs the person in.
- One active membership opens its workspace.
- Multiple memberships open the workspace chooser.
- Zero memberships open the honest no-workspace state, where the account can accept an invitation or request a company connection.

#### B. New invited person using Google

- The public invitation page displays **Continue with Google** when both frontend and backend Google configuration are genuinely available.
- After Google authentication, the verified Google email must match the invitation email.
- A matching new global account may be created and the invitation accepted.
- The selected company membership, roles, and optional Driver link must be created exactly once.
- A mismatching Google email is rejected without consuming the invitation.
- Preserve the invitation token/return path during authentication.

#### C. Existing local account with the same email but Google not linked

- Do not auto-merge solely by matching email.
- Return the stable existing error such as `EXTERNAL_ACCOUNT_LINK_REQUIRED`.
- Present a clear action: sign in with the existing password, then link Google from Settings.
- Preserve a safe route back to the invitation after local sign-in where applicable.

#### D. Account settings

- List local and Google sign-in methods.
- Allow explicit Google linking after authenticating the existing account.
- Allow unlinking only when another usable sign-in method remains.
- Show localized success and error states.

### Configuration and honest availability

Support the existing variables:

```text
GOOGLE_WEB_CLIENT_ID
GOOGLE_ANDROID_CLIENT_ID
GOOGLE_SERVER_CLIENT_ID
```

For Web, document the exact authorized JavaScript origin:

```text
http://localhost:3000
```

The Google button must not appear as usable if the Flutter client ID or backend provider configuration is missing.

Valid Google OAuth configuration is available in the retained local environment and real Google Sign-In has already succeeded. Therefore:

- preserve the existing `.env` without printing, committing, overwriting, or rotating its values;
- reuse the configured public client ID safely for the real acceptance run;
- do not copy OAuth values into documentation, evidence, screenshots, logs, source files, or the final report;
- do not claim that credentials are unavailable solely because a disposable test stack did not inherit them;
- perform the real Firefox Google flows and record sanitized evidence without tokens, authorization codes, cookies, or personal account details;
- if Google becomes unavailable because of a genuine external outage or revoked configuration, provide concrete sanitized evidence and mark only the affected live scenario blocked. Deterministic tests still remain mandatory.

## Task 7 — Actionable error handling

Remove silent failure paths in the affected Sprint 4.3 UI.

At minimum:

- invitation creation;
- role update;
- Driver link/unlink;
- membership lifecycle actions;
- QR status/generation/regeneration;
- manual code preview/confirmation;
- Google sign-in/link/unlink;
- invitation acceptance.

Requirements:

- Preserve the actual `ApiException` rather than collapsing it to `null` or `false` without context.
- Map stable backend error codes to localized English and Arabic messages.
- Show an appropriate inline error or snackbar.
- Include a retry action where retry is safe.
- Do not expose stack traces, hashes, JWTs, invitation tokens, QR secrets, or tenant identifiers in user-facing errors.
- Log enough server-side context for diagnosis using correlation/request IDs without logging secrets.

## Task 8 — Automated test coverage

### Backend integration tests

Add tests for at least:

- linking an accepted Driver-role membership after invitation acceptance;
- adding Driver role then linking through the intended explicit workflow;
- rejecting link without Driver role when implicit role addition was not confirmed;
- idempotent same account/Driver link;
- rejecting an already-linked Driver without silently replacing the prior account;
- unlink restrictions for active trip/session/handover states;
- tenant isolation for membership, Driver, role, QR status, and QR mutation endpoints;
- last-active-Owner and self-demotion protection;
- Operations privilege-escalation rejection;
- role-change audit and stale-token rejection;
- full invitation URL construction and single-use behavior;
- first QR generation and non-secret status response;
- QR regeneration invalidating the old code;
- concurrent QR generation preserving exactly one active credential;
- Driver preview/confirm through the manual code;
- fake Google success, mismatch, collision, explicit linking, unlink-last-method protection, invalid token, and unconfigured provider.

### Flutter tests

Add tests for at least:

- **Link Driver** appears for eligible unlinked members;
- only eligible unlinked Drivers appear in the selector;
- successful link refreshes the visible member and Driver data;
- role editor permissions and confirmation states;
- QR never-generated and active states;
- generation progress prevents double submission;
- generated QR, manual code, copy, and PNG download behavior;
- regeneration warning;
- localized API errors rather than generic failure;
- unsupported camera UI says **Enter truck code**;
- invitation UI receives and copies a complete URL;
- invitation Google button availability logic;
- Google email mismatch and existing-account guidance;
- English/LTR and Arabic/RTL layouts at desktop and mobile widths.

Run the complete existing suites, not only focused tests.

## Task 9 — Real Firefox acceptance

Use independent Firefox profiles or private contexts. Tabs in the same normal profile are not independent because they share Web storage.

### Scenario 1 — Link after acceptance

1. Owner creates an invitation with the Driver role but deliberately leaves Driver record unselected.
2. Copy the complete invitation URL.
3. Open it directly in a clean Driver profile.
4. Accept and sign in.
5. Confirm the Driver workspace honestly reports that no Driver record is linked.
6. Owner opens Members and links the account to an existing unlinked Driver.
7. Refresh or reauthenticate the Driver profile.
8. Confirm the linked Driver workspace becomes available without database edits.

### Scenario 2 — Role then Driver link

1. Use a disposable membership that does not initially have the Driver role.
2. Verify direct linking is prevented or explicitly offers the approved atomic add-role-and-link flow.
3. Complete the intended flow as Owner.
4. Verify roles and Driver identity converge in both profiles.

### Scenario 3 — QR generation and manual code

1. Owner opens an existing truck.
2. Verify **QR not generated**.
3. Generate a QR.
4. Verify the QR is visibly rendered and the manual code is present.
5. Copy the code and download a non-empty PNG.
6. Driver opens **Enter truck code**, pastes the code, previews the correct truck, and confirms according to availability/handover rules.
7. Owner regenerates the QR.
8. Verify the old code fails and the new code succeeds.

### Scenario 4 — Invitation deep link

1. Create a fresh invitation.
2. Copy exactly what the UI supplies.
3. Paste it into a clean Firefox private window without manually editing it.
4. Complete acceptance.
5. Reopen the same URL and verify single-use rejection.

### Scenario 5 — Google (mandatory real-browser acceptance)

The retained environment already has working Google OAuth configuration and real Google Sign-In has succeeded. Complete all of the following in real Firefox profiles:

1. Verify Google login for a Google-linked account.
2. Verify invitation acceptance with matching Google email.
3. Verify a mismatching Google email does not consume the invitation.
4. Verify an existing local same-email account receives explicit link guidance rather than silent merge.
5. Link Google from Settings and verify later Google login.
6. Verify logout and a fresh Google login in a new browser profile.

Do not downgrade this scenario to mocked-only proof. If an external Google outage prevents completion, retain the deterministic tests and provide concrete sanitized failure evidence.

### Browser evidence rules

- Capture sanitized English and Arabic screenshots for the new flows.
- Record HTTP statuses and stable error codes without storing tokens or secrets.
- Do not retain raw invitation tokens, QR codes, JWTs, cookies, Google ID tokens, or personal Google account data in evidence.
- Clearly separate real-browser proof from automated proof.

## Task 10 — Regression, data safety, and activation

Run and record:

- .NET Release build with zero warnings/errors;
- complete backend integration test suite;
- Flutter analyzer;
- complete Flutter test suite;
- EF migration drift check;
- Flutter Web release build with Google disabled;
- Flutter Web release build with configuration wiring enabled when safe public client IDs are available;
- real Firefox acceptance;
- API and PostgreSQL health;
- tenant-isolation checks;
- retained volume/container identity comparison;
- retained business-count comparison.

If a migration is added, prove it on a disposable legacy database before touching the retained environment.

At the end, provide exact activation commands for the retained `tms-smoke` environment. Commands must use:

```text
docker compose -p tms-smoke ...
```

Do not assume plain `docker compose exec` resolves the correct project.

Explain that an existing Owner password is not changed by modifying `.env`.

Do not replace the retained environment silently. If the task authorization permits an in-place API rebuild, first create and verify a non-empty backup, then preserve named volumes and confirm the applied migration. Otherwise provide the commands for the user.

## Documentation

Update:

- `README.md`;
- `docs/architecture.md`;
- Sprint evidence under `docs/evidence/sprint4_3_1/`;
- the implementation plan and timing record.

Document:

- account versus membership versus Driver semantics;
- role-management authorization matrix;
- Driver linking/unlinking invariants;
- QR status, one-time raw-secret display, download, regeneration, and manual-code workflow;
- explicit statement that printing is not implemented;
- explicit statement that physical camera scanning remains unavailable unless genuinely proven;
- complete invitation URL configuration;
- Google Cloud Web origin and client-ID configuration;
- Google account collision/linking behavior;
- exact retained-stack activation and verification commands;
- environment limitations.

## Explicit non-goals

Do not add:

- QR printing;
- public company search;
- public Driver marketplace or ratings;
- phone/SMS OTP;
- finance;
- maintenance;
- documents;
- route optimization;
- SignalR redesign;
- real GPS provider integration;
- Android background tracking;
- physical camera-scan claims without a supported device and real proof;
- unrelated UI redesigns.

## Definition of done

Sprint 4.3.1 is complete only when:

1. An accepted Driver-role account can be linked later through the Owner UI.
2. Role management is explicit, authorized, tenant-safe, audited, and protects the last active Owner.
3. Linking never silently steals a Driver record from another account.
4. The Driver sees the linked workspace after normal refresh/reauthentication without database manipulation.
5. Truck details clearly show QR status.
6. First generation produces a visible QR, manual code, copy action, and downloadable PNG.
7. Regeneration invalidates the old code and preserves exactly one active credential.
8. Unsupported camera environments honestly use manual-code wording.
9. Invitation copy produces a complete URL that opens directly in an independent browser profile.
10. Google invitation/login/linking flows are implemented securely and tested deterministically.
11. Real Google login, invitation acceptance, email-mismatch protection, explicit linking, logout, and fresh-profile login are exercised in Firefox using the already-working OAuth configuration.
12. Affected UI mutations show localized actionable errors.
13. English, Arabic, LTR, RTL, desktop, and mobile-width tests pass.
14. Full backend and Flutter regression suites pass.
15. Retained data, `.env`, credentials, and volumes remain intact.
16. Real-browser proof is clearly distinguished from automated proof.

## Required final report

Return a concise but complete report containing:

- implemented behavior;
- root causes fixed;
- files/modules changed;
- migrations added or an explicit statement that none were required;
- backend build/test totals;
- Flutter analyze/test totals;
- Web build result;
- real Firefox scenarios completed;
- Google live-test status and why;
- QR generation/download/manual-code proof;
- account-to-Driver linking proof;
- English/Arabic responsive proof;
- retained-data and volume-safety result;
- environment limitations;
- remaining risks or deferred work;
- exact activation commands;
- git status;
- elapsed time per task and total active elapsed time.

Do not describe Sprint 4.3.1 as fully end-to-end validated if any mandatory browser scenario was not actually completed.
