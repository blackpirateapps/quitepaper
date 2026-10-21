# Quiet Paper — Flutter Cloud Storage, Free/Premium Plan & Upload Quota UX

You are working directly inside the existing **Quiet Paper** Flutter repository.

The backend storage quota and Premium entitlement system has already been implemented.

Your task is to implement the **complete production-ready Flutter client experience** for that backend functionality.

This is NOT a prototype, mockup, placeholder, wireframe, pseudocode exercise, or partial implementation.

You must inspect the existing Flutter codebase before modifying it and integrate the feature into the current architecture, Riverpod state management, API client, sync engine, attachment/document services, Settings UI, typography, theme system, error handling, and testing conventions.

Do not create parallel infrastructure when an existing subsystem already provides the required capability.

---

# 1. Backend Contract

The backend now provides these account/storage rules:

## Free

- Cloud storage limit: **1 GB**
- Maximum individual file: **10 MB**

## Premium

- Cloud storage limit: **10 GB**
- Maximum individual file: **10 MB**

The 10 MB individual file limit applies to both plans.

The cloud quota applies to all cloud-backed encrypted files:

- images
- PDFs
- scanned documents
- imported PDFs
- generic attachments
- other supported cloud-backed binary resources

Local/offline storage is not subject to the cloud quota.

Do not reimplement these limits independently in multiple Flutter files.

The Flutter app should consume the backend's authoritative account/storage data.

---

# 2. Critical Product Principle

Quiet Paper is offline-first.

The cloud quota must NEVER prevent a user from continuing to work locally.

If cloud storage is full:

- the user can continue creating/editing notes
- the user can attach files locally
- files remain encrypted locally
- the attachment/document can remain pending for cloud synchronization
- sync/upload should retry when storage becomes available

Do not delete local content because cloud quota is exhausted.

Do not block note creation because cloud storage is full.

Do not turn a cloud quota condition into a generic fatal error.

---

# 3. IMPORTANT: New Cloud Storage Page

Do NOT expand or repurpose the existing **Storage & Cleanup** page.

Create a **new dedicated Cloud Storage page**.

The existing Storage & Cleanup system must remain intact.

The current codebase already contains storage-management functionality for:

- storage profiling
- cleanup
- attached assets
- orphaned assets
- garbage collection

and it already integrates with Settings. Preserve that functionality.

The new page should answer a different question:

> "How much cloud storage do I have, what plan am I on, and what is using my storage?"

The existing Storage & Cleanup page should continue answering:

> "What local/cloud storage resources exist and what can I clean up?"

Do not merge these experiences.

---

# 4. New Navigation / Settings Entry

Add a dedicated Settings row:

```text
Cloud Storage
342 MB of 1 GB used
```

or:

```text
Cloud Storage
2.4 GB of 10 GB used
```

This row should navigate to the new Cloud Storage page.

The row should fit the existing iOS Grouped Table / Bear-inspired Settings design.

Do not remove or replace the existing:

```text
Storage & Cleanup
```

row.

The user should see both as distinct concepts.

Suggested ordering:

```text
STORAGE & ATTACHMENTS

Cloud Storage                         ›
342 MB of 1 GB used

Storage & Cleanup                     ›
Manage local/cloud storage

Attached Assets                       ›
Browse attached files
```

Adapt the exact wording to existing Settings terminology after inspecting the repository.

---

# 5. Cloud Storage Page

Create a dedicated screen, using the repository's established screen conventions.

A suggested logical structure:

```text
Cloud Storage

342 MB
of 1 GB used

████████░░░░░░░░░░░░

658 MB remaining

Free Plan
```

Then:

```text
STORAGE

Images                         284 MB
Documents                       42 MB
Other files                     16 MB
────────────────────────────────────
Total                          342 MB
```

Then:

```text
FREE PLAN

1 GB encrypted cloud storage

Upgrade to Premium →
```

For Premium:

```text
Cloud Storage

2.4 GB
of 10 GB used

████░░░░░░░░░░░░░░░░░░

7.6 GB remaining

Premium
```

Do NOT blindly copy these exact values; they are examples only.

Use the real backend data.

---

# 6. Dedicated Domain Model

Introduce or extend an appropriate storage domain model.

Prefer a small immutable model such as:

```dart
enum StoragePlan {
  free,
  premium,
}

class StorageUsage {
  final StoragePlan plan;
  final int usedBytes;
  final int reservedBytes;
  final int limitBytes;

  int get remainingBytes;
  double get usageFraction;
  bool get isNearQuota;
  bool get isOverQuota;
}
```

Adapt this to existing repository architecture.

Do not duplicate:

```text
1 GB
10 GB
10 MB
```

as UI constants.

The backend remains authoritative.

---

# 7. API Integration

The backend exposes an authenticated storage-profile endpoint.

Inspect the actual backend contract implemented in the repository and integrate with that exact endpoint and JSON response structure.

Do not guess the endpoint or response shape.

Add the API call to the existing:

```text
lib/core/sync/sync_api_client.dart
```

or the appropriate existing API abstraction.

Do not create a second HTTP client.

Reuse:

- existing authentication
- token refresh
- base URL handling
- error parsing
- retry behavior
- existing response conventions

The project already has centralized automatic 401 handling and token refresh in `HttpSyncApiClient`. Preserve that pattern.

---

# 8. Riverpod State

Use the repository's existing Riverpod architecture.

Create or extend a provider responsible for cloud storage account state.

Conceptually:

```text
storageUsageProvider
```

or an appropriately named provider after inspecting the existing code.

It should support:

```text
loading
data
error
```

states.

Do not have every widget make its own API request.

The provider should be the single Flutter-side source of truth for current server-reported storage state.

---

# 9. Storage State Refresh Policy

Do not blindly make API calls every time a widget rebuilds.

Refresh storage information at sensible lifecycle boundaries.

At minimum consider:

- after sign-in
- after initial authenticated app startup
- when the Cloud Storage page opens
- after successful upload confirmation
- after successful cloud deletion
- after meaningful sync completion
- after app resumes from background when appropriate
- user pull-to-refresh

Use the existing sync lifecycle and provider architecture where possible.

Avoid unnecessary network traffic.

---

# 10. Stale/Offline Storage State

Quiet Paper is offline-first.

Storage information comes from the server, so the app should distinguish between:

```text
current server state
```

and:

```text
last known state
```

When offline, continue showing the last known storage information where appropriate.

For example:

```text
342 MB of 1 GB used
Last updated 18 min ago
```

Do not display stale data as though it was just fetched.

Do not block the entire Storage page because the network is unavailable if a previous successful state exists.

If no server state has ever been fetched:

```text
Cloud storage
Unable to load storage information while offline.
```

Use the repository's existing error/offline UI conventions.

---

# 11. Storage Formatting

Create/reuse a central byte-size formatting utility.

The whole app should use consistent formatting.

Expected behavior includes:

```text
0 B
8 KB
842 KB
1.2 MB
842 MB
1.4 GB
```

Avoid showing excessive precision.

Do not scatter ad-hoc byte-formatting logic throughout widgets.

Use the backend/product unit convention consistently.

The current backend uses decimal units:

```text
1 MB = 1,000,000 bytes
1 GB = 1,000,000,000 bytes
```

The UI should represent the same values clearly.

---

# 12. Storage Usage Progress Indicator

Create a reusable storage usage visualization.

It should support:

### Normal

```text
342 MB / 1 GB
```

### Near quota

```text
824 MB / 1 GB
```

### Full

```text
1 GB / 1 GB
```

### Over quota

```text
1.3 GB / 1 GB
```

Do not allow an over-quota value to produce an invalid Flutter progress value.

Clamp the visual progress to `[0, 1]`.

The textual state must still communicate the actual overage.

---

# 13. Near-Quota State

Use a consistent threshold.

Prefer the same threshold used by the backend/admin system if the backend exposes one.

Otherwise use:

```text
>= 80%
```

as the Flutter presentation threshold.

Near quota should subtly communicate:

```text
You're getting close to your storage limit.
```

Do not create an intrusive full-screen warning merely because someone crosses 80%.

---

# 14. Full Quota State

When:

```text
used >= limit
```

show a clear but calm state:

```text
Cloud storage is full

You've used all 1 GB available on your
Free plan.

Existing notes and files are safe.

You can free space or upgrade to Premium.
```

Actions:

```text
Manage Storage
Upgrade to Premium
```

The exact action routing must follow the current app architecture.

---

# 15. Over-Quota State

This can happen after a Premium → Free downgrade.

Example:

```text
9.2 GB used
1 GB limit
```

Show:

```text
You're over your storage limit

9.2 GB of 1 GB used

Your existing files remain safe.
New cloud uploads are paused until you
free enough space.
```

Actions:

```text
Manage Storage
```

Do NOT tell the user their files will be deleted.

Do NOT automatically delete anything.

The backend explicitly retains existing content on downgrade.

---

# 16. Plan Display

Use a restrained Premium visual treatment.

For Free:

```text
Free
```

For Premium:

```text
Premium
```

Do not add noisy marketing labels such as:

```text
PRO USER
ULTIMATE
VIP
```

Use the existing Quiet Paper aesthetic.

A small plan badge is acceptable.

---

# 17. Premium Upgrade Area

The backend entitlement already supports Premium.

Billing is NOT part of this Flutter task.

Do not implement:

- Stripe
- Google Play Billing
- App Store purchases
- subscriptions
- payment processing

However, the app should have a clean upgrade affordance.

Until the actual billing flow exists, use the repository's existing navigation strategy if a billing destination already exists.

If no billing destination exists, implement the UI architecture without inventing a fake purchase flow.

Do not show a button that pretends a payment succeeded.

Do not create mock checkout screens.

A future billing implementation should be able to plug into the existing Premium entitlement.

---

# 18. Storage Breakdown

The Cloud Storage page should display a useful breakdown where the existing backend/API data supports it.

Potential categories:

```text
Images
PDF documents
Other files
```

Each can display:

```text
count
size
```

Example:

```text
Images
23 files · 284 MB

Documents
4 files · 42 MB

Other files
7 files · 16 MB
```

Do not invent data that the API does not provide.

If the current storage profile only exposes total usage, inspect whether existing local/API data can safely support a breakdown without introducing expensive new network calls.

Do not make hundreds of API requests just to render the breakdown.

---

# 19. Relationship to Existing Storage Management

Keep these screens distinct.

## Cloud Storage

Concerned with:

- plan
- quota
- used
- remaining
- upgrade
- storage status

## Storage & Cleanup

Concerned with:

- storage profiling
- cleanup
- reclaimable space
- orphaned assets
- garbage collection
- destruction lifecycle

The existing storage management screen already includes cleanup analysis and attached/orphaned asset management.

Do not regress that screen.

---

# 20. Attachment Upload Preflight

Inspect all existing attachment/document upload flows.

Before expensive work where practical, provide client-side preflight validation.

At minimum:

```text
file size <= 10 MB
```

This is a UX optimization only.

The backend remains authoritative.

Do not trust client-side validation as a security or entitlement mechanism.

---

# 21. File Too Large Error

Create/use a typed Flutter exception for the backend's file-size error, following the existing exception architecture.

The UI should say something like:

```text
File too large

This file is 14.2 MB.
Quiet Paper supports files up to 10 MB.
```

Do not show raw API JSON.

Do not show stack traces.

Do not confuse this with quota exhaustion.

---

# 22. Storage Quota Error

Create/use a typed exception for:

```text
STORAGE_QUOTA_EXCEEDED
```

The app should be able to distinguish:

```text
file too large
```

from:

```text
not enough storage
```

and from:

```text
generic network/server failure
```

The message should use the structured backend data where available.

Example:

```text
Not enough cloud storage

You have 18 MB remaining.
This file needs 42 MB.
```

Do not fabricate sizes.

---

# 23. Upload Behavior When Cloud Quota Is Full

This is critical.

Suppose the user selects an 8 MB image while cloud storage is full.

The client should:

1. Encrypt/save locally as normal.
2. Preserve the local attachment.
3. Mark cloud synchronization appropriately.
4. Record the quota-blocked condition.
5. Avoid repeatedly hammering the backend.
6. Retry later when quota becomes available.

Do not delete the attachment.

Do not force the user to reattach it.

Do not show "attachment failed" when local attachment creation succeeded.

---

# 24. Sync State

Inspect the existing attachment/document upload states.

The generic attachment system currently has states such as:

```text
local_only
upload_pending
synced
download_pending
error
```

and local attachment metadata is persisted in SQLite.

Integrate quota failures into this lifecycle cleanly.

Prefer a dedicated retryable/quota-blocked state if the existing architecture supports extending the state enum safely.

If a richer error reason can be stored alongside an existing upload state, use that instead.

Do not make a quota-blocked item look like an unrecoverable corruption/error state.

---

# 25. Automatic Retry

When quota becomes available:

```text
blocked by quota
        ↓
storage refreshed
        ↓
upload eligible
        ↓
upload_pending
        ↓
synced
```

The user should not have to delete and re-add the file.

Use the existing sync engine rather than creating a second upload scheduler.

The repository already has a dedicated sync engine and attachment/document sync services. Preserve those boundaries.

---

# 26. Avoid Excessive Retries

Do not repeatedly retry a quota-blocked upload every few seconds.

A quota error is not a transient network failure.

The upload should resume after one of the following:

- storage state refresh
- successful deletion
- successful Premium entitlement update
- manual sync/storage refresh
- app resume
- normal sync retry lifecycle

Follow existing retry/backoff conventions for network errors.

---

# 27. Local Preflight vs Server Authority

Use local information to improve UX.

For example:

```text
remaining = 5 MB
selected file = 8 MB
```

The client can immediately surface:

```text
Not enough cloud storage.
```

But it must still call the backend when upload authorization is required.

Do not skip backend quota authorization because the client predicted that the upload should fit.

The server is authoritative.

---

# 28. Refresh After Cloud Mutations

After:

- successful upload
- successful deletion
- successful remote destruction
- sync completion

refresh or invalidate the storage provider as appropriate.

Avoid forcing an expensive full refresh if the existing architecture provides a safe local delta.

However, correctness is more important than avoiding one lightweight storage-profile request.

---

# 29. Storage Breakdown and Existing Local Data

The existing app has:

- local attachment records
- local document records
- cloud URLs
- byte sizes
- upload states

and already maintains storage-management functionality.

Do not confuse local SQLite totals with authoritative cloud usage.

The Cloud Storage page should prefer backend storage usage.

Local values can only be used for immediate UI estimates/previews where appropriate.

---

# 30. Account Settings Integration

The existing Settings account section already displays the authenticated user's email and sync status.

Preserve that.

You can enhance the subtitle or add a nearby row such as:

```text
Cloud Storage
342 MB of 1 GB used
```

Do not replace the existing email/profile row.

Do not move authentication controls unnecessarily.

---

# 31. Sign-In / Sign-Out Lifecycle

On sign-out:

- clear/invalidate server-derived storage state as appropriate
- do not accidentally clear local encrypted notes merely because storage state is cleared
- preserve the existing sign-out semantics

The project explicitly distinguishes ordinary sign-out from local vault erasure. Preserve that distinction.

On sign-in:

- fetch storage profile at an appropriate time
- do not block core offline app startup unnecessarily
- do not require cloud connectivity for local vault access

---

# 32. Auth Expiration

Reuse the current automatic 401 refresh behavior.

Do not write new token-refresh logic in storage screens or upload widgets.

The existing API client already performs one forced token refresh/retry when an authenticated endpoint receives 401.

---

# 33. Error Handling

Do not expose:

```text
FormatException
HTTP 500
SocketException
JSON parsing details
stack traces
```

directly to users.

Use the current centralized API error extraction/formatting behavior.

Typed domain exceptions should be converted to calm, useful user-facing messages.

---

# 34. Cloud Storage Page States

The page must have intentional UI for:

### Initial loading

Use existing Quiet Paper loading patterns.

### Loaded

Show full storage/plan UI.

### Offline with cached state

Show cached values and a subtle stale indicator.

### Offline without cached state

Show a useful empty state.

### Server error with cached state

Keep cached data visible and show a non-destructive refresh/error message.

### Server error without cached state

Show a retry action.

### Over quota

Show the over-quota state.

---

# 35. Pull to Refresh

The new Cloud Storage page should support pull-to-refresh where appropriate.

Do not introduce pull-to-refresh into the existing Storage & Cleanup page unless already present.

Refreshing should update:

- plan
- used bytes
- reserved bytes if exposed
- limit
- remaining bytes
- breakdown if available

---

# 36. Accessibility

The new page must support:

- semantic labels
- readable text
- sufficient touch targets
- progress indicator semantics
- screen-reader-friendly plan/status information

For example, a progress bar should expose something equivalent to:

```text
Cloud storage: 342 MB of 1 GB used
```

Do not rely only on color to communicate near/full/over quota.

---

# 37. Responsive Design

The app supports phones and tablets.

The new page must behave correctly on:

- narrow phones
- large phones
- tablets
- split-view layouts where applicable

Follow the existing Settings max-width conventions.

The existing Settings screen uses a centered max-width layout on tablets. Preserve this aesthetic.

Avoid horizontal overflow.

Use the repository's established responsive helpers.

---

# 38. Theme Support

Use:

- `AppColors`
- `AppTypography`
- `AppSpacing`
- `AppRadii`

and all current theme-family abstractions.

Do not hardcode colors.

The application supports multiple editorial theme families, so the new screen must automatically adapt.

Do not introduce a new color palette specifically for storage.

Premium styling should use existing accent/theme tokens.

---

# 39. Existing Editorial Aesthetic

The screen should feel like Quiet Paper.

Prefer:

- grouped table rows
- generous whitespace
- restrained typography
- subtle progress indicators
- minimal borders
- quiet labels
- calm upgrade affordance

Avoid:

- giant SaaS-style pricing cards
- gradients unless already part of the design system
- excessive shadows
- "LIMIT REACHED!!!"
- noisy badges
- gamification
- promotional clutter

---

# 40. Storage Usage Card

Create a reusable widget for the main storage summary.

Potential conceptual layout:

```text
Cloud Storage

342 MB
of 1 GB used

████████░░░░░░░░░░░░

658 MB remaining

Free Plan
```

Use responsive typography and avoid fixed heights that can overflow.

Do not put business logic inside this widget.

It should consume a `StorageUsage`/view model.

---

# 41. Plan Badge

Create/reuse a small plan badge.

Examples:

```text
Free
```

```text
Premium
```

Use semantic colors/tokens.

Do not encode plan values inside presentation strings everywhere.

---

# 42. Upgrade Card

For Free users, provide a subtle upgrade card/row.

For Premium users, do not show an upgrade prompt.

Potential Free content:

```text
Need more room?

Premium includes 10 GB of encrypted
cloud storage.

Upgrade to Premium →
```

This should only appear as appropriate in the product flow.

Do not create fake billing behavior.

---

# 43. Manage Storage Link

Cloud Storage should link to the existing Storage & Cleanup screen.

For example:

```text
Manage Storage                         ›
```

This is an important separation:

```text
Cloud Storage
      ↓
quota/plan information

Manage Storage
      ↓
cleanup/asset inspection
```

Do not duplicate the existing cleanup tools inside the new page.

---

# 44. File Size Information

Where users select files, subtly communicate:

```text
Maximum file size: 10 MB
```

Use this in relevant attachment/document import surfaces.

Inspect the existing attachment/document picker UI and integrate naturally.

Do not clutter every unrelated UI element with the limit.

---

# 45. Attachment Detail Size

Where attachments already display metadata, include file size where appropriate.

The existing Notes List already shows attachment metadata such as PDF page counts and image/attachment counts.

Do not unnecessarily redesign those cards.

Add size only where it naturally fits existing detail/attachment views.

---

# 46. No Cloud Quota Blocking of Local Save

This is a hard requirement.

The following must NEVER happen:

```text
Cloud quota full
        ↓
User attaches file
        ↓
Attachment discarded
```

Instead:

```text
Cloud quota full
        ↓
User attaches file
        ↓
Encrypted local file saved
        ↓
Cloud upload blocked/pending
```

The existing encrypted local attachment architecture must be preserved.

---

# 47. Sync Recovery

When cloud quota becomes available again:

- refresh storage profile
- invalidate quota-blocked upload eligibility
- let the existing sync engine process pending attachments/documents
- avoid duplicate upload jobs

If an item previously received a quota-specific error, it should not be permanently stuck.

---

# 48. Storage State and Sync State Separation

Do not make `StorageUsage` responsible for upload queue state.

Do not make `SyncEngine` responsible for rendering storage UI.

Keep the boundaries:

```text
StorageService
    ↓
plan/quota state

SyncEngine
    ↓
upload/download lifecycle

Storage UI
    ↓
presentation
```

Upload code may consume storage state/preflight helpers, but should not own the storage screen's state.

---

# 49. API Models

Use dedicated API/domain models rather than passing raw `Map<String, dynamic>` into widgets.

For example:

```text
StorageUsageResponse
StorageUsage
StorageBreakdown
```

Adapt to existing architecture.

Validate server response fields defensively.

Handle absent/null optional fields according to actual backend response semantics.

Do not crash because the backend adds an unrelated field.

---

# 50. Backend Compatibility

Inspect the exact backend implementation currently in the repository.

Do not assume the backend returns:

```text
usageFraction
remainingBytes
reservedBytes
breakdown
```

unless it actually does.

Use the real contract.

If a value can be derived safely from returned fields, derive it in the model.

Do not duplicate server-derived constants unnecessarily.

---

# 51. Storage Fraction

If backend returns:

```text
usedBytes
limitBytes
```

derive:

```dart
double get usageFraction =>
    limitBytes <= 0 ? 0 : usedBytes / limitBytes;
```

Clamp presentation values between 0 and 1.

Over-quota must remain visible through textual status even if the progress bar is visually clamped.

---

# 52. Plan Changes Propagation

The backend admin can change users between Free and Premium.

Flutter should therefore NOT cache Premium status indefinitely.

Storage profile refresh should detect:

```text
Free → Premium
```

and:

```text
Premium → Free
```

without requiring app reinstall.

After a refresh:

- plan badge updates
- storage limit updates
- upgrade affordance appears/disappears
- quota state recalculates
- pending uploads become eligible if appropriate

---

# 53. Downgrade UX

If the server reports:

```text
plan = free
usedBytes > limitBytes
```

do not treat that as a malformed API response.

It is a legitimate over-quota state.

Render it explicitly.

Example:

```text
Free Plan

9.2 GB of 1 GB used

8.2 GB over your limit

Your existing files are safe.
Delete some cloud files to resume uploads.
```

---

# 54. Storage Availability Check

Create one reusable client-side helper if needed:

```text
canUploadBytes(size)
```

It should answer based on the latest known storage state.

Possible result categories:

```text
allowed
fileTooLarge
insufficientStorage
storageStateUnknown
```

Do not reduce everything to `bool`.

A richer result makes UI behavior substantially cleaner.

---

# 55. Unknown Storage State

If the client has never fetched account storage and is offline, do not confidently claim:

```text
You have 342 MB remaining
```

unless that is locally cached from a previous successful response.

Where state is unknown, let the backend determine upload authorization when connectivity exists.

Local work may continue.

---

# 56. Local Cached Storage Profile

Use appropriate lightweight local persistence if the current architecture supports it.

Do not introduce persistent storage solely for this feature if a simple in-memory cache is sufficient.

If persisting the last-known profile:

- store only non-sensitive metadata
- never store auth tokens in the new feature
- never store encryption keys
- invalidate appropriately on sign-out/account change

Follow existing application persistence patterns.

---

# 57. Multiple Accounts / Account Switching

Inspect whether the application supports account switching.

If it does, ensure storage state cannot leak from one account to another.

Example:

```text
Alice → 342 MB / 1 GB
sign out
Bob signs in
```

Bob must NOT briefly display Alice's storage values.

Scope storage state by authenticated account identity.

If the app only supports one active account, preserve the existing architecture but still clear/invalidate storage state on logout.

---

# 58. Device/Session Independence

Storage quota is account-level.

Do not treat it as device-level local storage.

Two devices signed into the same account should ultimately see the same cloud storage usage.

Do not store separate per-device quota calculations as authoritative state.

---

# 59. Tests — Domain

Add unit tests for:

- Free plan parsing
- Premium plan parsing
- byte formatting
- usage fraction
- exact quota
- near quota
- over quota
- remaining bytes
- zero bytes
- large byte values
- malformed/defensive API fields where appropriate

---

# 60. Tests — API

Add tests for:

- successful storage profile fetch
- authentication failure
- token-refresh retry through existing API infrastructure
- malformed server response
- server error
- offline/network failure mapping
- plan change detection
- over-quota parsing

Do not duplicate the existing token-refresh tests if the API client already covers them; add only the storage-specific assertions needed.

---

# 61. Tests — UI

Add widget tests for:

### Cloud Storage page

- loading
- loaded Free state
- loaded Premium state
- near-quota state
- full state
- over-quota state
- offline cached state
- error with cached state
- error without cached state
- pull-to-refresh

### Settings

- Cloud Storage row appears
- correct subtitle
- navigation works
- existing Storage & Cleanup row remains

### Upgrade

- Free shows upgrade affordance
- Premium does not show upgrade affordance

### Manage Storage

- navigation reaches the existing Storage & Cleanup page
- existing storage management functionality remains intact

---

# 62. Tests — Upload UX

Add tests for:

- <=10 MB file preflight allowed
- >10 MB file preflight rejected
- quota insufficient state
- quota-exceeded backend error mapping
- file-too-large backend error mapping
- local attachment survives quota block
- quota-blocked state remains retryable
- storage refresh can make a previously blocked upload eligible

Use the existing attachment/document test infrastructure.

---

# 63. Tests — Sync

Verify that:

```text
quota exceeded
```

does not cause:

```text
local attachment deletion
```

and does not irreversibly corrupt the upload queue.

Verify that after quota becomes available:

```text
blocked upload
    ↓
pending
    ↓
synced
```

works through the existing sync engine.

---

# 64. Performance

Do not:

- fetch storage repeatedly during rebuilds
- perform Cloudinary calls from the Storage screen
- scan the entire local database on every storage-page render
- decrypt attachments to calculate storage UI
- perform large synchronous computations on the UI thread

The backend is authoritative for cloud usage.

The existing app has significant performance-sensitive behavior around large notes and storage, so avoid introducing new synchronous scans into the writing loop.

---

# 65. No Encryption Changes

Do NOT change:

- AttachmentCrypto
- Document encryption
- Master Key
- XChaCha20-Poly1305
- AAD
- encrypted file formats
- key management

The existing architecture encrypts attachment data before cloud persistence.

This feature is about entitlement/quota UX only.

---

# 66. No Cloudinary Changes

Do not modify Cloudinary upload architecture unless a client compatibility adjustment is strictly required by the implemented backend contract.

The existing client already uploads encrypted payloads directly to Cloudinary after backend authorization.

Do not proxy files through Flutter's backend.

Do not send plaintext files to the backend.

---

# 67. Existing Storage Management Must Continue Working

Run all existing storage-management tests.

The existing storage layer currently includes:

- storage profile functionality
- GC
- reference management
- attached asset management
- orphan handling

and associated tests.

Do not accidentally merge new account quota state into those existing cleanup models unless the repository architecture clearly calls for it.

---

# 68. Error Copy

Use calm language.

### File too large

```text
File too large

This file is 14.2 MB.
Quiet Paper supports files up to 10 MB.
```

### Not enough storage

```text
Not enough cloud storage

You have 18 MB remaining.
This file needs 42 MB.
```

### Cloud storage full

```text
Cloud storage is full

You've used all the storage available
on your current plan.

Your existing files are safe.
```

### Over quota

```text
You're over your storage limit

Your existing files are safe.
Free some storage before adding
new files to the cloud.
```

Adapt wording to existing Quiet Paper error-message conventions.

Do not use these as hardcoded copy if the backend provides more precise values.

---

# 69. Snackbar vs Sheet vs Page

Use the appropriate surface based on seriousness.

### File >10 MB

A concise dialog/sheet or inline import error is sufficient.

### Quota unexpectedly reached during upload

Use the existing upload error presentation, potentially followed by:

```text
Manage Storage
Upgrade
```

### Full Cloud Storage page

Show the complete account-level explanation there.

Do not use a giant modal every time the quota is hit.

---

# 70. Navigation

Inspect the existing routing/navigation implementation.

Add the new page according to the existing architecture.

Do not introduce a competing router.

Support:

- phone
- tablet
- split-view where applicable

Respect existing editor/tablet navigator behavior.

---

# 71. Existing Settings Aesthetic

The current Settings redesign uses:

- grouped containers
- flush rows
- subtle dividers
- Cupertino-style controls
- centered tablet max width
- editorial typography

Preserve the same design language.

The Cloud Storage page should feel like it belongs in that system.

---

# 72. No Mock Premium State

Do not add a local toggle saying:

```text
Premium = true
```

for development.

The actual plan must come from the backend account storage profile.

For widget tests, construct test models/providers explicitly.

Do not put debug-only Premium bypasses into production code.

---

# 73. Client-Side Constants

The 10 MB file limit may be represented client-side for early validation, but it must have a single canonical definition.

For example:

```dart
static const maxUploadBytes = 10_000_000;
```

However:

- use one location
- document that backend remains authoritative
- do not duplicate it in every importer
- do not use a different value for PDF/image/generic attachments

If the backend exposes upload limits dynamically, prefer consuming that instead.

---

# 74. Future-Proofing

The architecture should support future plans without rewriting the UI.

The model should not assume:

```text
only Free and Premium forever
```

Use an enum only if it matches the backend contract and existing product model.

The UI should gracefully render plan information through a domain abstraction.

Future:

```text
Free
Premium
Pro
```

should be possible without redesigning the entire storage provider.

Do not implement Pro now.

---

# 75. Do Not Implement Billing

Again, this task is NOT:

- subscription purchase
- payment verification
- receipt validation
- App Store integration
- Google Play integration
- Stripe integration

Premium status already exists as an account entitlement.

The Flutter client only needs to display/use the current entitlement.

---

# 76. Files to Inspect Before Coding

Before editing, inspect at minimum:

```text
lib/core/sync/sync_api_client.dart
lib/core/sync/sync_models.dart
lib/core/sync/sync_engine.dart

lib/core/storage/storage_management_service.dart

lib/core/attachments/
lib/core/documents/

lib/features/settings/presentation/settings_screen.dart
lib/features/settings/presentation/storage_management_screen.dart

existing storage tests
existing sync tests
existing attachment tests
existing document tests
```

Also inspect:

- provider organization
- navigation implementation
- API exception hierarchy
- Settings grouped-row components
- theme tokens
- existing lifecycle hooks

The handoff confirms those storage and sync components already exist, so extend them deliberately rather than creating replacements.

---

# 77. Search the Repository Before Modifying

Search for:

```text
Storage Management
storageManagement
storage_management
Cloud Storage
storage/profile
upload-auth
confirm
upload_state
upload_pending
synced
local_only
AttachmentSyncService
DocumentSyncService
HttpSyncApiClient
ApiException
```

Find the actual current implementations and follow established patterns.

Do not assume filenames are unchanged from the handoff if the repository has evolved.

---

# 78. Preserve Existing APIs Where Possible

Do not unnecessarily rename existing methods/providers/classes.

If an existing storage service already has related functionality, extend it carefully or compose a new account-level service around it.

Do not break existing callers.

---

# 79. Avoid Architecture Duplication

Do NOT create:

```text
Another SyncApiClient
Another HTTP client
Another auth service
Another storage database
Another settings router
Another theme system
Another state-management framework
```

Use the existing architecture.

---

# 80. Generated Code

If the repository uses generated code:

- modify source files, not generated output
- run the correct generators afterward
- commit/update generated files only if repository conventions require them

Do not manually edit generated Riverpod/Drift/API artifacts unless the project requires it.

---

# 81. Static Analysis

At the end, run:

```bash
flutter analyze
```

It must pass with:

```text
0 errors
0 warnings
```

or the project's current clean baseline.

---

# 82. Full Flutter Test Suite

Run:

```bash
flutter test
```

Do not only run the newly added tests.

Existing project tests must continue passing.

The project already has extensive automated coverage, including storage-management and sync lifecycle tests.

---

# 83. Targeted Tests

Also run the most relevant targeted suites separately for fast diagnosis, such as:

```text
storage tests
settings tests
attachment tests
document tests
sync tests
```

Use the actual repository paths.

---

# 84. No Fake Test Success

Do not:

- skip tests
- weaken assertions merely to get green
- delete failing old tests
- alter production behavior solely to satisfy mocks
- claim success if Flutter fails to build/analyze/test

If a genuine external/environment issue prevents a test from running, report it exactly.

---

# 85. Production Verification

Before completion verify:

```text
Free account
    ↓
1 GB displayed

Premium account
    ↓
10 GB displayed

Free account
    ↓
10 MB file limit

Premium account
    ↓
10 MB file limit

Quota full
    ↓
local attachment still saved

Quota full
    ↓
upload remains retryable

Quota available
    ↓
pending upload resumes

Premium → Free
    ↓
existing files retained
    ↓
over-quota state displayed

Free → Premium
    ↓
10 GB displayed
    ↓
previously blocked uploads can resume

Offline
    ↓
last known storage shown when available
```

---

# 86. Final UX Acceptance Criteria

The feature is complete only when:

### Settings

- [ ] New Cloud Storage row exists
- [ ] Existing Storage & Cleanup remains separate
- [ ] Existing Attached Assets remains intact
- [ ] Cloud Storage row shows current plan/usage
- [ ] Navigation works on phone/tablet

### Cloud Storage screen

- [ ] Plan visible
- [ ] Used storage visible
- [ ] Storage limit visible
- [ ] Remaining storage visible
- [ ] Progress indicator visible
- [ ] Near-quota state works
- [ ] Full state works
- [ ] Over-quota state works
- [ ] Breakdown shown when supported
- [ ] Manage Storage navigation works
- [ ] Free users see upgrade affordance
- [ ] Premium users do not see unnecessary upgrade prompt
- [ ] Pull-to-refresh works
- [ ] Offline/cache behavior works

### Uploads

- [ ] 10 MB maximum is enforced client-side for UX
- [ ] Backend remains authoritative
- [ ] >10 MB errors are clearly differentiated
- [ ] Quota errors are clearly differentiated
- [ ] Local file remains safe when cloud quota blocks upload
- [ ] Quota-blocked uploads remain retryable
- [ ] Retry works after quota becomes available

### Account lifecycle

- [ ] Sign-in loads correct storage state
- [ ] Sign-out clears account-specific storage state
- [ ] Multiple-account leakage is impossible
- [ ] Premium changes propagate after refresh

### Design

- [ ] Matches Quiet Paper editorial aesthetic
- [ ] Works in all theme families
- [ ] Responsive on phones/tablets
- [ ] Accessible
- [ ] No hardcoded theme colors
- [ ] No noisy SaaS-style marketing UI

### Quality

- [ ] Existing storage-management behavior preserved
- [ ] Existing sync behavior preserved
- [ ] Existing attachment/document behavior preserved
- [ ] Tests added
- [ ] Existing tests still pass
- [ ] `flutter analyze` clean
- [ ] `flutter test` clean
- [ ] No mock/placeholder production code

---

# 87. Implementation Instructions

Do not stop after producing a design.

Actually implement the feature in the repository.

Do not merely output suggested code.

Do not leave TODOs.

Do not leave placeholder screens.

Do not create fake Premium state.

Do not invent backend fields.

Inspect the existing backend/client contract and implement against the real one.

Use the current codebase's architecture and conventions.

When an implementation choice is ambiguous, resolve it by inspecting the repository rather than asking unnecessary questions.

Do not make unrelated refactors.

Keep the change focused on the Cloud Storage/plan/quota client experience.

---

# 88. Final Deliverable

When complete, provide a concise engineering summary containing:

1. Files added
2. Files modified
3. New Cloud Storage screen architecture
4. Riverpod/provider changes
5. API client changes
6. Storage state/error model
7. Upload preflight behavior
8. Sync/quota-block behavior
9. Settings integration
10. Offline/cached behavior
11. Tests added
12. Exact commands run
13. Final `flutter analyze` result
14. Final `flutter test` result
15. Any genuine limitations or repository constraints

Do not claim a test/build passed unless you actually ran it.

The implementation must be production-ready, integrated with the existing Quiet Paper architecture, and free of mockups/placeholders in production code.