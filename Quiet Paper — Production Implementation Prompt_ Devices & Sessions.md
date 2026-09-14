# Quiet Paper — Production Implementation Task
## Devices & Sessions + Local Vault Preservation on Sign Out

You are working directly inside the existing **Quiet Paper** production repository.

Your job is to implement a complete, production-ready **Devices & Sessions** system and update logout semantics so that **signing out disconnects the account session but does NOT destroy the locally stored encrypted vault or its decryption keys**.

This is an implementation task, not a prototype.

**Do not create mock implementations, fake API responses, placeholder repositories, TODO-only methods, hardcoded sample devices, simulated timestamps, or non-functional UI.**

Everything must be wired end-to-end through the actual Flutter app, actual backend API, actual Turso/libSQL database, actual Firebase authentication state, actual Drift database, and actual secure storage.

Before modifying code, inspect the existing architecture and implementation thoroughly. Reuse existing abstractions where appropriate rather than creating parallel systems.

---

# 1. PRODUCT REQUIREMENT

Quiet Paper needs a first-class:

**Settings → Devices & Sessions**

feature.

The purpose is to let users see which installations of Quiet Paper are currently associated with their account and remotely revoke sessions.

The feature must NOT expose encryption status.

The feature must NOT expose online/offline indicators for now.

The feature should remain consistent with Quiet Paper's existing warm editorial / iOS Grouped Table / Bear-inspired design language.

---

# 2. CRITICAL SECURITY / DATA SEMANTICS

This distinction is mandatory:

### Sign Out

Signing out means:

> Disconnect this device from the user's cloud account.

It does NOT mean:

> Destroy this device's local vault.

When a user signs out locally:

- Firebase/account session is removed.
- Cloud synchronization stops.
- Device is no longer authenticated to the cloud API.
- Local SQLite database remains intact.
- Locally stored encrypted notes remain intact.
- Locally stored encrypted attachments remain intact.
- Locally stored encrypted documents remain intact.
- Local decryption key material remains available.
- User can continue using/decrypting the local vault while signed out.
- Signing in again can reconnect the same local vault to the account and resume synchronization.

### Sign Out & Erase Local Data

This is a separate destructive action.

It means:

- Sign out of account.
- Stop cloud sync.
- Delete the local vault/database.
- Delete local encrypted attachment/document data belonging to the vault.
- Delete locally persisted master-key/decryption-key material.
- Clear local account/session-specific cryptographic state.
- Leave the device effectively empty of the local Quiet Paper vault.

The two operations MUST NOT be conflated.

---

# 3. IMPORTANT EXISTING ARCHITECTURE

Read and respect the existing handoff document and repository implementation.

Relevant existing architecture includes:

- Flutter client.
- TypeScript/Vercel serverless backend.
- Firebase Authentication for account identity.
- Turso/libSQL backend database.
- Drift SQLite local database.
- `AuthService` / `FirebaseAuthService`.
- `SecureKeyManager`.
- `SyncEngine`.
- `SyncApiClient`.
- existing device ID in sync metadata.
- backend `sync_devices` infrastructure.
- `last_acknowledged_revision`.
- `last_active_at`.
- existing safe sync boundary / GC behavior.
- Flutter secure storage for authentication/session/key state.

The current architecture already tracks device information for synchronization. Do not replace that system with a second unrelated device-tracking mechanism.

The existing backend currently uses device IDs as part of synchronization and safe GC boundaries.

Extend that infrastructure cleanly.

---

# 4. FIRST STEP — AUDIT THE REPOSITORY

Before coding:

1. Locate the existing `sync_devices` backend schema/migrations.
2. Locate all backend device registration/update logic.
3. Locate all client-side device ID generation/storage.
4. Locate all authentication session persistence logic.
5. Locate `FirebaseAuthService.signOut()`.
6. Locate all calls to `clearLocalKeys()`.
7. Locate all code paths that interpret logout as a reason to destroy cryptographic state.
8. Locate sync authentication middleware.
9. Locate existing `GET /api/...` and `POST /api/...` conventions.
10. Locate Settings screen architecture and grouped-row components.
11. Locate existing password/logout confirmation UI.
12. Locate existing tests around auth, sync, database, key manager and logout.
13. Locate database migration version and current schema version.
14. Inspect the full `HANDOFF(5).md`, especially the sections covering auth persistence, device checkpoints, sync, garbage collection, and current settings architecture.

Do not assume the handoff is the complete implementation. Verify against actual source code.

---

# 5. BACKEND DATA MODEL

Use the existing `sync_devices` infrastructure rather than introducing an unrelated `devices` table unless the existing implementation genuinely makes extension impossible.

The device record should support at least:

```text
id
user_id
device_id
device_name
platform
model
os_version
app_version
created_at
last_active_at
last_acknowledged_revision
revoked_at
```

Use the repository's established naming/style conventions.

Requirements:

- `device_id` must be unique per user.
- A single device installation should map to one stable device record.
- Reconnecting the same installation must update its existing record rather than create duplicates.
- Device registration must be authenticated.
- Device records must be strictly scoped to the authenticated user.
- A user must never be able to query or mutate another user's devices.
- Revocation must be persisted server-side.
- Revoked devices must not be silently recreated as active on every sync request.
- Database indexes must be appropriate for:
  - user lookup,
  - device lookup,
  - active-device queries,
  - revoked-device queries where useful.

Add a real production migration.

Do not modify an existing migration destructively.

Add a new migration using the repository's migration conventions.

---

# 6. DEVICE METADATA

The client should register/update real information available from the platform.

Capture:

- stable installation/device ID already used by Quiet Paper sync,
- human-readable device name,
- platform,
- model,
- OS version,
- Quiet Paper app version,
- creation/first-seen timestamp,
- last active timestamp.

Do not fabricate any fields.

Do not depend on device names being stable across OS upgrades.

Use the appropriate Flutter/platform APIs already present in the project, and add a package only when justified and compatible with the repository.

For unsupported platforms, use a meaningful real fallback such as the platform name rather than fake hardware metadata.

---

# 7. DEVICE REGISTRATION

On authenticated startup or authenticated sync:

- register the current device if necessary;
- update `last_active_at`;
- update app/platform metadata as appropriate;
- update `last_acknowledged_revision` when synchronization legitimately acknowledges a revision;
- do not repeatedly create records;
- do not perform unnecessary database writes on every UI rebuild.

Device registration must be idempotent.

The API must tolerate retries and network duplication.

Use the existing auth token machinery and existing sync client abstractions.

Do not create a second authentication system.

---

# 8. DEVICE REVOCATION

Implement real backend revocation.

Add an authenticated endpoint following the project's existing API conventions, for example:

```text
POST /api/v1/devices/:deviceId/revoke
```

or an equivalent route consistent with the actual codebase.

The endpoint must:

1. authenticate the caller;
2. verify the device belongs to the caller;
3. mark it revoked;
4. prevent revoked sessions/devices from performing authenticated sync;
5. return a structured API response;
6. preserve auditability;
7. be safe to retry.

A device must not be able to revoke another user's device.

Do not return internal database errors directly to clients.

Use the project's established `ApiError` / structured-error conventions.

---

# 9. SIGN OUT ALL OTHER DEVICES

Implement:

```text
POST /api/v1/devices/revoke-others
```

or an equivalent endpoint using the repository's conventions.

Semantics:

- Revoke every other active device for the authenticated user.
- Do NOT revoke the current device.
- Operation must be atomic where practical.
- The result should contain the number of affected devices.
- Calling it again should be safe.
- It must not affect note data.
- It must not delete encryption keys from the backend.
- It must not delete the user's account.

The current device must be identified using the real current device ID rather than a name or model.

---

# 10. DEVICE LIST API

Implement a real authenticated endpoint to retrieve the current user's devices.

For example:

```text
GET /api/v1/devices
```

Return device metadata sufficient for the UI:

- device ID or safe identifier,
- device name,
- platform,
- model,
- OS version,
- app version,
- created timestamp,
- last active timestamp,
- revoked timestamp where relevant.

Do not expose unnecessary internal database identifiers.

Do not expose sensitive authentication tokens.

Do not expose encryption keys, wrapped master keys, password-derived material, salts, or cryptographic secrets through this API.

The endpoint must only return devices belonging to the authenticated account.

---

# 11. CURRENT DEVICE IDENTIFICATION

The API and client need a reliable way to identify:

> This device

Use the existing persisted device ID already used by the synchronization layer.

Do not generate a new random ID every app launch.

Do not use the Firebase UID as the device ID.

Do not use an email address as the device ID.

Do not silently change the device ID during ordinary app updates.

Preserve existing device identity across:

- app restarts,
- app updates,
- background process termination,
- normal sync failures.

Follow the repository's existing secure/local persistence conventions.

---

# 12. DEVICE RENAMING

Implement device rename as a real feature.

Add an authenticated endpoint, for example:

```text
PATCH /api/v1/devices/:deviceId
```

with a validated payload:

```json
{
  "deviceName": "My Phone"
}
```

Requirements:

- validate length;
- trim whitespace;
- reject empty names;
- reject control characters;
- enforce a sensible maximum length;
- authorize against user ownership;
- persist to database;
- return updated device;
- UI must update without app restart.

Default device names should come from actual platform/device data where available.

---

# 13. REVOKED DEVICE BEHAVIOR

When a device has been remotely revoked:

The next authenticated request from that device must receive a dedicated structured response such as:

```text
DEVICE_REVOKED
```

Do not overload every failure into a generic `401`.

The client must recognize remote revocation.

On receiving `DEVICE_REVOKED`:

1. Stop cloud sync.
2. Mark current cloud session invalid.
3. Remove Firebase/account session credentials.
4. Preserve local SQLite database.
5. Preserve local encrypted attachments/documents.
6. Preserve local decryption keys.
7. Preserve locally created unsynced data.
8. Transition the UI to a signed-out state.
9. Tell the user clearly that the device was signed out remotely.
10. Do not silently delete the local vault.

Example user-facing message:

> This device was signed out remotely. Your local notes are still here. Sign in again to resume sync.

Do not claim anything about encryption status in the UI.

---

# 14. LOCAL SIGN OUT SEMANTICS — CHANGE EXISTING IMPLEMENTATION

This is a required architectural change.

Find the existing behavior where explicit logout calls:

```text
clearLocalKeys()
```

or otherwise destroys the master key.

Change the semantics so ordinary:

```text
Sign Out
```

does NOT clear the local decryption keys.

After sign out:

- authentication session is gone;
- local vault remains;
- decryption remains possible;
- no cloud sync occurs;
- the app must not access authenticated endpoints;
- signing back in should reuse the local vault correctly.

This must be implemented consistently across every logout path.

Do not fix only the main Settings button while leaving other logout paths with destructive behavior.

Audit all of:

- Settings logout;
- auth error logout;
- session-expiry logout;
- remote-device-revocation logout;
- account switching if present;
- sign-out from auth screens;
- app bootstrap auth failure;
- any error recovery path invoking `clearLocalKeys()`.

Separate session clearing from local-vault destruction.

---

# 15. INTRODUCE EXPLICIT LOCAL-VAULT ERASURE

Create a deliberate service/API-level concept for:

```text
eraseLocalVault()
```

or equivalent.

It must be clearly distinct from:

```text
signOut()
```

The implementation should have one authoritative destructive path rather than scattered database/key deletion calls.

Local erase should cover all local vault state that should not survive a destructive logout:

- Drift database/vault content;
- encrypted attachments;
- encrypted documents;
- OCR data;
- local sync queues;
- sync metadata;
- device/session-specific local records where appropriate;
- locally persisted master key/decryption-key material;
- cached wrapped key state;
- any local state that could incorrectly reconnect stale encrypted data.

Do not blindly delete unrelated application preferences such as typography settings unless repository architecture establishes them as vault-owned.

Do not destroy user preferences unnecessarily.

---

# 16. LOCAL STORAGE BOUNDARY

Inspect the existing storage architecture and explicitly categorize:

### Account/vault state

Things that belong to the encrypted notebook and account.

### Device/application preferences

Things such as:

- typography settings,
- theme,
- update snooze,
- trusted link domains,
- UI preferences.

Do not erase unrelated application preferences when performing "Sign Out & Erase Local Data" unless the existing product architecture clearly treats them as vault-specific.

The goal is:

> erase the local vault, not factory-reset Quiet Paper.

---

# 17. LOCAL SIGN OUT UX

Update Settings.

Under the existing account section, add:

```text
Devices & Sessions                 ›
Change Account Password             ›
Sign Out                            ›
```

Keep the existing iOS Grouped Table / Bear aesthetic.

For Sign Out, use a confirmation flow.

Preferred wording:

**Sign out of this device?**

> Your local notes will stay on this device and remain available offline. Cloud synchronization will stop until you sign in again.

Actions:

```text
Cancel
Sign Out
```

The destructive action is account/session related but NOT data destructive.

Do not use wording that implies local data deletion.

---

# 18. SIGN OUT & ERASE LOCAL DATA UX

Make this available either from the Devices screen/current-device detail or an appropriately placed account-security action.

Use stronger warning language:

**Sign out & erase local data?**

> This will remove the local Quiet Paper vault from this device, including locally stored encrypted notes and attachments. This cannot be undone.

Where relevant, warn about unsynced changes:

> You have 3 local changes that have not been synchronized.

Never lie about the state.

If the app can reliably determine there are unsynced changes, display the real count.

If the repository's current sync state cannot guarantee an exact count, do not invent one. Use safer wording.

Require an explicit destructive confirmation.

---

# 19. IMPORTANT UNSYNCED-DATA SAFETY

Before allowing:

**Sign Out & Erase Local Data**

inspect the actual sync queue/state.

If unsynced mutations exist:

Show an explicit warning.

For example:

> Some changes on this device have not reached the cloud. Erasing local data will permanently remove those local changes.

Do not allow the user to accidentally believe the cloud already contains those changes.

Do not automatically perform a network sync when the user is explicitly offline.

Do not block destructive erase forever because the network is unavailable.

The user must be able to consciously choose data destruction.

---

# 20. DEVICES & SESSIONS SCREEN

Create a dedicated screen.

Use the existing Settings design language.

Top:

```text
DEVICES & SESSIONS

Your account is signed in on 3 devices.
```

Then grouped device rows.

Example conceptual layout:

```text
Pixel 9 Pro
Android · Quiet Paper 1.5.5
Active  now
This device

MacBook Pro
macOS · Quiet Paper 1.5.5
Active 2 hours ago

iPad Pro
iPadOS · Quiet Paper 1.4.9
Active 12 days ago
```

Do NOT show:

- encryption status;
- online/offline state;
- encryption key information.

Do show:

- "This device";
- last active;
- platform;
- app version;
- device model/name.

Use relative time formatting consistent with the application's existing utilities.

---

# 21. DEVICE DETAIL SCREEN / SHEET

Tapping a device should expose useful details.

For example:

```text
< Devices & Sessions

My Phone

THIS DEVICE

Android 16
Quiet Paper 1.5.5

First signed in
Sep 12, 2026

Last active
Just now

DEVICE ID
••••A91F
```

For non-current devices provide:

```text
Sign Out
```

For current device:

```text
Sign Out
Sign Out & Erase Local Data
```

Do not display full internal device identifiers.

Show only a short suffix if needed for diagnostics.

---

# 22. “THIS DEVICE” UX

Current device should visually stand out subtly.

Example:

```text
My Phone                         This device
Android · 1.5.5
Active now
```

Do not add a loud badge.

Do not use green “online” dots.

Do not introduce visually noisy security dashboards.

Keep Quiet Paper quiet.

---

# 23. SIGN OUT ALL OTHER DEVICES UI

At the bottom of the device list:

```text
Sign Out All Other Devices
```

Use destructive styling consistent with the current Settings design.

Confirmation:

**Sign out all other devices?**

> This will sign out Quiet Paper from every other device connected to your account. This device will remain signed in.

Then execute the real backend request.

On success:

> Signed out of 2 other devices.

Do not claim an arbitrary count.

Use the actual backend result.

---

# 24. EMPTY / ERROR / LOADING STATES

Implement real states.

### Loading

Use the existing Quiet Paper loading language/components.

### Empty

If this is technically possible, show:

> No other devices are currently signed in.

### Network/API failure

Use existing error handling conventions.

Do not show raw JSON, stack traces, HTML, SQLite errors, or server internals.

### Signed-out state while opening devices

Require authentication.

Do not use stale cached device list as if it were authoritative.

---

# 25. OFFLINE BEHAVIOR

Quiet Paper is offline-first.

For the Devices & Sessions screen:

- local notes remain fully usable offline;
- device management requires network connectivity;
- if the user opens Devices & Sessions while offline, show a calm explanatory state;
- do not pretend that cached data is authoritative;
- do not show fake device/session changes.

Example:

> Device management requires an internet connection.

The user must still be able to edit/decrypt local notes normally while signed out/offline.

---

# 26. ACCOUNT RE-SIGN-IN AFTER LOCAL SIGN OUT

This is a critical regression area.

Scenario:

1. User signs in.
2. Notes sync locally.
3. User signs out.
4. User opens local note.
5. Note remains decryptable.
6. User edits note while signed out/offline.
7. User signs back into the SAME account.
8. Local vault remains intact.
9. Sync resumes.
10. Local edits are correctly reconciled according to existing sync/conflict semantics.

Do not wipe the database simply because authentication state changed.

Do not create a new local vault every time a Firebase session changes.

Do not lose the existing device identity.

---

# 27. ACCOUNT SWITCHING

Audit whether the current application supports signing into a different Quiet Paper account on the same device.

If it does:

Do NOT allow account A's local encrypted vault to silently appear under account B.

Define a safe transition based on actual repository architecture.

At minimum:

- identify whether the local vault is account-bound;
- ensure device/account association is explicit;
- do not sync one account's local changes into another account;
- do not overwrite local encrypted data silently.

If the repository currently does not properly support multiple-account local-vault switching, do not invent a fragile solution. Implement the safest supported behavior and document the limitation in code/comments/tests.

---

# 28. SYNC DEVICE CHECKPOINTS

Preserve existing synchronization semantics.

The existing backend uses active device checkpoints for garbage-collection safe boundaries.

Do NOT break:

- `last_acknowledged_revision`;
- safe sync boundary calculations;
- stale-device expiration;
- cursor expiration handling;
- `SYNC_CURSOR_EXPIRED`;
- tombstone synchronization;
- note version retention.

When a device is revoked, make sure it is no longer treated as an active participant where the existing architecture requires that.

But do not accidentally delete historical sync state immediately if the repository's GC design expects controlled cleanup.

Respect the existing >90-day expiration and safe-boundary model.

---

# 29. DEVICE REVOCATION VS GC

Device revocation is an authentication/session operation.

It is NOT equivalent to:

- deleting the device's notes;
- deleting note history;
- deleting sync history immediately;
- deleting cloud attachments;
- deleting the account.

Keep these systems separate.

The existing storage lifecycle / garbage collector must continue to function normally.

---

# 30. API AUTHORIZATION

Every device endpoint must use the existing Firebase authentication middleware.

Do not trust:

- user ID from request body;
- email from request body;
- arbitrary device owner ID;
- client-provided Firebase UID.

Derive the authenticated user from the verified Firebase token using existing middleware.

Do not allow device enumeration by another user.

---

# 31. INPUT VALIDATION

Use the repository's existing Zod validation layer.

Validate:

- device ID;
- device name;
- platform;
- model;
- OS version;
- app version where client registration sends them.

Apply reasonable maximum lengths.

Reject malformed values.

Do not put arbitrary client strings directly into SQL statements.

Use parameterized database queries consistent with the existing code.

---

# 32. RATE LIMITING / ABUSE CONSIDERATIONS

Follow existing repository patterns if rate limiting exists.

At minimum ensure:

- device list cannot enumerate another user;
- revoke operations require authentication;
- repeated revoke calls are idempotent;
- rename operations cannot create unbounded data;
- device registration cannot create unlimited duplicate devices for one installation.

Do not introduce a new dependency just for speculative rate limiting unless the project already has an appropriate mechanism.

---

# 33. DATABASE MIGRATION

Create a real migration.

Requirements:

- forwards migration;
- correct indexes;
- safe handling for existing installations;
- no destructive recreation of existing tables;
- compatible with current schema version;
- updated migration runner;
- tests covering upgrade behavior.

Do not simply modify the current production migration as though no users exist.

---

# 34. CLIENT ARCHITECTURE

Follow existing feature architecture.

Likely structure:

```text
lib/features/devices/
    domain/
    application/
    presentation/
```

But use actual repository conventions if a better existing pattern exists.

Potential pieces:

```text
device_model.dart
devices_repository.dart
devices_provider.dart
devices_screen.dart
device_detail_screen.dart / device_detail_sheet.dart
```

Names are suggestions only.

Do not duplicate `SyncApiClient` functionality unnecessarily.

Prefer extending the existing API abstraction.

---

# 35. API CLIENT

Extend the real existing `SyncApiClient` / HTTP client.

Provide production methods equivalent to:

```dart
Future<List<Device>> getDevices();

Future<Device> renameDevice(
  String deviceId,
  String deviceName,
);

Future<void> revokeDevice(
  String deviceId,
);

Future<int> revokeOtherDevices();
```

Use actual HTTP requests.

Use existing authentication/token-refresh behavior.

Preserve the existing 401 retry mechanism.

Handle structured `DEVICE_REVOKED` separately.

Do not create an in-memory fake implementation.

---

# 36. AUTH SESSION REFACTOR

Refactor authentication so these responsibilities are separate:

```text
clearAuthSession()
```

and:

```text
clearLocalVaultKeys()
```

and:

```text
eraseLocalVault()
```

Do not use ambiguous methods such as:

```text
logoutAndClearEverything()
```

for every scenario.

The code should make destructive behavior difficult to invoke accidentally.

Use strongly named APIs.

---

# 37. SECURE STORAGE

Review exactly what is currently persisted in `FlutterSecureStorage`.

Separate:

### Session material

Examples:

- Firebase auth session;
- refresh token;
- ID token metadata.

### Vault/decryption material

Examples:

- persisted master key;
- wrapped key state;
- encryption key metadata needed for local unlock.

Normal sign out should clear the former but retain the latter.

Local-vault erase should clear both where appropriate.

Do not log sensitive secure-storage values.

Do not log keys.

Do not expose keys in exceptions.

---

# 38. MASTER KEY LIFECYCLE

Do not create duplicate master-key caches.

Do not change encryption primitives.

Do not re-encrypt notes.

Do not change:

- Argon2id configuration;
- XChaCha20-Poly1305;
- encrypted note format;
- attachment encryption;
- document encryption;
- recovery-key semantics.

This task is about session/device lifecycle, not redesigning cryptography.

---

# 39. ATTACHMENT / DOCUMENT REQUIREMENT

A particularly important acceptance criterion:

After normal Sign Out:

- an existing encrypted image attachment stored locally must still open;
- an existing encrypted scanned document stored locally must still open;
- OCR/search behavior requiring the local master key should continue to work where existing architecture permits;
- notes remain readable/decryptable offline.

Do not solve this by copying plaintext into another storage area.

The content must remain encrypted at rest according to existing architecture.

---

# 40. REMOTE SIGN-OUT + LOCAL DATA

Another acceptance criterion:

Device A is signed in.

Device B remotely revokes Device A.

Device A is then disconnected from cloud authentication.

Device A's local vault must remain.

Device A must not be able to sync until re-authenticated.

Device A must not lose locally stored encrypted attachments.

Device A must not lose unsynced local notes merely because the session was remotely revoked.

---

# 41. TESTING — REQUIRED

Do not stop after implementing the UI.

Add/update production tests.

### Backend tests

Cover at minimum:

1. authenticated device registration;
2. idempotent device registration;
3. device listing;
4. authorization isolation;
5. device rename;
6. rename validation;
7. revoke device;
8. revoke-others;
9. current device excluded from revoke-others;
10. revoked device rejected;
11. revoked device cannot sync;
12. already-revoked device operations remain safe/idempotent;
13. device checkpoint fields remain correct;
14. database migration.

### Flutter tests

Cover at minimum:

1. device model serialization;
2. API client request/response parsing;
3. device list rendering;
4. current-device indicator;
5. device detail rendering;
6. relative timestamp display;
7. rename flow;
8. revoke confirmation;
9. revoke-others confirmation;
10. empty state;
11. network error state;
12. signed-out state;
13. normal sign out preserves local database;
14. normal sign out preserves master key;
15. normal sign out allows local decryption;
16. sign-out then sign-in resumes sync;
17. sign-out & erase removes local vault/key material;
18. remote revocation preserves local vault;
19. remote revocation stops sync;
20. unsynced local data survives session revocation.

### Integration/regression tests

Create a realistic lifecycle test:

```text
login
→ sync
→ close/reopen
→ sign out
→ open note
→ open encrypted attachment
→ modify note offline
→ sign back in
→ sync
→ verify data integrity
```

And:

```text
device A login
device B login
device B revokes A
A receives DEVICE_REVOKED
A retains local data
A cannot sync
A signs back in
A resumes sync
```

Do not assert only UI labels. Verify actual state transitions.

---

# 42. SECURITY REGRESSION TEST

Add an explicit regression test proving:

> Ordinary logout must NOT call local-vault destruction.

This is important enough that the test should make the intended contract obvious.

For example, architecturally test:

```text
signOut()
```

clears authenticated session but does not clear master key.

And:

```text
eraseLocalVault()
```

does clear master key.

---

# 43. NO PLAINTEXT REGRESSION

Do not introduce any plaintext server-side device payload containing:

- note content;
- note titles;
- note bodies;
- tags;
- attachment contents;
- master keys.

Device/session APIs are metadata/security APIs only.

The zero-knowledge guarantee must remain unchanged.

---

# 44. UI DESIGN RULES

Use existing:

- `AppColors`;
- `AppTypography`;
- `AppSpacing`;
- `AppRadii`;
- `_SettingsGroup`;
- `_SettingsRow`;
- `QuietButton`;
- `QuietIconButton`;
- existing confirmation dialogs/sheets where appropriate.

Do not introduce generic Material cards if the existing Settings architecture has better native components.

Do not create gratuitous visual hierarchy.

Do not add:

- online dots;
- encryption badges;
- security-score dashboards;
- noisy gradients;
- large illustrations;
- unnecessary cards.

Keep it editorial and quiet.

---

# 45. ACCESSIBILITY

All device actions must be accessible.

Provide:

- semantic labels;
- readable text;
- sufficient touch target size;
- meaningful button labels;
- confirmation dialog semantics;
- screen-reader-accessible current-device labeling.

Do not encode meaning only by color.

---

# 46. RESPONSIVENESS

The app supports tablets / split-view layouts.

The Devices & Sessions screen must work cleanly on:

- narrow phones;
- large phones;
- portrait tablets;
- landscape tablets;
- desktop layouts supported by the app.

Respect existing maximum-width conventions.

Avoid intrinsic-width overflow in action rows.

Use the repository's established responsive patterns.

---

# 47. ERROR HANDLING

Never surface:

```text
SqliteException(...)
FormatException(...)
StateError(...)
Axios(...)
HTML response bodies
raw Firebase errors
stack traces
```

directly to the user.

Use existing error-cleaning conventions.

Errors should distinguish where useful:

- unable to load devices;
- unable to rename device;
- unable to revoke device;
- session expired;
- device revoked;
- offline/network unavailable.

Do not create misleading “success” states before the backend operation actually succeeds.

---

# 48. LOGGING

Add useful structured diagnostic logging where appropriate.

Never log:

- Firebase tokens;
- refresh tokens;
- master keys;
- passwords;
- recovery keys;
- encrypted key material;
- plaintext note content.

Device ID logging, if needed for debugging, should be minimized/redacted according to existing privacy conventions.

---

# 49. PERFORMANCE

Device list operations should be lightweight.

Do not fetch note data.

Do not initialize the full notebook unnecessarily just to render Devices & Sessions.

Do not cause a full sync every time the screen opens.

Use existing caching/reactive patterns where appropriate, but do not show stale cached device data as authoritative after a failed refresh.

---

# 50. DATA CONSISTENCY

When renaming or revoking a device:

- update backend;
- update local UI state only after confirmed success;
- handle retries safely;
- avoid duplicate snackbar events;
- avoid race conditions from rapid taps.

Disable action buttons while an operation is pending.

Use the project's existing loading button conventions.

---

# 51. CURRENT DEVICE REGISTRATION AFTER UPDATE

An app update must not create a second device record.

A user should see:

```text
My Phone
Quiet Paper 1.5.6
```

rather than:

```text
My Phone
Quiet Paper 1.5.6

My Phone
Quiet Paper 1.5.5
```

The stable installation/device ID is the identity.

App version metadata is mutable metadata.

---

# 52. DEVICE LIST EXAMPLE

The final UI should conceptually look like:

```text
DEVICES & SESSIONS

3 devices

┌─────────────────────────────────────┐
│ My Phone                    This device
│ Android · Quiet Paper 1.5.5         │
│ Active now                         › │
├─────────────────────────────────────┤
│ Work Laptop                          │
│ macOS · Quiet Paper 1.5.5            │
│ Active 2 hours ago                 › │
├─────────────────────────────────────┤
│ iPad                                 │
│ iPadOS · Quiet Paper 1.4.9           │
│ Active 12 days ago                 › │
└─────────────────────────────────────┘

Sign Out All Other Devices
```

This is a conceptual target, not permission to hardcode these devices.

Every displayed value must come from the real backend/device state.

---

# 53. DO NOT IMPLEMENT

Do NOT implement any of the following in this task unless the existing architecture absolutely requires it:

- encryption-status indicators;
- online/offline indicators;
- passkeys;
- 2FA;
- login-location tracking;
- IP-address display;
- browser fingerprinting;
- security score;
- device geolocation;
- email notifications;
- push notifications;
- analytics dashboards;
- admin-facing device UI changes unrelated to this feature;
- fake/demo devices;
- fake timestamps;
- mock network requests in production code.

---

# 54. DOCUMENTATION

Update the engineering handoff/documentation with the new architecture.

Document:

1. device registration;
2. device identity;
3. device metadata;
4. device revocation;
5. revoke-all-other-devices;
6. normal sign-out semantics;
7. sign-out-and-erase semantics;
8. remote revocation behavior;
9. local-vault preservation;
10. relationship between device sessions and sync checkpoints.

Explicitly state:

> Normal sign out does not destroy the local encryption/decryption key material.

And:

> Local vault destruction is an explicit destructive operation.

---

# 55. CODE QUALITY REQUIREMENTS

Production-ready means:

- no TODO placeholders;
- no dead code;
- no unreachable branches;
- no commented-out alternative implementation;
- no unnecessary duplication;
- no hardcoded test data in production;
- no swallowed exceptions;
- no silent failure;
- no arbitrary delays;
- no fake loading;
- no simulated API responses;
- no temporary shortcuts;
- no bypassing existing validation;
- no disabling tests merely to make CI pass.

Follow existing Dart formatting/lint rules and TypeScript conventions.

---

# 56. FINAL VALIDATION

After implementation, run the repository's actual verification commands.

At minimum:

```bash
flutter analyze
flutter test

cd backend
npm test
npm run build
```

Also run:

- relevant migration tests;
- device-specific tests;
- auth lifecycle tests;
- sync tests;
- any integration tests available.

Fix all resulting issues.

Do not report “done” while tests are failing.

---

# 57. FINAL ACCEPTANCE CRITERIA

The implementation is complete only when all of the following are true:

### Devices

- User can open Settings → Devices & Sessions.
- Real devices are listed.
- Current device is identified.
- Device metadata is real.
- Device can be renamed.
- A non-current device can be revoked.
- All other devices can be revoked.
- Backend enforces ownership.
- Revoked devices cannot sync.
- Device registration is idempotent.

### Normal Sign Out

- Firebase/account session is removed.
- Local SQLite vault remains.
- Local encrypted notes remain.
- Local encrypted attachments remain.
- Local encrypted documents remain.
- Master/decryption keys remain.
- Local notes remain decryptable offline.
- Sync stops.
- Re-sign-in resumes sync.

### Sign Out & Erase

- Account session removed.
- Local vault removed.
- Local encrypted content removed.
- Local key material removed.
- Sync state cleared appropriately.
- Unsynced local data warning appears when detectable.
- Operation requires explicit destructive confirmation.

### Remote Revocation

- Device can be revoked from another device.
- Revoked device receives a dedicated revoked state.
- Sync stops.
- Local vault remains.
- Local key material remains.
- Local notes remain accessible offline.
- Re-sign-in reconnects safely.

### Security

- No encryption status shown in UI.
- No online status shown in UI.
- No plaintext content reaches device-management APIs/backend.
- No secrets are logged.
- No cross-user device access is possible.

### Existing functionality

- Existing sync remains functional.
- Existing GC/safe sync boundary behavior remains functional.
- Existing auth persistence behavior remains functional.
- App updates do not duplicate device records.
- Existing local backup/restore continues to work.
- Existing attachment/document/OCR behavior continues to work.
- Existing Settings styling remains consistent.

---

# 58. IMPLEMENTATION APPROACH

Work incrementally but finish the entire feature.

Recommended sequence:

1. Audit existing code.
2. Formalize session-vs-vault ownership.
3. Refactor logout/key-clearing semantics.
4. Add database migration/extensions for device metadata/revocation.
5. Add backend device APIs.
6. Integrate device registration with existing sync/auth lifecycle.
7. Add client API models/repository/providers.
8. Implement Devices & Sessions UI.
9. Implement rename/revoke/revoke-others.
10. Implement explicit local-vault erase path.
11. Implement remote-revocation handling.
12. Add comprehensive tests.
13. Run the full validation suite.
14. Update `HANDOFF(5).md`.

Do not stop at step 8 just because the UI is visible.

This task is complete only when the complete client/backend/auth/database lifecycle works end-to-end.

---

# 59. IMPORTANT AGENT BEHAVIOR

You are an implementation agent operating on a real repository.

Therefore:

- inspect before modifying;
- preserve existing architecture;
- make real changes;
- run tests;
- fix failures;
- do not fabricate missing functionality;
- do not leave a partial implementation;
- do not replace production dependencies with mocks;
- do not merely describe what should be done;
- actually implement it.

When something in the existing code conflicts with this specification, inspect the implementation and choose the smallest safe architectural change that satisfies the requirement without compromising the existing zero-knowledge, offline-first, multi-device synchronization model.

At the end, provide a concise implementation summary containing:

- files changed;
- database migration added;
- backend endpoints added/changed;
- auth/logout lifecycle changes;
- UI screens/actions added;
- tests added/updated;
- verification commands and results;
- any genuine architectural limitation that could not safely be resolved.

Do not claim tests passed unless they actually passed.