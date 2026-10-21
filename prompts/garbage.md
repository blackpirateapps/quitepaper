# Quiet Paper — Production-Grade Cloud Storage Lifecycle, Synchronized Trash, Permanent Destruction & Garbage Collection

## Mission

Implement a flagship, production-ready **Cloud Storage Lifecycle and Garbage Collection subsystem** for Quiet Paper.

This is not a simple database cleanup task.

The implementation must establish a complete, durable lifecycle for notes, trash, permanent deletion, note versions, synchronization history, tombstones, attachments, documents, OCR records, Cloudinary objects, idempotency records, orphaned resources, and physical database compaction.

The implementation must preserve all existing Quiet Paper invariants:

- Offline-first behavior remains intact.
- Markdown remains the canonical note representation.
- The backend remains strictly zero-knowledge / crypto-blind.
- The backend must never decrypt note content, OCR plaintext, attachment plaintext, or possess user master keys.
- Existing conflict resolution must continue to work.
- Existing cursor-based synchronization must continue to work.
- Existing backups and restores must remain compatible.
- Existing attachment and document synchronization must remain compatible.
- Existing tests must continue passing, with comprehensive new tests added.
- No destructive operation may silently resurrect data, permanently delete data that another active device may still need, or leave externally stored Cloudinary objects behind unnecessarily.

The user has explicitly decided on these product semantics:

1. Deleting a note means **move it to Trash**.
2. Trash is synchronized across devices.
3. Trash is retained **forever** unless the user explicitly permanently deletes the note.
4. Restoring a trashed note is synchronized across devices.
5. Permanently deleting a note means destroying the note and everything associated with it.
6. Permanent deletion must eventually delete associated encrypted attachment/document binaries from Cloudinary.
7. Attachments and documents must have user-visible management in Settings.
8. Settings must show both attached resources and orphaned resources.
9. Old sync history, versions, idempotency records, tombstones, orphaned resources, and other stale data must be eligible for safe garbage collection.
10. Garbage collection must be device-aware and must not break synchronization for legitimate offline devices.
11. The system must support dry-run analysis and storage accounting.
12. GC must be incremental, crash-safe, idempotent, observable, and retryable.

---

# PHASE 0 — FULL REPOSITORY AUDIT BEFORE MODIFYING CODE

Do not immediately implement anything.

First inspect the repository and produce a concrete implementation model based on the actual code.

Inspect at minimum:

### Backend

- `backend/src/db/client.ts`
- `backend/src/db/migrate.ts`
- all backend migrations
- `backend/src/sync/syncService.ts`
- `backend/src/api/handler.ts`
- `backend/src/validation/schemas.ts`
- attachment/document services
- key services
- all sync-related tests
- all database-related tests

### Flutter

Inspect the current implementations of:

- `lib/core/sync/sync_engine.dart`
- `lib/core/sync/sync_api_client.dart`
- `lib/core/sync/sync_models.dart`
- `lib/core/database/app_database.dart`
- all notes tables
- note versions table
- sync queue table
- sync metadata table
- document tables
- document OCR tables
- attachment tables
- attachment service
- document service
- conflict resolver
- conflict persistence
- backup service
- Settings screen
- existing trash UI and repository methods
- any code involved in permanent deletion
- any code that parses `qp://asset/...`
- any code that parses `qp://document/...`

Search the entire repository for:

- `deletePermanently`
- `emptyTrash`
- `trash`
- `trashed`
- `deletedAt`
- `isDeleted`
- `sync_changes`
- `note_versions`
- `idempotency`
- `Cloudinary`
- `attachment`
- `document`
- `document_ocr_pages`
- `qp://asset/`
- `qp://document/`
- revision/cursor handling
- sync conflict handling
- note deletion
- note restoration

Do not assume the handoff is perfectly synchronized with the current source tree. Treat the code as the authority.

Before implementation, report:

1. Actual current schema.
2. Actual current sync state machine.
3. How deletion currently works locally.
4. How deletion currently reaches the server.
5. How trash currently works.
6. How restore currently works.
7. How permanent deletion currently works.
8. How versions are created, synchronized, and pruned.
9. How `sync_changes` is generated and consumed.
10. How device identity/cursors currently work.
11. How attachments are associated with notes.
12. How documents are associated with notes.
13. How OCR records are associated with documents.
14. How Cloudinary deletion currently works, if at all.
15. Which operations currently create orphaned data.
16. Whether Turso currently exposes or uses any database compaction mechanism.
17. Any existing migration/version constraints that affect implementation.

Do not invent missing architecture.

---

# PHASE 1 — DEFINE A FORMAL RESOURCE LIFECYCLE

Introduce a clear lifecycle model.

## Note lifecycle

The canonical state machine must be:

```text
ACTIVE
  |
  | Delete
  v
TRASHED
  |
  | Restore
  v
ACTIVE

TRASHED
  |
  | Permanent Delete
  v
DESTROYING
  |
  v
DESTROYED
```

Never interpret normal Trash as physical deletion.

A trashed note must remain available indefinitely until the user explicitly permanently deletes it.

---

# PHASE 2 — SYNCHRONIZED TRASH

Extend sync so Trash is a first-class cloud-synchronized state.

A note deletion initiated by the user must:

1. Mark the note as trashed locally.
2. Preserve its encrypted content.
3. Preserve its metadata required for Trash.
4. Preserve versions according to the existing version policy.
5. Queue the mutation for synchronization.
6. Persist the corresponding server-side lifecycle state.
7. Generate a revision in the server's sync history.
8. Cause other devices to receive the note as trashed.
9. Prevent an older active copy on another device from silently resurrecting the note.

A Trash operation is NOT permanent deletion.

---

# PHASE 3 — RESTORE

Restore must also be a first-class synchronized operation.

When restored:

1. The note becomes active locally.
2. The mutation is queued.
3. The server receives the state transition.
4. A server revision is generated.
5. Other devices receive the restored state.
6. Existing conflict logic must continue to apply.

Do not implement restore as a local-only flag change.

---

# PHASE 4 — EXPLICIT SYNCHRONIZATION OPERATIONS

Where appropriate, make lifecycle operations explicit rather than inferring everything from generic delete fields.

Conceptually support:

```text
UPSERT
TRASH
RESTORE
PERMANENT_DELETE
```

Use the actual project's established model conventions where possible.

Do not blindly replace existing protocol structures if a backward-compatible representation can safely encode these semantics.

The final protocol must remain compatible with already deployed clients wherever practical.

If a breaking protocol change is unavoidable, implement explicit versioning and migration behavior.

---

# PHASE 5 — PERMANENT DELETION

Permanent deletion must mean complete logical destruction of all resources belonging exclusively to the note.

Do not treat permanent deletion as a simple:

```sql
DELETE FROM notes
```

The implementation must discover all associated resources first.

At minimum investigate and handle:

```text
note
├── note versions
├── sync/conflict records
├── attachment references
├── attachments
├── documents
├── OCR pages
├── related metadata
└── server-side sync tombstone/history
```

The exact dependency graph must come from the actual repository.

Permanent deletion must be idempotent.

Calling permanent deletion twice must not corrupt state or cause an unrecoverable error.

---

# PHASE 6 — IMPORTANT: DISTRIBUTED DELETE SAFETY

Do not destroy the synchronization knowledge needed by offline devices prematurely.

Example:

```text
Device A
permanently deletes Note X

Device B
has not synchronized for 60 days
```

If the server completely forgets that Note X existed, Device B can later upload its stale copy and resurrect it.

Therefore distinguish:

### Resource destruction

Destroy:

- current note content
- versions
- documents
- OCR pages
- attachments
- metadata

when appropriate.

### Synchronization tombstone

Retain enough synchronization information to tell stale devices:

```text
Note X was permanently deleted.
```

The tombstone itself must become garbage collectable once the server can prove that relevant devices no longer require it.

---

# PHASE 7 — DEVICE CHECKPOINT / ACKNOWLEDGEMENT MODEL

Implement a durable server-side model for per-device synchronization checkpoints if one does not already exist.

Conceptually:

```text
sync_devices

id
user_id
device_id
last_acknowledged_revision
last_seen_at
created_at
updated_at
```

Use the project's existing identity model rather than inventing a second device ID system if one already exists.

The purpose is to establish a GC safety barrier.

For a user:

```text
Device A → revision 1000
Device B → revision 980
Device C → revision 735
```

The safe synchronization boundary is conceptually:

```text
min(acknowledged revisions of eligible active devices)
```

Do not delete synchronization history newer than this safety boundary.

---

# PHASE 8 — DEVICE LIVENESS / LEASES

Prevent abandoned devices from blocking GC forever.

Define server-side device activity semantics.

Recommended conceptual states:

```text
ACTIVE
STALE
EXPIRED
```

with configurable server-side thresholds.

Recommended baseline:

```text
ACTIVE  < 30 days
STALE   30–90 days
EXPIRED > 90 days
```

Do not blindly hardcode these numbers if the existing product architecture already has a retention/configuration mechanism.

Expired devices may be removed from the active GC barrier.

However, the behavior must be designed so a long-offline device can recover through a full resynchronization rather than receiving a silently incomplete delta stream.

---

# PHASE 9 — SYNC HISTORY GC

The `sync_changes` table is append-only and therefore a primary source of database growth.

Implement a safe revision-history GC.

Requirements:

- Never remove changes required by an eligible device.
- Never remove a change needed for conflict resolution.
- Never remove required permanent-deletion knowledge.
- Never break historical revision lookup while the revision is still required by supported conflict behavior.
- Use a conservative safety boundary.
- Process rows incrementally in bounded batches.
- Make the operation idempotent.
- Record GC metrics.

Introduce a concept similar to:

```text
gc_boundary_revision
```

or derive it deterministically from device checkpoints.

---

# PHASE 10 — SYNC CURSOR EXPIRATION AND FULL RESYNC

Introduce an explicit mechanism for clients whose cursor is older than the retained history window.

Example:

```text
server current revision = 100000
retained delta history begins = 92000

client cursor = 87000
```

The server must not pretend that incremental sync is possible.

Return a structured condition such as:

```text
SYNC_CURSOR_EXPIRED
```

The client must then perform a safe full/current-state resynchronization.

Do not silently skip missing revisions.

Do not allow cursor gaps to produce inconsistent note state.

Implement end-to-end tests for:

- cursor still valid
- cursor exactly at boundary
- cursor older than boundary
- permanent delete near boundary
- conflict scenarios near boundary
- offline device returning after expiry

---

# PHASE 11 — NOTE VERSION GARBAGE COLLECTION

The existing product retains up to 50 note versions per note.

Preserve that product behavior unless repository analysis demonstrates a safer equivalent.

The lifecycle should be:

```text
ACTIVE NOTE
→ version retention policy applies

TRASHED NOTE
→ version retention policy still applies

PERMANENTLY DELETED NOTE
→ all note versions belonging exclusively to that note become destructible
```

Ensure version records are removed during permanent note destruction.

Also verify that cloud `note_versions` and local versions remain consistent.

Do not accidentally delete a version that is still needed for conflict resolution.

---

# PHASE 12 — IDEMPOTENCY KEY GC

The idempotency-key table is a retry cache, not permanent historical data.

Implement TTL-based cleanup.

Each entry should have enough metadata to determine expiration safely.

Conceptually:

```text
created_at
expires_at
```

Delete expired entries incrementally.

The retention duration must be longer than the maximum retry/replay window supported by the backend.

Never delete an idempotency entry while a request could still legitimately be retried within the supported replay window.

Add tests for expiry and retry behavior.

---

# PHASE 13 — ATTACHMENT RESOURCE GRAPH

Treat attachments as first-class cloud resources.

The implementation must establish a reliable relationship between:

```text
note
  ↓
Markdown qp://asset/<UUID>
  ↓
attachment reference
  ↓
attachment metadata
  ↓
Cloudinary object
```

The server is crypto-blind and cannot inspect encrypted Markdown.

Therefore do not make the server parse plaintext note bodies.

Instead implement or extend a client-produced reference projection.

For example:

```text
attachment_references

user_id
attachment_id
note_id
last_confirmed_at
```

Use the actual project schema and naming conventions where possible.

The reference projection must be updated whenever a note's canonical Markdown changes.

It must be updated for:

- creation
- editing
- restore
- trash
- permanent deletion
- import
- backup restore
- conflict resolution
- merge
- attachment insertion
- attachment removal

Do not depend solely on parsing a future note mutation after the fact.

---

# PHASE 14 — ORPHANED ATTACHMENTS

An attachment is conceptually orphaned when the server can determine that:

```text
reference_count == 0
```

Do NOT immediately destroy it.

Use:

```text
REFERENCED
ORPHANED
PENDING_DELETION
DELETED
```

or an equivalent safe lifecycle.

Orphaned resources must have a grace period before permanent destruction.

This protects against synchronization races such as:

```text
Device A removes reference
Device B still has older note
```

The orphaned object must survive long enough for legitimate synchronization convergence.

The grace period must be configurable at the service level.

Do not expose arbitrary retention controls to users unless the existing product design calls for them.

---

# PHASE 15 — CLOUDINARY DELETION

Permanent attachment/document destruction must eventually remove the corresponding Cloudinary resource.

Do not delete only the Turso metadata.

Do not delete the Turso metadata first and assume Cloudinary will somehow follow.

Because Cloudinary is an external dependency, implement a durable destruction-job / cleanup queue.

Conceptually:

```text
destruction_jobs

id
user_id
resource_type
resource_id
cloudinary_public_id
operation
state
attempt_count
available_at
last_error
created_at
updated_at
```

Use the project's existing job/queue patterns if available.

States may conceptually be:

```text
PENDING
PROCESSING
RETRYING
COMPLETED
FAILED
```

The operation must be retryable and idempotent.

Cloudinary deletion should tolerate:

- already deleted object
- transient network failure
- timeout
- rate limiting
- authentication failure
- missing resource
- repeated execution

A permanent resource deletion must never become permanently stuck simply because one Cloudinary request failed transiently.

---

# PHASE 16 — DOCUMENT + OCR RESOURCE LIFECYCLE

Treat documents as a resource graph:

```text
document
├── Cloudinary encrypted PDF
└── document_ocr_pages
```

If a document is no longer referenced by any note and becomes eligible for destruction:

1. Mark it orphaned.
2. Respect the orphan grace period.
3. Queue destruction.
4. Delete Cloudinary encrypted document data.
5. Remove OCR pages.
6. Remove document metadata.
7. Record completion/failure.
8. Retry failures safely.

OCR records must never survive indefinitely after their owning document is permanently destroyed.

The actual schema already includes encrypted OCR page payloads and separate document metadata, so verify every dependency in the repository before implementation.

---

# PHASE 17 — NOTE PERMANENT-DELETION RESOURCE GRAPH

For a note being permanently deleted, establish the resource graph first.

For example:

```text
NOTE X
│
├── versions
│
├── conflicts
│
├── references to assets
│      └── attachments
│             └── Cloudinary object
│
├── references to documents
│      ├── document metadata
│      ├── OCR pages
│      └── Cloudinary PDF
│
└── sync lifecycle/tombstone
```

Important:

An attachment/document must only be physically destroyed when no other note references it.

Do not assume:

```text note deleted
→ attachment deleted
```

without reference analysis.

The correct rule is:

```text
note permanently destroyed
+
resource has zero remaining references
+
resource retention/grace period satisfied
→ destruction eligible
```

This is essential if the same resource can ever be reused by multiple notes.

---

# PHASE 18 — SETTINGS: STORAGE & ATTACHMENT MANAGEMENT

Add a dedicated Settings section.

Use Quiet Paper's existing iOS Grouped Table / Bear-inspired settings architecture rather than introducing a visually unrelated UI.

The handoff establishes grouped settings, flush rows, responsive tablet layout, and the existing editorial aesthetic. Preserve these patterns.

Create something conceptually like:

```text
STORAGE & ATTACHMENTS

Cloud Storage
────────────────────────────
Attachments          37
Documents            12
Orphaned              4
Estimated Storage   184 MB
```

Then provide resource management.

---

# PHASE 19 — ATTACHED RESOURCE VIEW

Display resources that are referenced by active or trashed notes.

Each item should show where practical:

- resource type
- filename/title
- size
- parent note
- creation date
- cloud state
- encryption/resource state
- orphan status
- document/OCR state where applicable

Examples:

```text
Sunset.jpg
Used by: Weekend Trip
2.4 MB
Attached
```

```text
Tax Receipt.pdf
Used by: Taxes 2025
842 KB
Attached
OCR available
```

Users should be able to inspect the resource and navigate to its parent note/document where appropriate.

---

# PHASE 20 — ORPHANED RESOURCE VIEW

Provide a clear Orphaned section.

Example:

```text
ORPHANED

old-photo.png
No notes reference this
1.8 MB
Orphaned 14 days ago
```

```text
scan-2025.pdf
No notes reference this
5.1 MB
Orphaned 31 days ago
```

Display the resource's deletion eligibility state.

Do not offer destructive deletion if the server says the resource is not yet eligible.

Once eligible, allow a user-initiated delete if product semantics support it.

User-triggered deletion and automatic GC must share the same destruction machinery.

---

# PHASE 21 — STORAGE PROFILER

Implement backend and/or administrative diagnostics that measure logical storage composition.

At minimum report:

```text
notes
note_versions
sync_changes
idempotency_keys
documents
document_ocr_pages
attachments
attachment_references
conflicts
destruction_jobs
other relevant tables
```

For every category where reasonably possible expose:

- row count
- approximate payload size
- oldest row
- newest row
- eligible row count
- estimated reclaimable bytes

Do not rely on guessed values.

Use actual database queries and actual field lengths where appropriate.

---

# PHASE 22 — DRY RUN GC

Implement a dry-run mode.

A dry-run must:

- never delete anything
- calculate what would be collected
- report counts
- report estimated bytes
- report resource categories
- report blockers
- report the GC boundary
- report stale/expired devices
- report orphaned resources
- report permanently deleted objects awaiting cleanup
- report failed destruction jobs

Example output:

```text
Quiet Paper Storage GC Report

Database logical size:
15.0 MB

Notes:
700 rows

Note versions:
8,421 rows
Potentially reclaimable: 2.4 MB

Sync changes:
9,212 rows
Potentially reclaimable: 3.8 MB

Idempotency keys:
913 rows
Potentially reclaimable: 0.2 MB

Orphaned attachments:
4
Potentially reclaimable: 6.7 MB

Orphaned OCR:
37 pages
Potentially reclaimable: 0.9 MB

Safe sync boundary:
revision 92,000

Estimated reclaimable:
14.0 MB
```

The example above is illustrative only; never hardcode these values.

---

# PHASE 23 — INCREMENTAL GC ENGINE

Implement a central GC coordinator.

Conceptually:

```text
GarbageCollector
├── StorageProfiler
├── RevisionCollector
├── VersionCollector
├── IdempotencyCollector
├── TombstoneCollector
├── OrphanCollector
├── AttachmentCollector
├── DocumentCollector
├── OcrCollector
└── DestructionJobProcessor
```

Use the actual project architecture where appropriate.

Every collector must:

- be independently testable
- process bounded batches
- commit safely
- tolerate interruption
- be retryable
- be idempotent
- expose metrics
- avoid unbounded memory usage

Do not implement an enormous single database transaction for the entire GC pass.

Use bounded batches such as 50–500 rows depending on actual query cost.

Tune after measuring.

---

# PHASE 24 — CRASH SAFETY

Assume the process can terminate at every possible point:

```text
before deleting
during deleting
after DB deletion
before Cloudinary deletion
after Cloudinary deletion
before updating job status
after updating job status
```

The resulting state must always be recoverable.

Examples:

### Crash before deletion

Next run retries.

### Crash after Cloudinary deletion but before marking complete

Next run recognizes "already gone" as success.

### Crash after DB cleanup but before job completion

Next run must not fail catastrophically because the DB object is already gone.

### Crash during batch processing

Already committed batches remain valid.

Uncommitted work is retried.

---

# PHASE 25 — CONCURRENCY CONTROL

GC may run concurrently with sync.

This is critical.

A resource must not be declared orphaned while a legitimate synchronized note reference is still being established.

Implement appropriate safeguards such as:

- transactions
- revision checks
- timestamps
- status transitions
- optimistic concurrency
- compare-and-swap semantics
- grace periods
- revalidation immediately before destruction

Use the safest mechanism supported by the actual schema.

Before physically deleting a resource, perform a final authoritative eligibility check.

Never trust stale GC candidate data.

---

# PHASE 26 — BACKUP SAFETY

Permanent deletion must not accidentally delete restore data required by existing backup semantics.

Review the existing backup architecture before implementation.

The handoff states that backups contain full notebook state and that restored notes are marked dirty for cloud sync.

Determine whether backup references need to be considered part of resource ownership.

Do not silently alter backup semantics.

Do not make permanent deletion retroactively rewrite an already-created local backup.

---

# PHASE 27 — ZERO-KNOWLEDGE / PRIVACY INVARIANTS

This project must remain crypto-blind.

The backend must never:

- decrypt note content
- decrypt note versions
- decrypt OCR payloads
- inspect plaintext Markdown
- inspect attachment plaintext
- obtain the master key
- derive the master key
- create searchable plaintext copies

The reference-projection system must contain only metadata necessary for resource ownership.

Never add plaintext note content to Turso merely to make GC easier.

---

# PHASE 28 — SECURITY REQUIREMENTS

All new endpoints must enforce:

- authenticated Firebase identity
- user ownership isolation
- authorization checks
- input validation
- resource ownership checks
- safe ID validation
- bounded batch sizes
- structured errors
- no cross-user resource deletion

A user must never be able to provide an attachment ID, document ID, note ID, or job ID belonging to another account and cause deletion.

Add explicit cross-user security tests.

---

# PHASE 29 — BACKWARD COMPATIBILITY

Existing clients may not understand new GC semantics.

Design the migration so:

- old clients do not accidentally resurrect trashed notes
- old clients cannot bypass permanent deletion semantics unintentionally
- old clients continue syncing where safe
- cursors remain valid until deliberately expired
- unsupported operations receive structured responses
- protocol capabilities can be detected where necessary

If capability negotiation is needed, implement it explicitly.

Do not infer client capability from app version strings unless unavoidable.

---

# PHASE 30 — DATABASE MIGRATIONS

Create production-safe migrations for all required new tables, indexes, columns, and constraints.

Follow the existing migration conventions.

Your handoff documents previous migration failures and the importance of defensive/idempotent migrations. Existing migrations use version gates and safe table/column creation logic.

Therefore:

- never issue duplicate column additions
- never assume a historical schema is perfect
- preserve existing migration behavior
- test upgrade paths from multiple historical schema versions
- ensure migrations are retry-safe

At minimum test:

```text
latest schema → latest schema
older → latest
intermediate → latest
fresh database → latest
```

as applicable to the actual migration history.

---

# PHASE 31 — INDEXING

Add indexes based on actual query patterns, not blindly.

Investigate indexes needed for:

```text
user_id
note_id
revision
trashed/deletion lifecycle
device checkpoints
attachment references
orphan eligibility
destruction jobs
idempotency expiration
version lookup
document ownership
OCR ownership
Cloudinary cleanup
```

Use composite indexes where appropriate.

Do not over-index large encrypted payload tables without measurement.

---

# PHASE 32 — PHYSICAL DATABASE COMPACTION

Do not equate:

```text
rows deleted
```

with:

```text
database physically smaller
```

Separate:

### Logical GC

Deletes obsolete records.

### Physical compaction

Reclaims unused database pages where the Turso/libSQL deployment and operational model safely support it.

Investigate the exact Turso/libSQL capabilities actually available to this project rather than guessing.

Do not add arbitrary `VACUUM` operations without understanding:

- Turso behavior
- replication implications
- locking
- execution duration
- serverless constraints
- operational safety

If physical compaction cannot safely be automated, implement reporting and document the limitation rather than pretending logical GC shrinks the database immediately.

---

# PHASE 33 — SCHEDULING

GC should not run on every note mutation.

Create an appropriate maintenance trigger.

Possible triggers:

- scheduled server maintenance
- periodic lazy invocation
- explicit admin invocation
- threshold-based GC
- post-sync opportunistic processing

Choose the mechanism compatible with the project's Vercel/Turso deployment.

Do not introduce an unsupported long-running background process.

If scheduled execution requires infrastructure not currently present, implement the GC as an idempotent endpoint/job that can safely be invoked by an external scheduler.

---

# PHASE 34 — OBSERVABILITY

Every GC run should produce structured information.

Track:

```text
run_id
started_at
finished_at
status
duration_ms

revision rows inspected
revision rows deleted

version rows inspected
version rows deleted

idempotency rows deleted

orphaned attachments found
attachments destroyed
attachments failed

documents destroyed
OCR records destroyed

tombstones retained
tombstones deleted

destruction jobs processed
jobs retried
jobs failed

estimated bytes reclaimed
```

Never log plaintext content, encryption keys, ciphertext unnecessarily, or sensitive user data.

Prefer resource IDs and hashes only where safe and necessary.

---

# PHASE 35 — SETTINGS STORAGE STATISTICS

The Settings UI should expose meaningful storage information without pretending to know exact physical DB size when it cannot.

Display categories such as:

```text
Notes
Version history
Sync history
Attachments
Documents
OCR
Orphaned resources
```

Also show:

```text
Estimated reclaimable
```

where available.

If physical database size is unavailable or only approximate, clearly label it as approximate.

---

# PHASE 36 — USER-FACING GC UX

Do not make normal users think about internal database mechanics.

The primary UI should use concepts such as:

- Storage
- Attachments
- Documents
- Orphaned
- Sync history
- Storage cleanup

rather than technical terms like:

- tombstone
- revision compaction
- garbage collector

Internal/debug builds can expose deeper diagnostics.

---

# PHASE 37 — ERROR HANDLING

All new errors must be structured.

Examples:

```text
RESOURCE_NOT_FOUND
RESOURCE_ALREADY_DELETED
RESOURCE_NOT_OWNED
DELETION_IN_PROGRESS
GC_CURSOR_EXPIRED
GC_NOT_ELIGIBLE
CLOUD_STORAGE_DELETE_RETRYABLE
CLOUD_STORAGE_DELETE_FAILED
```

Use the project's existing structured API error conventions.

Never expose raw SQL errors, Cloudinary response bodies, HTML error pages, internal stack traces, or secrets to users.

The project already has structured error extraction and resilient non-JSON handling; extend those conventions rather than creating a parallel error model.

---

# PHASE 38 — TEST PLAN

This implementation is incomplete without extensive tests.

## Backend unit tests

Add tests for:

- Trash transition
- Restore transition
- Permanent deletion
- idempotent permanent deletion
- lifecycle revision generation
- device checkpoints
- device expiry
- safe GC boundary
- cursor expiration
- full resync trigger
- tombstone retention
- version cleanup
- idempotency cleanup
- orphan detection
- reference counting
- Cloudinary deletion jobs
- retry logic
- already-deleted Cloudinary resource
- destruction job idempotency
- cross-user isolation
- concurrent deletion
- concurrent edit
- delete-vs-edit
- trash-vs-edit
- restore-vs-delete
- permanent-delete-vs-offline-edit
- migration behavior
- storage profiler
- dry-run GC

## Flutter tests

Add tests for:

- Trash UI
- synchronized Trash state
- Restore
- permanent deletion
- attachment association
- attachment reference updates
- orphaned-resource presentation
- Settings storage screen
- document lifecycle
- OCR cleanup
- backup/restore interactions
- sync after permanent deletion
- cursor expiration recovery
- stale device/full resync behavior

## Integration tests

Build multi-device scenarios.

At minimum:

### Scenario A

```text
Device A creates note
Device B syncs
A trashes note
B syncs
```

Expected:

```text
B sees note in Trash
```

### Scenario B

```text
A trashes note
B remains offline
A restores
B later syncs
```

Expected:

```text
B sees note active
```

### Scenario C

```text
A trashes note
B remains offline
A permanently deletes note
B reconnects
```

Expected:

```text
B does NOT resurrect note
```

### Scenario D

```text
A edits note offline
B permanently deletes note
A reconnects
```

Expected:

Existing conflict semantics are respected and no silent resurrection occurs.

### Scenario E

```text
Note contains attachment
Note permanently deleted
```

Expected:

Attachment remains only if another note references it.

### Scenario F

```text
Note contains document
Document contains OCR
Note permanently deleted
```

Expected:

All exclusive resources eventually disappear.

### Scenario G

```text
Attachment becomes orphaned
```

Expected:

It appears in Settings as orphaned and is not destroyed before the grace period.

### Scenario H

```text
GC runs twice
```

Expected:

Second run is harmless and produces no corruption.

### Scenario I

```text
GC crashes between Cloudinary deletion and DB state update
```

Expected:

Next run safely repairs the state.

### Scenario J

```text
Device cursor is older than retained history
```

Expected:

Structured cursor-expired response and correct full resync.

---

# PHASE 39 — PERFORMANCE REQUIREMENTS

Do not scan the entire database unnecessarily.

GC queries must:

- use indexes
- operate in bounded batches
- avoid loading large encrypted payloads when metadata is sufficient
- avoid decrypting content server-side
- avoid O(N²) reference analysis
- avoid unbounded result sets
- avoid giant transactions

Storage reporting must also be bounded and efficient.

The current application has already required significant performance work around avoiding full-table scans and main-thread blocking, so apply the same discipline to maintenance operations.

---

# PHASE 40 — IMPLEMENTATION ORDER

Implement in this order unless repository analysis proves another sequence safer:

### Step 1
Schema audit and design document.

### Step 2
Device checkpoint model.

### Step 3
Explicit synchronized lifecycle semantics.

### Step 4
Trash sync.

### Step 5
Restore sync.

### Step 6
Permanent deletion model.

### Step 7
Reference projection for attachments/documents.

### Step 8
Destruction jobs.

### Step 9
Cloudinary cleanup.

### Step 10
Document/OCR cleanup.

### Step 11
Version GC.

### Step 12
Idempotency GC.

### Step 13
Revision-history GC.

### Step 14
Cursor expiration/full-resync support.

### Step 15
Storage profiler.

### Step 16
Dry-run GC.

### Step 17
Scheduled/incremental GC execution.

### Step 18
Settings storage/attachment management UI.

### Step 19
Physical-compaction investigation/implementation if safely supported.

### Step 20
Full integration/regression test pass.

Do not leave placeholder implementations.

---

# PHASE 41 — CODE QUALITY

Follow existing project conventions.

Do not:

- duplicate repositories/services unnecessarily
- bypass the existing sync engine
- bypass existing authentication
- bypass existing conflict handling
- put business logic inside widgets
- expose database rows directly to presentation
- add plaintext fields for convenience
- disable tests
- weaken encryption
- suppress analyzer warnings
- introduce magic constants without documented purpose
- silently swallow cleanup failures

Prefer:

- explicit domain models
- typed lifecycle states
- typed API payloads
- transactional operations
- structured error types
- dependency injection
- deterministic test fixtures
- migration tests
- idempotent service methods

---

# PHASE 42 — FINAL VALIDATION GATES

Before considering the implementation complete, run:

```bash
cd backend
npm test
npm run build

flutter analyze
flutter test
```

Also run any relevant integration/end-to-end suites.

The handoff expects a clean static analysis and comprehensive automated testing. Preserve that standard.

Do not report success unless the actual commands pass.

---

# PHASE 43 — FINAL DELIVERABLE

When implementation is complete, provide a concise engineering report containing:

## 1. Root cause of the original storage growth

Identify exactly which tables/resources were causing the current ~15 MB growth.

Do not speculate.

Provide actual measured numbers.

## 2. Database changes

List:

- migrations
- new tables
- new columns
- indexes
- constraints

## 3. Sync protocol changes

Explain:

- Trash
- Restore
- Permanent Delete
- device checkpoints
- cursor expiration
- tombstones

## 4. GC architecture

Explain every collector and its safety rule.

## 5. Attachment lifecycle

Explain:

```text
attached
→ orphaned
→ eligible
→ destroying
→ deleted
```

## 6. Cloudinary deletion

Explain retry, idempotency, and failure handling.

## 7. Storage profiler result

Show the actual breakdown of the current database.

## 8. Test results

Report:

```text
backend tests: X passed
flutter tests: X passed
analysis: clean
integration tests: X passed
```

Only state numbers that actually occurred.

## 9. Known limitations

Explicitly state anything that could not safely be implemented because of Turso, Vercel, Cloudinary, Flutter, or existing architectural constraints.

---

# NON-NEGOTIABLE INVARIANTS

The following must never be violated:

### Privacy

The backend remains crypto-blind.

### Trash

Deleting a note moves it to synchronized Trash.

### Trash retention

Trash is retained indefinitely until explicit permanent deletion.

### Restore

Restore is synchronized.

### Permanent deletion

Permanent deletion destroys the note's exclusively-owned resources.

### Shared resources

A resource referenced by another note must never be destroyed merely because one note was deleted.

### Cloudinary

Externally stored resources must eventually be cleaned up.

### Offline synchronization

GC must never silently resurrect deleted content.

### Cursor integrity

A client must never receive a delta stream with missing revisions.

### Conflict integrity

GC must not destroy data still required for supported conflict resolution.

### Idempotency

Repeating a deletion or GC operation must be safe.

### Crash recovery

Every destructive operation must be recoverable after process termination.

### Security

Cross-user deletion must be impossible.

### Performance

GC must be incremental and bounded.

### Observability

Every cleanup operation must be diagnosable without leaking plaintext or secrets.

### Backups

Do not silently violate existing backup/restore semantics.

---

# IMPORTANT AGENT BEHAVIOR

Do not blindly implement this specification against assumptions.

First inspect the repository and reconcile this specification with the actual implementation.

Where the current architecture already provides a mechanism, extend it instead of creating a parallel mechanism.

Where the current architecture differs from this specification, choose the safest migration path and explicitly document the difference.

Do not delete production data during development/testing unless the repository's existing test infrastructure is explicitly isolated from production.

Use local/in-memory/test Turso-compatible databases for destructive tests.

For Cloudinary behavior, use mocks/fakes in unit tests and a controlled integration test path where appropriate.

Do not make irreversible production schema/data changes merely to prove the feature works.

The final result must be suitable for a production application with users who may have multiple devices, long offline periods, large note histories, attachments, documents, OCR, conflicts, backups, and intermittent network connectivity.

This subsystem should be designed as **infrastructure**, not as a one-off cleanup script.