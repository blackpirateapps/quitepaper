# Quiet Paper — Flagship Coding-Agent Implementation Prompt

You are implementing the next major feature phase of **Quiet Paper**, an offline-first Flutter notes application with a Bear-inspired editorial UI, local Drift/SQLite persistence, client-side zero-knowledge encryption, Firebase authentication, Vercel/TypeScript backend services, Turso/libSQL metadata storage, and direct Cloudinary object storage.

The repository already contains image attachment support. Your task is to implement a **production-quality Scan Documents feature** that integrates completely with the existing architecture.

This is **not** a greenfield redesign.

You MUST inspect the actual repository first and preserve existing architecture, naming conventions, crypto primitives, database patterns, sync behavior, UI patterns, and tests.

The existing project explicitly treats Markdown as the canonical note representation and performs client-side encryption before network transfer. Preserve those invariants.

The existing editor deliberately maintains the underlying Markdown source as the canonical representation with 1:1 cursor/selection correspondence rather than introducing a separate rich-text document model. Do not replace that architecture.

---

# 1. The Feature Being Implemented

Add a dedicated **Scan Document** feature.

The user should be able to:

1. Open the document scanner directly from the note editor.
2. Capture one or more physical document pages.
3. Have the scanner automatically detect the page/document boundary.
4. Automatically normalize the captured page for document presentation.
5. Continue scanning additional pages without leaving the scanner.
6. Retake a page.
7. Remove a page.
8. Reorder pages.
9. Finish the scan.
10. Have Quiet Paper generate a PDF locally.
11. Encrypt the PDF locally.
12. Persist the encrypted document locally.
13. Insert a stable internal document reference into the Markdown note.
14. Continue editing immediately without waiting for a network upload.
15. Upload the encrypted PDF directly from the Flutter client to Cloudinary.
16. Synchronize document metadata/state through the existing Vercel/Turso sync architecture.
17. Download/decrypt/view the document on another device.
18. Continue to work completely offline.

The canonical scanned-document resource is a **PDF**, not a collection of ordinary image attachments.

---

# 2. Final Resource URI Architecture

Quiet Paper now has three intentionally distinct internal resource types:

```text
qp://asset/<UUID>
qp://document/<UUID>
qp://note/<UUID>
```

Meaning:

```text
qp://asset/<UUID>
    Ordinary image/file attachment.

qp://document/<UUID>
    Scanned multi-page document whose canonical binary payload is a PDF.

qp://note/<UUID>
    Another Quiet Paper note.
    This is a future note-linking resource and MUST be architecturally supported now,
    but its full user-facing linking feature is NOT part of this implementation.
```

The `qp://` namespace is a first-class internal Quiet Paper resource URI scheme.

Do NOT treat these as ordinary external URLs.

Do NOT route them through the existing external-link trust confirmation flow.

Do NOT send them to the system browser.

The existing app has domain-based external hyperlink safety behavior; internal `qp://` resources must be resolved inside Quiet Paper instead.

---

# 3. Canonical Markdown Representation

A scanned document must be represented in Markdown as:

```markdown
[Scanned Document](qp://document/<UUID>)
```

Example:

```markdown
Receipt — August

[Scanned Document](qp://document/550e8400-e29b-41d4-a716-446655440000)
```

The UUID identifies the document.

The display text is presentation only.

The document title/display text MUST NOT become the document's identity.

Do not use:

```markdown
[Scanned Document](https://res.cloudinary.com/...)
```

Do not use local filesystem paths.

Do not embed PDF bytes in Markdown.

Do not base64-encode PDFs into Markdown.

Do not create a proprietary Markdown syntax for scanned documents.

The existing Markdown source must remain canonical.

---

# 4. Internal URI Abstraction

Create or extend a centralized `QuietPaperUri` abstraction.

Do NOT scatter raw string checks throughout the application.

The URI parser must conceptually expose:

```text
scheme
resourceType
resourceId
```

Examples:

```text
qp://asset/abc
    scheme = qp
    resourceType = asset
    resourceId = abc

qp://document/def
    scheme = qp
    resourceType = document
    resourceId = def

qp://note/ghi
    scheme = qp
    resourceType = note
    resourceId = ghi
```

The exact Dart naming can follow repository conventions, but there must be one centralized implementation.

The parser must:

* validate the scheme
* validate the resource type
* validate the resource ID
* reject malformed URIs safely
* reject unsupported resource types safely
* support serialization back to canonical URI form
* support equality
* support deterministic parsing
* have unit tests

The resource system must be extensible.

Do not create a separate parser implementation for `asset`, `document`, and `note`.

---

# 5. Resource Resolution Architecture

Separate URI parsing from resource resolution.

The architecture should conceptually be:

```text
Markdown
    ↓
QuietPaperUri parser
    ↓
QuietPaperUri
    ↓
ResourceResolver
    ├── AssetResolver
    ├── DocumentResolver
    └── NoteResolver
```

`DocumentResolver` must be implemented now.

`NoteResolver` must exist architecturally for future note-to-note navigation, but do not build the full note-linking UX in this feature.

The Markdown parser must not:

* directly query Drift
* directly call Cloudinary
* directly perform navigation
* directly decrypt documents

The parser identifies the resource.

A higher presentation/application layer resolves and renders it.

---

# 6. Scanner Button Placement

The current editor already has an image attachment button in the formatting/insertion toolbar.

Add the **Scan Document button immediately next to the existing image attachment button**.

The scanner button must be a dedicated scanner/document icon rather than reusing the generic image icon.

Conceptually:

```text
...   link   image   scan   #
```

Do NOT hide document scanning behind the existing image button unless the repository's current toolbar mechanics make a dedicated adjacent button technically impossible.

The design goal is explicit discoverability:

* image button = attach image
* scanner button = scan document

Do not make the editor toolbar visually noisy.

Follow Quiet Paper's existing warm editorial/Bear-like styling, typography, spacing, hit targets, light/dark themes, and tablet behavior.

---

# 7. Read-Only Mode

Quiet Paper already supports note-level read-only mode.

When a note is read-only:

* scanner button must not allow a scan
* document insertion must be disabled
* document deletion must be disabled
* document replacement must be disabled
* Markdown document references must remain non-editable according to existing read-only behavior

Viewing an already-existing document remains permitted if consistent with the current read-only experience.

Do not bypass read-only mode with document-specific UI.

---

# 8. Scanner UX

The scanner must use a dedicated full-screen scanner workflow.

Conceptually:

```text
┌──────────────────────────────────────┐
│  ×                              ⋯    │
│                                      │
│                                      │
│          LIVE CAMERA PREVIEW         │
│                                      │
│        ┌────────────────────┐        │
│        │                    │        │
│        │      DOCUMENT      │        │
│        │                    │        │
│        └────────────────────┘        │
│                                      │
│                                      │
│                  ●                   │
│                                      │
│      Pages: 1                         │
└──────────────────────────────────────┘
```

The exact visual design should follow the existing app's visual language.

The scanner must clearly communicate:

* camera preview
* document boundary when detected
* capture state
* page count
* close/cancel
* completion
* additional pages

Do not display technical debugging information.

---

# 9. Document Detection

The scanner must support automatic document/page boundary detection.

The implementation should:

1. Analyze the camera preview for a document-like rectangular page.
2. Identify the page boundary.
3. Display a subtle visual indication when a page is confidently detected.
4. Capture a normalized document page when appropriate.
5. Fall back gracefully when automatic detection cannot confidently find a page.

Do not require the user to manually draw four crop corners.

Do not introduce a manual crop UI.

Do not add a full image editor.

If automatic detection is unavailable on a particular device/platform, provide a safe fallback capture mode that still allows the user to take the page normally.

The user experience should remain useful even if document detection is imperfect.

---

# 10. Automatic Document Normalization

Automatic document normalization IS part of the scanner.

The scanner may:

* correct perspective automatically
* normalize page geometry
* orient the page appropriately
* produce a clean document-page representation

This does NOT constitute a user-facing image-editing feature.

The following are explicitly NOT allowed:

* manual crop
* manual rotate
* brightness editor
* contrast editor
* filters
* markup
* drawing
* annotations
* image editing controls

The scanner performs automated acquisition/normalization only.

---

# 11. Multi-Page Scanning

A single scan session must support multiple pages.

After capturing page one, the user remains in the scanner workflow.

Conceptually:

```text
Page 1       Page 2       Page 3       +
```

The page manager must support:

* add page
* retake page
* delete page
* reorder pages

Reordering is document organization, not image editing.

Do not add manual image-editing capabilities.

The scanner session must not finalize until the user chooses Done/Finish.

---

# 12. Scanner Completion

When the user taps Done:

```text
Captured pages
      ↓
Validate pages
      ↓
Assemble PDF locally
      ↓
Persist local document
      ↓
Encrypt PDF locally
      ↓
Persist encrypted document
      ↓
Insert Markdown reference
      ↓
Return to editor immediately
      ↓
Background synchronization
```

The user must not wait for Cloudinary.

The note must become usable immediately after local PDF creation/persistence.

---

# 13. PDF Is the Canonical Scanned Document

This is a hard requirement.

The **canonical scanned document payload is a PDF**.

Cloudinary stores the encrypted PDF.

Do NOT treat individual scanned pages as the canonical cloud representation.

Do NOT store a multi-page scan as five unrelated `qp://asset/...` image references.

The note contains one resource reference:

```markdown
[Scanned Document](qp://document/<UUID>)
```

The document resource contains the complete PDF.

The PDF is the authoritative document representation.

---

# 14. Local Document Model

Create a first-class document/scan model.

Conceptually:

```text
Document
────────────────────────
id
noteId
createdAt
updatedAt

mimeType
byteSize
pageCount

sha256

encryptionKeyVersion

isDirty
isDeleted
serverRevision
syncedAt

uploadState

cloudObjectId
cloudVersion / cloud metadata
```

The exact field names should follow repository conventions.

The semantic requirements are mandatory.

The document ID is a stable UUID.

The PDF bytes are not stored inside the Markdown note.

---

# 15. Document Pages

The scanner UI needs an intermediate page model while scanning.

Conceptually:

```text
ScanSession
 ├── Page 1
 ├── Page 2
 ├── Page 3
 └── Page 4
```

Each temporary page may contain:

* local temporary image data/path
* dimensions
* capture ordering
* detected geometry if needed for processing
* processing state

Once the PDF has been generated, the document's canonical stored payload is the PDF.

Do not unnecessarily persist every temporary page as a permanent cloud attachment.

Clean temporary scan-page files after successful PDF generation/persistence.

If a page is needed for retry before PDF generation completes, retain it locally until the scan operation finishes or is cancelled safely.

---

# 16. PDF Generation

Generate the PDF locally on the device.

The PDF generation pipeline must:

* preserve page order
* preserve all captured pages
* use appropriate page dimensions
* produce a standards-compliant PDF
* avoid unnecessary quality loss
* handle multiple pages
* fail gracefully
* clean up temporary data on failure

The PDF MIME type must be:

```text
application/pdf
```

Do not generate the canonical PDF on Vercel.

Do not send raw page images to Vercel for PDF assembly.

Do not use Cloudinary to construct the canonical PDF.

The client generates the PDF.

---

# 17. Preview and Thumbnail

The canonical document is the PDF.

For UI performance, generate local presentation derivatives as necessary:

```text
document
 ├── canonical PDF
 ├── thumbnail
 └── preview/first-page representation
```

These derivatives are implementation-level presentation assets.

The original/canonical PDF remains authoritative.

Do not let a thumbnail become the document's source of truth.

Do not upload unnecessary derivatives if the implementation can efficiently generate them locally from the encrypted PDF after download.

Prefer the simplest practical design.

---

# 18. Document Viewer

A scanned document should not be rendered as ordinary Markdown image content.

When the user activates the document reference, open a dedicated document viewer.

Conceptually:

```text
┌─────────────────────────────────────┐
│ ←  Scanned Document            ⋯    │
├─────────────────────────────────────┤
│                                     │
│             PAGE 1                  │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│             PAGE 2                  │
│                                     │
└─────────────────────────────────────┘
```

The viewer should:

* open the encrypted local document if available
* download encrypted PDF if necessary
* decrypt locally
* render pages
* support scrolling
* support reasonable zoom
* show page progression/count
* provide a close/back action
* support both phone and tablet layouts

Do not build PDF annotation/editing.

Do not build document editing.

Do not expose Cloudinary URLs to the user.

---

# 19. Tablet Viewer

The app already has tablet-aware layouts.

Where practical, the document viewer should support a tablet-friendly presentation:

```text
┌──────────────┬──────────────────────┐
│ page 1       │                      │
│ page 2       │      Current page    │
│ page 3       │                      │
│ page 4       │                      │
└──────────────┴──────────────────────┘
```

Do not introduce a huge redesign.

Use existing max-width, spacing, typography, and split-pane conventions.

---

# 20. Document Title / Display Name

The canonical document identity is the UUID.

The Markdown display text may initially be:

```text
Scanned Document
```

Optionally, if the app already has an established naming mechanism, use a user-editable display title.

But do NOT make title the identity.

Changing the title must not change:

```text
qp://document/<UUID>
```

This is required for future stable resource linking.

---

# 21. No Image Editing

This feature MUST NOT include any user-facing image editing.

Explicitly out of scope:

* crop tool
* rotate tool
* filters
* drawing
* annotation
* highlighting
* markup
* brightness editing
* contrast editing
* color adjustment
* AI cleanup
* background removal
* retouching

Automatic scanner normalization is allowed because it is part of document capture.

---

# 22. No OCR in V1

Do not implement OCR in this phase.

However, structure the document model so OCR can be added later.

Possible future model:

```text
Document
 ├── encrypted PDF
 └── encrypted OCR text
```

Do not add OCR dependencies or UI now unless the repository already requires them for another feature.

Do not perform cloud OCR.

---

# 23. Future Search Compatibility

Existing Quiet Paper search is local.

Do not add document-content search in this phase.

Future OCR text could eventually participate in local search.

The current implementation should not attempt to index visual document content.

---

# 24. Encryption

The PDF MUST be encrypted locally before cloud upload.

Use the existing Quiet Paper encryption architecture.

The current application uses a random 256-bit master key and XChaCha20-Poly1305 content encryption with unique nonces and authenticated associated data.

Do not invent a separate user password for documents.

Do not create a separate document master key.

Use the existing Quiet Paper master-key hierarchy unless the repository's current crypto implementation requires a documented derived-key design.

The document encryption envelope MUST include:

* format/version
* document ID or binding context
* encryption key version
* nonce
* ciphertext
* authenticated metadata as appropriate

Use a document-specific associated-data namespace.

For example, conceptually:

```text
quietpaper:document:<documentId>:v1
```

Do not copy the note-associated-data string.

The exact envelope serialization must be documented and tested.

---

# 25. Encryption Integrity

The encrypted PDF must be authenticated.

Tampering must cause decryption/verification failure.

Test:

* valid roundtrip
* wrong key
* altered ciphertext
* altered nonce
* altered metadata
* wrong document ID
* wrong encryption version
* corrupted PDF
* incomplete upload/download

Do not silently render corrupted content.

---

# 26. SHA-256

Compute SHA-256 over the canonical plaintext PDF bytes before encryption.

Use the hash for:

* integrity verification
* content identity/deduplication assistance
* debugging
* upload metadata verification

Do not use the hash as the document's primary identity.

The UUID identifies the document.

The SHA-256 identifies the PDF content.

---

# 27. Direct Cloudinary Upload

This is one of the most important requirements.

**The encrypted PDF MUST be uploaded directly from Flutter to Cloudinary.**

The Vercel function MUST NOT proxy the PDF.

Do not send PDF bytes to Vercel.

Do not stream PDF contents through Vercel.

Do not make Vercel wait for the PDF transfer.

Architecture:

```text
                    CONTROL PLANE

Flutter ───────────────→ Vercel
   │                        │
   │                        ├── Firebase authentication
   │                        ├── authorization
   │                        ├── upload authorization
   │                        ├── metadata
   │                        └── synchronization
   │
   │
   │ DATA PLANE
   └──────────────────────→ Cloudinary
              encrypted PDF bytes
```

This is required because serverless execution/request constraints make Vercel inappropriate as a large-binary proxy.

---

# 28. Cloudinary Security

Never embed Cloudinary permanent API secrets in Flutter.

The Flutter app may receive short-lived or appropriately scoped upload authorization generated by the backend.

The intended flow:

```text
1. Flutter creates local document.
2. Flutter encrypts PDF.
3. Flutter requests upload authorization.
4. Vercel authenticates Firebase user.
5. Vercel verifies document/note ownership.
6. Vercel generates appropriate Cloudinary upload parameters/signature.
7. Flutter uploads encrypted PDF directly to Cloudinary.
8. Cloudinary returns upload result.
9. Flutter reports upload completion/metadata to Vercel.
10. Vercel validates and records metadata/sync state.
```

At no point does Vercel receive the PDF body.

---

# 29. Cloudinary Object Naming

Use opaque stable identifiers.

Prefer something conceptually based on the document UUID:

```text
document/<documentId>/original
```

or the repository's equivalent Cloudinary object naming convention.

Do NOT put plaintext metadata such as:

* email addresses
* note titles
* document names
* user names

into Cloudinary object identifiers.

Cloudinary object identifiers are storage metadata, not canonical Quiet Paper identity.

---

# 30. Cloudinary as Blob Storage

Because the PDF is encrypted before upload, Cloudinary cannot inspect its semantic document contents.

Do not depend on Cloudinary for:

* PDF OCR
* PDF editing
* PDF annotation
* PDF page manipulation
* semantic extraction
* document intelligence

Cloudinary is the encrypted object store/delivery layer.

---

# 31. Backend Responsibilities

The Vercel backend must remain responsible for:

```text
Firebase authentication
Attachment/document ownership
Authorization
Upload authorization/signing
Document metadata
Revision tracking
Sync metadata
Idempotency
Deletion authorization
Cloud object lifecycle coordination
```

It must NOT:

```text
Receive plaintext PDFs
Receive encrypted PDF byte streams
Decrypt PDFs
Generate PDFs
Render PDFs
Edit PDFs
Hold the Quiet Paper master key
```

The existing backend already follows a crypto-blind architecture. Preserve it.

---

# 32. Backend Attachment/Document Validation

Add strict schemas for documents.

Validate:

* document UUID
* note UUID
* ownership
* MIME type
* byte size
* page count
* SHA-256 format
* encryption version
* Cloudinary object ID
* deleted state
* revision/base revision
* upload completion state
* idempotency key

Reject impossible combinations.

For example:

```text
deleted = true
+
active upload authorization
```

must be rejected.

A user must not register a document against another user's note.

Never trust client-provided ownership.

---

# 33. Document Database Table

Add a dedicated Drift table for documents.

Conceptually:

```text
documents
────────────────────────────
id
note_id
created_at
updated_at

mime_type
byte_size
page_count
sha256

encryption_key_version

is_dirty
is_deleted
server_revision
synced_at

upload_state

cloud_object_id
cloud_version
```

Use the repository's established SQL/Dart naming style.

A document is NOT simply an `asset` row with a MIME type of PDF unless the existing architecture makes that abstraction genuinely cleaner.

The product semantics require a distinct document resource.

---

# 34. Attachment vs Document

Keep these concepts distinct:

```text
asset
    ordinary image/file attachment

document
    scanned multi-page PDF
```

Both may share lower-level encrypted-storage/upload infrastructure.

Do not duplicate crypto/upload code.

But they must have separate resource identity types:

```text
qp://asset/<id>
qp://document/<id>
```

This distinction is deliberate and must remain visible at the domain/resource level.

---

# 35. Shared Infrastructure

Where appropriate, build reusable infrastructure beneath both asset and document resources:

```text
EncryptedResource
CloudUploadService
ResourceRepository
ResourceSyncService
QuietPaperUri
```

Do not duplicate:

* upload state machines
* Cloudinary authorization logic
* encryption primitives
* hashing logic
* URI parsing
* sync infrastructure

However, do not force images and scanned documents into an identical domain model if their semantics differ.

---

# 36. Offline-First Scanner Behavior

The entire scanner workflow must function without network connectivity.

Example:

```text
Airplane mode

Scan page 1
Scan page 2
Scan page 3
Done

PDF generated locally
PDF encrypted locally
Document stored locally
Markdown updated locally
```

The note remains usable.

Later:

```text
Network returns
    ↓
upload authorization
    ↓
direct Cloudinary upload
    ↓
metadata synchronization
```

The user must never be required to stay online while scanning.

---

# 37. Upload State Machine

Use explicit document upload state.

Conceptually:

```text
LOCAL_ONLY
    ↓
UPLOAD_AUTH_PENDING
    ↓
UPLOADING
    ↓
UPLOADED
    ↓
SYNCED
```

Failure:

```text
UPLOADING
    ↓
UPLOAD_FAILED
    ↓
RETRY_PENDING
```

Exact enum names may follow existing conventions.

The semantics are mandatory.

Document upload state must be independent of note sync state.

Example:

```text
Note = SYNCED
Document = UPLOADING
```

is valid.

Do not block the note synchronization engine waiting for the PDF upload.

---

# 38. Sync Integration

Integrate documents into the existing sync architecture.

The current project has revision tracking, push/pull, idempotency, cursor synchronization, conflict handling, and an offline mutation queue.

Documents should participate as a first-class sync resource.

Conceptually:

```text
SyncChange
 ├── NoteChange
 ├── AttachmentChange
 └── DocumentChange
```

Or use a generalized resource-change mechanism if that fits the repository better.

Do not create a second independent sync engine.

---

# 39. Note Revision vs Document State

A PDF upload is NOT a note content revision.

However:

```text
[Scanned Document](qp://document/<UUID>)
```

being inserted into Markdown IS a note content revision.

Therefore:

```text
document upload progress
    ≠
note revision
```

but:

```text
document reference inserted/removed
    =
note Markdown revision
```

Preserve this separation.

---

# 40. Document Deletion

Removing the document reference from Markdown must NOT immediately physically delete the Cloudinary object.

Use a tombstone/retention lifecycle:

```text
Markdown reference removed
        ↓
document marked deleted locally
        ↓
tombstone synchronized
        ↓
server acknowledges deletion
        ↓
cloud object becomes eligible for physical deletion
```

Use delayed garbage collection.

Do not immediately destroy cloud data when the user presses Undo or when a transient editing operation removes the reference.

The project already has careful tombstone handling for notes. Apply equivalent safeguards to documents.

---

# 41. Remote Deletion

When another device deletes a document:

```text
remote tombstone
    ↓
local document deleted
    ↓
NO new outgoing deletion mutation
```

Ensure that applying a remote deletion does not enqueue another deletion back to the server.

Use the existing database APIs/flags for applying remote mutations without generating local mutations where appropriate.

---

# 42. Orphaned Documents

Detect documents that exist locally but are no longer referenced by any note Markdown.

Do NOT immediately delete them.

Keep them available long enough to handle:

* undo
* editing races
* sync delays
* restore operations
* interrupted updates
* multi-device conflicts

Implement safe delayed orphan cleanup only where appropriate.

---

# 43. Undo/Redo

Document insertion must integrate with the Markdown editor's undo/redo semantics.

Before:

```text
Paragraph
```

After:

```markdown
Paragraph

[Scanned Document](qp://document/abc123)
```

Undo must restore the previous Markdown.

However, undoing the Markdown reference must NOT immediately destroy the document resource.

Let resource garbage collection/tombstone rules manage unused documents.

This avoids coupling editor undo to destructive storage deletion.

---

# 44. Autosave

The existing editor uses debounced autosave plus focus/lifecycle/exit flushing.

When a document is inserted:

1. Save document locally.
2. Insert Markdown reference.
3. Trigger normal note autosave.
4. Do not wait for cloud upload.

The editor must remain responsive.

---

# 45. Process Termination

If the user closes the app while:

* scanning
* generating a PDF
* encrypting
* uploading

the implementation must recover safely.

Before completion of PDF generation:

* temporary scan data may remain until cleanup/recovery.

After PDF generation:

* the encrypted document must be persistently stored.

During upload:

* the local encrypted PDF remains authoritative for retry.

On next launch:

* pending documents can resume synchronization.

Do not require the user to rescan the physical pages.

---

# 46. App Update / Restart

The existing project explicitly handles persistent auth and master-key state across process restarts and app updates.

Document synchronization must behave similarly.

A pending document must survive:

* app close
* process kill
* device restart
* app update
* network interruption

provided the local attachment data remains available.

---

# 47. Password-Protected Notes

The app supports note-level password protection.

A document associated with a locked/password-protected note must not leak plaintext document content.

When the note is locked:

* do not render the document preview in plaintext
* do not expose decrypted pages
* do not allow document interaction that bypasses the note lock

Document encryption remains independently applied.

---

# 48. Local File Storage

Persist encrypted document data in an app-private location consistent with existing local storage architecture.

Do not persist permanent plaintext PDFs unnecessarily.

Temporary plaintext page images/PDF representations must be cleaned up when they are no longer needed.

Use streaming/file-based operations where possible.

Avoid loading huge PDFs completely into memory when the platform/library permits file-backed operations.

---

# 49. PDF Viewer Security

The PDF viewer must receive the decrypted document through a controlled application path.

Do not:

* upload plaintext PDF somewhere else
* pass sensitive PDF URLs to third-party services
* expose Cloudinary ciphertext URLs as user-facing links
* use a web viewer that requires uploading the document externally

The document remains local after decryption.

---

# 50. External Link Safety

A `qp://document/...` reference is an internal application resource.

It must NOT invoke:

```text
LinkConfirmationDialog
```

or the external-domain trust mechanism.

Do not call `url_launcher` for internal Quiet Paper resources.

Instead:

```text
qp://document/id
        ↓
DocumentResolver
        ↓
DocumentViewer
```

---

# 51. Backup and Restore

Quiet Paper already has `.qpbackup` creation/restoration with optional encryption, merge/keep-both/clean-replace semantics, and restored notes being re-queued for cloud sync.

Document scanning MUST integrate with that system.

A backup must not silently lose scanned documents.

The backup representation must preserve:

* document ID
* note association
* document metadata
* page count
* hash
* encryption metadata
* canonical PDF payload or a recoverable encrypted representation

For an encrypted backup, attachment/document confidentiality must remain consistent with the existing backup security model.

Restore must:

* restore the document
* preserve document UUID where safe
* restore Markdown references
* mark restored cloud-syncable resources dirty
* reset server revision as appropriate
* allow documents to synchronize afterward

Do not accidentally issue destructive remote deletions during restore.

Test merge, keep-both, and clean-replace semantics.

---

# 52. Existing Image Attachment System

The repository already has image attachment support.

Do NOT reimplement it.

Instead:

* inspect the existing image attachment domain
* reuse its encryption/storage/upload mechanisms where appropriate
* extend shared resource infrastructure
* add `document` as a separate resource type
* preserve existing image behavior

The goal is:

```text
Image:
qp://asset/<UUID>

Scan:
qp://document/<UUID>
```

with shared lower-level infrastructure.

Do not regress existing image functionality.

---

# 53. Resource Resolver Behavior

The resource resolver must support:

```text
asset
document
note
```

Conceptually:

```text
resolve(qp://asset/id)
    → asset resource

resolve(qp://document/id)
    → document resource

resolve(qp://note/id)
    → note resource
```

For unsupported/missing resources:

```text
not found
deleted
corrupt
locked
unavailable
```

must produce controlled presentation states rather than application crashes.

---

# 54. Markdown Rendering Behavior

A document reference should render as a quiet embedded document object.

Example:

```text
┌─────────────────────────────────────┐
│  document icon                      │
│  Scanned Document                   │
│  4 pages                            │
└─────────────────────────────────────┘
```

The exact appearance should follow the current app design.

Do not display:

* raw `qp://document/...`
* Cloudinary URLs
* database UUIDs

to normal users unless in an appropriate diagnostic/debug context.

The Markdown source remains available when editing.

---

# 55. Editor Source Integrity

The existing editor architecture explicitly requires source-contiguous parsing and preservation of exact source characters/caret positions.

Do not implement document references by replacing Markdown with hidden tokens.

Do not manipulate the underlying source into custom placeholders.

The source remains:

```markdown
[Scanned Document](qp://document/abc123)
```

exactly.

The renderer/presentation layer interprets it.

---

# 56. Note-to-Note Linking Foundation

Although full note linking is NOT being implemented now, ensure that:

```markdown
[Encryption Architecture](qp://note/7d92...)
```

can already be parsed by the generic URI system.

The target identity is the UUID.

The display title can change without rewriting the source link.

If the note is deleted:

```text
qp://note/id
```

remains stable.

The renderer can later show a broken/deleted-note state.

If the note is restored, the same URI can resolve again.

Do not build the actual note-linking UI now.

---

# 57. Search

Do not add OCR or image/document text indexing in this phase.

Existing search remains local and textual.

Future OCR may be indexed locally later.

Do not call remote search services.

---

# 58. Export/Import

Do not silently redefine existing Markdown import behavior.

External image links remain external image links unless the current image feature already defines a migration/import path.

Do not automatically download arbitrary external PDFs or images during Markdown import.

A separate future import enhancement may address that.

---

# 59. Error Handling

All scanner and document errors must be structured and recoverable.

Handle:

* camera permission denied
* camera unavailable
* scanner initialization failure
* document detection failure
* capture failure
* PDF generation failure
* encryption failure
* local disk failure
* upload authorization failure
* Cloudinary upload failure
* network unavailable
* document corruption
* decryption failure
* missing document
* deleted document
* invalid URI

Do not crash.

Do not silently discard the user's scan.

Do not lose a completed scan merely because Cloudinary is unavailable.

---

# 60. Permissions

Use the existing platform permission architecture where available.

Scanner requires camera permission.

Handle denied permission gracefully.

Do not ask for unnecessary permissions.

Do not request storage permissions solely because a modern platform API can use app-private storage or a system picker.

Follow the project's existing Android/iOS conventions.

---

# 61. Platform Support

Inspect the project's actual supported targets before implementation.

Implement the scanner for platforms where camera/document scanning makes sense according to the current project.

For platforms without an appropriate camera API, provide a graceful unsupported-state or existing file-import pathway rather than breaking the application.

Do not pretend all platforms support identical camera capabilities.

Do not add fragile platform-specific code without tests or guards.

---

# 62. UI Performance

The scanner must not make the editor lag.

Document generation, encryption, thumbnail generation, and upload must not unnecessarily block the UI thread.

Use appropriate isolates/background work where required by the actual Flutter implementation.

Do not perform large PDF encryption synchronously on the main UI thread if it causes visible jank.

The editor should return quickly after local persistence.

---

# 63. Document Page Rendering Performance

The document viewer should not decode every page at full resolution simultaneously.

Use lazy page rendering/virtualization where possible.

Load only the pages near the viewport.

Cache reasonably sized page representations.

Free distant page resources when appropriate.

Keep memory usage bounded for large scanned documents.

---

# 64. Multi-Page Limits

Introduce reasonable configurable safeguards for:

* maximum scanned page count
* maximum PDF size
* maximum individual page dimensions
* maximum local temporary scan size

The exact numbers should be chosen based on the existing app's supported environments and practical memory/storage constraints.

Enforce client-side for user feedback and backend-side for metadata validation where relevant.

Do not choose arbitrary tiny limits that make ordinary documents unusable.

---

# 65. Cloudinary PDF Limits

Ensure direct upload configuration handles large PDFs without passing the PDF through Vercel.

Use the Cloudinary upload mechanism appropriate for the expected document size.

If a resumable/chunked direct-upload mechanism is required by the chosen Cloudinary API for larger files, implement it on the Flutter → Cloudinary data path.

The Vercel backend still must never receive the PDF bytes.

---

# 66. Upload Retry

If a Cloudinary upload fails:

* retain the encrypted PDF locally
* preserve the document UUID
* mark upload failed/retryable
* retry later
* do not regenerate the scan unnecessarily
* do not require the user to rescan

If upload authorization expires:

* request a fresh authorization
* retry the direct upload

Do not lose the local PDF.

---

# 67. Idempotency

The existing backend already uses idempotency keys to prevent duplicate note creation on retries.

Use idempotency for document metadata registration and completion operations.

Retries must not create:

* duplicate document records
* duplicate metadata
* duplicate tombstones
* conflicting revisions

The document UUID remains stable across retries.

---

# 68. Conflict Handling

Do not merge PDF contents.

Scanned documents are immutable content objects.

If two devices independently create scans:

```text
Device A → document/A
Device B → document/B
```

both can coexist.

Conflicts happen around note Markdown and metadata references, not inside PDF bytes.

Do not mutate the canonical PDF content of an existing document ID.

---

# 69. Document Replacement

If future/current UX allows replacing a document, do NOT overwrite the PDF bytes associated with an existing document ID.

Create a new document ID:

```text
old:
qp://document/A

new:
qp://document/B
```

Update the Markdown reference.

Retire A through the normal deletion/tombstone lifecycle.

This preserves immutable resource identity.

---

# 70. Testing Requirements

Add comprehensive automated tests.

## URI tests

Test:

```text
qp://asset/<valid UUID>
qp://document/<valid UUID>
qp://note/<valid UUID>
```

Reject:

```text
wrong scheme
missing ID
invalid ID
unknown resource type
malformed URI
unexpected path
```

Test serialization roundtrip.

---

## Markdown tests

Test:

```markdown
[Scanned Document](qp://document/abc123)
```

including:

* parsing
* rendering
* source preservation
* exact offsets
* malformed URI
* deleted resource
* missing resource
* multiple documents in one note
* mixed images/documents/links
* future `qp://note/...` compatibility

Do not regress existing Markdown parsing.

---

## Scanner tests

Where the chosen scanner implementation can be abstracted/tested:

* initialization
* permission denied
* capture
* multi-page capture
* retake
* deletion
* reorder
* completion
* cancellation
* detection fallback

Mock platform/camera dependencies where necessary.

---

## PDF tests

Test:

* single-page PDF
* multi-page PDF
* page ordering
* PDF metadata
* hash computation
* corrupted PDF
* empty scan session
* PDF generation failure

---

## Crypto tests

Test:

* encrypt/decrypt
* wrong key
* tampering
* associated-data mismatch
* nonce handling
* encryption version
* corrupted ciphertext
* large PDF
* multiple documents

---

## Database tests

Test:

* document creation
* lookup
* update
* deletion
* tombstone
* note relationship
* hash
* size
* page count
* upload state
* server revision
* migrations
* restart persistence

---

## Sync tests

Test:

* offline document creation
* note reference sync
* document metadata sync
* upload retry
* authorization refresh
* direct upload completion
* remote document pull
* remote deletion
* local deletion
* deletion races
* note deletion while document upload is pending
* idempotency
* multi-device scenarios
* no remote-delete → local-delete → push loop

---

## Cloudinary integration tests

Mock the Cloudinary client where appropriate.

Prove architecturally that:

```text
Flutter → Cloudinary
```

is the binary data path.

And:

```text
Flutter → Vercel
```

contains only authorization/metadata/control data.

The backend must not expose an endpoint that receives document byte bodies.

---

## Backup tests

Test:

* backup containing documents
* encrypted backup containing documents
* restore
* merge
* keep-both
* clean replace
* restored Markdown references
* restored document UUIDs
* restored document sync state
* cloud re-sync after restore
* missing cloud object
* deleted cloud object

---

# 71. Static Analysis and Full Validation

Before completion, run the project's full validation.

At minimum:

```bash
flutter analyze
flutter test
```

and the appropriate backend:

```bash
npm test
npm run build
```

Run Drift code generation if schema changes require it:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use the repository's actual scripts if they differ.

Do not claim tests passed unless actually executed.

Do not leave generated files stale.

Do not suppress warnings merely to obtain a clean result.

---

# 72. Database Migration

Add a proper Drift migration.

The migration must:

* preserve all existing notes
* preserve all tags
* preserve existing attachments/images
* preserve sync metadata
* preserve existing revisions
* add document structures safely
* be tested against an existing database version
* support a fresh database

Do not rewrite existing Markdown.

Do not convert existing image attachments into documents.

---

# 73. Backend Database Migration

Add the corresponding backend/Turso migration.

Keep document metadata separate from note plaintext.

Do not add plaintext document-content columns.

Do not store plaintext PDF content.

Store only necessary metadata and encrypted/object-storage references.

---

# 74. Security Documentation

Update the security architecture documentation.

It must explicitly state:

```text
Document plaintext:
    exists only on authorized client devices during processing/viewing

Document canonical payload:
    PDF

Document encryption:
    client-side

Cloudinary:
    encrypted PDF only

Vercel:
    metadata/control plane only

Turso:
    metadata only
```

Also document operational metadata that Cloudinary may observe, such as:

* upload timing
* object size
* object count
* object identifiers
* network access patterns

Do not claim Cloudinary has zero metadata visibility.

The security claim is specifically about plaintext document confidentiality.

---

# 75. Existing Master-Key Lifecycle

The app persists its unlocked master key securely and clears it on logout/key clearing.

The document system must obey exactly the same lifecycle.

When the master key is unavailable:

* documents cannot be decrypted
* document plaintext must not be exposed
* locked states must be handled safely

On logout/key clearing:

* temporary plaintext document files must be cleaned up
* decrypted caches must be removed where appropriate
* no master-key material may be persisted in ordinary storage

---

# 76. Existing Backup Security

The existing backup system uses optional Argon2id/XChaCha20-Poly1305 encryption.

Do not introduce a separate document password.

Do not weaken backup security merely to simplify PDF handling.

The backup architecture must clearly distinguish:

```text
encrypted application resource
```

from:

```text
encrypted backup container
```

so that security layers remain understandable.

---

# 77. Existing External Link Behavior

Do not modify the existing external-link confirmation flow except where necessary to ensure `qp://` resources bypass it.

External links continue to follow the existing trust mechanism.

Internal resources remain entirely within the application.

---

# 78. UI Acceptance Criteria

From the current editor shown in the product:

* Existing image attachment button remains intact.
* New scanner button is placed immediately beside it.
* Scanner button uses a clear document/scanner icon.
* Scanner button follows existing icon sizing/accessibility conventions.
* Scanner UI is full-screen.
* Scanner supports multi-page capture.
* Scanner uses automatic document detection/normalization.
* There is no image-editor UI.
* Finishing a scan creates a local PDF.
* Returning to the editor is immediate after local completion.
* The note receives one document reference.
* The document reference looks native and quiet.
* The raw `qp://` URI is not visible in normal viewing.
* The document opens into a dedicated viewer.
* Phone and tablet layouts work.
* Light and dark themes work.
* Read-only mode is respected.

---

# 79. Final Architecture

The completed system should look conceptually like this:

```text
                         QUIET PAPER

                    ┌──────────────────┐
                    │      NOTE        │
                    │                  │
                    │ Markdown source  │
                    └────────┬─────────┘
                             │
                             │ references
                             ▼
                  ┌──────────────────────┐
                  │ QuietPaperUri        │
                  │                      │
                  │ qp://asset/...       │
                  │ qp://document/...    │
                  │ qp://note/...        │
                  └───────┬──────────────┘
                          │
              ┌───────────┼────────────┐
              ▼           ▼            ▼
           Asset       Document       Note
                         │
                         │
                  canonical PDF
                         │
                  encrypt locally
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
        Local storage           Cloudinary
        encrypted PDF           encrypted PDF
             │
             │
             ▼
        Sync metadata
             │
             ▼
           Vercel
             │
             ▼
           Turso
```

---

# 80. Non-Negotiable Network Boundary

The binary data path MUST be:

```text
Flutter
   ↓
local PDF
   ↓
local encryption
   ↓
Cloudinary
```

The metadata path MUST be:

```text
Flutter
   ↓
Vercel
   ↓
Turso
```

Do not implement:

```text
Flutter
   ↓
Vercel
   ↓
Cloudinary
```

for PDF bytes.

Do not implement:

```text
Flutter
   ↓
Cloudinary plaintext PDF
```

Do not implement:

```text
Flutter
   ↓
Vercel plaintext PDF
```

These are hard architectural constraints.

---

# 81. Explicitly Out of Scope

Do NOT implement:

* image editing
* scan-page manual crop
* manual rotation editor
* filters
* annotations
* drawing
* markup
* OCR
* cloud OCR
* document semantic search
* AI document understanding
* public document links
* public PDF URLs
* collaborative document editing
* note-linking UI
* `[[wikilink]]` syntax
* server-generated PDFs
* Vercel PDF proxying
* plaintext PDFs in Cloudinary
* rich-text document-model replacement

---

# 82. Future-Proofing Requirements

The implementation should make the following future features straightforward without implementing them now:

```text
qp://note/<UUID>
    → internal note linking

encrypted OCR text
    → local document search

document sharing/export
    → explicit user action

document metadata/title
    → stable resource identity

additional resource types
    → same QuietPaperUri system
```

Do not over-engineer speculative features, but do not make future support impossible.

---

# 83. Final Invariants

Before declaring the task complete, verify that all of these are true:

```text
Markdown remains the canonical note source.

qp://asset/<UUID> represents ordinary image attachments.

qp://document/<UUID> represents scanned PDF documents.

qp://note/<UUID> is reserved and architecturally supported for future note links.

The scanned document's canonical payload is a PDF.

The PDF is generated locally.

The PDF is encrypted locally.

Cloudinary stores encrypted PDF bytes only.

Vercel never receives PDF bytes.

Vercel is the control plane.

Turso stores document metadata and sync state.

The document UUID is its stable logical identity.

Cloudinary object IDs are storage identities, not note identities.

The scan works offline.

The note does not wait for Cloudinary.

Uploads retry safely.

Uploads survive process termination.

Document deletion uses tombstones and delayed physical deletion.

Remote deletions do not loop back into outgoing deletions.

Read-only mode is respected.

Password-protected notes do not expose document plaintext.

Existing image attachments continue to work.

Existing Markdown editor invariants remain intact.

No rich-text document model is introduced.

No user-facing image/document editing is implemented.

No OCR is implemented.

The scanner button is immediately adjacent to the existing image button.

The resource URI architecture is centralized and reusable.

The implementation has comprehensive automated tests.

Flutter analysis passes.

Flutter tests pass.

Backend tests pass.

Backend build/typecheck passes.

Database migrations pass.

Documentation accurately describes the encryption and Cloudinary trust boundaries.
```

---

# 84. Required Agent Deliverable

When the implementation is complete, report:

1. Exact files created and modified.
2. Drift/schema migration details.
3. Backend API/control-plane changes.
4. Cloudinary direct-upload flow.
5. Encryption/envelope design.
6. Scanner lifecycle and page-management behavior.
7. PDF generation behavior.
8. Document database model.
9. `qp://` URI/resource architecture.
10. Markdown parser/editor changes.
11. Document viewer implementation.
12. Backup/restore changes.
13. Sync state machine.
14. Deletion/tombstone behavior.
15. Tests added.
16. Commands actually executed.
17. Actual test/analyze/build results.
18. Any repository-specific deviation from this specification and why.

Do not claim anything was implemented, tested, or verified unless it was actually done.

Do not silently substitute a simpler design for the direct Cloudinary architecture.

Do not route document bytes through Vercel.

Do not weaken the existing zero-knowledge encryption model.

The finished implementation should make **Scan Document** feel like a native Quiet Paper capability: capture pages effortlessly, produce one clean PDF document, keep the PDF encrypted and local-first, store the canonical encrypted PDF in Cloudinary via direct upload, synchronize only metadata through the existing backend, and represent the document permanently inside Markdown as:

```markdown
[Scanned Document](qp://document/<UUID>)
```

while preserving the broader Quiet Paper resource architecture for future `qp://note/<UUID>` internal note linking.
