# Quiet Paper — Production Backend Storage Quota, Premium Entitlements & Admin User Management

You are working directly inside the existing **Quiet Paper** repository.

Your task is to implement a **complete, production-ready backend storage quota and Premium entitlement system**, integrated into the existing architecture and admin panel.

This is NOT a prototype, mockup, demo, pseudocode exercise, or placeholder implementation.

You must inspect the existing repository and implement the feature fully using the project's actual architecture, naming conventions, database patterns, authentication model, Cloudinary integration, admin framework, validation layer, tests, and migration system.

Do not invent parallel infrastructure when an existing subsystem already solves the problem.

---

# 1. Existing Architecture — Preserve It

Quiet Paper currently has:

- Flutter client
- TypeScript/Vercel serverless backend
- Turso/libSQL database
- Firebase Authentication
- Zod request validation
- Existing sync services
- Existing attachments/documents services
- Direct-to-Cloudinary encrypted file uploads
- Server-rendered admin panel
- Existing admin authentication/session system
- Existing admin users explorer
- Existing admin user-detail/audit page
- Existing admin storage page
- Existing garbage collection and destruction-job system

The architecture is zero-knowledge.

The backend MUST NOT decrypt user content or file contents.

The file payload flow already uses:

1. Client-side encryption
2. Backend upload authorization
3. Direct upload from client to Cloudinary
4. Backend upload confirmation
5. Turso metadata persistence

The backend remains an authentication, authorization, quota, metadata, and control plane.

Do not change the encryption model.

Do not proxy file bytes through Vercel.

Do not introduce plaintext file persistence.

Do not weaken any existing zero-knowledge guarantees.

Existing generic attachment files are encrypted client-side before cloud storage, and the current architecture supports arbitrary binary attachments in addition to images and PDFs. Preserve that behavior.

---

# 2. Business Rules

Implement exactly these backend storage rules.

## Free plan

- Cloud storage allowance: **1 GB**
- Maximum individual uploaded file: **10 MB**

## Premium plan

- Cloud storage allowance: **10 GB**
- Maximum individual uploaded file: **10 MB**

The 10 MB individual-file limit applies equally to Free and Premium.

Premium does NOT bypass the 10 MB per-file restriction.

The storage quota applies to cloud-stored encrypted files.

Local/offline device storage remains unlimited and is outside the backend cloud quota.

---

# 3. Storage Definition

The cloud storage quota is ONE unified quota per user.

The quota must include all cloud-backed binary resources belonging to a user, including:

- images
- PDFs
- scanned documents
- imported PDFs
- generic document attachments
- arbitrary binary attachments
- other existing Cloudinary-backed file resources

Do NOT create separate image, PDF, and attachment quotas.

A user has one cloud storage bucket:

```text
User Cloud Storage
├── Images
├── PDFs
├── Documents
└── Generic Attachments
```

All contribute to the same quota.

Use the existing attachment/document metadata and ownership model.

Do not create an unrelated second storage table unless the existing schema absolutely requires one.

---

# 4. Important Size Semantics

There are two different concepts:

### Upload limit

The individual file restriction is:

```text
10 MB maximum
```

The user-facing file being uploaded must not exceed this limit.

### Storage accounting

Storage consumption must be based on the actual encrypted object size that is retained in cloud storage, not merely a client-provided estimate.

The backend must not blindly trust a `byteSize` sent by the client.

Where possible, use the actual Cloudinary object metadata during confirmation.

Do not silently permit a confirmed uploaded object to exceed 10 MB.

Encryption overhead must be handled consistently.

Define and document whether the product's MB/GB units are decimal or binary, and use the same definitions everywhere.

For this implementation use:

```text
1 MB = 1,000,000 bytes
1 GB = 1,000,000,000 bytes
10 MB = 10,000,000 bytes
1 GB = 1,000,000,000 bytes
10 GB = 10,000,000,000 bytes
```

These constants must live in one authoritative backend location.

Do not duplicate magic numbers across services.

---

# 5. Plan Model

Add an explicit user plan/entitlement:

```text
free
premium
```

The backend must determine the user's storage allowance from the plan.

Do NOT make the Flutter client authoritative for Premium status.

Do NOT make the admin UI authoritative.

The backend database must be the source of truth for the user's current entitlement.

Introduce a centralized plan configuration, for example conceptually:

```ts
FREE_STORAGE_BYTES
PREMIUM_STORAGE_BYTES
MAX_FILE_SIZE_BYTES
```

Use the project's existing naming conventions.

Do not hardcode plan logic in individual routes.

---

# 6. User Database Changes

Extend the existing `users` table safely.

The implementation should provide, as appropriate to the current schema:

```text
plan
storage_used_bytes
storage_reserved_bytes
email
```

Use sensible defaults that are safe for existing users.

Expected defaults:

```text
plan = free
storage_used_bytes = 0
storage_reserved_bytes = 0
```

Email should be populated from the authenticated Firebase identity whenever possible.

Do not fabricate emails.

Do not break existing users if email is temporarily unavailable.

Determine whether the existing schema already has an email column before adding one.

If email already exists, reuse it.

---

# 7. Storage Accounting Model

Maintain a materialized storage counter.

Do NOT calculate total storage using a full `SUM(...)` over every file record on every request.

The authoritative user-level counter should be maintained transactionally.

Use:

```text
storage_used_bytes
storage_reserved_bytes
```

Conceptually:

```text
available_bytes =
    plan_storage_limit
    - storage_used_bytes
    - storage_reserved_bytes
```

The exact implementation must follow the existing database abstraction and transaction mechanisms.

---

# 8. Upload Reservations

Implement storage reservation during upload authorization.

This is required to prevent concurrent uploads from exceeding quota.

Example race that must be prevented:

```text
User has 5 MB remaining.

Upload A requests 4 MB.
Upload B requests 4 MB.

Both must NOT independently observe 5 MB remaining
and both get approved.
```

Therefore:

### During upload authorization

1. Authenticate user.
2. Load user's plan.
3. Determine storage limit.
4. Validate requested file size <= 10 MB.
5. Compute remaining capacity.
6. Verify the requested amount fits.
7. Atomically reserve the upload size.
8. Issue Cloudinary upload authorization.

### During confirmation

1. Validate reservation ownership.
2. Determine actual uploaded size.
3. Verify actual size <= 10 MB.
4. Convert the reservation into committed usage.
5. Remove the reservation.
6. Persist file metadata.

### On failed/abandoned upload

The reservation must eventually be released.

Reservations must have a mechanism for expiration/recovery.

Do not allow abandoned reservations to permanently consume quota.

Use the project's existing serverless-safe patterns.

If a reservation table is required, create it properly.

If the existing metadata schema can safely support reservations without a new table, use that instead.

Prefer the smallest robust schema change.

---

# 9. Reservation Design

If creating a reservation table, use a production-grade structure that supports:

- unique reservation ID
- user ID
- resource/attachment ID when available
- reserved byte count
- status
- creation timestamp
- expiration timestamp
- finalized timestamp where appropriate
- idempotency/reference fields when appropriate

Statuses should be explicit, such as:

```text
pending
finalized
released
expired
```

Do not create a vague boolean-only reservation model.

The implementation must be safe under retries.

---

# 10. Idempotency

Existing sync/upload operations already use idempotency concepts.

Preserve and extend the existing pattern instead of inventing a conflicting one.

Upload authorization and confirmation MUST behave correctly if:

- the same request is retried
- the network times out after Cloudinary succeeds
- the confirmation is retried
- the client sends duplicate confirmation
- the client retries after receiving an error

No duplicate storage accounting.

No double reservation.

No double usage increment.

No negative usage.

No duplicate files caused by retry behavior.

---

# 11. Existing Attachment Upload Flow

The existing architecture has:

```text
POST /api/v1/attachments/upload-auth
POST /api/v1/attachments/confirm
```

and equivalent document upload flows.

The backend currently signs Cloudinary parameters and the client uploads encrypted files directly to Cloudinary.

Extend this system.

Do NOT replace it with server-side upload proxying.

Do NOT upload raw bytes to Vercel.

Do NOT store plaintext in Turso.

The storage quota must be enforced at the authorization/control-plane stage.

The confirmation stage must finalize actual storage usage.

---

# 12. Attachments AND Documents

Inspect the repository carefully.

There are separate concepts/services for attachments and documents.

The existing document schema includes:

- byte_size
- cloud_public_id
- cloud_url
- upload_state
- deletion fields
- ownership through the user/note relationship

The backend already stores PDFs and other documents in Cloudinary while Vercel handles authorization and metadata.

The generic attachment system also stores arbitrary binary files.

Both systems MUST participate in the same per-user quota.

Do not implement quota enforcement in only one upload path.

Audit all existing cloud-upload endpoints and ensure the quota system covers every route capable of creating billable cloud storage.

Search the entire backend before modifying anything.

---

# 13. Maximum File Size

The existing code/documentation currently references a 50 MB generic attachment limit.

Replace the actual implementation with the new:

```text
10,000,000 bytes
```

Do not merely update comments.

Find the actual validation and ingestion enforcement.

The limit must be enforced in the backend independently of the client.

The client-side limit may also later mirror it, but backend validation is authoritative.

---

# 14. Quota Enforcement Error

Create a dedicated structured API error for quota exhaustion.

Use the project's existing `ApiError` conventions.

Conceptually:

```json
{
  "error": {
    "code": "STORAGE_QUOTA_EXCEEDED",
    "message": "Storage quota exceeded.",
    "details": {
      "plan": "free",
      "usedBytes": 985000000,
      "reservedBytes": 5000000,
      "limitBytes": 1000000000,
      "remainingBytes": 10000000,
      "requiredBytes": 12000000
    }
  }
}
```

Follow the repository's established response/error envelope instead of blindly copying this exact JSON if the existing API uses a different structure.

The result must still expose enough structured information for the Flutter client to show an accurate message.

---

# 15. Individual File Limit Error

Create/use a dedicated validation or API error code for an oversized file.

For example:

```text
FILE_TOO_LARGE
```

with structured data containing:

```text
maxBytes
providedBytes
```

Use the existing error conventions.

Do not return vague generic errors.

---

# 16. Deletion and Storage Reclamation

Storage must be released correctly when cloud resources are removed.

Inspect all existing deletion paths.

This includes, as applicable:

- attachment deletion
- document deletion
- permanent deletion
- trash cleanup
- remote destruction jobs
- garbage collection
- orphan cleanup
- failed upload cleanup
- replacement/update of uploaded resources

The storage accounting must not become permanently inflated.

Do NOT subtract storage twice.

If a resource has already been accounted for and later receives a deletion tombstone, make the accounting idempotent.

Your existing system has asynchronous Cloudinary/DB destruction jobs and GC behavior; integrate quota release with those lifecycle semantics rather than bypassing them.

---

# 17. Cloud Deletion Failure Semantics

Think carefully about this case:

```text
DB says file deleted
Cloudinary deletion fails
```

and the opposite:

```text
Cloudinary deletion succeeds
DB operation fails
```

Do not make storage accounting dependent on a fragile assumption that both always succeed atomically.

Inspect the existing destruction-job architecture and use its state transitions.

Storage usage should represent the resource lifecycle consistently.

If the existing architecture uses asynchronous destruction jobs, integrate quota release at the appropriate authoritative lifecycle point.

Avoid introducing a new deletion subsystem.

---

# 18. Updates/Replacements

If an existing file is replaced or re-uploaded:

```text
old size = 7 MB
new size = 9 MB
```

usage must change by:

```text
+2 MB
```

not +9 MB.

Likewise:

```text
old size = 9 MB
new size = 4 MB
```

must reduce usage by 5 MB.

Handle these deltas transactionally.

Do not permit negative usage.

---

# 19. Quota Reconciliation

Implement a safe internal/admin reconciliation mechanism.

Because materialized counters can theoretically become inconsistent after historical migrations, crashes, or old bugs, create a service that can calculate true usage from authoritative file metadata.

This should NOT be used on every request.

It should be available for:

- admin inspection
- diagnostics
- migration verification
- repair
- testing

Conceptually:

```text
recalculateUserStorageUsage(userId)
```

and optionally:

```text
reconcileUserStorageUsage(userId, dryRun)
```

If the repository already has similar reconciliation/GC infrastructure, integrate with it.

Do not silently modify counters during a normal read request.

---

# 20. Storage API

Add a normal authenticated user-facing endpoint for storage information.

Use the existing `/api/v1/...` conventions.

Conceptually:

```http
GET /api/v1/account/storage
```

Response should contain enough information for a future Flutter UI:

```json
{
  "plan": "free",
  "usedBytes": 425000000,
  "reservedBytes": 5000000,
  "limitBytes": 1000000000,
  "remainingBytes": 570000000,
  "usageFraction": 0.43
}
```

Use the project's actual response conventions.

Do not include unnecessary private/internal admin information.

---

# 21. Central Account/Entitlement Service

Create or extend a centralized backend service responsible for:

- resolving user plan
- resolving storage limit
- determining file-size limits
- determining remaining storage
- changing plan
- exposing storage profile
- possibly validating entitlements

Do not place plan logic directly inside admin views.

Do not place plan logic directly inside Cloudinary signing code if it belongs in a reusable service.

The upload subsystem should depend on a clear entitlement/quota abstraction.

---

# 22. Premium Plan Administration

The existing admin panel must allow an administrator to change a user's plan.

The admin panel already has:

```text
/admin/users
/admin/users/:id
```

and server-rendered admin views/services.

Extend the existing user-detail page.

Do NOT create a separate "Premium management" website.

---

# 23. Admin User List

The `/admin/users` page must show the user's email.

Current user exploration already supports user inspection and user metadata.

Extend it to show at least:

```text
Email
Plan
Storage Used
Storage Limit
Notes
Devices
Media/Files
```

Use the existing table and responsive layout conventions.

Do not make the IDs the main useful identity field anymore.

Email should be searchable.

Search should support:

```text
email
Firebase UID
internal user ID
```

Case-insensitive email search is expected.

---

# 24. Email Source

The user's email must come from the authoritative Firebase identity and/or be stored in the local `users` table.

Inspect the current auth/user-creation flow first.

If `users.email` already exists, reuse it.

If it does not exist, add it safely.

Keep it synchronized when user authentication/account state is refreshed.

Never guess or synthesize email addresses.

---

# 25. Admin User Detail Page

Extend the existing user inspection page.

The page should prominently show:

```text
Email
Firebase UID
Internal User ID
Plan
Storage Used
Storage Limit
Remaining Storage
Usage Percentage
```

Then existing information should continue to appear:

- cryptographic parameters
- devices
- revision history
- GC controls
- existing audit information

Do not regress the current admin functionality.

---

# 26. Admin Plan Control

On `/admin/users/:id`, add a production-ready plan management control.

Required behavior:

### Free user

Show:

```text
Plan
Free

Storage
xxx MB / 1 GB

[ Make Premium ]
```

### Premium user

Show:

```text
Plan
Premium

Storage
x.x GB / 10 GB

[ Downgrade to Free ]
```

Use confirmation before changing the plan.

The operation must be authenticated through the existing admin session/auth middleware.

It must be a real backend action, not a front-end-only state change.

---

# 27. Downgrade Behavior

If a Premium user has more than 1 GB stored and is downgraded:

Example:

```text
9.2 GB used
10 GB Premium limit
1 GB Free limit
```

DO NOT delete files.

DO NOT automatically destroy data.

The user becomes:

```text
over quota
```

Existing cloud content remains accessible.

New uploads are blocked until the user is back under quota.

Deletion remains allowed.

Download/access remains allowed according to the existing product behavior.

When usage falls below the Free limit, uploads resume.

The admin UI should visibly indicate the over-quota state.

Example:

```text
Plan
Free

Storage
9.2 GB / 1 GB

Status
Over quota by 8.2 GB
```

---

# 28. Premium Upgrade Behavior

When changing:

```text
Free → Premium
```

only the plan/entitlement needs to change.

Storage contents remain untouched.

The storage limit immediately becomes 10 GB.

No file migration is required.

No Cloudinary object migration is required.

---

# 29. Admin Audit Log

Changing a user's plan is a privileged account operation.

Create an audit record using the project's existing database conventions, or create a narrowly scoped admin audit table if one does not exist.

The audit should record at least:

```text
action
admin identity/session identifier if available
user ID
old plan
new plan
timestamp
```

Example action:

```text
PLAN_CHANGED
```

Make this idempotent where appropriate.

Do not store the admin password.

Do not expose sensitive admin session secrets.

---

# 30. Admin Dashboard Enhancements

The existing admin dashboard already presents storage-related metrics.

Extend it to show useful plan/quota information.

Include metrics such as:

```text
Total Users
Free Users
Premium Users
Total Cloud Storage Used
Free Storage Used
Premium Storage Used
Users Near Quota
Users Over Quota
```

Define "near quota" consistently, for example >= 80%.

Do not invent arbitrary complicated analytics.

The dashboard should use efficient aggregate queries.

Do not load every user row into memory just to calculate summary metrics.

---

# 31. Admin Storage Page Enhancements

The existing `/admin/storage` page already reports Cloudinary attachment/document metrics and destruction jobs.

Preserve that functionality.

Add useful quota-related information:

- total stored bytes
- total Free users
- total Premium users
- users over quota
- users >= 80% usage
- aggregate Free usage
- aggregate Premium usage

Maintain the existing destruction-job functionality.

Do not replace the page.

---

# 32. Admin API

If the existing admin architecture exposes JSON APIs, add appropriate authenticated admin endpoints where useful.

Potential endpoint:

```http
POST /api/admin/users/:id/plan
```

Request:

```json
{
  "plan": "premium"
}
```

or:

```json
{
  "plan": "free"
}
```

Use Zod validation.

Enforce admin authorization server-side.

Do not trust hidden HTML fields or client-side controls.

If the existing admin architecture uses form POSTs into `handleAdminRequest()`, integrate through that mechanism while preserving clean internal service boundaries.

---

# 33. Admin Security

The existing admin panel uses password authentication and HMAC-signed session cookies.

Preserve that system.

All new admin mutations must use the existing authenticated admin middleware.

Do not create an unprotected admin endpoint.

Do not add a second admin password mechanism.

Do not expose plan-changing functionality through ordinary authenticated user endpoints.

A normal Firebase-authenticated user must never be able to make themselves Premium.

---

# 34. CSRF Considerations

Inspect the existing admin POST/form security model.

If CSRF protection exists, use it.

If the existing session architecture requires CSRF protection for state-changing HTML forms and it is absent, implement an appropriate CSRF mechanism for the new mutation rather than ignoring the issue.

Do not introduce a security regression.

---

# 35. Database Migration Safety

This is a critical requirement.

Database migrations MUST be production-safe.

Before changing schema:

1. Inspect the current migration numbering.
2. Inspect the migration runner.
3. Inspect the current production schema assumptions.
4. Determine the next migration number correctly.
5. Do not edit already-applied migrations unless the repository's migration system explicitly requires a controlled repair migration.
6. Add a new forward-only migration.
7. Ensure existing users receive safe defaults.
8. Ensure existing file rows remain valid.
9. Ensure all required indexes are created safely.
10. Ensure migration behavior is compatible with Turso/libSQL.

Never casually rewrite historical migration files.

---

# 36. Migration Ordering

Inspect the existing migration history carefully.

Do not assume the migration number from documentation.

Use the actual repository state.

The handoff already documents past migration-order problems involving indexes referring to columns before those columns existed. Avoid repeating this class of error.

For new schema changes:

- add columns before indexes that depend on them
- populate/backfill before enforcing constraints
- create indexes after required columns exist
- use safe defaults for existing rows
- ensure migration can run against the real current schema

---

# 37. Backfilling Existing Data

Existing users and files already exist.

After adding the plan/storage columns:

```text
existing users → free
existing usage counters → safely populated
```

Do NOT assume usage is zero for existing users.

You must perform a real backfill/reconciliation based on existing authoritative metadata.

Before declaring the migration complete, calculate the current storage consumed by each user from existing attachment/document records.

The backfill must be safe for the current production data model.

If file tables use different ownership paths, join them correctly through notes/users as appropriate.

Do not double-count a resource.

Do not count deleted/nonexistent cloud resources incorrectly.

Document the exact inclusion/exclusion rules.

---

# 38. Migration Idempotency / Recovery

Because deployment/migration processes can fail midway, the migration must be designed so a partially completed deployment can be diagnosed and safely resumed according to the existing migration runner's semantics.

Do not create unsafe "drop and recreate everything" logic.

Do not delete user data.

Do not reset counters blindly.

If a data backfill is too large for one synchronous migration under the repository's deployment environment, implement a production-safe staged/backfill mechanism rather than timing out.

Inspect the existing migration runner before choosing the implementation.

---

# 39. Existing Data Reconciliation

After migration, there should be a way to verify:

```text
stored counter == recomputed authoritative usage
```

for all users.

Add a testable reconciliation function.

If appropriate, add a one-time migration/admin diagnostic query.

Do not leave the system dependent on a manually executed undocumented SQL command.

---

# 40. Handling Old Files Over 10 MB

There may already be existing attachments larger than the new 10 MB limit because the old system documented a 50 MB limit.

DO NOT delete or mutate existing files simply because the new upload limit is 10 MB.

The 10 MB rule applies to NEW upload/creation authorization.

Existing content remains retained.

Existing files continue to count toward storage quota.

If an old file is replaced, the resulting new upload must obey the 10 MB limit.

---

# 41. Existing Users Who Exceed 1 GB

There may be existing users with more than 1 GB of data because the old system had no quota.

Do NOT delete data.

Default existing users to Free unless repository/business logic explicitly says otherwise.

If an existing Free user is already above 1 GB:

```text
existing data retained
account marked over quota
new uploads blocked
downloads remain available
deletions remain available
```

Do not introduce destructive cleanup.

The admin panel must make such accounts obvious.

---

# 42. Usage Definition

Document precisely what counts toward quota.

At minimum:

```text
cloud encrypted attachment bytes
+
cloud encrypted document bytes
+
other cloud-backed file resources
```

Decide whether OCR metadata is included or excluded based on the actual storage architecture.

Do not make a guess.

Inspect whether OCR payloads are materially stored in Turso rather than Cloudinary and keep quota semantics aligned with the product promise of file storage.

The backend currently stores encrypted OCR datasets in Turso/libSQL while binary PDF payloads live in Cloudinary.

Do not accidentally charge the user twice for data represented in two database records.

---

# 43. Storage Accounting and Cloudinary

Inspect the existing Cloudinary metadata implementation.

Determine what field represents the authoritative cloud object size.

Use that value during confirmation/reconciliation.

Do not assume `content_length` semantics without checking the existing Cloudinary integration.

Do not introduce API calls on every storage read.

---

# 44. Performance

The implementation must scale.

Avoid:

- N+1 Firebase requests in `/admin/users`
- full-table file scans during every upload
- `SUM` across all resources on every user storage request
- loading entire user populations into application memory
- repeated Cloudinary API calls for ordinary storage reads

Use indexed database queries.

Add indexes only where justified.

Admin dashboard aggregate queries should be efficient.

User storage reads should be constant-time from the materialized counter.

---

# 45. Email in Users Explorer

The Users Explorer must show email prominently.

Example logical layout:

```text
EMAIL                  PLAN       STORAGE         NOTES   DEVICES
alice@example.com      Premium    2.1 GB / 10 GB    42      3
bob@example.com        Free       842 MB / 1 GB     18      1
```

The actual HTML/styling must follow the existing admin design.

Do not use placeholder rows.

Do not hardcode example users.

---

# 46. Email Search

Update existing user search.

Search must support:

- exact email
- partial email
- Firebase UID
- internal user ID

Use parameterized queries.

Do not concatenate raw search text into SQL.

Preserve pagination.

---

# 47. Admin Plan Display

Use explicit human-readable labels:

```text
Free
Premium
```

not internal lowercase enum values alone.

Where status is useful, show:

```text
Free
Premium
Over quota
```

Do not introduce a "Pro" label unless the backend enum actually uses it.

---

# 48. Plan Change Service API

Create a reusable backend service method, conceptually:

```ts
changeUserPlan(userId, newPlan, auditContext)
```

It should:

1. verify user exists
2. read old plan
3. determine whether change is necessary
4. update plan atomically
5. record audit
6. return resulting account state

Repeated request with the same plan should be safe.

Changing Free → Free should not create noisy duplicate audit events unless existing audit conventions require it.

Changing Premium → Free should correctly expose over-quota state.

---

# 49. Do Not Couple Billing Yet

Do NOT implement Stripe, App Store Billing, Google Play Billing, subscriptions, payment processing, or webhooks in this task.

Premium is currently an administrative entitlement.

The abstraction must make future billing integration possible, but billing itself is NOT part of this implementation.

Later, billing can set:

```text
plan = premium
```

through a trusted backend path.

---

# 50. Do Not Change Flutter Yet Unless Strictly Required

This task is primarily backend.

Do not make broad Flutter UI changes.

Only modify client code if a tiny compatibility update is necessary because an existing backend API contract is changing.

The backend should be complete and testable independently.

A future client task can consume:

```text
GET /api/v1/account/storage
```

and the storage/quota error responses.

---

# 51. Validation

Inspect existing:

```text
backend/src/validation/schemas.ts
```

and extend it using the current Zod style.

Validate:

- plan enum
- upload size
- storage-related request fields
- admin mutation payloads

Do not trust TypeScript types alone.

---

# 52. Tests — Mandatory

This feature is incomplete without tests.

Add comprehensive Vitest coverage.

At minimum test:

## Plans

- new users default to Free
- Premium user receives 10 GB
- Free user receives 1 GB
- plan lookup is correct

## File size

- exactly 10 MB accepted
- less than 10 MB accepted
- greater than 10 MB rejected
- Premium does NOT get a larger individual file limit

## Quota

- upload allowed when within quota
- upload rejected when over quota
- upload allowed when exactly at boundary if resulting usage does not exceed limit
- reservation reduces available capacity
- reservation expires/releases
- confirmation converts reservation to usage
- duplicate confirmation does not double-count
- failed upload releases reservation
- concurrent uploads cannot exceed quota

## Storage deltas

- create increases usage
- update larger increases by difference
- update smaller decreases by difference
- delete decreases usage
- repeated delete does not double-subtract
- zero-byte resource works according to existing semantics
- usage never becomes negative

## Existing oversized files

- existing >10 MB resources remain retained
- old oversized resource continues counting toward storage
- new uploads are still restricted to 10 MB

## Existing over-quota users

- existing Free user >1 GB can remain stored
- new uploads are rejected
- deletion remains possible
- upgrade to Premium allows uploads if under 10 GB
- downgrade from Premium to Free does not delete data
- over-quota status is correctly reported

## Storage API

- authenticated user receives storage profile
- unauthenticated request is rejected
- usage and remaining values are accurate

## Admin

- users list includes email
- search by email works
- search by Firebase UID continues working
- search by internal ID continues working
- Free user can be changed to Premium
- Premium user can be changed to Free
- invalid plan rejected
- non-admin cannot change plan
- admin session required
- audit event created
- repeated same-plan operation is safe
- over-quota downgrade is correctly represented

## Migration

- migration applies to a clean database
- migration applies to a representative pre-migration schema
- existing users receive safe defaults
- existing storage is correctly backfilled
- no existing file is deleted
- counters match recomputed authoritative usage after migration

---

# 53. Concurrency Tests

This is mandatory.

The quota system must be tested for concurrent requests.

Simulate:

```text
remaining = 10 MB

request A = 7 MB
request B = 7 MB
```

Only one combined amount may be reserved/committed if both cannot fit.

The final committed + reserved total must NEVER exceed the user's plan limit.

Do not rely on application-level locking alone if the DB can provide transactional atomicity.

Use the transaction semantics appropriate to Turso/libSQL.

---

# 54. Transaction Safety

Inspect the existing database client helpers.

Do not create a second database connection system.

Use existing transaction/query abstractions.

Quota mutations must be atomic.

The implementation must protect against:

- concurrent uploads
- repeated confirmation
- repeated deletion
- partial failure

---

# 55. Admin UI Quality

The admin panel is already server-rendered and responsive.

Preserve:

- existing editorial visual language
- navigation
- flash-message mechanism
- responsive tables
- authenticated session behavior
- existing storage/destruction views

The new plan controls should look native to the existing admin UI.

Do not introduce a new frontend framework.

Do not turn the admin panel into a SPA.

---

# 56. Admin Flash Messages

Use the existing flash/action feedback system.

Examples:

```text
User upgraded to Premium.
```

```text
User downgraded to Free.
```

```text
Plan change failed.
```

Do not expose raw database or stack-trace errors in the UI.

---

# 57. Admin Confirmation

Plan changes must require an intentional action.

For downgrade:

```text
Downgrade this user to Free?
Their existing files will not be deleted, but uploads will be blocked if they exceed 1 GB.
```

For upgrade:

```text
Make this user Premium?
Their cloud storage allowance will increase from 1 GB to 10 GB.
```

The actual UX should fit the existing admin rendering system.

---

# 58. No Security Regression

Do not expose:

- encryption passwords
- master keys
- plaintext note contents
- plaintext attachment contents
- Firebase service-account secrets
- Cloudinary API secrets
- admin passwords
- signed upload secrets beyond their intended response
- raw internal credentials

The admin panel may display metadata such as:

- email
- plan
- storage
- IDs
- dates
- counts

but never decrypt content.

The existing admin tests explicitly verify zero-knowledge content absence; preserve that guarantee.

---

# 59. API Error Semantics

Use existing `ApiError`/HTTP mapping conventions.

Do not introduce inconsistent response shapes.

Prefer stable machine-readable error codes.

At minimum, ensure the client can distinguish:

```text
FILE_TOO_LARGE
STORAGE_QUOTA_EXCEEDED
```

from generic server errors.

---

# 60. Observability

Use the existing logging/error conventions.

Important events should be distinguishable:

- quota rejection
- upload reservation
- upload finalization
- reservation expiration
- quota release
- admin plan change
- quota reconciliation discrepancy

Do not log:

- file contents
- plaintext content
- encryption keys
- authentication secrets
- admin password

---

# 61. Reconciliation and Drift Handling

Build safeguards for accounting drift.

Possible invariant:

```text
storage_used_bytes >= 0
storage_reserved_bytes >= 0
```

and:

```text
storage_used_bytes + storage_reserved_bytes
<= storage_limit_bytes
```

for normal valid accounts.

An over-quota user after a downgrade is allowed to violate the last condition because the plan limit can change downward without deleting data.

Therefore distinguish:

```text
normal quota violation
```

from:

```text
legacy/downgraded over-quota state
```

Do not attempt to "fix" this by deleting files.

---

# 62. Backfill Logic

When calculating existing usage, carefully inspect:

- attachment ownership
- document ownership
- deleted rows
- pending uploads
- failed uploads
- cloud deletion states
- duplicate/retry metadata

Only count authoritative cloud-retained resources.

Do not count a failed uncommitted upload as committed usage.

Do not count a reservation as usage.

Do not count the same resource twice.

---

# 63. Admin Storage Metrics

Use actual authoritative counters where appropriate.

For user-level storage:

```text
SUM(users.storage_used_bytes)
```

is acceptable for aggregate reporting.

Do not recompute every user's full file usage for the dashboard.

For reconciliation tools, authoritative recomputation is acceptable.

---

# 64. Backward Compatibility

Existing API routes and clients must continue working unless a change is intentionally required.

Do not rename endpoints unnecessarily.

Do not alter encryption formats.

Do not alter Cloudinary object naming conventions.

Do not alter existing resource URI formats.

Do not alter sync revision semantics.

Do not break existing deletion lifecycle.

---

# 65. Repository Inspection Requirement

Before writing code:

1. inspect `backend/src`
2. inspect `backend/migrations`
3. inspect `backend/tests`
4. inspect current attachment routes/services
5. inspect current document routes/services
6. inspect current admin routes/services/views
7. inspect current DB migration runner
8. inspect current user creation/auth synchronization
9. inspect current Cloudinary integration
10. inspect existing storage management
11. inspect destruction/GC behavior
12. inspect current tests before adding new ones

Do not implement based only on this prompt.

The existing repository is authoritative for implementation details.

---

# 66. Search Before Changing

Search for all of the following and trace their complete lifecycle:

```text
attachments/upload-auth
attachments/confirm
documents/upload-auth
documents/confirm
cloudinary
byte_size
storage
destruction
garbage collection
users
firebase_uid
email
admin users
admin storage
upload_state
is_deleted
deleted_at
cloud_public_id
```

Also search for every route that creates or confirms cloud-backed resources.

Do not assume there are only two upload paths.

---

# 67. Documentation

Update the engineering handoff/documentation with the final architecture.

Document:

- plans
- storage allowances
- 10 MB maximum
- storage accounting semantics
- reservation lifecycle
- quota enforcement points
- deletion/reclamation behavior
- downgrade behavior
- existing-user migration behavior
- admin plan management
- email display/search
- audit logging
- reconciliation mechanism

Do not write documentation describing functionality that is not actually implemented.

---

# 68. Environment Variables

Do not introduce new environment variables unless genuinely necessary.

Do not put storage limits in environment variables unless there is an architectural reason.

Plan entitlements should normally be application/domain configuration.

Do not require manual production environment editing merely to establish the default Free/Premium limits.

---

# 69. Code Quality

Production standards are required.

The result must:

- compile cleanly
- pass TypeScript checks
- pass lint/format rules where applicable
- pass all backend tests
- preserve existing tests
- have strong error handling
- avoid unsafe casts
- avoid `any` unless already accepted by project conventions and genuinely required
- have clear service boundaries
- have comments only where logic is non-obvious
- avoid duplicated constants
- avoid dead code
- avoid TODO placeholders
- avoid mock implementations
- avoid fake Cloudinary responses in production code

---

# 70. Testing Strategy

Prefer unit tests for pure entitlement/quota logic.

Use integration-style tests for:

- DB mutations
- upload authorization
- confirmation
- deletion
- admin plan change
- migration behavior

Use the project's existing mocks/fakes for external services where appropriate.

Do not replace real production code with mocks merely to make tests pass.

---

# 71. Test Existing Behavior

Before concluding, run the complete backend test suite.

Do not only run newly added tests.

The existing backend already contains extensive auth, sync, conflict, crypto-blindness, lifecycle, GC, device, attachment/document, and admin tests.

All existing tests must continue passing.

---

# 72. Build Verification

At the end:

```bash
cd backend
npm test
npm run build
```

Also run any project-specific lint/typecheck commands discovered in the repository.

If the repository has a migration validation command, run it.

If tests are numerous, run the complete suite rather than only targeted tests.

---

# 73. Final Verification Checklist

Before declaring completion, verify all of the following:

### Entitlements

- [ ] Free = 1 GB
- [ ] Premium = 10 GB
- [ ] Both = 10 MB max individual file
- [ ] Plan is backend-authoritative
- [ ] Limits are centralized

### Storage

- [ ] Unified quota across images/PDFs/documents/attachments
- [ ] Materialized usage counter
- [ ] Reservation counter/lifecycle
- [ ] Atomic quota enforcement
- [ ] Correct deletion release
- [ ] Correct replacement delta
- [ ] No double counting
- [ ] No negative counters
- [ ] Reconciliation available

### Uploads

- [ ] upload-auth enforces max size
- [ ] upload-auth enforces available quota
- [ ] confirmation validates actual size
- [ ] retries are idempotent
- [ ] abandoned reservations recover
- [ ] no Vercel file proxying
- [ ] no plaintext handling

### Existing Data

- [ ] migration safely backfills usage
- [ ] existing large files retained
- [ ] existing >1 GB users retained
- [ ] existing over-quota users blocked only from new uploads
- [ ] no destructive migration

### Admin

- [ ] user email displayed
- [ ] email search works
- [ ] plan displayed
- [ ] storage displayed
- [ ] Free → Premium works
- [ ] Premium → Free works
- [ ] downgrade does not delete data
- [ ] over-quota state visible
- [ ] audit record written
- [ ] admin authentication enforced

### Security

- [ ] ordinary user cannot change own plan
- [ ] admin session required
- [ ] no secrets exposed
- [ ] no plaintext content exposed
- [ ] no encryption regression
- [ ] no Cloudinary secret leakage

### Quality

- [ ] migration tested
- [ ] concurrency tested
- [ ] retry/idempotency tested
- [ ] all backend tests pass
- [ ] TypeScript build passes
- [ ] no placeholder/mock production code
- [ ] documentation updated

---

# 74. Implementation Style

Do not stop at analysis.

Actually modify the repository.

Do not return a proposed patch without applying it.

Do not merely tell me which files should change.

Implement the complete feature.

When you encounter ambiguity, inspect the actual repository and choose the implementation that best preserves the established architecture.

Do not ask for permission to make normal engineering decisions that can be resolved from the codebase.

Do not leave incomplete TODOs.

Do not leave commented-out alternative implementations.

Do not claim success unless the implementation and verification commands actually pass.

---

# 75. Final Deliverable

When finished, provide a concise engineering summary containing:

1. What files were added/modified
2. Database migration number and what it changes
3. Storage accounting design
4. Reservation/concurrency design
5. Upload enforcement changes
6. Admin changes
7. Email/search changes
8. Downgrade behavior
9. Reconciliation mechanism
10. Tests added
11. Exact verification commands run
12. Final test/build results
13. Any genuine limitations or repository constraints discovered

Do not fabricate successful test results.

If something could not be completed because the repository genuinely prevents it, state exactly what blocked it and what was completed instead.

The implementation itself must be production-ready.