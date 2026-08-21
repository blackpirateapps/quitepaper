# Quiet Paper — Implement Production-Grade Conflict-Aware Cloud Sync

You are implementing a production-grade synchronization and conflict-resolution system for **Quiet Paper**, an offline-first Flutter notes application with a TypeScript/Vercel backend, Turso/libSQL storage, client-side XChaCha20-Poly1305 encryption, encrypted note version history, encrypted attachments/documents, and cursor-based synchronization.

This is an implementation task, not a design exercise.

Do not merely describe the solution. Inspect the existing repository, adapt the implementation to the actual code, make all required migrations/code changes/tests/UI changes, and leave the repository in a working state.

Do not introduce placeholders, TODOs, fake implementations, mock-only behavior, "future work", or partial conflict handling.

Do not remove or weaken existing encryption, authentication, revision, idempotency, offline-first, backup, attachment, document, OCR, or version-history guarantees.

The final implementation must compile, pass tests, preserve backward compatibility where possible, and provide complete real conflict resolution.

## 1. Existing Architecture You Must Preserve

Quiet Paper is offline-first.

Local persistence uses Drift/SQLite.

Cloud sync is implemented by:

* `lib/core/sync/sync_engine.dart`
* `lib/core/sync/sync_models.dart`
* `lib/core/sync/sync_api_client.dart`
* `lib/core/sync/sync_provider.dart`
* `lib/core/database/...`
* `backend/src/sync/syncService.ts`
* `backend/src/api/handler.ts`
* `backend/src/validation/schemas.ts`

The backend stores note metadata and encrypted blobs but never plaintext note content.

The backend currently tracks revisions through `notes.revision` and an append-only `sync_changes` log and already detects stale `baseRevision` values using structured `SYNC_CONFLICT`. The existing project also has idempotency keys and push batching capped at 100 changes per request. The client already synchronizes encrypted note versions through `note_versions`, with `/sync/versions/push` and `/sync/versions/pull`. The editor treats Markdown as the canonical note representation, preserving a 1:1 relationship between source characters and editor offsets.
The project already has:

* encrypted note version history;
* non-destructive version restoration;
* offline sync queueing;
* deletion tombstones;
* encrypted attachments with stable UUIDs;
* `qp://asset/<UUID>` references;
* encrypted documents and OCR data;
* local backup/restore;
* persistent authentication and master-key storage.

Do not replace these systems. Extend them cleanly.

## 2. Primary Objective

Upgrade synchronization from:

```text
detect stale revision
    →
return SYNC_CONFLICT
```

to:

```text
detect stale revision
    →
obtain competing revision
    →
identify common ancestor
    →
decrypt locally
    →
perform deterministic 3-way merge
    →
automatically resolve safe changes
    →
persist unresolved conflicts
    →
let the user resolve only the true conflicts
    →
create a new merge revision
    →
continue normal sync
```

The backend must remain completely crypto-blind.

All plaintext comparison, merging, conflict classification, and conflict UI must happen on the trusted client after local decryption.

## 3. Non-Negotiable Data Safety Rules

Implement these invariants and test them explicitly.

### Never use last-write-wins for note content

Do not resolve content conflicts using `updatedAt`, device clock time, request order, or whichever upload happens to arrive last.

Timestamps may be metadata only.

### Never silently discard a branch

Whenever local and remote content diverge from the same ancestor, both branches must remain recoverable through version history.

### Every merge is a new revision

Never modify historical revisions in place.

A conflict resolution must create a new immutable revision/version.

### One conflicted note must not block unrelated notes

A note in `conflict_pending` must not repeatedly retry forever or prevent clean notes from synchronizing.

### Remote deletion versus local edit is a real conflict

Never automatically let deletion win against an unacknowledged edit.

### Attachment content is immutable

A referenced attachment UUID identifies an immutable encrypted object.

Removing a Markdown reference is not equivalent to immediately destroying the attachment.

### Offline-first behavior remains mandatory

No sync operation may block note editing, app startup, or local persistence.

## 4. Revision Model

Clearly distinguish these concepts throughout the implementation:

```text
serverRevision
baseServerRevision
localRevision
versionNumber
```

They must not be conflated.

Use the existing server revision as the ordering mechanism for cloud state.

Use note version numbers for the existing user-visible version-history feature.

Add ancestry/merge metadata where required to establish the relationship between revisions.

A resolved merge should conceptually form:

```text
ancestor
├── local branch
└── remote branch
       ↓
   merge revision
```

The UI does not need to expose a Git-style DAG, but the storage model must preserve enough provenance to recover either parent branch.

## 5. Backend Conflict Protocol

Extend the existing `SYNC_CONFLICT` response instead of replacing it with an opaque error.

When a push uses a stale `baseRevision`, return structured conflict information containing at minimum:

```json
{
  "code": "SYNC_CONFLICT",
  "noteId": "...",
  "baseRevision": 41,
  "serverHead": {
    "revision": 42,
    "contentCiphertext": "...",
    "contentNonce": "...",
    "encryptionKeyVersion": 1,
    "isDeleted": false,
    "deletedAt": null
  }
}
```

Use the project's actual field naming conventions rather than introducing inconsistent parallel names.

The server must never decrypt the ciphertext.

The conflict payload must contain enough information for the client to perform a merge.

The client must be able to obtain the required common ancestor locally or through existing encrypted version-history data.

If the ancestor is not available locally, add a secure revision retrieval mechanism that returns the encrypted historical blob only.

Do not send plaintext to the server.

## 6. Backend Responsibilities

The backend may perform:

* authentication;
* authorization;
* revision validation;
* optimistic concurrency;
* revision allocation;
* append-only sync logging;
* idempotency;
* encrypted historical-blob retrieval;
* conflict-state persistence if required;
* transactional conflict resolution commits.

The backend must never perform:

* plaintext Markdown diffing;
* plaintext title comparison;
* plaintext tag comparison;
* plaintext merge;
* semantic content inspection.

Preserve the existing zero-knowledge guarantee that note titles, bodies, and tags never reach the backend as plaintext.

## 7. Add a First-Class Conflict Domain

Create a client-side conflict domain under:

```text
lib/core/sync/conflict/
```

Use clean separation such as:

```text
conflict_model.dart
conflict_state.dart
conflict_detector.dart
conflict_repository.dart
conflict_resolver.dart
merge_result.dart
markdown_merge_engine.dart
metadata_merge_engine.dart
```

Use equivalent naming if the existing repository conventions require it, but preserve the architectural separation.

The system must represent a conflict explicitly.

Each conflict must contain:

```text
id
noteId
baseRevision
localRevision
remoteRevision
conflictType
state
createdAt
resolvedAt
resolutionRevision
```

Store encrypted content/branch references safely according to the existing encryption architecture.

Do not duplicate large ciphertext blobs unnecessarily when an existing local version record can be referenced.

## 8. Conflict States

Implement deterministic states:

```text
detected
autoMerged
manualRequired
resolving
resolved
```

Do not repeatedly upload an unresolved conflict.

Once a note transitions to `manualRequired`, normal sync attempts must skip that note until the user resolves it or explicitly chooses a resolution action.

Other notes continue syncing.

## 9. Local Sync Queue State

Extend the existing sync queue semantics so a conflicted note can be represented as a durable queue state.

The state must survive:

* process death;
* app restart;
* device restart;
* temporary network failure;
* authentication refresh;
* long periods offline.

Existing retry logic must not turn one unresolved conflict into an infinite HTTP loop.

## 10. Client Conflict Algorithm

Implement deterministic 3-way merging.

For a conflict:

```text
BASE
LOCAL
REMOTE
```

calculate:

```text
merge(BASE, LOCAL, REMOTE)
```

Never compare only:

```text
LOCAL vs REMOTE
```

The base is mandatory because it tells the algorithm which changes originated on each branch.

## 11. Merge Note Fields Independently

The encrypted note payload logically contains note fields such as:

```text
title
body/content
tags
```

Merge these fields independently.

A conflict in one field must not cause unrelated fields to be lost.

### Title rules

If:

```text
BASE == LOCAL
```

then remote wins.

If:

```text
BASE == REMOTE
```

then local wins.

If:

```text
LOCAL == REMOTE
```

then use that value.

If both changed differently from the base, create a title conflict.

Never silently choose using timestamp.

### Tags

Treat tags as normalized sets rather than arbitrary text.

For additions/removals, calculate operations relative to the base.

Safe independent additions must be combined.

Safe independent removals must be preserved.

Do not lose a tag merely because another device added an unrelated tag.

If the same base tag is explicitly removed by one branch and explicitly retained/modified in a conflicting way by the other branch, classify it as a metadata conflict rather than silently selecting one branch.

Respect the application's existing tag normalization rules.

## 12. Markdown 3-Way Merge Engine

The note body is canonical Markdown and must remain a plain Markdown string.

Do not migrate the note model to rich-text JSON, HTML, Delta, ProseMirror, Quill, or another alternate source of truth. The existing editor architecture explicitly treats Markdown as canonical.

Implement a production-grade 3-way Markdown merge.

The merge engine must:

* preserve unchanged base content exactly;
* apply independent local insertions;
* apply independent remote insertions;
* apply independent deletions;
* apply independent replacements;
* preserve Markdown syntax;
* preserve line endings;
* preserve meaningful whitespace;
* preserve fenced code blocks;
* preserve lists;
* preserve checklists;
* preserve blockquotes;
* preserve headings;
* preserve links;
* preserve image/document `qp://` references;
* avoid duplicate insertion of the same logical change;
* avoid silently dropping either branch.

Prefer a source-preserving line/region-aware strategy rather than normalizing the entire document before diffing.

The result should minimize changes outside actual conflict regions.

## 13. Markdown Conflict Granularity

Do not surface an entire note as conflicting when only a small region conflicts.

For example:

```text
2,000-line note
1 conflicting paragraph
```

must produce one focused conflict block, not two entire document alternatives.

Represent unresolved body conflicts with:

```text
baseText
localText
remoteText
start/end location or stable conflict identifier
```

The merged document should contain conflict objects that can be resolved independently.

## 14. Safe Markdown Merge Examples

The implementation must support these cases automatically.

### Independent additions

Base:

```markdown
# Shopping

- Milk
- Eggs
```

Local:

```markdown
# Shopping

- Milk
- Eggs
- Coffee
```

Remote:

```markdown
# Shopping

- Milk
- Eggs
- Bread
```

Result:

```markdown
# Shopping

- Milk
- Eggs
- Coffee
- Bread
```

No manual conflict.

### Same value change

Base:

```text
Meeting at 3 PM.
```

Local:

```text
Meeting at 4 PM.
```

Remote:

```text
Meeting at 4 PM.
```

Result:

```text
Meeting at 4 PM.
```

No conflict.

### Genuine replacement conflict

Base:

```text
Meeting at 3 PM.
```

Local:

```text
Meeting at 4 PM.
```

Remote:

```text
Meeting at 5 PM.
```

Result:

```text
manualRequired
```

The user must choose or edit the merged value.

## 15. Delete-versus-Edit Conflicts

Handle these cases explicitly:

```text
edit + unchanged → edit
unchanged + edit → edit
edit + independent edit → merge
edit + conflicting edit → manual conflict
delete + delete → delete
delete + unchanged → delete
unchanged + delete → delete
edit + delete → delete-vs-edit conflict
delete + edit → delete-vs-edit conflict
```

Never silently discard an edited branch.

The user must be offered:

```text
Keep edited note
Delete note
Keep both
```

## 16. Keep-Both Conflict Resolution

Implement a true Keep Both option.

When the user chooses Keep Both:

* preserve the original note UUID and branch;
* create a new UUID for the second branch;
* make the second note's title deterministic and human-readable;
* append `(Conflict Copy)` or equivalent project-consistent suffix;
* preserve all content/tags/metadata from the selected branch;
* record provenance linking the conflict copy to the original note;
* queue the new note for normal cloud sync;
* ensure the operation is idempotent.

Never create multiple copies if the same resolution request is retried.

## 17. Conflict Resolution UI

Do not interrupt active writing with a blocking modal.

Use passive indicators in the existing Settings/sync state and note list.

Examples of intended UX:

```text
Cloud Sync
1 note needs attention
```

and a subtle conflict indicator on the affected note.

Opening conflict resolution should provide a dedicated screen/sheet.

Display:

```text
Your version
Other device
Merged result
```

For body conflicts, show only actual conflict regions.

Provide actions:

```text
Use mine
Use theirs
Edit merged text
```

For title:

```text
Use mine
Use theirs
Edit
```

For delete-vs-edit:

```text
Keep edited note
Delete note
Keep both
```

For tags:

```text
Keep merged tags
Adjust tags
```

The user should not have to manually compare two entire documents if most of the note was already safely merged.

## 18. Conflict Resolution Editing

The merged result must be editable before finalizing.

The editor must preserve:

* Markdown source;
* cursor/selection behavior;
* existing Markdown WYSIWYG behavior;
* native undo/redo;
* formatting operations;
* checklist behavior;
* links;
* image references;
* document references.

The conflict screen may use the existing Markdown editor infrastructure rather than inventing a separate editing engine.

## 19. Conflict Resolution Commit

When the user resolves a conflict:

1. Save the current conflicted branch as a version if it is not already represented in version history.
2. Preserve the remote branch.
3. Preserve the common ancestor.
4. Create a new merged local version.
5. Mark the conflict `resolved`.
6. Set the new note state to dirty/pending synchronization.
7. Set `baseServerRevision` to the remote server head used during conflict resolution.
8. Queue the merged revision for upload.
9. Ensure the server accepts it atomically.
10. Do not delete historical branches.

The merged revision must become the new authoritative server revision only after successful push.

## 20. Merge Provenance

Extend version metadata so a merge revision can record:

```text
versionNumber
baseRevision
localParentRevision
remoteParentRevision
mergeType
resolutionSummary
```

Possible merge types:

```text
auto
manual
keepMine
keepTheirs
keepBoth
delete
restore
```

Existing user-visible version history must remain functional.

A merge revision must appear in version history with understandable information such as:

```text
Merged changes from another device
```

Do not expose internal UUIDs unnecessarily.

## 21. Version History Integration

Quiet Paper already keeps up to 50 note versions and synchronizes encrypted note versions. Preserve this behavior.

Do not allow automatic conflict resolution to overwrite or prune away the branches required to recover from the conflict.

If pruning could remove a conflict ancestor or parent branch needed for recovery, protect that version until the conflict is fully resolved and synchronized.

After resolution succeeds, normal pruning may resume according to the existing retention policy.

## 22. Attachment Conflict Rules

Attachments use stable UUIDs and encrypted blobs.

A Markdown merge should treat:

```markdown
![Image](qp://asset/<UUID>)
```

as a reference to an immutable logical object.

### Safe case

Base:

```markdown
Hello
```

Local:

```markdown
Hello

![A](qp://asset/A)
```

Remote:

```markdown
Hello

![B](qp://asset/B)
```

Merged result:

```markdown
Hello

![A](qp://asset/A)

![B](qp://asset/B)
```

No attachment conflict.

### Reference removal

If one branch removes an attachment reference while another branch still references it:

* do not immediately destroy the attachment;
* preserve the local/cloud attachment record;
* let unreferenced-object cleanup happen later.

### Attachment garbage collection

Implement conservative garbage collection.

An attachment may be physically removed only when it is proven not to be referenced by:

* the current note;
* retained note versions;
* unresolved conflict branches;
* pending sync operations;
* restored backup state requiring it;
* another note where the existing schema permits shared references.

Never delete attachment data merely because one note revision stopped referencing it.

## 23. Documents and OCR

Apply the same preservation principle to:

```text
qp://document/<UUID>
```

and associated encrypted document/OCR data.

Do not delete a document or OCR data merely because a single merged branch removes a reference.

Respect the existing encrypted OCR design and on-device processing architecture. Plaintext OCR data must remain client-side.

## 24. Ordering of Sync Operations

Refactor `SyncEngine.syncNow()` into explicit phases:

```text
1. validate local state
2. pull remote changes
3. apply non-conflicting remote changes
4. detect locally dirty notes
5. push clean local changes in batches
6. process stale-revision conflicts
7. fetch remote heads/ancestors as required
8. run local conflict resolution
9. persist automatic merges
10. persist manual conflicts
11. enqueue resolved merges
12. push automatic merges
13. push resolved merges
14. pull resulting authoritative revisions
15. finalize cursor/state
```

A conflict in one note must not interrupt processing of unrelated notes.

## 25. Push Batching

Preserve the existing backend maximum of 100 changes per push request.

The current system already chunks note changes and version changes into batches of at most 100 items. Do not regress this behavior.

When conflict retries create additional merge work, continue to batch at 100 or less.

Every retriable request must remain idempotent.

## 26. Idempotency

Conflict resolution must be safe under:

* HTTP retry;
* timeout after server commit;
* app crash after local commit;
* app crash after remote commit;
* repeated Sync Now;
* duplicated foreground/background sync triggers.

Generate deterministic or persisted operation identifiers for merge commits where appropriate.

Never create duplicate notes, duplicate conflict copies, duplicate versions, or duplicate server revisions because a request was retried.

## 27. Cursor Safety

Do not advance the local sync cursor past remote changes that have not been durably applied.

If a sync batch partially succeeds:

* preserve all successfully applied changes;
* preserve all unapplied changes;
* leave the cursor at the last fully durable point;
* retry safely.

Do not skip a remote change merely because a conflict occurred in another note.

## 28. Remote Pull Deletion Safety

Preserve the existing fix where remotely received deletions are applied locally without re-enqueuing them for push.

The project already introduced an `enqueueSync: false` mechanism for pulled deletions. Do not regress this behavior.

Extend the same principle to conflict resolution operations.

## 29. Backup Compatibility

The local `.qpbackup` system already supports merge/keep-both/clean-replace restore strategies and restored notes are marked dirty for cloud synchronization.

Extend backups so that:

* unresolved conflicts can be backed up safely;
* conflict metadata is preserved;
* branch/version provenance remains recoverable;
* restored conflicts do not create duplicate conflict records;
* restored notes continue using the normal sync engine.

Do not break existing backup files.

If an older backup lacks conflict metadata, treat it as a normal historical snapshot.

## 30. Migration Strategy

Add proper Drift migrations and backend SQL migrations.

Do not edit existing migration files that may already have been applied in production.

Create new numbered migrations.

Backend migration(s) must be transactional where Turso/libSQL semantics allow.

Flutter migrations must support upgrading an existing installation from the current production schema without data loss.

Do not require users to reinstall.

Do not delete existing note/version/attachment data during migration.

## 31. Suggested Local Database Structures

Use the existing schema conventions, but add the equivalent of:

### Conflict table

```text
sync_conflicts
id
note_id
base_revision
local_revision
remote_revision
conflict_type
state
created_at
resolved_at
resolution_revision
```

### Optional branch metadata

Use existing version records whenever possible rather than duplicating encrypted data.

### Queue state

Extend `sync_queue` with an explicit conflict state if the current queue model supports it cleanly.

Do not introduce duplicate sources of truth for queue entries.

## 32. Suggested Backend Structures

Use the existing `notes`, `sync_changes`, `note_versions`, and idempotency architecture.

Add only what is necessary for:

* encrypted historical revision retrieval;
* ancestry/provenance;
* merge commit validation;
* conflict-aware idempotency.

Do not create a server-side plaintext conflict system.

## 33. Conflict Retrieval Endpoint

Implement a proper encrypted conflict retrieval path.

A client that detects a stale revision must be able to retrieve the competing encrypted server state without needing the server to understand its plaintext.

The response must be authenticated and scoped to the current user.

Never permit one user's note ciphertext to be queried using another user's note ID.

Enforce ownership exactly as existing sync APIs do.

## 34. Security Requirements

Preserve:

* Firebase authentication;
* encryption-password separation;
* Master Key security;
* XChaCha20-Poly1305;
* note-bound AAD;
* attachment-bound AAD;
* encryption-key version checks;
* crypto-blind backend behavior.

The backend must not log ciphertext unnecessarily.

Never log:

* plaintext title;
* plaintext body;
* plaintext tags;
* decrypted OCR;
* decrypted attachment data;
* encryption keys.

Conflict diagnostics may include:

```text
noteId
revision numbers
conflict type
state
device ID
timestamps
operation IDs
```

but never plaintext.

## 35. Encryption Details

Use the existing crypto implementation rather than creating a second crypto stack.

Existing note content uses the Master Key with XChaCha20-Poly1305 and note-bound AAD.

Existing attachment encryption uses XChaCha20-Poly1305 with asset-bound AAD.

Existing OCR data is encrypted client-side.

Do not change these primitives unless the current code requires a bug fix and the fix is compatible with existing stored data.

## 36. Conflict Detection Must Be Deterministic

Two identical inputs:

```text
BASE
LOCAL
REMOTE
```

must always produce the same:

```text
merge classification
merged content
conflict regions
conflict type
```

Do not make conflict classification dependent on:

* current time;
* device ID;
* network order;
* map iteration order;
* database row ordering without explicit sorting.

## 37. Stable Conflict Ordering

When multiple conflict regions exist, order them by document source offset.

When displaying them, preserve the same order in every run.

When applying multiple user resolutions, use stable identifiers rather than fragile line numbers whenever practical.

## 38. Markdown Parser Interaction

Do not modify the editor parser merely for cosmetic reasons.

The existing parser deliberately preserves exact source offsets and IME behavior.

Merged Markdown must be passed through the same source-of-truth editing pipeline.

Do not create a second normalized Markdown representation.

Do not change whitespace semantics.

## 39. Conflict Indicators

Add a subtle, consistent visual indication to the existing Quiet Paper aesthetic.

Do not introduce noisy Material cards.

The user should be able to understand:

```text
Syncing...
Offline • Changes saved locally
All notes synced
1 note needs attention
```

using the current Settings and sync visual language.

## 40. Sync Status Model

Extend `SyncState` or equivalent so it can represent:

```text
idle
syncing
offline
success
error
conflictsPending
```

with:

```text
pendingConflictCount
```

or an equivalent derived value.

Do not expose raw exception strings in the UI.

The project already improved structured sync error extraction; preserve that behavior.

## 41. Settings UI

Extend the existing Cloud Sync section.

When there are conflicts:

```text
Cloud Sync
1 note needs attention
```

Tapping it opens the conflict list.

The conflict list must show:

* note title when safely available locally;
* conflict type;
* relative time;
* concise explanation;
* resolution action.

Do not expose encrypted/internal IDs.

Provide:

```text
Review
```

for each conflict.

## 42. Conflict List

Implement:

```text
Sync Conflicts
```

with entries such as:

```text
Project Meeting
Edited on another device
Needs review
```

or:

```text
Shopping List
Both devices edited the same section
Needs review
```

or:

```text
Research Notes
One device deleted this note
Needs review
```

Resolved conflicts should leave the list and remain available through version history.

## 43. User Resolution Guarantees

When the user chooses:

```text
Use mine
```

do not mutate the stored remote branch.

When the user chooses:

```text
Use theirs
```

do not mutate the stored local branch.

When the user chooses:

```text
Keep both
```

preserve both.

When the user edits a merged result:

```text
store the final user-authored content as the authoritative merge result
```

Always retain the pre-resolution branches.

## 44. Automatic Resolution Policy

The implementation must automatically resolve:

* unchanged fields;
* same-value changes;
* independent title/body/tag changes;
* independent Markdown insertions;
* independent Markdown deletions;
* independent Markdown replacements;
* independent attachment additions;
* independent metadata additions.

The implementation must require user intervention for:

* same-region divergent text edits;
* contradictory title edits;
* contradictory tag operations;
* delete-vs-edit;
* structurally ambiguous Markdown replacements;
* unresolved attachment/document semantic collisions.

When in doubt, prefer a visible conflict over silent data loss.

## 45. No False-Positive Conflict Flood

Do not classify every simultaneous edit as a conflict.

A large note edited independently on two devices should merge automatically wherever the changed regions do not overlap.

Examples to test:

```text
device A edits heading
device B edits last paragraph
→ automatic merge

device A adds checklist item
device B adds unrelated checklist item
→ automatic merge

device A adds an image
device B adds a document reference
→ automatic merge

device A modifies title only
device B modifies body only
→ automatic merge
```

## 46. Concurrent Checklist Editing

Because Quiet Paper supports Markdown checklists, explicitly test concurrent changes such as:

Base:

```markdown
- [ ] Buy milk
- [ ] Buy eggs
```

Local:

```markdown
- [x] Buy milk
- [ ] Buy eggs
```

Remote:

```markdown
- [ ] Buy milk
- [x] Buy eggs
```

The result should retain both independent checklist state changes.

Do not corrupt Markdown syntax.

## 47. Concurrent Markdown Formatting

Test simultaneous edits involving:

* headings;
* bold;
* italic;
* strike;
* code;
* links;
* lists;
* blockquotes;
* checklists;
* highlights;
* images;
* document references.

The merged result must remain valid Markdown and preserve source fidelity.

## 48. Version-History Recovery

Add tests proving that after a merge:

* the ancestor remains inspectable;
* local branch remains inspectable;
* remote branch remains inspectable;
* merge revision is inspectable;
* restoring an old branch creates another normal version rather than mutating history.

Existing non-destructive version restoration must continue to work.

## 49. Server-Side Tests

Expand backend tests for:

* stale base revision;
* conflict payload;
* encrypted server-head retrieval;
* correct ownership checks;
* idempotent conflict retries;
* merge commit validation;
* concurrent pushes;
* revision ordering;
* cursor behavior;
* deletion conflicts;
* duplicate merge request;
* duplicate keep-both request;
* malformed conflict data;
* invalid revision ancestry;
* unauthorized revision access.

The backend test suite already covers sync and conflict detection. Extend it rather than replacing it.

## 50. Flutter Unit Tests

Add deterministic unit tests for:

### Metadata merge

* unchanged/local/remote;
* same values;
* divergent titles;
* tag addition;
* tag removal;
* contradictory tag operations.

### Markdown merge

* independent insertions;
* independent deletions;
* independent replacements;
* same-region conflicts;
* adjacent edits;
* identical edits;
* multiline edits;
* headings;
* lists;
* checklists;
* code fences;
* blockquotes;
* links;
* images;
* documents;
* whitespace;
* line endings.

### Delete conflicts

* edit vs delete;
* delete vs edit;
* delete vs delete.

### Attachments

* independent additions;
* reference removal;
* retained old versions;
* cleanup safety.

### Conflict persistence

* create;
* reload;
* resolve;
* retry;
* restart.

## 51. Integration Tests

Create realistic multi-device simulations:

### Scenario A — offline independent editing

```text
Device A offline
Device B offline
Both edit same note
A reconnects and syncs
B reconnects and syncs
```

Expected:

* no data loss;
* deterministic merge;
* conflict only where necessary.

### Scenario B — conflicting same paragraph

Expected:

* one conflict region;
* both edits preserved;
* no unrelated text lost.

### Scenario C — delete versus edit

Expected:

* conflict presented;
* all three choices work;
* historical branches remain recoverable.

### Scenario D — attachment race

Expected:

* no broken `qp://asset` references;
* no premature attachment deletion.

### Scenario E — 150+ dirty notes

Expected:

* batching still works;
* conflicts do not prevent later batches;
* 100-item backend limit never violated.

The current system already has explicit 100-item batching tests; preserve and extend them.

### Scenario F — network failure after server commit

Expected:

* retry does not create duplicate revision;
* local state eventually converges.

### Scenario G — process killed during conflict resolution

Expected:

* conflict remains recoverable;
* no partial data loss;
* subsequent sync is idempotent.

## 52. Property-Style Invariants

Add tests for:

```text
merge(base, base, remote) == remote
merge(base, local, base) == local
merge(base, local, local) == local
merge(base, remote, remote) == remote
```

For independently changed disjoint regions:

```text
merge(base, local, remote)
```

must retain both changes.

For conflicting regions:

```text
status == manualRequired
```

and neither branch may disappear.

## 53. Convergence Requirement

Two devices that eventually receive all revisions and make identical conflict-resolution choices must converge to the same final note content and metadata.

Repeated sync operations after convergence must be no-ops.

There must be no endless "changed again" loop caused solely by sync reconciliation.

## 54. No Sync Ping-Pong

A merge result pushed by Device A and pulled by Device B must not cause Device B to generate a semantically identical new merge revision.

Use revision/base information correctly so identical resolved states converge.

## 55. Conflict Resolution Across App Restart

Persist enough state so this sequence works:

```text
conflict detected
app killed
app restarted
user returns to note
user resolves conflict
sync succeeds
```

No conflict data may exist only in RAM.

## 56. Conflict Resolution While Offline

If the user has:

```text
local branch
remote conflict branch already fetched
```

the user must be able to resolve the conflict completely offline.

The resulting merge is then queued for synchronization.

Do not require network access merely to choose the final merged content.

## 57. Conflict Resolution During Version History Restore

If the user restores an older version while a conflict is pending:

* preserve the conflict;
* create a normal new version from the restored state;
* require the conflict system to rebase the eventual pending resolution against the current authoritative server revision.

Do not silently discard the pending conflict.

## 58. Rebase Stale Conflicts

If the user leaves a conflict unresolved while another device creates new revisions, the conflict system must not become invalid.

Before finalizing a manual resolution:

1. determine the current server head;
2. determine whether the selected resolution still applies cleanly;
3. rebase the resolution where possible;
4. otherwise produce a new focused conflict.

Never blindly push against a newer head.

## 59. Automatic Rebase

If:

```text
conflict was created from server revision 42
current server head is 43
```

and revision 43 is independent of the user's conflicting region, automatically rebase the resolution and continue.

If revision 43 touches the same region, surface the newly created conflict.

## 60. Conflict Resolution Auditability

Keep enough local metadata to explain:

```text
what conflicted
which revisions participated
how it was resolved
when it was resolved
```

Do not expose sensitive implementation details to the user, but make debugging possible.

## 61. Logging

Add structured sync diagnostics.

Useful values:

```text
syncOperationId
noteId
baseRevision
localRevision
remoteRevision
mergeStatus
conflictType
resolutionType
duration
```

Never log plaintext content.

Use the application's existing logging conventions.

## 62. Performance

The merge engine must run off the UI thread for large notes where necessary.

Do not freeze the editor when merging long Markdown files.

Use isolate/background computation if the final implementation demonstrates it is required.

Do not optimize prematurely by sacrificing correctness.

## 63. Large Notes

Explicitly test notes containing:

* 10,000+ lines;
* long code blocks;
* many Markdown links;
* many checklist items;
* many image references.

The merge must remain practical and must not duplicate the entire document excessively in memory.

## 64. Database Transactions

Local resolution operations affecting:

```text
note
versions
sync queue
conflict state
attachments/reference state
```

must use a transaction wherever Drift supports it.

The system must not end up with:

```text
conflict marked resolved
but merge version missing
```

or:

```text
merge version exists
but sync queue entry missing
```

## 65. Backend Transactions

A merge commit or conflict-aware revision acceptance must be atomic.

Do not create a `notes` revision without its corresponding `sync_changes` entry.

Do not create a `sync_changes` entry without the corresponding note state.

Do not consume an idempotency key for a failed transaction.

## 66. API Validation

Extend Zod schemas for all new fields.

Validate:

* UUIDs;
* revision numbers;
* enum values;
* ciphertext and nonce constraints;
* conflict-state values;
* payload size;
* operation IDs.

Preserve the existing tombstone behavior where deleted notes can legally contain empty ciphertext/nonce values.

## 67. Backward Compatibility

Existing clients may not understand the new conflict payload.

Do not break ordinary pushes from the current implementation unexpectedly.

Where possible:

* preserve existing successful push response fields;
* preserve `SYNC_CONFLICT` as the error code;
* add additional structured fields;
* ensure unsupported conflict-resolution endpoints fail clearly.

The repository should remain internally consistent after the implementation.

## 68. Existing Sync Behavior That Must Not Regress

Verify all existing guarantees still work:

* offline local writes;
* autosave;
* sync queue persistence;
* push batching;
* pull cursor;
* idempotency;
* deletion tombstones;
* pulled deletion queue suppression;
* version synchronization;
* encryption-key versions;
* authentication;
* attachment sync;
* document sync;
* OCR sync;
* backups;
* version history.

## 69. UI Regression Requirements

Do not redesign the overall Quiet Paper visual system.

Use the existing warm editorial / Bear-like design language.

Do not introduce:

* large noisy cards;
* generic Material conflict dialogs;
* aggressive red warning banners;
* unnecessary blocking flows.

Conflict UI should feel like a natural extension of the existing app.

## 70. Documentation

Update:

```text
docs/sync-protocol.md
```

with the actual implemented protocol.

Document:

* revision model;
* conflict detection;
* conflict response payload;
* client-side 3-way merge;
* conflict states;
* deletion behavior;
* attachment behavior;
* merge commits;
* idempotency;
* cursor semantics;
* recovery;
* encryption boundary;
* test strategy.

Update the engineering handoff document with the completed implementation.

Do not document behavior that is not actually implemented.

## 71. Do Not Fake the Merge Engine

Do not implement conflict handling using:

```text
if localUpdatedAt > remoteUpdatedAt
```

Do not implement:

```text
choose local
```

Do not implement:

```text
choose remote
```

Do not insert raw conflict markers such as:

```text
<<<<<<< LOCAL
=======
>>>>>>> REMOTE
```

into the production note content unless the user explicitly chooses a raw-text conflict representation.

The user-facing result should be a clean Markdown document.

## 72. No Silent Fallback

If a merge cannot safely determine the correct result:

```text
manualRequired
```

is the correct outcome.

Do not invent semantics.

The principle is:

> Prefer a visible conflict over silent data loss.

## 73. Implementation Sequence

Follow this order:

### Phase 1 — Repository inspection

Inspect the actual implementations of:

```text
sync_engine.dart
sync_models.dart
sync_api_client.dart
sync queue tables/DAO
notes table/DAO/repository
note version models/storage
backend syncService.ts
backend validation schemas
backend sync migrations
API handler
attachment storage/sync
backup models/services
Settings sync UI
VersionHistory UI
```

Do not guess existing method signatures or schema details.

### Phase 2 — Protocol

Implement backend revision/conflict protocol and migrations.

### Phase 3 — Client domain

Implement conflict models, persistence, merge engine, and tests.

### Phase 4 — Sync engine integration

Integrate conflict detection, retrieval, merge, persistence, rebasing, and queue state.

### Phase 5 — UI

Implement conflict indicators, conflict list, focused conflict resolver, and Settings integration.

### Phase 6 — Attachments/documents

Verify preservation and garbage-collection safety.

### Phase 7 — Backup/version-history integration

Persist and restore conflict-related state correctly.

### Phase 8 — Exhaustive tests

Run backend and Flutter suites.

### Phase 9 — Static validation

Run:

```bash
flutter analyze
flutter test
cd backend && npm run build
cd backend && npm test
```

Fix all errors, warnings, test failures, race conditions, and schema-generation issues.

## 74. Generated Code

If Drift schema changes require code generation, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Commit/update all generated code required by the repository.

Do not leave generated files inconsistent.

## 75. Acceptance Criteria

The implementation is complete only when all of these are true:

```text
[ ] Conflict detection still returns SYNC_CONFLICT for stale revisions.
[ ] Conflict responses contain enough encrypted data for client resolution.
[ ] Server never decrypts or merges note content.
[ ] Client performs true 3-way merges.
[ ] Common-ancestor semantics are enforced.
[ ] Independent Markdown edits merge automatically.
[ ] Same-region divergent edits become focused conflicts.
[ ] Title conflicts are handled independently.
[ ] Tags use set-aware merging.
[ ] Delete-vs-edit is explicit.
[ ] Keep Both is implemented and idempotent.
[ ] Attachments are preserved safely.
[ ] Documents and OCR references are preserved safely.
[ ] Conflicts survive app restarts.
[ ] Conflicts do not block unrelated notes.
[ ] Unresolved conflicts do not retry forever.
[ ] Resolutions can happen offline.
[ ] Resolutions create immutable merge revisions.
[ ] Historical branches remain recoverable.
[ ] Version history displays merge revisions.
[ ] Stale conflicts can be rebased.
[ ] Sync converges across devices.
[ ] No sync ping-pong occurs.
[ ] 100-item push batching remains intact.
[ ] Idempotency remains intact.
[ ] Cursor advancement remains safe.
[ ] Pulled deletion behavior does not regress.
[ ] Backup/restore remains compatible.
[ ] Existing attachment/document sync remains functional.
[ ] No plaintext reaches the backend.
[ ] No plaintext is logged.
[ ] Drift migrations are backward-compatible.
[ ] Backend migrations are production-safe.
[ ] Flutter tests pass.
[ ] Backend tests pass.
[ ] Flutter analyze passes.
[ ] Backend build passes.
[ ] No TODO/placeholders remain.
```

## 76. Required Final Agent Report

When implementation is complete, report:

```text
1. Files changed
2. Database migrations added
3. Backend API changes
4. Sync-engine changes
5. Merge algorithm implemented
6. Conflict UI implemented
7. Attachment/document handling changes
8. Backup/version-history changes
9. Tests added
10. Commands executed
11. Test/build/analyze results
12. Any compatibility considerations
```

Do not claim success unless the corresponding commands actually pass.

Do not omit failed tests.

Do not stop after implementing the backend. The feature is incomplete until the Flutter client, persistence, conflict UI, merge engine, version history, attachments, backups, and test suites all work together.

## Final engineering principle

Quiet Paper must behave as though each device has its own branch of the user's notebook, while making that complexity invisible during normal use.

The system must be:

```text
offline-first
zero-knowledge
revision-aware
three-way-merge based
conflict-preserving
idempotent
crash-safe
attachment-safe
version-history aware
deterministic
convergent
non-destructive
```

When there is a safe automatic answer, resolve it silently.

When there is not a safe automatic answer, preserve every branch and ask the user to resolve only the genuinely ambiguous portion.

Never silently destroy user-authored content.
