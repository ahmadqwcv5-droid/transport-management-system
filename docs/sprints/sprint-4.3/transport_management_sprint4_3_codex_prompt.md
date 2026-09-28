# Transport Management System — Sprint 4.3 Codex Implementation Prompt

## Sprint Title

**Sprint 4.3 — Global Accounts, Company Memberships, Invitations, Google Sign-In, and Safe Driver–Truck Handover**

---

## Role

Act as a senior product engineer, solution architect, security engineer, ASP.NET Core engineer, Flutter engineer, PostgreSQL/EF Core engineer, QA engineer, and logistics operations specialist.

Work directly in the existing repository. Inspect the current implementation before changing it. Do not assume that this prompt perfectly describes every current filename or abstraction; adapt to the actual architecture while preserving the product rules and acceptance criteria below.

This sprint is an architectural identity and membership sprint. It must not be implemented as superficial screens around the current tenant-bound `User` model.

---

## Repository and Current Baseline

Repository:

```text
https://github.com/ahmadqwcv5-droid/transport-management-system
```

Expected starting point at prompt creation time:

```text
32f1867 feat(tracking): complete sprint 4.2.2 reliability
```

Before implementation:

1. Fetch and inspect the actual current branch and latest commit.
2. Record the real baseline commit in the sprint plan.
3. Inspect `git status` and preserve all user-owned changes.
4. Read the current README, architecture documentation, previous sprint plans, migrations, authentication implementation, tenant query filters, roles, company-user management, Driver/User link, DriverTruckSession behavior, trip assignment workflow, notifications, and map/tracking code.
5. Run the available baseline build and tests before changing behavior.
6. Do not modify `.env`, credentials, retained PostgreSQL volumes, or retained business data.
7. Do not commit or push. Leave the completed changes uncommitted for user review unless the user explicitly changes that instruction.

The current system already includes, among other things:

- ASP.NET Core backend, EF Core, and PostgreSQL.
- Flutter Web application with Arabic/English localization and RTL/LTR.
- Strong tenant scoping using `CompanyId`.
- Owner/operations/driver experiences.
- Company user management and Driver records optionally linked to a user.
- Driver password changes and driver operational workspace.
- Trucks, clients, drivers, trips, routes, tracking, simulator, maps, notifications, geofences, and operational dashboards.
- Default Driver-to-truck recommendation behavior.
- DriverTruckSession and driver trip workflow.
- Stable MapLibre/OpenFreeMap behavior from Sprint 4.2.2.
- Monotonic current-position projection and immutable tracking history.

All of this working behavior must be preserved.

---

## Product Context

The product must support both:

1. A transport company with Owners, Operations users, accountants, and Drivers.
2. A future independent owner-operator who manages their own truck and work.

The current model binds a `User` directly to one `CompanyId` and one role. That is too restrictive for the intended product because one human may:

- belong to more than one company;
- be a Driver in one company and an Owner or Operations user in another;
- own an independent workspace later;
- leave a company without losing their personal account;
- accept a company invitation using an existing account;
- use local credentials or Google to authenticate;
- have a company-specific Driver record without exposing personal or other-company data.

This sprint must introduce a clean distinction between:

- global personal authentication identity;
- company/workspace membership;
- company-specific authorization and roles;
- the company-specific Driver operational record;
- current truck session and default truck preference;
- trip assignment and historical driver participation.

The system remains a fleet/transport operations product. It must **not** become a public driver marketplace or load board in this sprint.

---

## Non-Negotiable Product Decisions

### 1. One personal account, multiple company memberships

A person owns one global account. The account must not be owned by one company.

A company relationship is represented by a membership with:

- Company/Workspace ID;
- account ID;
- one or more roles or an equivalent permission-safe representation;
- membership status;
- invitation/acceptance and audit metadata;
- joined, suspended, revoked, and left timestamps where applicable.

All operational business data remains tenant-owned and scoped by `CompanyId`.

### 2. A Driver record is not the same thing as a login account

Preserve the useful separation found in mature fleet systems:

- A company can have a Driver record before that driver receives application access.
- A Driver record may be invited and linked to an existing or newly created global account.
- The account may have a different Driver record in another company.
- Company-specific notes, employment state, assignments, and trip history stay inside that company.

Do not expose one company's Driver data to another company through the global account.

### 3. Company joining is private and explicit

Support both:

- an Owner/authorized manager inviting a person to the company;
- an authenticated Driver entering an exact company code and requesting connection.

Do not add fuzzy/public company discovery. Do not expose a directory of companies.

### 4. No public driver marketplace

The company may:

- invite a known person by email;
- connect an invitation to an existing Driver record;
- later accept a connection request initiated using its exact company code;
- use an exact driver/share code if the architecture benefits from it.

The company must not browse arbitrary public drivers in this sprint.

### 5. Password ownership belongs to the person

Owners and managers must never set or see another user's permanent password.

Invited users set their own password or authenticate with Google. Invitation tokens are not passwords.

### 6. Google Sign-In is additive

Implement Google Sign-In now, but keep email/password authentication available.

Phone-number/OTP authentication is explicitly deferred. Design the account and external-login model so a phone identity provider can be added later without rewriting memberships or business entities.

### 7. Default truck, active truck session, and trip assignment are different concepts

- **Default truck:** the company's normal/persistent truck preference for a Driver.
- **Active truck session:** the truck the Driver is currently operating during a shift/session.
- **Trip assignment:** the truck and Driver responsible for a specific trip at a given time.

Never overload one field to represent all three concepts.

### 8. QR switching must preserve trips and accountability

A Driver may scan a truck QR code to operate another truck when substituting for another Driver.

However:

- scanning must not silently steal a truck or active trip;
- scanning must not recreate, reset, or lose the trip;
- route geometry, current route progress, tracking run, trail, notifications, and trip identity must remain intact;
- the system must preserve who was originally assigned and who actually operated each portion;
- a takeover of another Driver's active trip requires explicit Owner/Operations approval by default;
- all handovers must be audited and notified;
- future driver performance evaluation must be possible from preserved participation data.

---

## Sprint Objectives

Deliver all of the following:

1. A global account and company membership foundation.
2. Safe migration of every current user and credential.
3. Invitation and company-connection workflows.
4. Workspace selection/switching for accounts with multiple memberships.
5. Local email/password and Google authentication using the same account model.
6. A future-compatible boundary for phone/OTP authentication without implementing OTP.
7. Company-specific Driver-to-account linking.
8. Persistent default-truck assignment.
9. Secure per-truck QR codes.
10. Active Driver–truck sessions and safe truck switching.
11. Approved mid-trip driver handover without losing the trip.
12. Historical trip driver participation for later evaluation.
13. Complete English/Arabic UX and RTL/LTR behavior.
14. Strong tenant isolation, authorization, concurrency, audit, tests, documentation, and evidence.

---

# Workstream 1 — Baseline Audit and Mandatory Implementation Plan

Create:

```text
docs/sprints/sprint-4.3/SPRINT4_3_IMPLEMENTATION_PLAN.md
```

Before material implementation, record:

- current branch and commit;
- worktree state;
- current authentication and refresh-token design;
- current `User`, `Company`, `Driver`, roles, query filters, and claims;
- current company-user creation/linking flow;
- current default Driver/truck selection behavior;
- current DriverTruckSession invariants;
- current trip assignment and trip-event model;
- current development seeding behavior;
- baseline backend/Flutter test counts;
- migration and retained-data safety plan;
- exact task breakdown and acceptance matrix.

Track real active elapsed time for every task and the total sprint. Do not invent timings after implementation.

The plan must be updated during the sprint and finalized with completed results, limitations, and deferred work.

---

# Workstream 2 — Global Account and Membership Architecture

## Required outcome

Replace the architectural assumption that an authentication identity belongs permanently to one company.

The exact entity names may follow repository conventions, but the resulting concepts must include equivalents of:

```text
Account
Company / Workspace
CompanyMembership
MembershipRole or an equivalent multi-role model
ExternalLogin
CompanyInvitation
CompanyConnectionRequest
```

The existing tenant-owned `Driver` remains company-specific, but it must link safely to the global account/membership rather than assuming the global identity belongs only to that company.

## Membership states

Support an explicit state model such as:

```text
Pending
Active
Suspended
Revoked
Left
```

Do not use deletion as the normal way to remove a person's company access.

## Roles

Preserve all current roles and policies. Support the business requirement that one person may have more than one capability in a workspace, including a future independent Owner + Driver.

Do not weaken authorization into frontend-only checks.

## Active workspace

Authentication identifies the person. Authorization and tenant scope use the currently selected active membership/workspace.

Provide secure equivalents of:

```text
GET  /api/auth/me
GET  /api/auth/workspaces
POST /api/auth/switch-workspace
```

The actual route names may follow existing conventions.

Workspace switching must:

- require an Active membership;
- issue/rotate application tokens safely;
- include the active company and membership/roles in validated claims;
- never accept an arbitrary client-provided CompanyId without membership validation;
- revalidate membership during refresh;
- stop access quickly after suspension or revocation;
- preserve secure refresh-token rotation and revocation behavior.

## Tenant isolation

Tenant query filters for operational records must remain effective.

Membership lookup across companies is a special identity boundary. Implement it through an explicit, reviewed identity store/service rather than casually disabling tenant filters throughout the application.

Add architecture tests preventing tenant-owned business data from being queried without company scope.

---

# Workstream 3 — Safe Legacy Migration

Create an additive, reviewable EF Core migration that safely migrates all existing users.

Requirements:

- Every existing login must continue to work after migration.
- Preserve password hashes; never reset passwords automatically.
- Preserve roles, company association, active state, driver link, refresh-token safety, and audit history.
- Create one global account and one active membership for each current user, unless the real data reveals a collision requiring a documented deterministic strategy.
- Do not invent memberships, companies, drivers, or geography.
- Do not delete existing users before the migrated model is proven.
- Handle normalized-email uniqueness explicitly.
- Detect and report duplicate/conflicting identities instead of silently merging them.
- Make Up and Down behavior explicit and honest. If a fully lossless rollback is impossible after multi-membership data exists, document that fact and use an appropriate guarded migration strategy rather than pretending otherwise.
- Run EF model-drift checks.
- Apply and validate the migration on an isolated PostgreSQL database first.
- Record retained business counts before and after without polluting retained data.

The migration must not modify `.env` or destroy volumes.

---

# Workstream 4 — Local Authentication and Google Sign-In

## Existing email/password login

Preserve local email/password authentication and password change behavior.

Update it so login authenticates the global account first, then:

- automatically enters the only active workspace when exactly one exists;
- shows a workspace chooser when multiple exist;
- shows onboarding/join options when none exist;
- never guesses a company from email alone.

## Google Sign-In

Implement Google Sign-In through a provider-neutral external identity abstraction, for example:

```text
IExternalIdentityVerifier
ExternalLogin(provider, providerSubject, accountId)
```

Security requirements:

- Validate the Google ID token or authorization result on the backend.
- Validate issuer, audience/client ID, signature, expiration, nonce/state where applicable, and verified email.
- Never trust a Google email sent as plain client JSON.
- Never store a Google password.
- Do not store Google access/refresh tokens unless a real product requirement exists. Authentication alone does not require them.
- Store the stable Google subject identifier, not email alone, as the external identity key.
- Do not silently link an existing local account solely because the Google email matches. Require the existing account to authenticate and explicitly link Google, or implement an equivalently secure confirmation flow.
- Detect provider-subject and email conflicts with stable localized error codes.
- Do not expose OAuth client secrets to Flutter.
- Keep configuration outside source control.
- Add safe `.env.example`/README documentation without modifying `.env`.
- Support separate Web and future Android client identifiers/configuration.
- If Google is not configured, keep local login fully functional and hide or clearly disable the Google action.

The backend must issue the application's own access and refresh tokens after successful external authentication. The rest of the application must not depend on Google tokens.

## Account linking UI

Under account settings, support:

- viewing linked sign-in methods;
- explicitly linking Google to an authenticated local account;
- unlinking Google only when another usable sign-in method remains;
- preserving password-change capability for local accounts.

## Testability

Use a fake external identity verifier for automated tests. Tests must not depend on live Google services or real secrets.

A live Google browser test may be reported only if valid test credentials and configuration are already available and the full flow is genuinely completed. Otherwise report build/configuration and deterministic integration tests honestly; do not claim a live Google login.

---

# Workstream 5 — Future Phone Authentication Boundary

Phone-number/OTP login is **not** part of this sprint.

However, ensure the architecture can later support:

- normalized E.164 phone identities;
- verified/unverified status;
- OTP challenge lifecycle;
- phone identity uniqueness;
- account recovery;
- invitation by phone/SMS;
- linking a phone login to an existing account.

Do not implement fake OTPs, hardcoded codes, or development backdoors in production paths.

Do not make phone number mandatory now.

Document the planned extension point in `docs/architecture.md`.

---

# Workstream 6 — Company Invitations

## Invitation creation

Authorized Owner/Operations users can invite a person with:

- email;
- intended roles;
- optional existing company Driver record;
- optional display name/context;
- expiration date;
- inviter and audit metadata.

Driver invitations must normally be attached to a specific company Driver record when that record already exists.

## Invitation security

- Generate a cryptographically secure, non-guessable token.
- Store only a secure hash of the raw token.
- Make invitations single-use and expiring.
- Support Pending, Accepted, Expired, Revoked, and Declined states.
- Prevent acceptance by the wrong authenticated email unless an explicit secure recovery/admin correction workflow is used.
- Never expose password hashes or internal IDs in invitation URLs.
- Do not claim email delivery exists unless an email provider is genuinely configured.
- When delivery is unavailable, provide a safe copy-link workflow for the Owner.

## Acceptance

An invited person may:

- sign in with an existing local/Google account;
- create a local account and set their own password;
- accept or decline;
- review company name, intended role, linked Driver identity, and relevant location/privacy expectations before accepting.

On acceptance:

- create/activate the membership transactionally;
- link the correct company Driver record;
- do not create duplicate Driver records;
- notify the inviter/company;
- write a durable audit event;
- make the workspace available immediately.

---

# Workstream 7 — Exact Company Code and Connection Requests

Give every company a private, unique, non-sequential, case-insensitive company connection code.

Owner capabilities:

- view the company code;
- copy it;
- generate a QR/link if useful;
- revoke/regenerate it with confirmation;
- see pending connection requests;
- approve, reject, or cancel requests;
- link an approved Driver request to an existing Driver record or create one through a reviewed flow.

Driver capabilities:

- enter the exact code;
- see only the exact matching company's safe public summary, such as name, logo if available, and operational locality;
- submit one connection request;
- view Pending/Approved/Rejected/Cancelled status;
- cancel a pending request.

Security and privacy:

- No fuzzy search.
- No paginated company directory.
- No endpoint that can enumerate all companies.
- Rate-limit or otherwise mitigate brute-force code discovery.
- Company codes must be sufficiently random.
- Do not expose company users, fleet size, clients, trucks, routes, or private locations before approval.
- Approval must not accidentally link a same-name Driver without explicit confirmation.

---

# Workstream 8 — Workspace and Membership UX

## Global account experience

The header/profile area must clearly show:

- person name/avatar or initials;
- active role(s);
- active company/workspace name;
- account settings;
- workspace switch action when more than one membership exists.

## Workspace chooser

Show each active membership with:

- company name;
- role(s);
- status;
- optional logo;
- a clear select action.

Pending invitations and connection requests must be visually separate from active workspaces.

## Membership management

Owner/authorized UI must distinguish:

- company Driver record without app access;
- invitation pending;
- account connected and active;
- suspended/revoked membership;
- invitation expired;
- connection request awaiting review.

Do not collapse these into one ambiguous “user” status.

## Revocation and leaving

- Revoking membership removes future access but preserves company trips, events, notifications, and audits.
- A Driver leaving a company retains their global account but loses that company's private data.
- Existing tokens for the revoked workspace must stop working promptly.
- Do not delete historical trip references.

---

# Workstream 9 — Default Truck Assignment

Preserve existing working default-Driver selection behavior and formalize default truck assignment.

Company behavior:

- An Owner/Operations user can assign a default truck to a Driver.
- The relationship is company-scoped and auditable.
- Only active Drivers and active trucks are selectable.
- Conflicting defaults are handled explicitly according to a documented rule.
- Assigning a default truck does not create or start a trip.
- Assigning a default truck does not automatically start a DriverTruckSession unless the current business rule explicitly requires it and is safely documented.

Driver behavior:

- The default truck is shown prominently as “Your assigned/default truck”.
- It remains visible when no trip is active.
- The Driver can see truck photo, plate/fleet code, status, current location freshness, and whether it is the active session truck.
- A different temporary truck session does not silently replace the default truck.
- Only an authorized company user can make the temporary truck the new default through an explicit action.

---

# Workstream 10 — Secure Truck QR Codes

## QR identity

Each truck can have an active QR credential managed by the company.

Requirements:

- Do not encode a raw sequential database ID as the only secret.
- Use a high-entropy opaque token or signed/revocable code.
- Store a hash where practical.
- Allow Owner/Operations to regenerate/revoke the code.
- Regeneration invalidates the previous QR.
- QR resolution is limited to authenticated active members of the same company.
- Cross-tenant QR use must return a safe not-found/forbidden response without leaking truck details.
- Log QR generation, regeneration, scan attempts as appropriate, and successful switches.

Owner UI:

- show truck identity and photo;
- generate/regenerate QR;
- provide a printable/downloadable QR label;
- explain that the QR identifies the truck, not a trip.

Driver UI:

- “Scan truck QR” action;
- camera scanning where supported;
- a manual code fallback for Web/test environments and unavailable camera permissions;
- explicit permission/error/retry states;
- a confirmation screen before mutation showing truck photo, plate, status, current Driver/session, and active trip context.

Use a testable QR-scanner abstraction. Do not claim real camera acceptance unless an actual camera/device was used.

---

# Workstream 11 — Active Driver–Truck Sessions

Strengthen or extend the existing `DriverTruckSession` model.

Required invariants:

- A Driver has at most one active truck session within a company.
- A truck has at most one active Driver session within a company.
- Session start/end/switch is transactional and concurrency-safe.
- Starting a new safe session closes the previous session with a reason and timestamp.
- A session records source such as DefaultAssignment, ManagerAssignment, DriverQrScan, or ApprovedHandover.
- The session records who initiated and who approved the change when applicable.
- Default truck assignment is not overwritten by a temporary session.
- Membership revocation/suspension prevents new sessions and safely ends or flags active sessions according to documented policy.

When scanning an unoccupied truck with no conflicting active trip:

1. Show confirmation.
2. End the Driver's previous safe session if one exists.
3. Start the new truck session.
4. Preserve truck position and tracking state.
5. Notify/audit the switch.

If a conflict exists, do not silently mutate anything.

---

# Workstream 12 — Mid-Trip Driver Substitution and Handover

This is a critical workflow.

Scenario:

> Company assigned Truck A and Trip T to Driver A. Driver B must temporarily drive Truck A and complete the same trip. Driver B scans Truck A's QR.

## Required behavior

If the truck has an active/reserved trip assigned to another Driver:

1. Show Driver B the safe trip summary needed for confirmation.
2. Create a pending takeover/handover request.
3. Notify authorized Owner/Operations users immediately.
4. Do not change the active trip, truck session, or Driver assignment before approval.
5. Owner/Operations sees:
   - trip number;
   - client/cargo summary subject to existing permissions;
   - truck photo/plate;
   - current Driver;
   - requesting Driver;
   - trip phase;
   - current location freshness;
   - consequences of approval.
6. Owner/Operations approves or rejects with an optional/required reason according to the action.
7. Approval occurs transactionally with optimistic concurrency protection.

## On approval

- Preserve the same Trip ID.
- Preserve the same truck.
- Preserve route plan, repositioning plan, route geometry, stops, progress, trail, current position, notifications, and tracking run unless a real domain rule requires otherwise.
- End Driver A's active participation/session at the handover timestamp.
- Start Driver B's participation/session at the same logical handover boundary.
- Update the trip's current operational Driver assignment so Driver B sees and can continue the trip.
- Preserve Driver A as the original/prior assignee in immutable history.
- Notify Driver A, Driver B, and the approving company user.
- Add trip timeline/audit events containing previous Driver, new Driver, initiator, approver, time, reason, phase, truck, and request ID.
- The already-open Driver B workspace must converge to the active trip without logout.
- Driver A must lose future mutation permission for that trip immediately while retaining only any allowed historical view.

## Evaluation-ready attribution

Add an explicit historical representation equivalent to:

```text
TripDriverParticipation
- CompanyId
- TripId
- DriverId
- StartedAt
- EndedAt
- Source / AssignmentType
- StartedPhase
- EndedPhase
- StartedPositionId (optional)
- EndedPositionId (optional)
- AssignedBy / ApprovedBy
- HandoverRequestId (optional)
```

Do not implement a driver-rating algorithm in this sprint. Instead, preserve trustworthy data so future evaluation can attribute work to the Driver who actually performed it.

Do not simply overwrite `Trip.DriverId` and lose history.

## Rejection/cancellation

- Rejection leaves all assignments unchanged.
- The requesting Driver sees a localized rejection state.
- Requests expire or become invalid if the trip, session, membership, truck, or assignment changes first.
- Replaying an accepted request is idempotent and cannot create duplicate sessions/participation.

## Manager-initiated handover

Allow Owner/Operations to initiate a direct handover through the trip/truck UI with the same confirmation, history, concurrency, and notification rules.

Do not add automatic unapproved takeover in this sprint.

---

# Workstream 13 — Notifications and Audit

Add durable localized events/notifications for at least:

- company invitation created/revoked/accepted/declined/expired;
- company connection requested/approved/rejected/cancelled;
- membership suspended/reactivated/revoked;
- Google login linked/unlinked where appropriate;
- default truck assigned/changed;
- truck QR regenerated;
- truck session started/ended/switched;
- handover requested/approved/rejected/expired;
- active trip Driver changed.

Notification payloads must use stable event codes and structured data, not English strings as business logic.

Driver-facing notifications must identify:

- company;
- truck plate/fleet code;
- trip number when relevant;
- previous/current Driver context when permitted;
- action required;
- navigation target.

Reuse the existing clear visual/audio notification system. Do not create duplicate audio loops or notification storms.

Audit records are not the same as dismissible UI notifications. Preserve important security and assignment actions durably.

---

# Workstream 14 — Flutter Screens and UX

Implement polished responsive Flutter flows consistent with the current design system.

## Authentication

- Existing email/password login.
- “Continue with Google” when configured.
- Honest unconfigured state.
- Invitation-aware sign-up/sign-in.
- Pending invitation acceptance.
- Workspace chooser.
- No-workspace onboarding actions.

## Account settings

- Profile identity.
- Change password where local credentials exist.
- Linked sign-in methods.
- Link/unlink Google safely.
- Future phone placeholder only if it clearly says unavailable/not configured; do not present fake OTP functionality.

## Owner/Operations

- Membership/user management separated from Driver records.
- Invitations list and creation.
- Connection requests inbox.
- Company code display/copy/regenerate.
- Link invitation/request to a Driver record.
- Default truck assignment.
- Truck QR view/print/regenerate.
- Handover request confirmation with full context.
- Membership suspend/reactivate/revoke actions with confirmation.

## Driver

- Clear profile header showing person, Driver role, and active company.
- Pending invitation/connection state.
- Default truck card.
- Active truck session card.
- Scan/manual QR action.
- Truck confirmation before switching.
- Pending handover state.
- Approved/rejected feedback.
- Existing map, trip workflow, ETA, notifications, and post-trip vehicle visibility preserved.

## Localization and accessibility

- All new copy in ARB resources.
- English and Arabic complete.
- Correct RTL/LTR layouts.
- Do not reverse strings manually.
- Localize statuses and stable error codes centrally.
- Accessible labels for Google login, invitation actions, workspace switching, QR actions, and approval controls.
- Keyboard and browser usability for Web.

---

# Workstream 15 — API and Error Contract

Use stable ProblemDetails error codes. Include at least equivalent cases for:

```text
ACCOUNT_EMAIL_CONFLICT
EXTERNAL_LOGIN_ALREADY_LINKED
EXTERNAL_LOGIN_CONFIRMATION_REQUIRED
GOOGLE_AUTH_NOT_CONFIGURED
GOOGLE_TOKEN_INVALID
MEMBERSHIP_NOT_ACTIVE
WORKSPACE_ACCESS_DENIED
INVITATION_INVALID
INVITATION_EXPIRED
INVITATION_ALREADY_USED
INVITATION_EMAIL_MISMATCH
COMPANY_CODE_INVALID
CONNECTION_REQUEST_ALREADY_PENDING
DRIVER_ACCOUNT_ALREADY_LINKED
DRIVER_LINK_REQUIRED
TRUCK_QR_INVALID
TRUCK_QR_REVOKED
TRUCK_SESSION_CONFLICT
DRIVER_ALREADY_IN_ACTIVE_SESSION
TRUCK_ALREADY_IN_ACTIVE_SESSION
HANDOVER_APPROVAL_REQUIRED
HANDOVER_REQUEST_STALE
HANDOVER_ALREADY_RESOLVED
TRIP_ASSIGNMENT_CHANGED
CONCURRENCY_CONFLICT
```

Exact naming may follow existing conventions, but the semantics must be stable and localized in Flutter.

Do not depend on backend English message text in the UI.

---

# Workstream 16 — Security Requirements

At minimum verify:

- global account uniqueness and normalization;
- password hashing remains unchanged and safe;
- refresh-token rotation after workspace changes;
- membership checked on every workspace-sensitive token issuance/refresh;
- revoked memberships cannot continue through stale refresh tokens;
- invitation and QR raw secrets are not stored in plaintext where avoidable;
- invitation/connection/QR endpoints resist enumeration;
- Google token validation is backend-owned;
- no OAuth secrets in Flutter or source control;
- no cross-tenant Driver linking;
- no cross-tenant company code approval;
- no cross-tenant QR resolution;
- no cross-tenant trip takeover;
- only Owner/Operations can approve handovers;
- a Driver cannot approve their own takeover;
- concurrency cannot create two active sessions for one Driver or truck;
- account/membership changes are audited;
- sensitive logs do not include passwords, raw refresh tokens, OAuth tokens, invitation tokens, or QR secrets.

Use database constraints where they strengthen invariants, but inspect legacy data before adding any unique constraint.

---

# Workstream 17 — Automated Testing

## Backend integration tests

Cover at minimum:

### Migration and legacy compatibility

- current Owner login still works;
- current Driver login still works;
- current Driver link is preserved;
- current roles and company scope are preserved;
- password hashes are not changed;
- migration contains no invented business records;
- EF drift is clean.

### Accounts and workspaces

- account with one membership enters correctly;
- account with multiple memberships can list and switch;
- account cannot switch to a workspace without membership;
- suspended/revoked membership cannot refresh/access;
- roles are enforced server-side;
- one company's data remains invisible in another workspace.

### Google authentication

- valid fake verified Google identity can create/sign in according to policy;
- invalid issuer/audience/expiry/unverified email rejected;
- provider subject uniqueness enforced;
- matching email is not silently linked without secure confirmation;
- authenticated explicit link works;
- unlink blocked when it would remove the last sign-in method;
- unconfigured Google provider returns a stable safe result.

### Invitations

- create, accept, decline, revoke, expire;
- wrong account/email cannot accept;
- token replay is idempotently rejected;
- raw token is not persisted;
- existing Driver link preserved without duplicate Driver;
- acceptance creates correct membership and audit.

### Company code connections

- exact code success;
- wrong code safe failure;
- no directory/enumeration result;
- duplicate pending request prevented;
- approval/rejection/cancellation;
- approval links only the explicitly selected Driver;
- cross-tenant attempts rejected.

### Default truck and sessions

- default truck persists and is visible to Driver;
- temporary session does not overwrite default;
- one active session per Driver;
- one active session per truck;
- concurrent switches resolve safely;
- QR regeneration invalidates old QR;
- same-company QR works;
- cross-company QR leaks nothing.

### Active trip handover

- scanning another Driver's active-trip truck creates a request and changes nothing before approval;
- approval preserves Trip ID, truck, route, tracking run, progress, current position, and history;
- previous and new participation records have correct boundary timestamps;
- current Driver changes exactly once;
- old Driver loses mutation permission;
- new Driver can continue the next valid action;
- rejection changes nothing;
- stale request cannot override a newer assignment;
- duplicate approval is idempotent;
- Driver cannot self-approve;
- Owner/Operations authorization works;
- notifications and trip/audit events are created once;
- tenant isolation holds.

## Flutter tests

Cover at minimum:

- local login remains available;
- Google button configured/unconfigured behavior;
- invitation acceptance states;
- workspace chooser and active workspace header;
- memberships/invitations/connection request UI;
- company code exact lookup flow;
- Driver default truck card;
- QR scan abstraction and manual fallback;
- truck confirmation screen;
- pending handover UI;
- Owner approval/rejection modal content;
- trip remains visible after approved handover;
- Arabic/English and RTL/LTR;
- current map/follow/interpolation behavior does not regress;
- centralized error-code localization.

Run the entire existing suites, not only new focused tests.

---

# Workstream 18 — Real Browser Acceptance

Use real Flutter Web browser acceptance against an isolated backend/database where the environment permits.

Use two or more genuinely independent browser profiles/sessions:

- Owner/Operations;
- Driver A;
- Driver B where required.

Required real-browser scenarios:

1. Existing migrated Owner logs in using local credentials.
2. Owner creates an invitation linked to an existing or new Driver record.
3. Driver accepts it with a self-owned account and sees the correct company.
4. Driver uses exact company code to create a connection request in a separate scenario.
5. Owner approves the request and the already-open Driver UI converges.
6. Workspace header shows correct person, company, and role.
7. Workspace switching is proven if a multi-membership fixture is created in the isolated environment.
8. Owner assigns a default truck and Driver sees it.
9. Driver switches to a free truck using the QR/manual-code UI.
10. An active-trip takeover request is created by Driver B.
11. Owner sees complete confirmation details and approves it.
12. The same trip, route, progress, and truck remain; Driver B can continue it and Driver A cannot mutate it.
13. English/LTR and Arabic/RTL are both captured.
14. Existing map/tracking and notification behavior remains healthy.

Google acceptance rule:

- If no real Google OAuth credentials/configuration exist, do not block the sprint and do not fake a successful live login.
- Prove the provider abstraction, backend validation policy, configuration state, release build, and deterministic tests.
- Explicitly report live Google login as unavailable due to missing credentials/configuration.

QR camera rule:

- If no real camera/device is available, use the manual-code fallback and deterministic scanner-adapter tests.
- Do not claim physical camera scanning was tested.

Chrome/Android limitations must be stated honestly. Firefox Web acceptance is acceptable when it is the available real browser, but Android remains unverified until a valid SDK/device exists.

---

# Workstream 19 — Regression Protection

The sprint must not regress:

- tenant isolation;
- existing Owner, Operations, Accountant, and Driver permissions;
- default Driver recommendation in trip assignment;
- trip creation and route planning;
- Driver departure/arrival/loading/delivery/completion actions;
- automatic geofence behavior;
- fleet map and Driver map;
- Arabic map shaping;
- follow/free-explore/route-overview camera modes;
- marker interpolation and photo markers;
- operational-area preference;
- current-position chronology;
- notification sound/visual behavior;
- simulator development-only restrictions;
- stored business data and media volumes.

Do not rewrite the stable map/tracking subsystem unless a minimal compatibility change is required.

---

# Workstream 20 — Documentation and Evidence

Update:

```text
README.md
docs/architecture.md
docs/sprints/README.md
docs/sprints/sprint-4.3/SPRINT4_3_IMPLEMENTATION_PLAN.md
```

Create:

```text
docs/evidence/sprint4_3/
```

Document:

- final identity/account/membership model;
- legacy migration mapping;
- active workspace and token model;
- membership authorization boundary;
- Driver record versus account distinction;
- invitation and exact company-code flows;
- Google sign-in configuration and security;
- why phone OTP is deferred and how it fits later;
- default truck versus active session versus trip assignment;
- truck QR threat model;
- handover state machine and participation attribution;
- API/error contracts;
- tenant-isolation proof;
- migration Up/Down review;
- browser acceptance evidence;
- test/build results;
- environmental limitations;
- actual task elapsed times.

Evidence must distinguish:

- automated policy/unit proof;
- backend integration proof;
- database proof;
- real browser proof;
- unavailable live Google/camera/Android proof.

Do not present API setup or test injection as UI proof.

---

## Explicitly Deferred

Do not implement the following in Sprint 4.3:

- phone/SMS OTP authentication;
- public company search;
- public driver search;
- driver marketplace;
- load board;
- bidding, broker matching, or payments;
- driver-rating algorithm;
- independent-driver onboarding/business UI beyond foundations required for memberships;
- finance;
- maintenance/document modules;
- real GPS provider integration;
- SignalR/push redesign;
- broad map redesign;
- Android-specific background location without a valid Android environment;
- social login providers other than Google.

These remain future work. Sprint 4.4 is expected to cover guided onboarding and the independent owner-operator workspace. Trip Operations & Dispatch Control remains preserved for the subsequent roadmap and must not be forgotten.

---

## Required Validation Commands and Outcomes

Adapt commands to the repository, but the final report must include:

- clean .NET build with zero warnings/errors;
- complete backend integration suite passing;
- Flutter analyzer clean;
- complete Flutter tests passing;
- focused Sprint 4.3 tests passing;
- EF Core migration applied to isolated PostgreSQL;
- no EF model drift;
- Flutter Web release build passing;
- real-browser acceptance for all available scenarios;
- Docker Compose health where used;
- retained database/business-count and volume-identity comparison;
- confirmation that `.env` was untouched;
- honest Android/Chrome/Google/camera limitations;
- final `git status` showing only intended Sprint 4.3 changes plus preserved pre-existing user changes.

Do not overwrite retained credentials, reset the database, recreate retained volumes, or seed new demo records into the user's retained tenant.

Stop the retained simulator or use an isolated environment when taking data-safety snapshots so background telemetry is not mistaken for migration changes. Restore only processes you intentionally paused.

---

## Definition of Done

Sprint 4.3 is complete only when:

1. Existing users are safely migrated and can still authenticate.
2. Authentication identity is no longer permanently bound to one company.
3. An account can have multiple memberships and switch safely.
4. Tenant isolation remains enforced after switching.
5. Company invitations work end to end.
6. Exact company-code connection requests work without a public directory.
7. Driver records link to accounts without becoming global company data.
8. Local login remains functional.
9. Google Sign-In is correctly implemented/configurable and never falsely reported as live-tested.
10. The architecture is ready for phone OTP later without implementing it now.
11. Default truck assignment is persistent and distinct from active sessions.
12. Secure truck QR codes can be managed and resolved safely.
13. A Driver can switch to an available truck through QR/manual code.
14. Taking over another Driver's active trip requires approval.
15. Approved handover preserves the same trip, route, tracking, progress, and history.
16. Driver participation is historically attributable for future evaluation.
17. Owner/Operations and Driver UIs are complete in English and Arabic.
18. Full builds/tests/migration/browser acceptance pass within available environments.
19. Data, `.env`, credentials, and retained volumes are preserved.
20. Documentation, evidence, and actual elapsed-time records are complete.
21. No commit or push is performed.

---

## Required Final Response Format

Return a concise but complete report containing:

1. Architecture implemented.
2. Migration and legacy-account result.
3. Invitation and company-connection result.
4. Local and Google authentication result.
5. Workspace switching and tenant-isolation result.
6. Default truck and QR/session result.
7. Mid-trip handover and attribution result.
8. English/Arabic UX result.
9. Backend build/test totals.
10. Flutter analyzer/test totals.
11. EF migration/drift result.
12. Web release and browser acceptance result.
13. Data-safety result.
14. Exact environment limitations, especially live Google, QR camera, Chrome, and Android.
15. Actual elapsed time by task and total.
16. Documentation/evidence locations.
17. Final git status and explicit confirmation that no commit or push was performed.

Do not describe a partial mock, API-only shortcut, injected fixture, or deterministic unit test as full real-browser proof.
