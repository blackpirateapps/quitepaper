# MASTER IMPLEMENTATION PROMPT
## Quiet Paper — Generic Encrypted File Attachments
### Phase 1: Attachment Foundation, Storage, Lifecycle, Sync, Backup & Export

You are working inside the existing Quiet Paper Flutter application.

Implement **Phase 1 of the Generic Attachment System**.

The goal of Phase 1 is to evolve Quiet Paper from primarily supporting image/PDF attachments into a **first-class generic encrypted file attachment system**, while preserving the existing specialized behavior of:

- images
- scanned documents/PDFs
- OCR
- Cloudinary storage
- sync
- trash
- permanent deletion
- local backup
- export
- note links
- existing editor behavior

Phase 1 is infrastructure-first.

Do NOT attempt to implement rich previews for every possible file type in this phase.

Do NOT turn Quiet Paper into a document-management suite.

The fundamental product principle is:

> **Every file can be safely stored as an attachment. Some attachment types have additional capabilities.**

---

# 1. EXISTING ARCHITECTURAL INVARIANT

The current application is offline-first and uses client-side encryption for sensitive content/assets.

The existing attachment/document architecture includes encrypted local asset/document storage, Cloudinary synchronization, OCR for supported content, attachment references in Markdown, and separate document metadata for scanned PDFs. 
Do not weaken these guarantees.

Generic file attachments must follow the same fundamental security model.

---

# 2. PRIMARY OBJECTIVE

After Phase 1, users must be able to attach arbitrary ordinary files supported by the platform file picker, subject to sensible file-size/type/security restrictions.

Examples:

```text
DOCX
XLSX
PPTX
TXT
CSV
JSON
YAML
ZIP
Dart source
Python source
audio
video
fonts
archives
datasets
other binary files
```

The system must not require Quiet Paper to understand the file internally.

It must be capable of:

- selecting
- importing
- encrypting
- storing
- displaying metadata
- renaming
- sharing
- opening externally
- deleting
- restoring where applicable
- syncing
- backing up
- exporting

generic files.

---

# 3. DO NOT BREAK EXISTING SPECIALIZED ATTACHMENTS

This is a critical requirement.

Existing image attachments must continue to support their existing:

- image ingestion
- encryption
- thumbnails
- rendering
- OCR where applicable
- deduplication behavior
- Markdown references

Existing scanned/document attachments must continue to support their existing:

- document metadata
- page count
- PDF generation
- OCR
- encrypted document storage
- synchronization
- lifecycle

Do not replace these with a naive generic-file implementation.

Instead, introduce a common attachment abstraction/lifecycle while preserving specialized capabilities.

---

# 4. TARGET ARCHITECTURE

Move conceptually from:

```text id="f4m6j1"
Image
PDF
```

toward:

```text id="6sh3ra"
                     Attachment
                         │
             ┌───────────┼────────────┐
             │           │            │
           Image      Document      Generic File
             │           │            │
          specialized  specialized   generic
          behavior     behavior      behavior
             │           │            │
             └───────────┼────────────┘
                         │
                  Common Lifecycle
                         │
              Encryption / Storage
                         │
                 Sync / Backup
                         │
                    Cloudinary
```

Do not flatten existing document semantics.

---

# 5. FIRST STEP: INSPECT THE CODEBASE

Before changing anything, inspect:

### Attachment code

- AttachmentService
- attachment models
- attachment tables
- attachment repository
- attachment URI handling
- local asset storage
- encryption/decryption
- image import
- image rendering

### Document code

- DocumentService
- document model
- document table
- PDF builder
- document encryption
- document sync

### Sync

- SyncEngine
- attachment/document synchronization
- upload state
- download state
- deletion/tombstones

### Storage

- Cloudinary service
- upload/authentication
- download
- deletion
- cache
- local encrypted file paths

### UI

- formatting toolbar
- attachment button
- image picker
- document scanner
- attachment cards
- attachment actions

### Backup/export

- BackupService
- backup schema
- note export
- QPNOTE package
- Markdown export

### Database

- Drift schema
- migrations
- attachment-related indexes
- document relationships

### Existing tests

Find every test touching:

- attachments
- documents
- images
- OCR
- sync
- backup
- deletion
- note export

Do not assume the existing data model.

---

# 6. DEFINE WHAT "GENERIC ATTACHMENT" MEANS

A generic attachment is a file whose contents Quiet Paper does not need to interpret.

Examples:

```text
project.zip
database.sqlite
firmware.bin
presentation.pptx
dataset.csv
script.py
font.ttf
video.mp4
```

At minimum, Quiet Paper must preserve:

```text id="b2n6y0"
file bytes
filename
MIME type
extension
size
hash
attachment ID
note association
created timestamp
sync state
deletion state
```

---

# 7. ATTACHMENT IDENTITY

Every attachment must have a stable unique ID.

Use the existing UUID strategy if one already exists.

Do not use:

- filename
- file path
- hash
- Cloudinary public ID

as the logical attachment primary key.

The attachment ID identifies the logical relationship.

---

# 8. CONTENT IDENTITY

Store a cryptographic content hash, preferably SHA-256 where the existing architecture already uses that primitive.

Conceptually:

```text id="2b0q60"
attachmentId
contentHash
```

The attachment ID and content hash serve different purposes.

Do not replace the UUID with the hash.

---

# 9. ATTACHMENT KIND

Introduce a typed attachment classification.

Suggested conceptual values:

```text id="ivn0f3"
image
document
genericFile
```

Do not rely on this alone for preview behavior.

A PDF may remain a specialized document even though it is technically a file.

---

# 10. MIME TYPE

Persist the MIME type where available.

Do not rely solely on file extension.

Example:

```text id="l9s1zq"
image/jpeg
application/pdf
application/zip
text/plain
application/json
application/vnd.openxmlformats-officedocument.wordprocessingml.document
```

Normalize MIME type consistently.

---

# 11. FILE EXTENSION

Preserve the original extension where possible.

Do not derive the user's filename solely from MIME type.

For extensionless files, support an empty extension.

---

# 12. ORIGINAL FILENAME

Preserve the original filename in metadata.

The underlying encrypted storage filename may be completely different.

For example:

```text id="f3qvmz"
user:
report-final.xlsx

storage:
<attachment-uuid>.enc
```

Never use user-provided filenames directly as local storage paths.

---

# 13. LOCAL STORAGE

Generic encrypted files must live in app-private storage.

Do not place decrypted generic attachments into public storage merely because they are generic.

Use the existing attachment/document encrypted storage architecture where practical.

---

# 14. ENCRYPTION

Reuse the existing attachment encryption abstraction.

Do not invent another encryption implementation for generic files.

The current application already uses authenticated client-side encryption for assets/documents. Preserve that security model.

Requirements:

- authenticated encryption
- unique nonce requirements of the existing scheme
- versioned envelope
- integrity verification
- correct key version
- safe decryption failure

---

# 15. DO NOT LOG FILE CONTENTS

Never log:

- file bytes
- decrypted text
- passwords
- secrets
- authentication tokens
- Cloudinary credentials

Allowed diagnostics may include:

```text
attachment ID
MIME type
size
hash
operation
duration
state
```

subject to existing logging policy.

---

# 16. GENERIC FILE IMPORT

Add a user-facing attachment action:

```text id="igkv2j"
Add to Note

Photo
Scan Document
File
```

Existing:

- Photo
- Scan Document

must continue working exactly as before.

Add:

> File

which invokes the platform-appropriate generic file picker.

---

# 17. GENERIC FILE PICKER

The File action must support arbitrary files that the platform picker can expose.

Do not whitelist only:

```text
pdf/docx/xlsx
```

The user should be able to select unknown/unrecognized file types.

Use the existing platform abstraction if the application already has one.

---

# 18. MULTI-FILE SELECTION

Support selecting multiple generic files in one operation where the current platform/file-picker package permits it.

Example:

```text id="d5vly2"
report.pdf
budget.xlsx
script.py
archive.zip
```

All should enter the normal attachment ingestion pipeline.

---

# 19. MULTI-FILE IMPORT UX

Show progress:

```text id="qcl2rt"
Adding attachments

12 / 20

report.pdf
budget.xlsx
...
```

Use bounded processing concurrency.

Do not launch unlimited parallel encryption/uploads.

---

# 20. IMPORT PIPELINE

The generic file pipeline must be:

```text id="0f1h2e"
Platform File Picker
        ↓
File Validation
        ↓
MIME / Extension Detection
        ↓
Size Validation
        ↓
Hash
        ↓
Encrypted Local Storage
        ↓
Database Metadata
        ↓
Attachment Reference
        ↓
Normal Sync Pipeline
```

Do not upload plaintext files directly to Cloudinary.

---

# 21. IMPORT SHOULD BE OFFLINE-FIRST

Selecting a file and attaching it to a note must work offline.

The attachment must be usable locally immediately after import.

Cloud sync can happen asynchronously later.

---

# 22. LOCAL AVAILABILITY

Track whether the encrypted local file is available.

Conceptually:

```text id="d9t4wa"
localAvailable
```

or reuse the project's existing attachment state model.

Do not duplicate state if an equivalent field already exists.

---

# 23. SYNC STATE

Generic files must integrate with the existing attachment synchronization lifecycle.

Reuse existing state values where possible.

Potential states:

```text id="cs9ea8"
local
dirty
uploading
synced
downloadQueued
downloading
failed
deletePending
```

Do not create a second incompatible sync-state system.

---

# 24. CLOUDINARY STORAGE

Use the existing Cloudinary attachment/document integration.

Do not expose Cloudinary implementation details in the UI.

Do not store secrets in attachment metadata.

Do not assume every file is an image resource.

If Cloudinary currently requires separate resource types for non-image files, implement that inside the storage provider layer.

---

# 25. CLOUDINARY RESOURCE ABSTRACTION

Create or extend a storage abstraction such that the rest of Quiet Paper sees:

```text id="7ln6n7"
uploadAttachment
downloadAttachment
deleteAttachment
```

rather than:

```text uploadCloudinaryImage
uploadCloudinaryPDF
```

where appropriate.

Provider-specific details should remain behind the abstraction.

---

# 26. LARGE FILE STRATEGY

Before setting a generic attachment size limit, inspect:

- existing Cloudinary limits
- current encrypted storage implementation
- memory behavior
- upload implementation
- download implementation
- backup limits

Do not blindly reuse the existing 25 MB image limit for all files.

The current image pipeline has a 25 MB per-file limit, but generic binary attachments may require different limits.

Choose a documented limit based on the actual implementation.

---

# 27. MEMORY SAFETY

Do not read very large files entirely into memory unless unavoidable.

Prefer streaming/chunked processing for generic files where the existing encryption/storage stack supports it.

Do not convert generic files to giant byte arrays merely to calculate metadata if a streaming solution is available.

---

# 28. HASHING

Prefer streaming SHA-256 computation for large files where supported.

The final hash must be calculated over the original plaintext file bytes.

Do not hash encrypted ciphertext as the content identity unless the existing architecture explicitly defines that semantics.

---

# 29. MIME VALIDATION

Do not blindly trust extension.

Use a robust MIME detection strategy available within the project's dependencies/platform.

At minimum:

- extension hint
- picker-provided MIME where available
- magic/header validation for security-sensitive or previewed types

Do not reject every unknown binary simply because you cannot identify its format.

Unknown is a valid generic file state.

---

# 30. FILE SIZE VALIDATION

Reject files above the supported configured maximum.

Show a meaningful error:

```text id="ncn1gy"
This file is too large to attach.
```

Include actual limit when useful.

Do not crash.

---

# 31. ZERO-BYTE FILES

Support zero-byte files unless there is a legitimate security/storage reason not to.

A zero-byte attachment must remain a valid attachment.

---

# 32. FILE NAME SANITIZATION

Normalize metadata filenames.

Do not use filenames as paths.

Reject dangerous path components such as:

```text
../
..\
/
\
```

A filename such as:

```text id="d2by29"
../../secret.txt
```

must become a safe flat filename representation.

---

# 33. PATH TRAVERSAL

Never allow user-controlled filenames to determine:

```text id="slf50l"
/storage/path/<filename>
```

Use attachment IDs for local encrypted storage paths.

---

# 34. GENERIC ATTACHMENT MODEL

Create or extend a model conceptually containing:

```text id="m7h45o"
Attachment
    id
    noteId
    filename
    mimeType
    extension
    size
    contentHash
    kind
    createdAt
    updatedAt
    localPath
    syncState
    uploadState
    cloudIdentifier
    encryptionVersion
    isDeleted
    deletedAt
```

Use actual existing field names where already present.

Do not duplicate fields that the project already models elsewhere.

---

# 35. SPECIALIZED METADATA

Do not force image/document-specific fields into the generic core.

Examples:

```text id="6hn5n9"
Image:
    width
    height

Document:
    pageCount
    processingState
    OCR state

Generic:
    none required
```

Preserve existing specialized models.

---

# 36. CAPABILITY MODEL

Introduce a capability abstraction if useful.

Conceptually:

```text id="6t6w0m"
preview
thumbnail
openExternally
share
rename
delete
download
ocr
search
```

For Phase 1, the most important capabilities are:

```text id="n0m2as"
storage
openExternally
share
rename
delete
download
```

Do not expose capabilities that are not implemented.

---

# 37. GENERIC FILE CAPABILITIES

Generic files should at minimum support:

```text storage ✓
open externally ✓
share ✓
rename ✓
delete ✓
download/save ✓
```

Preview is NOT required in Phase 1.

---

# 38. GENERIC ATTACHMENT CARD

Create/extend the attachment presentation so unknown files can be shown.

Example:

```text id="sz9v8z"
┌─────────────────────────────────────┐
│  [file icon]  project.zip           │
│               ZIP Archive            │
│               48.2 MB               │
│                         ⋯           │
└─────────────────────────────────────┘
```

For known files:

```text id="wduq3v"
report.docx
Microsoft Word
1.8 MB
```

For unknown:

```text id="q5pp4b"
data.bin
Binary File
12.4 MB
```

Do not break existing image/PDF attachment cards.

---

# 39. ATTACHMENT TYPE LABEL

Use a human-readable type label.

Examples:

```text id="w6i0x3"
PDF Document
Microsoft Word
ZIP Archive
Text File
JavaScript File
Unknown File
```

Use MIME/extension resolution.

Do not display raw MIME types in normal UI.

---

# 40. GENERIC FILE ICON

Create a centralized:

```text id="bc6tvc"
AttachmentIconResolver
```

It should determine the icon from logical type/MIME/extension.

Do not scatter extension checks throughout widgets.

---

# 41. SHARE

Every generic file must support:

> Share

through the native share mechanism.

Before sharing, ensure the file is locally decrypted into a temporary shareable representation if required.

Do not share encrypted ciphertext unless that is explicitly the intended behavior.

---

# 42. TEMPORARY DECRYPTED SHARE FILE

If external sharing requires plaintext/decrypted file bytes:

1. decrypt to secure temporary storage
2. share using the platform API
3. clean up afterwards

Do not permanently store decrypted copies.

Do not write decrypted files into the attachment vault.

---

# 43. OPEN EXTERNALLY

Provide:

> Open With…

or:

> Open

for supported external file types.

Use the native platform file-opening mechanism.

Do not attempt to implement an internal viewer for arbitrary files in Phase 1.

---

# 44. TEMPORARY EXTERNAL-OPEN FILE

Where the platform requires a filesystem URI:

- decrypt only when necessary
- place it in a secure temporary location
- expose through the safest supported content URI/API
- clean it according to lifecycle constraints

Do not expose the encrypted vault directly.

---

# 45. RENAME

Implement:

> Rename

for generic attachments.

Renaming changes only:

```text filename
```

It must not alter:

```text contentHash
file bytes
attachment ID
```

unless the existing architecture intentionally couples those fields.

---

# 46. RENAME VALIDATION

Prevent:

- empty filename
- path traversal
- impossible/reserved names
- invalid filesystem paths

Preserve/adjust extension according to the user's action.

Do not silently change the file's actual content type because a user typed a different extension.

---

# 47. EXTENSION MISMATCH

If the user renames:

```text id="fztl4z"
report.pdf
```

to:

```text id="khc0b5"
report.jpg
```

do not silently treat the file as a JPEG.

The underlying MIME/content type should remain known independently.

Warn or preserve the original detected type where appropriate.

---

# 48. DELETE ATTACHMENT FROM NOTE

Provide:

> Remove Attachment

This removes the logical note association.

Do not automatically destroy shared underlying content if the architecture later supports deduplication.

For Phase 1, follow the actual existing reference/lifecycle model.

---

# 49. PERMANENT ATTACHMENT DELETION

When an attachment is permanently deleted according to existing product semantics:

- remove metadata
- remove encrypted local data
- remove cloud asset if owned
- remove sync state
- remove associated temporary resources
- update any references appropriately

Do not leave orphaned cloud objects.

---

# 50. NOTE TRASH

When a note is moved to Trash:

- attachment remains associated with the note
- attachment remains recoverable
- attachment must not be permanently deleted

This must match the existing trash model.

Your application intentionally keeps trash indefinitely. Preserve that behavior.

---

# 51. NOTE RESTORE

Restoring a trashed note must restore access to its attachments.

Do not re-upload unchanged attachments merely because the note was restored.

---

# 52. NOTE PERMANENT DELETE

When a note is permanently deleted:

all attachment associations must be removed.

If the attachment is not referenced elsewhere:

- delete encrypted local content
- delete cloud content
- remove attachment metadata

If the architecture permits shared attachment content in the future, ensure deletion is reference-aware.

Do not delete a shared blob merely because one note was permanently deleted.

---

# 53. ORPHAN DETECTION

Implement a safe mechanism or validation query for attachments that have no valid note association.

Do not silently delete orphans during ordinary operation.

If cleanup is implemented, make it explicit and safe.

---

# 54. SYNC INTEGRATION

Generic attachments must participate in existing synchronization.

Do not invent a second sync queue.

Reuse:

- dirty state
- upload state
- delete state
- revision semantics
- server identifiers
- conflict behavior

where applicable.

---

# 55. ZERO-KNOWLEDGE INVARIANT

The backend must never need plaintext file contents.

Generic attachments should follow:

```text id="zz0h6a"
Plain file
 ↓
client encryption
 ↓
encrypted payload
 ↓
cloud storage
```

Server metadata may contain only safe metadata required by the existing attachment architecture.

---

# 56. CLOUD METADATA

Do not send:

- plaintext file contents
- extracted text
- passwords
- OCR plaintext
- encryption keys

through the backend.

Metadata may include:

- attachment ID
- note ID
- size
- MIME type
- hash
- storage identifiers
- revision/state

only as appropriate to the existing architecture.

---

# 57. OFFLINE-FIRST SYNC

Immediately after attaching a file offline:

```text id="h2aq0d"
local attachment exists
dirty=true
```

Later, when online:

```text id="a1zj0u"
upload
→ server/cloud
→ synced
```

Do not require cloud availability before the user sees the attachment.

---

# 58. FAILED UPLOAD

If upload fails:

- keep local encrypted attachment
- mark sync/upload failure appropriately
- allow retry
- do not delete the user's local file

---

# 59. FAILED DOWNLOAD

If an attachment exists remotely but not locally:

- show unavailable/offline state
- allow download when connectivity returns
- verify integrity after decrypting/downloading

Do not silently report success if the file cannot be reconstructed.

---

# 60. INTEGRITY VALIDATION

After download:

```text id="3yrvm3"
download encrypted blob
 ↓
decrypt
 ↓
hash plaintext
 ↓
compare stored hash
```

If mismatch:

```text Attachment integrity check failed.
```

Do not present corrupt bytes as valid.

---

# 61. RETRY SAFETY

Retrying attachment upload/download must not create duplicate logical attachments.

Use stable attachment IDs and existing idempotency mechanisms where appropriate.

---

# 62. ATTACHMENT DELETION SYNC

Deleting an attachment must propagate through the normal sync mechanism.

Do not simply delete the local file and rely on absence to mean deletion.

Use the existing tombstone/deletion semantics where appropriate.

---

# 63. ATTACHMENT DOWNLOAD ON NEW DEVICE

On a fresh device:

1. sync attachment metadata
2. determine whether local content is required
3. download encrypted file when requested/appropriate
4. decrypt/verify
5. expose it locally

Do not download every massive attachment eagerly unless the current product policy already dictates that.

---

# 64. LAZY DOWNLOAD

Generic attachments should support lazy download.

Metadata can exist while bytes are not yet local.

UI should distinguish:

```text id="1g5fme"
Available
```

from:

```text id="0d7r6x"
Download required
```

---

# 65. ATTACHMENT DOWNLOAD UI

For a remote-only generic file:

```text id="l2m5dz"
project.zip
48.2 MB

[ Download ]
```

Do not pretend Open will work if bytes are absent.

---

# 66. DOWNLOAD PROGRESS

For large files:

```text id="4jv17x"
Downloading
42%
```

if the platform/storage layer provides reliable progress.

Otherwise use an indeterminate progress state.

Do not fake exact percentages.

---

# 67. CANCEL DOWNLOAD

Support cancellation where the existing transfer architecture supports it.

Clean partial downloads safely.

Do not leave corrupt ciphertext that can later be mistaken for a complete file.

---

# 68. BACKUP INTEGRATION

Extend the existing `.qpbackup` architecture so generic attachments can be backed up.

Do not create a second backup format.

The backup must preserve:

- attachment metadata
- attachment content
- association with note
- integrity
- necessary encryption metadata

Use the existing backup security architecture.

---

# 69. BACKUP SECURITY

Do not place decrypted generic files into an unencrypted backup if the current backup is encrypted or privacy-protected.

Respect the existing backup encryption semantics.

---

# 70. BACKUP RESTORE

A backup containing generic attachments must restore:

```text id="p5tbh5"
note
+
attachment metadata
+
attachment bytes
```

without breaking references.

---

# 71. BACKUP COLLISION HANDLING

If a note/attachment already exists during restore:

follow the existing backup conflict policy.

Do not create duplicate attachment records accidentally.

---

# 72. EXPORT INTEGRATION

The generic attachment system must integrate with the export system previously implemented.

Markdown portable export should be able to include generic files where appropriate.

Example:

```text id="ypcljg"
My Note/
  My Note.md
  attachments/
    diagram.png
    report.pdf
    report.xlsx
    script.py
```

Do not silently omit generic attachments.

---

# 73. QPNOTE INTEGRATION

QPNOTE must preserve generic attachments.

A full-fidelity package should be capable of containing:

```text id="2h5a81"
attachments/
    image.webp
    document.pdf
    spreadsheet.xlsx
    archive.zip
    source.py
```

Preserve original bytes whenever possible.

---

# 74. MARKDOWN REFERENCES

If an attachment is referenced directly in Markdown:

use the application's canonical attachment URI/reference model.

Do not invent a new generic attachment URI scheme unless the existing one cannot represent arbitrary files.

For example, if the existing asset reference supports:

```text id="3u2h3f"
qp://asset/<UUID>
```

determine whether that existing resource abstraction can safely represent generic files.

Do not create:

```text qp://generic-file/...
```

without architectural justification.

---

# 75. IMAGE COMPATIBILITY

Existing image Markdown:

```markdown id="5tqgvh"
![alt](qp://asset/<UUID>)
```

must continue to work.

Do not change image semantics merely because generic attachments were introduced.

---

# 76. DOCUMENT COMPATIBILITY

Existing scanned document references such as:

```markdown id="xmsx3z"
[Scanned Document](qp://document/<UUID>)
```

must continue to work.

Do not convert every document to a generic asset reference.

The existing document architecture contains meaningful metadata and processing semantics.

---

# 77. ATTACHMENT REPOSITORY

Where practical, expose a common attachment repository/service API:

```text id="v71z7h"
getAttachment
watchAttachmentsForNote
addAttachment
renameAttachment
removeAttachment
downloadAttachment
openAttachment
shareAttachment
```

Use actual project naming conventions.

Specialized services can remain underneath.

---

# 78. ATTACHMENT SERVICE

The generic service should orchestrate common lifecycle operations.

Do not turn it into a giant class containing:

- PDF generation
- OCR
- image normalization
- Cloudinary code
- UI state

Keep responsibilities separated.

---

# 79. CAPABILITY RESOLUTION

Use an `AttachmentCapabilityResolver` or equivalent if appropriate.

For example:

```text id="m6h1cd"
Image
→ thumbnail, preview, OCR, share, open

Scanned PDF
→ preview, OCR, share, open

DOCX
→ share, open

ZIP
→ share, open

Unknown
→ share, open
```

Phase 1 does not require all preview capabilities, but the architecture should be ready for them.

---

# 80. GENERIC FILE TYPE DISPLAY

Human-readable type detection should be centralized.

Examples:

```text id="mv2goa"
.docx → Microsoft Word
.xlsx → Microsoft Excel
.pptx → PowerPoint
.zip → ZIP Archive
.py → Python Source
.dart → Dart Source
.csv → CSV File
```

Do not create a thousand manual cases.

Use a sensible mapping with generic fallback.

---

# 81. ATTACHMENT MENU

Generic attachment actions:

```text id="n8j5w0"
Open
Share
Rename
Save As
Delete
```

Only expose Open when local content is available.

---

# 82. SAVE AS

Implement:

> Save As

where platform capabilities permit.

This should export a decrypted copy through safe platform file APIs.

Do not expose vault paths.

On Android, use the appropriate Storage Access Framework/document APIs where required rather than assuming direct public-storage writes.

The existing backup implementation already uses SAF for modern Android storage. Follow that platform-safe philosophy.

---

# 83. EXTERNAL OPEN SECURITY

Use safe content URIs/document providers rather than exposing arbitrary internal paths.

Do not grant permanent access unnecessarily.

Grant only required temporary permissions where the platform supports it.

---

# 84. ATTACHMENT DOWNLOAD + OPEN

If content is remote-only and user chooses Open:

```text id="h8e2i0"
download
→ verify
→ decrypt temporary open copy
→ Open With
```

Do not fail with an opaque error.

---

# 85. ATTACHMENT UI STATES

The attachment UI should distinguish:

```text id="g3o9nj"
Local
Downloading
Upload pending
Syncing
Failed
Deleted
Remote-only
```

Use existing sync status where possible.

Do not invent duplicate state machines.

---

# 86. GENERIC ATTACHMENT THUMBNAILS

Phase 1 does NOT require arbitrary file previews.

For unsupported files, use a type icon.

Do not create fake thumbnails.

---

# 87. IMAGE REGRESSION

Image attachments must continue to use existing thumbnails/previews.

Do not replace image rendering with generic icons.

---

# 88. PDF REGRESSION

Existing PDFs/documents must continue to open and render through the existing document viewer.

Do not reduce PDF functionality to "Open With."

---

# 89. OCR REGRESSION

Generic attachment support must not cause OCR to run on arbitrary files.

Existing OCR remains specialized.

Images and supported scanned documents continue to use the current OCR pipeline. The existing OCR implementation already has explicit page/attachment processing semantics.

---

# 90. SEARCH REGRESSION

Do not automatically index generic file contents in Phase 1.

Only index attachment metadata if the existing search model already supports it.

Full generic attachment text extraction/search is a later phase.

This avoids introducing plaintext leakage into the existing encrypted/OCR-aware search architecture.

---

# 91. NO AUTOMATIC OCR FOR GENERIC FILES

Do not run OCR on:

- ZIP
- DOCX
- XLSX
- source code
- arbitrary binaries

unless the existing application already has a specific safe implementation.

---

# 92. DUPLICATE FILE IMPORT

If the same exact file is picked twice in one import batch:

do not redundantly process it twice.

Choose behavior consistent with the existing attachment identity model.

---

# 93. CONTENT DEDUPLICATION

Do not aggressively implement global deduplication unless the existing architecture already supports shared content safely.

For Phase 1, recording content hashes is sufficient foundation.

Do not accidentally make two logical attachments share one file and then delete the bytes when only one reference is removed.

---

# 94. HASH-BASED VALIDATION

Use content hashes for:

- integrity
- duplicate detection
- backup validation
- transfer verification

Do not use hashes as authorization.

---

# 95. FILE CORRUPTION HANDLING

If local encrypted storage exists but decryption/hash validation fails:

- report attachment corruption
- do not silently overwrite
- offer re-download where remote copy exists
- preserve metadata
- avoid destroying potentially recoverable data

---

# 96. LOCAL STORAGE REPAIR

If a remote attachment exists but local encrypted bytes are missing:

mark remote-only/download-required.

Do not mark the attachment deleted.

---

# 97. CLOUD DELETE FAILURE

If permanent deletion succeeds locally but Cloudinary deletion fails:

follow the existing sync/deletion retry architecture.

Do not falsely report complete cloud deletion.

Do not lose the ability to retry.

---

# 98. ATTACHMENT DELETE IDEMPOTENCY

Repeated deletion requests must be safe.

Do not produce:

- duplicate deletion jobs
- errors from already-deleted remote objects
- inconsistent local state

Use existing idempotency semantics where possible.

---

# 99. ATTACHMENT UPLOAD IDEMPOTENCY

Repeated retries must not produce multiple cloud objects for one logical attachment if the existing provider architecture supports stable IDs/idempotency.

---

# 100. GENERIC FILE IMPORT FAILURE

If one file in a multi-file import fails:

- continue processing other valid files
- report which file failed
- do not roll back successful independent imports unless the existing UI semantics require atomic batches

Example:

```text id="r5mlq3"
Added 4 files.
1 file could not be attached.
```

Do not silently ignore failure.

---

# 101. IMPORT CANCELLATION

If user cancels a multi-file import:

- stop pending work
- clean temporary resources
- keep already completed attachments according to the chosen UX
- do not leave orphaned metadata

Prefer cancellation semantics that don't destroy completed user work.

---

# 102. FILE PICKER CANCELLATION

If the user cancels the picker:

- no error
- no mutation
- no empty attachment
- no notification required

---

# 103. ATTACHMENT COUNT

If the Notes/editor UI displays attachment counts, update them using actual attachment relationships.

Do not count failed/deleted attachments as active attachments.

---

# 104. ATTACHMENT METADATA FETCHING

Do not perform one database query per attachment widget.

Batch where possible.

---

# 105. N+1 QUERY PREVENTION

The note/editor UI must not trigger:

```text id="n1"
1 query per generic attachment
```

for type/metadata information.

Hydrate efficiently.

---

# 106. ATTACHMENT LIST PERFORMANCE

A note containing 100+ attachments should remain usable.

Avoid:

- huge widget trees
- loading every file's bytes
- decrypting every file for metadata
- generating thumbnails for unsupported files

Only metadata should be loaded initially.

---

# 107. LAZY CONTENT ACCESS

File bytes should be accessed only when needed for:

- opening
- sharing
- saving
- previewing when later implemented

---

# 108. PLATFORM FILE ACCESS

Inspect and follow the application's existing platform-safe APIs.

Do not make unsafe direct filesystem assumptions.

---

# 109. ANDROID

Respect Android Scoped Storage.

For:

- picking
- saving
- sharing

use the proper document/content URI mechanisms.

Do not request broad storage permissions merely because generic attachments are being added unless the platform and actual API requirement justify it.

---

# 110. IOS

Use the existing document picker/share infrastructure.

Do not expose internal sandbox paths.

---

# 111. DESKTOP

Use appropriate file picker/save/open mechanisms.

Support generic file paths safely.

---

# 112. WEB

If web is a supported platform, inspect its current attachment/storage behavior.

Do not assume mobile filesystem semantics apply.

If generic encrypted local storage is not supported on a platform, implement a documented graceful fallback rather than silently failing.

---

# 113. ACCOUNT BOUNDARY

Generic attachments must belong to the current user's notebook/account.

On logout/account switch:

- invalidate attachment queries
- clear account-local transient state
- do not expose previous account's files

Follow existing account reset semantics.

---

# 114. NOTE ASSOCIATION

An attachment can belong to a note.

Do not duplicate the attachment bytes in the note Markdown.

The Markdown may contain a reference to the attachment.

---

# 115. ATTACHMENT URIs

Reuse the existing URI/reference system where it can represent arbitrary attachments.

Inspect the current resource resolver before deciding.

Do not create multiple incompatible URI namespaces unnecessarily.

---

# 116. MARKDOWN IMAGE COMPATIBILITY

Do not break existing image import paths.

The current image importer rewrites local image references into canonical `qp://asset/<UUID>` references and performs encrypted ingestion. Preserve this behavior.

---

# 117. DOCUMENT COMPATIBILITY

Do not modify existing scanned-document references merely to fit the new generic model.

Preserve `qp://document/<UUID>` behavior where currently used.

---

# 118. ATTACHMENT RESOURCE RESOLUTION

Extend the resource resolver only as needed.

A generic file reference should resolve to the same conceptual object:

```text id="0oikak"
AttachmentResource
    id
    type
    local content
```

Do not make the Markdown parser aware of Cloudinary.

---

# 119. BACKGROUND PROCESSING

Generic file hashing/encryption of large files should not freeze the UI.

Use appropriate background execution.

Do not create isolates indiscriminately.

---

# 120. PROGRESS

Where possible, report meaningful:

```text id="6s6z8d"
Reading file
Encrypting
Saving
Uploading
```

Do not fabricate precision.

---

# 121. ERROR CATEGORIES

Use typed errors where the existing architecture supports them.

Potential:

```text id="7m5c6k"
fileNotFound
fileTooLarge
unsupportedAccess
invalidFile
encryptionFailed
storageFailed
uploadFailed
downloadFailed
integrityFailed
permissionDenied
cancelled
```

---

# 122. USER-FACING ERROR COPY

Errors must be understandable.

Never show raw exceptions.

Examples:

```text id="1ou7qh"
Couldn't attach this file.

Try again.
```

```text id="zq8p3a"
This file is larger than Quiet Paper allows.
```

```text id="lta2s0"
Couldn't download this attachment.
```

```text id="0zx35x"
Attachment integrity check failed.
```

---

# 123. NO CONTENT LEAK IN ERRORS

Do not include:

- full local file paths
- authentication data
- cloud URLs containing sensitive signatures
- file contents

in user-visible error messages.

---

# 124. EXPORT ERROR HANDLING

When an attachment cannot be included during export:

Follow the export subsystem's existing warning model.

Do not silently omit the generic file.

---

# 125. QPNOTE BYTE FIDELITY

For generic attachments included in QPNOTE:

The extracted/decrypted original bytes should match the imported plaintext file byte-for-byte.

Do not convert:

- line endings
- encoding
- compression
- file structure

for generic attachments.

---

# 126. BACKUP BYTE FIDELITY

Backup/restore should preserve generic attachment bytes.

Do not parse/re-serialize arbitrary files.

---

# 127. OPEN EXTERNALLY BYTE FIDELITY

The temporary decrypted file passed to the operating system must match the original plaintext bytes.

---

# 128. SAVE AS BYTE FIDELITY

The saved copy must match the original plaintext bytes exactly.

Verify with SHA-256 in tests.

---

# 129. RENAME BYTE FIDELITY

Renaming must not alter content.

Verify hash remains identical.

---

# 130. COPY / MOVE

Do not add arbitrary file-copy/move functionality beyond the attachment lifecycle.

---

# 131. ATTACHMENT CACHE

Do not create a redundant decrypted permanent cache.

Encrypted local attachment storage remains the authoritative offline copy.

---

# 132. TEMPORARY FILE CLEANUP

Any decrypted temp file created for:

- share
- open
- save

must have clear cleanup behavior.

Where platform share APIs keep files open beyond the immediate call, follow platform-specific safe lifecycle requirements and document the retention window.

Do not promise immediate deletion if the platform requires delayed cleanup.

---

# 133. CLOUDINARY DOWNLOAD CACHE

Reuse existing encrypted/local caching architecture where available.

Do not cache plaintext generic files permanently.

---

# 134. SECURITY REVIEW

Before completion inspect:

- filename path traversal
- MIME spoofing
- malicious extension
- archive files
- HTML/SVG
- oversized files
- temporary plaintext files
- external sharing
- external opening
- Cloudinary URLs
- local storage
- account separation

---

# 135. DO NOT EXECUTE FILES

Quiet Paper must never automatically execute an attachment.

This includes:

- scripts
- APKs
- EXEs
- shell files
- macros

Open externally only through explicit user action and OS mechanisms.

---

# 136. DO NOT AUTO-UNZIP

Do not extract ZIP/7z/TAR files automatically.

---

# 137. DO NOT PARSE ARBITRARY FILES IN PHASE 1

Generic storage is the goal.

Do not add:

- Office parsers
- archive browsers
- media players
- code editors
- document converters

to this phase.

---

# 138. ATTACHMENT CARD DESIGN

Use existing Quiet Paper styling.

The generic attachment card should feel like a native part of the editor.

Avoid:

- giant cards
- Material file-manager aesthetics
- colorful icons
- excessive metadata

Use:

```text id="7m6j8b"
small icon
filename
type / size
compact action
```

---

# 139. LONG FILENAMES

Long names must truncate gracefully.

Example:

```text id="bgh0zq"
really-long-project-document-name...
```

The full name must remain accessible through:

- tooltip
- details
- accessibility label

where supported.

---

# 140. ATTACHMENT DETAILS SHEET

Consider a compact details sheet containing:

```text id="0blhtr"
Filename
Type
Size
Created
Status
```

plus:

```text Open
Share
Save As
Rename
Delete
```

Only expose actual actions.

This can be a reusable generic attachment details UI.

---

# 141. TYPE DETECTION DISPLAY

For unknown file:

```text id="g9t6hw"
Unknown File
```

not:

```text application/octet-stream
```

unless in developer diagnostics.

---

# 142. FILE EXTENSION DISPLAY

Use lowercase/standardized display conventions consistently.

Do not mutate user filename unnecessarily.

---

# 143. ATTACHMENT METADATA EDITING

Phase 1 should support at least:

- rename

Do not add arbitrary custom metadata fields yet.

---

# 144. FAVORITES/PINNING

Do not add attachment favorites unless the product already has this concept.

---

# 145. ATTACHMENT NOTES

Do not add descriptions/comments to attachments in Phase 1.

---

# 146. GENERIC FILE ICONOGRAPHY

Centralize type-to-icon mappings.

Keep fallback icon neutral.

---

# 147. NO DATABASE SCHEMA DUPLICATION

If the existing attachment and document tables already overlap conceptually, carefully decide whether:

- add a generic attachment table
- extend existing attachment table
- create a common metadata table

based on actual code.

Do not create parallel systems like:

```text id="a"
attachments
generic_attachments
file_attachments
```

without a strong architectural reason.

---

# 148. DATABASE MIGRATION

If schema changes are necessary:

- increment schema version properly
- add indexes
- preserve current data
- migrate existing image/document records safely
- do not recreate existing attachment IDs unnecessarily

The current application has explicit migration hardening; follow it.

---

# 149. EXISTING DATA MIGRATION

If introducing a common abstraction, existing:

- image attachments
- document records

must remain valid.

Do not require users to re-import everything.

Use compatibility/adapters where possible.

---

# 150. IMAGE/DOCUMENT IDENTITY

Existing image/document IDs must not change merely because the new generic attachment abstraction exists.

Unless there is an explicitly safe migration strategy, preserve them.

---

# 151. SYNC BACKWARDS COMPATIBILITY

Do not alter existing sync payloads for images/documents unnecessarily.

If generic attachments require a new payload type, make it additive and versioned.

---

# 152. SERVER CHANGES

Only modify backend/Turso schema if genuinely required by the current architecture.

If backend changes are necessary:

- inspect current attachment/document endpoints
- preserve old clients
- make migrations additive
- preserve zero-knowledge

Do not perform unrelated backend refactoring.

---

# 153. CLOUD STORAGE BACKWARDS COMPATIBILITY

Existing Cloudinary image/document resources must remain accessible.

Do not change their resource IDs/paths during migration unless absolutely necessary.

---

# 154. ATTACHMENT BACKUP BACKWARDS COMPATIBILITY

Existing `.qpbackup` files must remain restorable after this feature.

Do not break old backup schemas.

If new generic attachments are added to a new backup schema:

- version it
- preserve old fields
- maintain backward restore support

---

# 155. EXPORT BACKWARDS COMPATIBILITY

Existing Markdown/PDF/HTML/DOCX/QPNOTE export flows must continue working.

Generic attachments must be included where those export formats support them.

---

# 156. QPNOTE MANIFEST

If the QPNOTE manifest already exists, extend it rather than replace it.

Generic attachment entries should include:

```text id="vjd9hn"
attachmentId
filename
mimeType
size
contentHash
relativePath
kind
```

or equivalent schema.

---

# 157. ATTACHMENT HASH IN QPNOTE

If generic file bytes are embedded:

the package manifest should be able to verify them.

Use SHA-256 where appropriate.

---

# 158. BACKUP INTEGRITY

Backup restore should validate attachment integrity.

If a file is corrupted:

- report the attachment
- do not silently create invalid content

---

# 159. TESTING — GENERIC IMPORT

Test importing:

```text id="n4c1sw"
.txt
.md
.csv
.json
.yaml
.xml
.zip
.docx
.xlsx
.pptx
.py
.dart
.bin
```

where the platform test environment supports fixture files.

Do not hard-code that all these formats must have special behavior.

They only need to survive as generic attachments.

---

# 160. TESTING — UNKNOWN FILE

Test:

```text id="9y8g3p"
mystery.bin
application/octet-stream
```

Expected:

- accepted as generic attachment
- correct filename
- correct size
- hash stored
- encrypted locally
- share/open supported where platform permits

---

# 161. TESTING — ZERO BYTE

Verify zero-byte generic file remains valid.

---

# 162. TESTING — LARGE FILE

Test near the maximum supported size.

Verify:

- import
- encryption
- local storage
- hash
- UI
- save/open/share
- cleanup

---

# 163. TESTING — OVERSIZED FILE

Verify rejection is clean and leaves no partial attachment.

---

# 164. TESTING — PATH TRAVERSAL

Use filenames:

```text id="f3u4e9"
../../secret.txt
..\..\secret.txt
/absolute/path.txt
C:\absolute\path.txt
```

Ensure safe handling.

---

# 165. TESTING — MIME SPOOFING

Test mismatched extension/MIME examples.

Verify generic handling does not execute/interpret the file unsafely.

---

# 166. TESTING — HASH

Import file.

Compute expected SHA-256.

Verify stored hash.

Rename.

Verify hash unchanged.

Save As.

Verify output hash matches original.

---

# 167. TESTING — BYTE FIDELITY

Compare original and restored file bytes.

They must match exactly.

Do not just compare file size.

---

# 168. TESTING — ENCRYPTION

Verify:

- local stored bytes are encrypted
- plaintext isn't present in the attachment vault
- decrypt restores exact original bytes

Use existing encryption tests/patterns.

---

# 169. TESTING — SHARING

Verify a generic file can be shared.

Where platform APIs make the final external handoff difficult to test automatically, test the temporary decrypted representation and cleanup behavior.

---

# 170. TESTING — OPEN EXTERNALLY

Verify the OS-facing file has:

- correct filename
- correct MIME
- correct bytes

where platform integration testing permits.

---

# 171. TESTING — RENAME

Verify:

```text id="3j9lq1"
filename changes
hash unchanged
bytes unchanged
attachment ID unchanged
```

---

# 172. TESTING — DELETE

Verify removal from note.

Then verify:

- local encrypted content cleanup
- cloud deletion according to lifecycle
- sync state

---

# 173. TESTING — TRASH

Trash note.

Verify attachment remains available.

Restore.

Verify attachment remains available.

---

# 174. TESTING — PERMANENT DELETE

Permanently delete note.

Verify:

- association removed
- encrypted attachment bytes removed
- cloud content removed according to existing architecture
- no orphan attachment metadata

---

# 175. TESTING — NEW DEVICE

Simulate:

```text id="2bh5v1"
Device A
attach file
sync

Device B
sync metadata
download
decrypt
verify hash
open
```

---

# 176. TESTING — OFFLINE

Import while offline.

Verify:

- attachment immediately appears
- encrypted local bytes exist
- note remains usable
- sync waits until connectivity returns

---

# 177. TESTING — FAILED UPLOAD

Force upload failure.

Verify:

- local attachment remains
- retry possible
- no duplicate attachment
- state accurately indicates failure

---

# 178. TESTING — FAILED DOWNLOAD

Force download failure.

Verify:

- no corrupt attachment
- metadata preserved
- retry works

---

# 179. TESTING — INTEGRITY FAILURE

Corrupt downloaded data.

Verify:

- hash mismatch detected
- file is not exposed as valid
- user sees recoverable error

---

# 180. TESTING — BACKUP

Create backup containing:

- image
- scanned PDF
- generic DOCX
- ZIP
- arbitrary binary

Restore.

Verify all original bytes.

---

# 181. TESTING — EXPORT

Create a note with:

- image
- PDF
- DOCX
- ZIP
- source file

Export Markdown with attachments.

Verify attachment references and files are preserved.

Export QPNOTE.

Verify all files are present.

---

# 182. TESTING — NO SEARCH LEAK

Attach a plaintext text file.

Verify Phase 1 does not automatically persist extracted text into the search index.

---

# 183. TESTING — IMAGE REGRESSION

Existing image tests must still pass.

Existing image UI must look identical or better.

---

# 184. TESTING — DOCUMENT REGRESSION

Existing scanned-document tests must still pass.

Existing PDF/document processing must be unaffected.

---

# 185. TESTING — OCR REGRESSION

Existing OCR tests must still pass.

Generic files must not accidentally enter OCR.

---

# 186. TESTING — SYNC REGRESSION

Run existing sync tests.

Especially verify:

- fresh-device behavior
- deletion
- trash
- attachment/document sync
- retries

---

# 187. TESTING — BACKUP REGRESSION

All existing backup tests must pass.

---

# 188. TESTING — UI

Test:

- attachment menu
- File picker
- generic attachment row/card
- actions menu
- rename
- share
- open
- save
- delete
- progress
- failure
- offline state

---

# 189. TESTING — MULTI-FILE IMPORT

Test:

```text id="qdkqtg"
10 valid files
2 oversized files
1 inaccessible file
```

Verify:

- successful files attach
- invalid files report failure
- no corrupt state
- progress correct
- cancellation safe

---

# 190. TESTING — PERFORMANCE

Test a note with:

```text id="58czhi"
100 generic attachments
```

Verify opening the note does not load all bytes into memory.

Only metadata should be loaded.

---

# 191. TESTING — VERY LARGE ATTACHMENT COUNT

Test 500+ attachments in a controlled environment.

Verify:

- scrolling
- metadata display
- no N+1 queries
- no memory explosion

---

# 192. TESTING — ACCOUNT SEPARATION

Switch accounts.

Verify previous account's attachment metadata/content is not visible.

---

# 193. TESTING — SECURITY

Test:

- path traversal
- MIME spoofing
- temporary plaintext cleanup
- protected notes
- malformed files
- corrupted ciphertext
- cloud download integrity
- logging

---

# 194. PROTECTED NOTES

The existing password-protected-note system encrypts note title/content/tags and uses a dedicated unlock flow.

Generic attachments associated with protected notes must not bypass that security model.

Follow existing rules for whether attachments are accessible before note unlock.

Do not invent weaker access semantics.

---

# 195. READ-ONLY MODE

In read-only note mode:

- attachments may be opened/shared
- attachment metadata may be viewed
- mutation actions such as rename/delete should be disabled or hidden

Follow existing read-only semantics.

The current editor already disables editing controls in read-only mode.

---

# 196. EXPORT + PROTECTED NOTES

Do not allow generic attachment export to bypass protected-note authorization.

Follow existing export security rules.

---

# 197. NO PERSISTED DECRYPTED COPIES

The generic attachment system must not leave decrypted copies in:

- cache
- thumbnails
- temp directory
- logs
- crash reports

unless required by an explicit, controlled external-share/open workflow.

---

# 198. TEMP CLEANUP

Where practical, run cleanup:

- after share
- after external open timeout/lifecycle
- on app startup for stale temp files
- after failed operations

Do not delete files still in active use by the platform.

---

# 199. STALE TEMP FILE CLEANUP

Implement a safe cleanup routine for temporary decrypted attachment files.

Use:

- creation timestamps
- ownership markers
- app-specific temp prefix

Do not delete unrelated temporary files.

---

# 200. FILE PROVIDER SECURITY

On Android/iOS, use secure provider/share mechanisms.

Never expose internal encryption directories to external apps directly.

---

# 201. DATA MODEL NAMING

Use user-facing term:

> Attachment

Use implementation-specific:

> GenericFileAttachment

only where useful.

Do not expose "Cloudinary" or "raw resource" terminology to users.

---

# 202. DOCUMENT VS GENERIC FILE

Preserve the existing scanned-document specialization.

Conceptually:

```text id="w8l9vu"
Generic File
      ↑
broad storage capability

Scanned Document
      ↑
specialized document capability
```

Do not make scanner output lose:

- page count
- processing state
- OCR
- document semantics

---

# 203. ATTACHMENT RESOURCE ABSTRACTION

If the existing `qp://asset/<UUID>` mechanism is image-oriented, determine whether it can safely become an all-file asset reference.

Do not make a rushed namespace change.

Preserve backwards compatibility.

---

# 204. MARKDOWN LINKING RULE

Generic arbitrary files may not automatically have a Markdown visual representation.

That's okay.

The attachment can exist attached to the note even if Markdown does not explicitly embed it.

Do not force every attachment into Markdown.

---

# 205. ATTACHMENT INSERTION

When a user adds a generic file:

The file should appear in the note's attachment area/card/list according to existing UI architecture.

Do not automatically insert a Markdown link unless that is already the application's established attachment behavior.

---

# 206. FILENAME COLLISION

Two different attachments may both be named:

```text id="0a5jv5"
report.pdf
```

They must remain distinct.

Use attachment IDs internally.

---

# 207. SAME FILE ATTACHED TO MULTIPLE NOTES

Do not assume this is supported unless the existing architecture supports it.

If implementing shared references is not safe yet:

each logical attachment can remain independent while still sharing the same content hash metadata.

Do not silently introduce reference-counted shared storage in Phase 1.

---

# 208. FUTURE DEDUPLICATION PREPARATION

Store content hashes so a future version can introduce content deduplication.

Do not implement risky global shared blobs now unless explicitly required.

---

# 209. ATTACHMENT ORDER

Preserve attachment insertion order where the existing UI relies on it.

If the existing model has an ordering field, reuse it.

Do not reorder attachments by filename.

---

# 210. ATTACHMENT CREATION TIME

Store actual attachment creation time according to existing semantics.

Do not use file modification time as a substitute unless that's how the current picker model works.

---

# 211. ATTACHMENT MODIFICATION TIME

Renaming metadata may update attachment metadata timestamp if appropriate.

Do not alter the underlying content timestamp semantics unnecessarily.

---

# 212. CONTENT IMMUTABILITY

An attachment's byte content should be immutable in Phase 1.

To replace a file's contents:

- remove old attachment
- add a new attachment

unless the existing architecture explicitly supports replacement.

This keeps content hashes and sync semantics straightforward.

---

# 213. NO IN-PLACE CONTENT EDITING

Do not implement:

- editing DOCX
- editing TXT
- editing CSV

in Phase 1.

---

# 214. NO AUTOMATIC FILE CONVERSION

Do not convert:

```text id="v41thg"
.docx → PDF
.csv → Markdown
.py → note
```

in Phase 1.

Those belong to later intelligence/preview phases.

---

# 215. GENERIC ATTACHMENT PREVIEW

For Phase 1:

unsupported generic files should use:

```text id="y8p4nn"
file icon
filename
type
size
Open / Share
```

Do not display a fake preview.

---

# 216. OPTIONAL TEXT PREVIEW

Do not implement text preview in Phase 1 unless already supported by the existing architecture.

Text extraction/search belongs to Phase 2.

---

# 217. OPTIONAL CODE PREVIEW

Do not implement code-file preview/editing in Phase 1.

This can reuse the future syntax-highlighting system later.

---

# 218. AUDIO/VIDEO

Do not embed media players in Phase 1.

Use external opening/sharing.

---

# 219. ARCHIVES

Do not unpack archives.

---

# 220. FONTS

Store safely as generic files.

Do not automatically install or register fonts.

---

# 221. EXECUTABLES

Store safely as generic files.

Do not execute/install automatically.

---

# 222. ATTACHMENT MALWARE MODEL

Quiet Paper is not an antivirus.

Do not pretend to scan all binaries for malware.

At most:

- validate container/file integrity
- restrict unsafe inline rendering
- use external OS handling for execution/opening

---

# 223. FILE TYPE POLICY

Have a centralized policy class/resolver rather than scattered conditions.

Conceptually:

```text id="9j7q7f"
AttachmentTypeResolver
AttachmentCapabilityResolver
AttachmentPolicy
```

---

# 224. ATTACHMENT POLICY

The policy can determine:

```text allowed
maxSize
capabilities
externalOpenAllowed
inlinePreviewAllowed
```

For Phase 1, most generic types should be:

```text allowed = true
inlinePreviewAllowed = false
externalOpenAllowed = true
```

subject to actual platform/security constraints.

---

# 225. UNKNOWN EXTENSIONS

Unknown extensions should normally be accepted as generic files if otherwise safe.

Do not reject unknown extensions merely because the application doesn't understand them.

---

# 226. FILE PICKER FILTERING

Prefer allowing:

> All Files

rather than maintaining an exhaustive extension whitelist.

If the picker API requires filters, choose the broadest safe option.

---

# 227. CLOUDINARY TYPE MAPPING

Provider mapping should be based on MIME/storage semantics, not UI category.

Inspect current provider limitations first.

---

# 228. BACKUP STORAGE EFFICIENCY

Do not unnecessarily duplicate attachment bytes inside multiple backup files if the existing backup architecture already packages them efficiently.

Follow the established `.qpbackup` structure.

---

# 229. EXPORT STORAGE EFFICIENCY

Do not duplicate a generic attachment in multiple package locations.

Use one physical copy per attachment within a QPNOTE.

---

# 230. ATTACHMENT CLEANUP AFTER EXPORT

Export must never delete original attachments.

Only temporary copies may be cleaned.

---

# 231. ATTACHMENT CLEANUP AFTER SHARE

Share must never alter/delete the logical attachment.

Only temporary decrypted share files may be cleaned.

---

# 232. ATTACHMENT CLEANUP AFTER OPEN

Opening externally must never alter/delete the logical attachment.

---

# 233. ACCOUNT LOGOUT CLEANUP

Do not accidentally delete user's encrypted local attachments merely because they logged out if the existing account-storage policy retains them.

Follow current security/account-reset behavior.

---

# 234. ATTACHMENT LOCAL ENCRYPTION KEY VERSION

Persist whatever key/envelope version the existing encryption architecture requires.

Do not hard-code one encryption version in the UI layer.

---

# 235. KEY ROTATION

Generic attachments must remain compatible with the application's existing encryption key rotation strategy.

Do not create an attachment implementation that becomes undecryptable after key rotation.

---

# 236. RECOVERY

If the existing recovery-key/encryption system supports recovery of attachments, generic files must follow the same recoverability model.

Do not introduce an attachment format that bypasses key recovery.

---

# 237. SYNC CONFLICT

Generic attachment metadata must participate in the existing sync conflict semantics.

Do not create special content-conflict resolution for generic files.

Binary contents are immutable in Phase 1.

---

# 238. REVISION

Attachment metadata mutations such as rename/delete must use the existing revision/sync model.

Do not mutate attachment metadata outside repository/sync architecture.

---

# 239. OFFLINE DELETE

If user deletes an attachment offline:

```text id="0b2x8s"
local deletion/tombstone
→ sync later
```

Do not immediately require network.

---

# 240. OFFLINE RENAME

Rename offline.

Verify:

- local state updates
- sync later
- no upload of file bytes is required if only metadata changed

---

# 241. ONLINE RENAME

Rename online.

Do not unnecessarily re-upload unchanged file contents.

Only metadata/sync changes should occur.

---

# 242. HASH STABILITY

Metadata operations must not change content hash.

---

# 243. FILE SIZE STABILITY

Metadata operations must not alter file size.

---

# 244. BACKUP VERSIONING

If backup schema changes:

Use explicit versioning.

Do not infer format solely from file extension.

---

# 245. EXPORT VERSIONING

If QPNOTE schema changes:

extend its existing manifest/version mechanism.

Do not break older package imports/validation.

---

# 246. DOCUMENTATION

Update `HANDOFF.md` or the project's equivalent engineering documentation with:

- generic attachment model
- lifecycle
- encryption
- local storage
- provider mapping
- sync
- backup
- export
- security
- supported capabilities
- Phase 1 limitations
- migration notes

---

# 247. NO PLACEHOLDER DOCUMENTATION

Document what actually exists.

Do not document future preview/search features as if implemented.

---

# 248. CODE QUALITY

Follow existing:

- Dart style
- Riverpod architecture
- repository patterns
- error types
- logging
- testing
- dependency management

Do not introduce unrelated refactors.

---

# 249. NO GOD SERVICE

Do not make one `GenericAttachmentService` responsible for:

- UI
- database
- Cloudinary
- encryption
- sharing
- file picking
- backup
- export

Use appropriate layers.

---

# 250. RECOMMENDED LAYERING

Conceptually:

```text id="p8zi44"
Presentation
    ↓
Attachment Application Service
    ↓
Attachment Repository
    ↓
Storage / Encryption / Sync abstractions
```

The exact project architecture takes precedence.

---

# 251. GENERIC FILE INGESTION SERVICE

Consider an abstraction such as:

```text id="1dprfu"
AttachmentImportService
```

Responsibilities:

- validate picked file
- derive metadata
- hash
- encrypt/store
- persist attachment
- return attachment ID/result

It should not know how to render the attachment.

---

# 252. ATTACHMENT OPEN SERVICE

Separate:

```text id="zoxth2"
AttachmentOpenService
```

for:

- local availability
- decrypt
- temporary file
- OS handoff
- cleanup

---

# 253. ATTACHMENT SHARE SERVICE

Likewise:

```text id="8yu5be"
AttachmentShareService
```

or combine with Open/Export infrastructure if the existing architecture has a better abstraction.

---

# 254. TESTABLE ABSTRACTIONS

All platform-specific components should be mockable:

- file picker
- share
- external open
- filesystem
- Cloudinary
- encryption where practical

---

# 255. TEST FIXTURES

Add deterministic fixtures for:

```text id="w7i9ta"
tiny text file
large binary
unknown extension
ZIP-like binary
JSON
DOCX-like fixture
image
PDF
```

Do not rely solely on live user files.

---

# 256. SECURITY FIXTURES

Include malicious filenames and malformed file headers.

---

# 257. BACKUP FIXTURES

Create backup fixture containing mixed attachment types.

---

# 258. SYNC FIXTURES

Create mixed local/remote attachment state fixtures.

---

# 259. UI TEST FIXTURES

Test mixed attachment list:

```text id="l5u3cw"
image
PDF
DOCX
ZIP
unknown
```

Verify each displays correctly.

---

# 260. REGRESSION TEST REQUIREMENT

Run the entire existing Flutter suite.

The current project has a broad test surface covering editor, Markdown, frontmatter, UI, crypto, sync and other systems. Do not only run the new attachment tests.

---

# 261. COMMANDS

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

If backend changes are genuinely required:

```bash
cd backend
npm test
npm run build
```

Run only the backend commands relevant to actual backend changes.

---

# 262. NO WARNINGS

Target:

```text
flutter analyze
0 errors
0 warnings
```

Do not suppress analyzer warnings merely to declare success.

---

# 263. DATABASE VALIDATION

If migrations change:

- test fresh install
- test upgrade from existing schema
- test current data
- test backup restore

---

# 264. CROSS-PLATFORM QA

Test the generic file picker and attachment actions on the platforms actually supported by the application.

At minimum, where supported:

- Android
- iOS
- desktop platforms

Do not claim unsupported platform behavior is working.

---

# 265. USER EXPERIENCE ACCEPTANCE

The normal flow should feel like:

```text id="h77e2r"
Open Note
   ↓
+
   ↓
Add to Note

Photo
Scan Document
File
```

Choose File:

```text id="y8do2v"
system file picker
```

Select:

```text id="3h0x70"
project.xlsx
```

Then:

```text id="v3lq1p"
project.xlsx
Microsoft Excel · 2.4 MB
```

Actions:

```text id="4s2gq9"
Open
Share
Rename
Save As
Delete
```

The user should not need to know anything about encryption, Cloudinary, resource types, hashes, or sync internals.

---

# 266. PHASE 1 LIMITATIONS MUST BE CLEAR

Phase 1 does NOT need to provide:

- in-app DOCX viewer
- in-app XLSX viewer
- in-app ZIP browser
- text attachment search
- generic attachment OCR
- code editor
- audio player
- video player
- archive extraction
- content conversion

These are future capabilities.

Generic files only need reliable lifecycle/storage behavior in this phase.

---

# 267. FUTURE-READY DESIGN

The Phase 1 architecture must make Phase 2 possible without a database redesign.

Future:

```text id="fdu2kr"
Attachment
    ↓
CapabilityResolver
    ↓
Previewer
```

can later add:

```text id="4j3k13"
TextPreviewer
CodePreviewer
SpreadsheetPreviewer
AudioPreviewer
VideoPreviewer
```

without changing the fundamental attachment storage model.

---

# 268. FUTURE SEARCH-READY

Store enough metadata to support future text extraction/indexing:

- MIME type
- extension
- hash
- size

but do not index content in Phase 1.

---

# 269. FUTURE DEDUP-READY

Store content hash.

Do not implement global shared blobs unless safely supported.

---

# 270. FUTURE PREVIEW-READY

Store reliable MIME/type metadata.

Do not store derived previews unless a capability actually requires them.

---

# 271. FINAL DEFINITION OF DONE

Phase 1 is complete only when:

### Import

- arbitrary generic files can be selected
- multiple files can be selected where supported
- size is validated
- metadata is recorded
- MIME/type is determined
- content hash is recorded
- file is encrypted locally
- attachment record is created

### Storage

- encrypted local storage works
- no plaintext permanent copies
- byte fidelity is preserved
- integrity can be verified

### UI

- generic attachment appears correctly
- filename is displayed
- type is displayed
- size is displayed
- unknown types have safe fallback
- Open works where supported
- Share works
- Rename works
- Save As works
- Delete works

### Sync

- offline attach works
- upload later works
- download works
- retry works
- deletion sync works
- rename syncs without unnecessary byte upload
- fresh-device recovery works

### Lifecycle

- trash preserves attachment
- restore preserves attachment
- permanent deletion cleans associations and storage according to ownership/reference semantics

### Backup

- generic attachment bytes are backed up
- restore works
- hashes/bytes remain correct

### Export

- Markdown portable export handles generic attachments
- QPNOTE includes generic attachments
- bytes remain unchanged
- no silent omission

### Security

- encryption preserved
- no secrets logged
- no plaintext OCR/indexing
- no arbitrary execution
- path traversal prevented
- temporary decrypted files controlled
- protected-note access rules preserved

### Regression

- image attachments still work
- scanned PDFs/documents still work
- OCR still works
- sync still works
- backup still works
- editor still works
- search still works
- existing tests pass

---

# 272. FINAL AGENT REPORT

After implementation provide:

```text
Generic Attachment System — Phase 1

Architecture:
- ...

Existing systems reused:
- ...

Generic attachment model:
- ...

Supported import behavior:
- ...

Supported user actions:
- ...

Encryption:
- ...

Local storage:
- ...

Cloud storage:
- ...

Sync:
- ...

Trash/deletion lifecycle:
- ...

Backup:
- ...

Export:
- ...

Database changes:
- ...

Backend changes:
- ...

Dependencies added:
- ...

Migration:
- ...

Tests added:
- ...

Existing tests:
- ...

flutter analyze:
- ...

flutter test:
- ...

Manual QA:
- ...

Known limitations:
- ...

Future Phase 2 extension points:
- ...
```

Do not claim an action works unless it has been implemented and verified.

Do not claim arbitrary file preview support in Phase 1.

Do not claim generic attachment text search in Phase 1.

Do not claim all file types have native in-app rendering.

The goal of this phase is:

> **Make arbitrary files first-class, secure, offline-capable Quiet Paper attachments without sacrificing the specialized behavior of images and scanned documents.**