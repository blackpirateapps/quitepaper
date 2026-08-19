
You are working on **Quiet Paper**, an offline-first Flutter notes application inspired by Bear Notes. You are extending the existing production-oriented architecture with **encrypted image attachments**, **direct-to-Cloudinary uploads**, and the foundational **internal `qp://` resource URI system** that will later support note-to-note linking.

This is an implementation task, not a greenfield redesign.

You MUST first study and respect the existing repository architecture, conventions, security model, sync engine, Markdown editor, Drift schema, Riverpod state management, authentication system, backup system, and tests. Do not replace existing architectural decisions merely because another approach is more familiar.

The current project deliberately treats Markdown as the canonical note representation, uses local SQLite/Drift persistence, performs client-side encryption using Argon2id and XChaCha20-Poly1305, and synchronizes encrypted note content through a Vercel/TypeScript backend with Turso/libSQL. The existing handoff explicitly states that note title/body/tags are encrypted before leaving the device and that the backend is crypto-blind. Preserve these invariants.

The existing editor also deliberately preserves a 1:1 relationship between Markdown source characters and the editable representation; no rich-text JSON, HTML, Delta, ProseMirror, Quill, or alternate document model is to be introduced.

Before you begin specify the env variables that needs to be added for the cloudinary image upload to work. 

---

# 1. Primary Objective

Implement the next Quiet Paper architecture phase with these capabilities:

1. Local image insertion from supported device sources.
2. Offline-first image storage.
3. Image references embedded in Markdown using stable internal Quiet Paper resource URIs.
4. Client-side encryption of image bytes before any network transfer.
5. Direct upload of encrypted image data from the Flutter client to Cloudinary.
6. No image byte streaming/proxying through Vercel serverless functions.
7. Vercel backend remains the control plane for authentication, authorization, upload authorization, metadata, synchronization, and lifecycle management.
8. Cloudinary is treated as encrypted object/blob storage rather than as an image-processing service.
9. Attachment metadata and attachment lifecycle participate in the existing synchronization model.
10. Image deletion is represented safely with tombstones and deferred physical deletion.
11. Image uploads never block note editing, autosave, or ordinary offline use.
12. A first-class `qp://` URI abstraction is introduced now.
13. `qp://asset/<UUID>` is used for image/attachment references.
14. `qp://note/<UUID>` is reserved and supported architecturally for future note-to-note links.
15. The URI system must be generic enough to support additional Quiet Paper resource types later.
16. Do NOT introduce image editing features.
17. Do NOT introduce note-linking UI in this phase; only build the foundational URI/resource architecture necessary for future note linking.
18. Preserve all existing encryption, authentication, sync, backup, editor, and offline-first guarantees.
19. Add comprehensive automated tests for the new behavior and regression protection.
20. Do not leave architectural decisions ambiguous; implement the contracts defined below unless the existing repository imposes a concrete constraint that requires adaptation.

---

# 2. Existing Architecture Is the Source of Truth

Before modifying code:

* Read the existing handoff document.
* Inspect the actual repository rather than relying only on the handoff.
* Identify the current Drift schema version and migration conventions.
* Identify the current `SyncEngine`, sync queue, sync API client, backend sync service, Zod schemas, and revision model.
* Identify the current Markdown tokenizer/parser/editor/controller architecture.
* Identify current crypto primitives and key management.
* Identify the current local backup/restore implementation and determine how attachments should participate without breaking existing backups.
* Inspect existing authentication and authorization boundaries.
* Inspect current error handling and logging conventions.
* Inspect existing test patterns and fixtures.
* Run the existing test suite and static analysis before changes.
* Do not remove or weaken existing tests merely to make new code pass.

The handoff identifies the current Drift database, sync engine, attachment-adjacent infrastructure, Markdown parser/editor, and Vercel backend as separate but cooperating layers. Preserve that separation.

---

# 3. Non-Negotiable Product Principles

## 3.1 Markdown remains canonical

A note remains a Markdown string.

Images are represented by references embedded in that Markdown.

Do not create a second rich-text document model.

Do not convert notes to HTML.

Do not create embedded image JSON nodes as the canonical note representation.

Do not turn the Markdown editor into a ProseMirror/Quill/Delta-style editor.

The existing editor architecture explicitly preserves the underlying Markdown characters and selection offsets. The image implementation must preserve that model.

---

## 3.2 Images are attachments/resources, not note content blobs

An image is an independently identifiable object associated with a note.

Conceptually:

```text
Note
 ├── canonical Markdown
 │      └── qp://asset/<attachment-id>
 │
 └── Attachment
        ├── metadata
        ├── local encrypted bytes
        └── cloud encrypted bytes
```

Do not place the raw image bytes into the note Markdown.

Do not base64-encode images into note bodies.

Do not make Cloudinary URLs part of the canonical Markdown.

---

## 3.3 Storage location must never become logical identity

The Markdown must refer to a stable logical resource identity:

```text
qp://asset/<attachment-id>
```

not:

```text
https://res.cloudinary.com/...
```

not:

```text
/storage/emulated/0/...
```

not a temporary local file path.

This ensures notes remain portable between devices and storage implementations.

---

# 4. Internal Quiet Paper URI System

Introduce a first-class `QuietPaperUri` abstraction.

The initial URI grammar is:

```text
qp://<resource-type>/<resource-id>
```

Initial supported resource types:

```text
qp://asset/<UUID>
qp://note/<UUID>
```

`asset` is implemented now.

`note` is reserved for future note-to-note linking and must be structurally supported by the URI parser/resolver architecture, but do not build the complete note-linking UX in this phase.

Do not scatter raw string checks across the codebase such as:

```dart
url.startsWith('qp://note/')
```

or:

```dart
url.startsWith('qp://asset/')
```

Instead introduce a reusable parser/model concept, for example:

```text
QuietPaperUri
 ├── scheme
 ├── resourceType
 └── resourceId
```

The precise naming may follow repository conventions, but the separation must exist.

Parsing:

```text
qp://note/abc
```

must produce conceptually:

```text
scheme = qp
resourceType = note
resourceId = abc
```

Likewise:

```text
qp://asset/xyz
```

must produce:

```text
scheme = qp
resourceType = asset
resourceId = xyz
```

Validate the URI structure rigorously.

Reject malformed or unsupported `qp://` URIs safely.

Do not allow arbitrary URI types to trigger unexpected application behavior.

---

# 5. Resource Resolution Architecture

Separate URI parsing from resource resolution.

The intended architecture is:

```text
Markdown
   ↓
Quiet Paper URI parsing
   ↓
QuietPaperUri
   ↓
Resource resolver
   ├── Note resolver
   └── Asset resolver
```

The Markdown layer identifies the resource reference.

The resolver determines what the reference means.

For assets:

```text
qp://asset/<id>
        ↓
Attachment resolver
        ↓
local attachment record
        ↓
local/decrypted image
```

For future notes:

```text
qp://note/<id>
        ↓
Note resolver
        ↓
local note record
        ↓
navigate to note
```

Do not couple Markdown parsing directly to database APIs, Cloudinary APIs, or navigation.

---

# 6. Markdown Image Representation

Canonical Markdown image syntax must remain standard Markdown-compatible syntax:

```markdown
![Alt text](qp://asset/550e8400-e29b-41d4-a716-446655440000)
```

The image reference is the `qp://asset/<UUID>` URI.

The alt text is ordinary Markdown text.

Do not store Cloudinary URLs in Markdown.

Do not store local filesystem paths.

Do not add unnecessary proprietary Markdown syntax for images.

The parser must recognize the internal URI as a valid image source and create an appropriate image token/presentation representation while preserving the original source characters and offsets.

The existing Markdown parser is deterministic and presentation-oriented; extend it rather than replacing it.

---

# 7. Future Note-to-Note Linking

Do not implement the full feature now, but the architecture MUST explicitly support:

```markdown
[Encryption Architecture](qp://note/<UUID>)
```

This is the future canonical representation for an internal note link.

The target note's current title must NOT be embedded as its identity.

For example:

```markdown
[Project Ideas](qp://note/3f4a...)
```

may display the current target title:

```text
2027 Product Ideas
```

without modifying the source Markdown merely because the referenced note's title changed.

This means:

```text
URI = stable identity
display text = presentation
```

Do not couple the note link's identity to note title text.

The same `QuietPaperUri` and resource resolver architecture must eventually service both asset links and note links.

Do not create a separate URI implementation later for notes.

---

# 8. Attachment Domain Model

Introduce a first-class attachment/asset model.

The exact Dart class/table names should conform to repository conventions, but the conceptual model must contain at least:

```text
id
noteId
createdAt
updatedAt

mimeType
byteSize

width
height

sha256

encryptionKeyVersion

isDirty
isDeleted
serverRevision
syncedAt

uploadState
cloudObject identifiers/metadata
```

Do not blindly copy this list if the existing schema represents equivalent state differently; instead preserve the semantic requirements.

Prefer an immutable stable UUID as attachment identity.

Keep identity separate from content hash:

```text
attachmentId = "what object is this?"
sha256        = "are these bytes identical?"
```

Do not use content hash as the attachment's primary identity unless the existing architecture makes that unavoidable.

---

# 9. Attachment Variants

The architecture should support multiple encrypted representations of an image:

```text
original
preview
thumbnail
```

Use a separate attachment-variant concept/table if that is the cleanest fit for the current schema.

The initial implementation should support:

* Original image.
* Preview image for normal editor rendering.
* Thumbnail for list/small-display contexts.

These are not user-facing image editing features.

They are implementation-level presentation assets.

The original image must remain untouched.

There must be no crop, rotate, annotate, filter, markup, drawing, or editing UI in this phase.

If local image resizing is required to generate preview/thumbnail variants, that is an internal performance operation only and must not be exposed as an editing workflow.

---

# 10. Encryption Requirements

All image bytes MUST be encrypted client-side before network transfer.

Cloudinary must receive encrypted bytes only.

Conceptually:

```text
plaintext image
      ↓
Flutter device
      ↓
encryption
      ↓
ciphertext
      ↓
Cloudinary
```

Never:

```text
plaintext image
      ↓
Cloudinary
```

and never:

```text
plaintext image
      ↓
Vercel
      ↓
Cloudinary
```

The existing Quiet Paper master key architecture uses a random 256-bit master key and XChaCha20-Poly1305 for content encryption. Preserve that cryptographic architecture and key-management model.

Use a distinct attachment encryption envelope/version from note content, rather than pretending an image is just another note JSON payload.

The attachment encryption design must provide:

* unique nonce per encrypted object/variant
* authenticated encryption
* attachment-bound associated data
* encryption key version information
* integrity verification
* explicit envelope versioning for future migration

The exact serialization must be documented.

Do not invent a second password or second master key for attachments.

The existing Quiet Paper master key is the appropriate root encryption key unless the repository's actual cryptographic implementation provides a concrete reason for a derived attachment-specific subkey.

If deriving subkeys, do so through an explicit documented key-derivation scheme rather than ad hoc concatenation.

---

# 11. Encryption Boundary

The security boundary is:

```text
Flutter plaintext
        ↓
local processing
        ↓
local encryption
        ↓
network
```

The backend MUST NOT implement decryption.

The backend MUST NOT receive plaintext image data.

Cloudinary MUST NOT receive plaintext image data.

Cloudinary MUST NOT become a source of cryptographic keys.

The backend remains crypto-blind consistent with the existing security model. The existing handoff explicitly verifies that backend source code contains no decryption methods or global decryption keys. Preserve this invariant.

---

# 12. Direct Cloudinary Upload — Critical Requirement

This is non-negotiable:

**Image bytes MUST be uploaded directly from Flutter to Cloudinary.**

Do NOT upload image bytes through Vercel serverless functions.

Do NOT stream image contents through the TypeScript backend.

Do NOT make the Vercel API receive the encrypted image body.

Reason:

The backend runs in Vercel serverless infrastructure, where execution duration and request/response constraints make it unsuitable as a large-image data proxy.

The backend is therefore the **control plane**, not the **data plane**.

Architecture:

```text
                    CONTROL PLANE

Flutter ───────────────→ Vercel
   │                        │
   │                        ├── authentication
   │                        ├── authorization
   │                        ├── attachment metadata
   │                        ├── upload authorization
   │                        └── sync coordination
   │
   │
   │ DATA PLANE
   └──────────────────────→ Cloudinary
              encrypted bytes
```

---

# 13. Cloudinary Credentials and Security

Never embed a Cloudinary API secret or unrestricted signing credential in the Flutter application.

The backend should authorize direct upload operations.

The intended flow is:

```text
1. Flutter creates local attachment.
2. Flutter encrypts the image/variant locally.
3. Flutter requests an upload authorization from Vercel.
4. Vercel authenticates the Firebase user.
5. Vercel verifies the attachment/note ownership and authorization.
6. Vercel generates the required limited Cloudinary upload authorization/signature/parameters.
7. Flutter uploads encrypted bytes directly to Cloudinary.
8. Cloudinary returns the upload result.
9. Flutter reports successful upload/metadata completion to Vercel.
10. Vercel records/validates the server-side metadata and synchronization state.
```

Do not send the encrypted image bytes to step 3.

Do not use Vercel as the upload proxy.

Use short-lived/appropriately scoped authorization where the Cloudinary integration permits it.

Do not expose unnecessary backend secrets to the client.

Cloudinary object identifiers must be treated as implementation/storage metadata, not canonical note identity.

---

# 14. Cloudinary Is an Encrypted Blob Store

Because the payload is ciphertext, Cloudinary cannot understand the image.

Therefore do NOT rely on Cloudinary's normal semantic image-processing pipeline for encrypted assets.

Do not depend on server-side transformations such as:

* resize
* crop
* quality optimization
* format conversion
* face detection
* smart cropping
* content analysis

for the encrypted payload.

All required presentation variants must be generated locally before encryption.

Treat Cloudinary primarily as durable object storage/delivery infrastructure for ciphertext.

The client downloads ciphertext, decrypts locally, and decodes the resulting plaintext image using Flutter's normal image facilities.

---

# 15. Local Image Processing

When an image is inserted:

```text
source image
    ↓
validate
    ↓
retain original bytes
    ↓
optionally generate preview
    ↓
optionally generate thumbnail
    ↓
encrypt each required representation
    ↓
persist locally
```

No user-facing image editing is permitted.

The original must remain available for restoration/export/backup.

Any generated variants must be deterministic enough for testing and should be generated only when useful.

Do not accidentally overwrite or destructively modify the original.

---

# 16. Image Sources

V1 should support practical image insertion routes appropriate to the existing Flutter platform support, including:

* Gallery/photo picker.
* Camera capture.
* Image clipboard paste where supported.
* File/image selection where supported by the existing app architecture.

Follow the repository's existing platform abstractions and dependencies.

Do not create platform-specific code unnecessarily if an existing package/service can be extended.

The UI should provide an understated, Quiet Paper/Bear-like insertion mechanism.

Do not introduce a visually noisy image-management interface.

---

# 17. Immediate Local Persistence

Image insertion must be immediately local.

When an image is inserted:

```text
image selected
    ↓
local attachment persisted
    ↓
Markdown updated immediately
    ↓
note autosaved
```

The note must not wait for network activity.

The user must be able to continue editing immediately.

The user must be able to close the application while the upload is pending.

The attachment must survive process termination.

This is essential to the existing offline-first philosophy.

---

# 18. Attachment Lifecycle

Use explicit attachment upload/sync state.

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

Failure path:

```text
UPLOADING
    ↓
UPLOAD_FAILED
    ↓
RETRY_PENDING
    ↓
UPLOAD_AUTH_PENDING
```

Do not require exact state names if existing conventions dictate otherwise, but the semantics must exist.

The attachment's upload state must be independent from the note's sync state.

Example:

```text
Note:
    synced

Attachment:
    upload pending
```

is valid.

A note being saved/synced must not imply that all attachment byte uploads are complete.

---

# 19. Sync Engine Integration

Integrate attachments into the existing sync architecture rather than creating an unrelated synchronization system.

The handoff identifies the current sync system as a debounced offline queue coordinator with models, API client, engine, and provider.

The conceptual model should become:

```text
Sync change
 ├── Note change
 └── Attachment change
```

or an equivalent discriminated change model.

Attachment metadata synchronization may include:

```text
attachment id
note id
created/updated timestamps
variant metadata
hash
size
encryption version
deletion state
cloud identifiers
server revision
```

Do not send plaintext image bytes through the sync protocol.

The sync protocol transports attachment metadata and state, not the binary payload.

---

# 20. Suggested Attachment Sync Flow

When a new image is inserted:

```text
1. Create attachment UUID locally.
2. Persist original/variants locally.
3. Compute SHA-256 locally.
4. Encrypt locally.
5. Insert qp://asset/<id> into Markdown.
6. Mark note dirty.
7. Mark attachment pending.
8. Autosave note.
9. Existing note sync handles the Markdown.
10. Attachment synchronization obtains upload authorization.
11. Flutter uploads ciphertext directly to Cloudinary.
12. Flutter records successful Cloudinary object metadata.
13. Attachment metadata is pushed/confirmed through Vercel.
14. Attachment becomes clean/synced.
```

Do not make the attachment upload a prerequisite for note synchronization.

---

# 21. Hashing and Integrity

Calculate a SHA-256 digest for the original image bytes locally.

Use it for:

1. Integrity verification.
2. Upload verification.
3. Retry/deduplication assistance.
4. Detecting accidental corruption.

Do not use SHA-256 as the primary attachment identity.

On download:

```text
Cloudinary ciphertext
    ↓
decrypt
    ↓
verify expected integrity
    ↓
decode/display
```

Failure must be explicit and recoverable.

Do not silently display corrupted or unauthenticated image data.

The AEAD authentication tag must already provide cryptographic integrity for ciphertext; SHA-256 serves as an additional content identity/integrity mechanism and must not be presented as a replacement for authenticated encryption.

---

# 22. Deduplication

The architecture should permit future content deduplication.

If identical image bytes are inserted multiple times:

```text
attachment A
attachment B
```

their UUIDs may remain distinct, while their hashes are equal.

Do not automatically change user-visible semantics merely because hashes match.

Do not share/delete physical storage in a way that can accidentally invalidate one attachment while another still references it.

Deduplication may be optimized later.

---

# 23. Attachment Deletion

Deleting an image from Markdown does NOT immediately mean physically deleting its cloud object.

Preferred lifecycle:

```text
Markdown reference removed
        ↓
attachment marked deleted
        ↓
local tombstone
        ↓
sync tombstone to server
        ↓
server confirms deletion
        ↓
cloud object becomes eligible for physical deletion
```

Use delayed physical deletion/garbage collection rather than immediate destructive deletion.

This protects against:

* offline devices
* delayed synchronization
* interrupted uploads
* race conditions
* restore workflows
* multiple devices observing different states

The existing project already had to address deletion tombstone loops and queue re-enqueue behavior. Follow that discipline for attachments.

Incoming remote deletions must NEVER accidentally create a new local deletion mutation that is then pushed back to the server.

Reuse or extend the existing `enqueueSync: false`-style safeguards where appropriate.

---

# 24. Cloud Deletion Must Be Authorized

The client must not directly perform arbitrary destructive Cloudinary deletion using permanent credentials.

Cloud deletion should be controlled by the backend or another secure server-authorized mechanism.

The backend must confirm ownership and authorization before permitting physical deletion.

Do not allow a malicious client to delete another user's object merely by knowing an object identifier.

---

# 25. Local Attachment Storage

Store encrypted attachment bytes locally in an appropriate app-private directory or repository-approved encrypted storage location.

Do not keep large plaintext image files in persistent storage unnecessarily.

Plaintext may exist temporarily in memory while rendering or during local processing, but do not retain plaintext copies longer than necessary.

Ensure attachment cleanup occurs when appropriate.

Use stable local paths unrelated to Cloudinary URLs.

The logical attachment UUID remains the canonical identifier.

---

# 26. Rendering in the Markdown Editor

Extend the existing Markdown tokenizer/parser/editor to recognize image syntax containing a `qp://asset/<UUID>` URI.

The editor must continue to preserve source text and character offsets.

Rendering must be presentation-only.

The stored source:

```markdown
![Sunset](qp://asset/abc123)
```

must remain exactly that source.

Do not replace it in the controller with generated widget placeholders.

Do not alter Markdown source merely to display an image.

The parser should create semantic information sufficient for the presentation layer to render the image.

The existing parser's deterministic source-slice philosophy and character-offset preservation must remain intact.

---

# 27. Image Rendering States

The editor should safely handle these states:

```text
Loading local image
Image available locally
Image unavailable locally but downloadable
Image download pending
Image upload pending
Image upload failed
Image missing/deleted
Image corrupted/decryption failed
Malformed resource URI
```

The visual treatment should remain quiet and editorial.

Do not create noisy progress UI around every image.

For ordinary upload-in-progress state, a subtle placeholder is sufficient.

A failed upload should allow retry without damaging the note's Markdown.

---

# 28. Image Interaction

V1 interaction should be limited to useful viewing/reference operations.

At minimum, support:

* Tap/open image appropriately.
* Delete attachment/reference.
* Replace attachment if the architecture supports it safely.
* Preserve/edit alt text through existing Markdown mechanisms where practical.

Do NOT implement:

* crop
* rotate
* filters
* drawing
* annotation
* markup
* image editor
* AI image description
* OCR
* server-side transformation controls

Those are explicitly out of scope.

---

# 29. Note Link Architecture — Future Only

Build the resource URI abstraction so that this future feature is natural:

```markdown
[Encryption Architecture](qp://note/7d92...)
```

The future renderer will resolve it to a note.

The target note title can change independently.

The source URI remains stable.

If the target note is deleted, do not automatically rewrite the referring Markdown.

Instead resolve the URI to a missing/deleted target and provide a quiet broken-link state.

If the note is later restored, the link can work again automatically.

This behavior must influence today's architecture even though the note-link UI itself is not implemented.

---

# 30. URI Resolver Must Be Extensible

Do not hardcode:

```text
if asset ...
else if note ...
```

in ten separate places.

Centralize resource parsing and type dispatch.

The architecture should allow future resource types such as:

```text
note
asset
```

and later additional internal resources without rewriting the entire Markdown layer.

Do not implement speculative resource types merely for abstraction purity.

---

# 31. Cloudinary Object Naming

Use server-authorized, stable object identifiers derived from the attachment UUID or another collision-safe backend-generated identifier.

Do not put sensitive plaintext information in Cloudinary object paths.

Do not use:

```text
/photos/<user-email>/<note-title>/sunset.jpg
```

Do not expose note titles, email addresses, or plaintext metadata in storage object names.

Prefer opaque IDs.

---

# 32. Metadata Privacy

Treat Cloudinary as potentially capable of observing operational metadata such as:

* object size
* upload timing
* object count
* storage identifiers
* delivery/access behavior

Do not claim that Cloudinary sees absolutely nothing.

The privacy claim should be:

> Cloudinary cannot read the plaintext image contents because image bytes are encrypted before upload.

Document this accurately.

---

# 33. Backend Responsibilities

The TypeScript/Vercel backend should handle:

```text
Authentication
Authorization
Attachment ownership
Upload authorization/signing
Attachment metadata
Sync metadata
Revision handling
Idempotency
Deletion authorization
Cloud-object lifecycle coordination
```

It MUST NOT handle:

```text
Plaintext image bytes
Image decryption
Master encryption keys
Image editing
Image rendering
```

The existing backend architecture includes Firebase auth middleware, Turso/libSQL, key service, sync service, validation, and structured errors. Extend those patterns rather than bypassing them.

---

# 34. Backend Validation

Add strict schemas for attachment operations.

Validate:

* attachment UUID format
* note ownership
* mime type
* byte-size limits
* image dimensions where applicable
* hash format
* encryption version
* variant type
* deletion state
* Cloudinary object identifiers
* revision/base-revision data
* idempotency keys

Reject impossible state combinations.

Examples:

```text
deleted attachment
+ active upload authorization
```

must not be accepted.

```text
foreign note ID
+ current Firebase user
```

must be rejected.

Do not trust the client merely because it is authenticated.

---

# 35. Idempotency

The existing system already uses idempotency keys to avoid duplicate note creation on network retries.

Apply the same principle to attachment metadata operations.

Retries must not create:

* duplicate attachment records
* duplicate cloud-registration records
* duplicate tombstones
* conflicting revisions

Direct Cloudinary upload retries and backend metadata retries should be safe to repeat according to the chosen upload protocol.

---

# 36. Sync Conflict Semantics

Do not attempt to merge image binaries.

Attachments should be immutable content objects for synchronization purposes.

Conflicts should occur around metadata/reference state, not image-byte editing.

Example:

```text
Device A:
note contains qp://asset/A

Device B:
note contains qp://asset/B
```

The existing note conflict mechanism resolves the Markdown conflict.

The attachment objects A and B can both safely exist.

Do not mutate image content in place.

---

# 37. Backup and Restore

This is important.

The existing project has a `.qpbackup` backup/restore system that stores a complete notebook snapshot and explicitly supports restored notes being re-queued for cloud sync.

Extend backup semantics so attachments are handled safely.

A backup must NOT silently lose image references.

At minimum, determine and implement a coherent format containing:

```text
attachment metadata
attachment identity
note association
variant metadata
hash
encryption metadata
image bytes or an explicit recoverable attachment representation
```

Do not store plaintext image bytes in an "encrypted backup" merely because the backup itself is later encrypted if doing so conflicts with the project's intended zero-knowledge architecture.

Prefer a backup representation that preserves the already-encrypted attachment payload or otherwise preserves attachment confidentiality consistently.

Restore must preserve attachment UUIDs where possible.

Restored attachments must participate in the existing dirty/serverRevision reset behavior so they can be synchronized to the cloud after restore.

The restore path must not accidentally delete remote attachments.

Document exact behavior.

---

# 38. Search

Existing search is 100% local.

Do not attempt OCR or image-content search in this phase.

Search should continue to operate on textual note content and metadata.

Image alt text may participate in search if that naturally fits the current Markdown/search model.

Do not introduce AI-based visual search.

---

# 39. Export/Import

Existing Markdown import/export behavior must not be silently broken.

For imported Markdown containing ordinary external image URLs:

```markdown
![image](https://example.com/image.jpg)
```

do not automatically redefine those as Quiet Paper assets unless the import design explicitly supports that.

For local files referenced during import, consider asset import only if it naturally fits the existing importer and can be implemented without breaking current behavior.

Do not change current import semantics merely to force attachments into the pipeline.

Any new import behavior must be explicitly documented and tested.

---

# 40. External URLs vs Internal `qp://` URLs

There are now two categories:

```text
External:
https://example.com/image.jpg

Internal:
qp://asset/abc
qp://note/def
```

Do not send `qp://` links through the existing external-link trust confirmation flow.

The existing app has a domain-based confirmation mechanism for external hyperlinks. Internal Quiet Paper URIs are application resources and must be handled separately.

Do not attempt to open:

```text
qp://asset/...
```

in the external browser.

Do not treat them as untrusted external URLs.

---

# 41. Security Model

Update the security documentation to explicitly state:

```text
Note plaintext:
    encrypted client-side

Attachment plaintext:
    encrypted client-side

Cloudinary:
    ciphertext only

Vercel:
    metadata/control plane only
    no plaintext images

Turso:
    metadata + encrypted note content
    no plaintext images
```

Document what metadata remains observable.

Preserve the existing guarantee that backend code has no decryption capability.

---

# 42. Performance Requirements

Images are potentially large.

Do not:

* load full-resolution images unnecessarily in list views
* base64 encode large images in memory for ordinary state management
* keep multiple full plaintext copies in RAM
* route image bytes through Vercel
* block note editing while waiting for upload
* download original resolution when preview/thumbnail is sufficient

Use streaming/file-based operations where appropriate.

The exact implementation should respect Flutter platform constraints.

---

# 43. Failure Recovery

The system must recover from:

* no network
* Cloudinary timeout
* Cloudinary rejection
* Vercel authorization failure
* expired upload authorization
* process termination during upload
* app update during upload
* device restart
* server retry
* duplicate upload completion
* attachment deletion during pending upload
* note deletion while attachment upload is pending

No failure may corrupt Markdown.

No failure may leave a permanently referenced attachment with no way to retry or recover.

No retry loop should cause uncontrolled duplicate cloud objects.

---

# 44. Upload Cancellation / App Termination

If the app closes while an upload is in progress:

* local encrypted attachment state must remain intact
* the attachment must remain retryable
* the note must remain readable offline
* the application must resume upload later

Do not require users to manually reinsert the image.

---

# 45. Attachment Replacement

If "replace image" is implemented in V1, prefer creating a new attachment identity rather than mutating an existing encrypted binary in place.

Example:

```text
old:
qp://asset/A

new:
qp://asset/B
```

Update the Markdown reference atomically.

Mark A as deleted/unused according to the normal lifecycle.

Do not rewrite attachment identity to point at different bytes.

This preserves the principle that an attachment ID identifies a particular immutable content object.

---

# 46. UI Design

All image UI must follow the existing Quiet Paper aesthetic:

* warm editorial surface
* restrained controls
* minimal elevation
* no noisy cards
* no excessive progress UI
* accessible hit targets
* consistent typography
* tablet-aware layouts
* dark/light theme compatibility

The handoff specifically emphasizes a calm Bear-like design and restrained interface.

Do not turn the editor into a media-management dashboard.

---

# 47. Editor Insertion UX

Design a minimal image insertion path around the existing editor toolbar/menu.

Potential actions:

```text
Photo
Camera
File
Paste
```

Use existing app conventions.

The actual UI labels may differ if the repository already has established terminology.

Do not create a large floating media toolbar.

---

# 48. Image Placeholder

When an attachment isn't immediately available, render a subtle placeholder.

Possible states:

```text
local image
uploading
download required
failed
missing
```

Avoid putting verbose technical errors inside the note.

Use appropriate retry affordances outside the core Markdown text.

---

# 49. Accessibility

Ensure image presentation has useful semantic descriptions from alt text where applicable.

Do not rely exclusively on visual appearance.

The raw Markdown alt text remains canonical.

Do not require users to enter redundant accessibility metadata unless the existing architecture requires it.

---

# 50. Tests — Required

Add extensive tests.

## URI tests

Test:

```text
qp://asset/<valid UUID>
qp://note/<valid UUID>
```

and reject:

```text
bad URI
unsupported type
missing ID
malformed ID
wrong scheme
unexpected path
```

Test round-trip serialization/parsing.

Test resource type dispatch.

---

## Markdown tests

Test:

```markdown
![Alt](qp://asset/abc)
```

Test:

* source preservation
* exact character offsets
* alt text
* URI extraction
* malformed asset URI
* ordinary external image URL
* note URI future compatibility
* mixed text/images
* multiple images
* nested Markdown contexts where applicable

Do not regress the existing whitespace/caret behavior.

---

## Encryption tests

Test:

* encryption/decryption roundtrip
* unique nonces
* wrong-key failure
* tampering failure
* associated-data mismatch failure
* attachment envelope version validation
* corrupted ciphertext
* corrupted metadata
* large image payloads
* variant encryption

Cloudinary or backend tests must verify that no decryption path exists server-side.

---

## Attachment database tests

Test:

* create
* update
* lookup by ID
* lookup by note
* deletion
* tombstone
* variants
* hash
* dirty state
* upload state
* revision state
* migrations
* restart persistence

---

## Sync tests

Test:

* create attachment offline
* resume upload online
* upload retry
* duplicate retry
* remote attachment metadata pull
* remote deletion
* local deletion
* deletion race
* note deleted while attachment pending
* attachment upload failure
* attachment metadata conflict
* idempotency
* multi-device synchronization

Test specifically that remote deletion does not get re-enqueued as a new local deletion mutation.

---

## Cloudinary integration tests

Where full live integration testing is inappropriate, mock the upload layer.

Test:

```text
Flutter requests upload authorization
Vercel validates ownership
Vercel returns upload authorization
Flutter uploads directly
Cloudinary response is accepted
metadata confirmation occurs
```

Test that the image byte payload is never sent to the Vercel attachment-control endpoint.

---

## Backup tests

Test:

* backup with images
* encrypted backup with images
* restore with images
* missing cloud asset
* restored attachment dirty state
* restored asset re-sync
* duplicate restoration
* attachment tombstone interaction

---

# 51. Static Analysis and Regression

Before finishing:

```bash
flutter analyze
flutter test
```

Run backend tests.

Run backend build/typecheck.

Run Drift code generation where required.

Do not leave generated files inconsistent with source changes.

Do not leave warnings.

Do not weaken analysis rules just to make the implementation pass.

---

# 52. Database Migration

Add the minimum necessary Drift migration.

Increment schema version only as appropriate.

Migration must preserve all existing notes/tags/sync metadata.

Existing installations upgrading to the new version must retain all existing data.

No migration may delete existing Markdown contents.

No migration may rewrite existing note content merely because the new URI system exists.

---

# 53. Backend Migration

Add backend schema migrations using the repository's existing migration conventions.

Do not mutate historical encrypted note data.

Attachment metadata should be additive.

Existing clients without image support should not be able to corrupt attachment state.

Where practical, maintain backward compatibility with current sync clients.

Document compatibility assumptions.

---

# 54. Existing Sync Revision Model

Use the existing revision/cursor/idempotency approach rather than inventing a second synchronization protocol.

The handoff explicitly describes:

* revision tracking
* cursor-based pull
* push/pull
* idempotency
* conflict handling
* append-only sync changes

Preserve these semantics.

Attachment changes should fit into this model.

---

# 55. Do Not Conflate Note and Attachment Revisions

A note revision tracks Markdown/note metadata state.

An attachment revision tracks attachment metadata/state.

Do not increment a note revision merely because a cloud upload progresses.

However, insertion/removal of the `qp://asset/...` reference DOES change the note's Markdown and therefore the note revision.

This distinction is important:

```text
image upload progress
    ≠
note content change
```

but:

```text
insert/remove image reference
    =
note content change
```

---

# 56. Local Reference Integrity

The system should be able to detect:

```text
Markdown references qp://asset/A
```

when attachment A is missing locally.

This must not crash rendering.

Prefer a controlled unresolved-resource state.

Similarly, an attachment record with no corresponding Markdown reference may be considered orphaned and eligible for cleanup after appropriate synchronization/retention rules.

Do not immediately delete orphaned attachments merely because a transient edit temporarily removes/reinserts a reference.

---

# 57. Orphan Collection

Design for orphan detection.

Possible state:

```text
attachment exists
but no note Markdown references it
```

Do not immediately destroy it.

Track enough metadata to allow safe delayed cleanup.

This is particularly important for:

* interrupted note edits
* undo/redo
* restore
* sync races
* failed replacements
* multi-device operations

---

# 58. Undo/Redo

Image insertion should interact correctly with the existing editor's undo/redo semantics.

At the Markdown level:

```text
before:
paragraph

after:
paragraph
![Image](qp://asset/A)
```

Undo must restore the previous Markdown source.

However, undoing the Markdown reference must NOT necessarily immediately physically delete the attachment object.

Let attachment garbage collection handle unused attachments safely.

This avoids destructive behavior coupled directly to text editing.

---

# 59. Autosave

The existing editor autosaves with debounce/focus/lifecycle/exit behavior. Preserve that behavior.

When an image is inserted:

* update Markdown
* trigger normal note autosave
* persist attachment locally
* do not wait for cloud upload

The note must remain fully functional offline.

---

# 60. Read-Only Notes

The existing project supports note-level read-only mode.

Read-only mode must prevent:

* image insertion
* image deletion
* attachment replacement
* Markdown image-reference editing

but still allow viewing/downloading/rendering according to existing read-only behavior.

Do not bypass read-only mode through image-specific controls.

---

# 61. Password-Protected Notes

The existing project supports note-level password protection where the title/content/tags are encrypted in the note itself.

Attachment handling must respect note security.

An attachment associated with a password-protected note must not become an accidental plaintext metadata leak.

Do not show attachment previews for a locked note without unlocking the note, unless the existing security model explicitly permits that.

The attachment itself remains encrypted independently.

---

# 62. Logout and Key Lifecycle

The existing app securely persists and clears authentication/session/master-key state.

Attachment encryption/decryption MUST use the same lifecycle rules.

When encryption keys are unavailable:

* do not decrypt attachments
* do not expose plaintext attachment data
* show the appropriate locked/unavailable state

On logout/clear-local-keys:

* attachment plaintext caches must be removed according to the same security model
* encrypted cloud/local attachment data may remain as appropriate for the existing logout architecture
* no cryptographic secret should be left in ordinary persistent storage

---

# 63. Local Cache Strategy

Distinguish:

```text
Encrypted durable attachment storage
```

from:

```text
Temporary decrypted presentation cache
```

The decrypted cache must be treated as sensitive temporary data.

Avoid unnecessary permanent plaintext copies.

Where practical:

```text
encrypted bytes → temporary decrypted representation → render → cleanup
```

Follow platform-safe file handling.

---

# 64. Image Size Limits

Introduce explicit configurable limits for:

* original image size
* dimensions
* number of variants
* attachment count where appropriate

Do not silently create enormous memory allocations.

Use backend validation limits as a second line of defense.

Client-side validation is for UX; backend validation is authoritative for metadata/authorization.

---

# 65. MIME Type Handling

Validate MIME types conservatively.

Do not trust a client-provided extension alone.

Where practical, infer/verify type from actual file contents.

Avoid allowing arbitrary executable content to be masqueraded as an image.

The object should be treated as untrusted ciphertext until decrypted and verified locally.

---

# 66. Cloudinary Retrieval

When retrieving an attachment:

```text
1. Resolve attachment ID locally.
2. Determine required variant.
3. Obtain authorized Cloudinary delivery/reference information if needed.
4. Download encrypted bytes directly from the appropriate cloud endpoint.
5. Decrypt locally.
6. Verify integrity.
7. Decode/render.
```

Do not route image downloads through Vercel.

The backend should not become a binary download proxy either.

---

# 67. Network Architecture Summary

The final architecture must look approximately like:

```text
                    ┌───────────────────────┐
                    │      Flutter App      │
                    │                       │
                    │ Markdown              │
                    │ Attachments            │
                    │ Encryption             │
                    │ Sync engine            │
                    │ URI resolver            │
                    └───────────┬───────────┘
                                │
               ┌────────────────┴────────────────┐
               │                                 │
               │ CONTROL                         │ DATA
               ▼                                 ▼
        ┌──────────────┐                  ┌──────────────┐
        │    Vercel    │                  │  Cloudinary  │
        │              │                  │              │
        │ Auth         │                  │ Encrypted    │
        │ Authorization│                  │ blobs        │
        │ Metadata     │                  │              │
        │ Sync         │                  │              │
        │ Revisions    │                  │              │
        └──────┬───────┘                  └──────────────┘
               │
               ▼
        ┌──────────────┐
        │    Turso     │
        │              │
        │ Notes        │
        │ Attachments  │
        │ Sync changes │
        └──────────────┘
```

**No image bytes through Vercel.**

**No plaintext image bytes to Cloudinary.**

**No plaintext image bytes to Turso.**

---

# 68. What Is Explicitly Out of Scope

Do NOT implement:

* image editing
* crop
* rotate
* filters
* drawing
* annotation
* markup
* OCR
* AI image descriptions
* visual similarity search
* AI image search
* public image sharing
* public image URLs
* collaborative real-time image editing
* note-linking UI
* `[[wikilink]]` syntax unless specifically required by the current codebase
* server-side image transformations
* Cloudinary semantic image processing
* image proxying through Vercel
* plaintext image storage in cloud services
* rich-text document-model replacement

Do not "improve" scope beyond this specification.

---

# 69. Recommended Initial File/Module Organization

Follow existing project structure rather than blindly copying this layout, but conceptually separate responsibilities into:

```text
lib/core/attachments/
    attachment_models
    attachment_repository
    attachment_crypto
    attachment_storage
    attachment_service
    attachment_sync
    attachment_provider

lib/core/uri/
    quiet_paper_uri
    resource_resolver

lib/features/editor/
    image parsing/tokenization
    image presentation
    insertion actions
```

Backend:

```text
backend/src/attachments/
    attachment service
    attachment authorization
    attachment validation
    cloudinary integration/control-plane logic
```

The actual locations must follow current repository organization.

Do not introduce unnecessary abstractions solely for abstraction's sake.

---

# 70. Documentation Requirements

Update the engineering handoff and relevant architecture docs to describe:

## Attachment architecture

```text
Note → Markdown → qp://asset/<id>

Attachment metadata → Turso

Encrypted attachment bytes → Cloudinary

Encryption → Flutter client

Authorization → Vercel
```

## URI system

```text
qp://asset/<id>
qp://note/<id>
```

## Sync lifecycle

Document the attachment state machine.

## Security

Document:

* encryption boundary
* Cloudinary observability
* backend limitations
* key handling
* metadata exposure

## Backup

Document how attachments are represented in backups.

## Future note linking

Document that `qp://note/<id>` is reserved as the stable internal note identity mechanism.

---

# 71. Acceptance Criteria

The feature is complete only when all of the following are true:

### Local/offline

* A user can insert an image without network connectivity.
* The image appears immediately.
* The note is saved immediately.
* The attachment survives process restart.
* Upload waits until connectivity is available.

### Encryption

* Image bytes are encrypted before network upload.
* Cloudinary receives ciphertext only.
* Vercel never receives image bytes.
* Decryption occurs only on an authorized client.
* Tampering is detected.
* Encryption is versioned and documented.

### Direct upload

* Flutter uploads encrypted bytes directly to Cloudinary.
* Vercel only handles authorization/control/metadata.
* Large images do not traverse Vercel.
* Vercel serverless execution time is not coupled to image transfer time.

### Markdown

* Markdown remains canonical.
* Images use standard Markdown image syntax.
* `qp://asset/<UUID>` is the canonical image reference.
* Existing editor selection/caret behavior is preserved.
* Existing Markdown behavior does not regress.

### URI architecture

* `QuietPaperUri` exists as a reusable abstraction.
* `qp://asset/<UUID>` works.
* `qp://note/<UUID>` is structurally supported/reserved.
* URI parsing is centralized.
* Resource resolution is separated from Markdown parsing.
* Cloudinary URLs never become canonical Markdown identity.

### Sync

* Attachment metadata participates in the existing sync system.
* Upload progress is independent of note sync state.
* Retries are safe.
* Idempotency works.
* Deletions use tombstones.
* Remote deletions do not loop back into local push queues.
* Multi-device scenarios work.

### Backup

* Backups do not silently lose attachments.
* Restore preserves or safely reconstructs attachment state.
* Restored attachments can synchronize correctly.
* Existing backup behavior remains intact.

### Security

* Read-only notes cannot be mutated through image controls.
* Locked/password-protected notes do not leak attachment plaintext.
* Logout/key clearing follows the existing cryptographic lifecycle.
* No backend decryption functionality exists.

### Quality

* Flutter analysis passes.
* Flutter tests pass.
* Backend tests pass.
* Backend build/typecheck passes.
* Database migrations pass.
* New code has focused unit/widget/integration coverage.
* No new warnings are introduced.

---

# 72. Implementation Discipline

While implementing:

1. Inspect first.
2. Make the smallest coherent architectural changes.
3. Reuse existing services and patterns.
4. Avoid duplicate sync engines.
5. Avoid duplicate encryption abstractions.
6. Avoid duplicate URI parsing.
7. Avoid embedding Cloudinary-specific details in Markdown.
8. Avoid making UI responsible for synchronization.
9. Avoid making Vercel responsible for binary transport.
10. Avoid coupling note revisions to upload progress.
11. Avoid destructive cleanup on normal editor undo.
12. Avoid introducing speculative features.

When uncertain, prefer the architecture described in this prompt and the existing Quiet Paper handoff.

---

# 73. Final Architectural Invariants

At the end of the implementation, the following statements MUST be true:

```text
Markdown is still the canonical note source.

qp://asset/<UUID> is the canonical identity of an image attachment.

qp://note/<UUID> is reserved for stable future internal note links.

Cloudinary URLs are never canonical note references.

Attachment UUIDs are logical identities, not storage locations.

Image bytes are encrypted before leaving the device.

Cloudinary receives ciphertext only.

Vercel never proxies image bytes.

Vercel remains the control plane.

Turso stores attachment metadata and encrypted note data.

Flutter owns encryption and decryption.

Attachment upload is asynchronous and independent of note editing.

Offline operation works.

Attachment deletion is tombstone-based and safely garbage-collected.

Remote deletion does not generate a new outgoing deletion loop.

The Markdown editor keeps its existing source/selection invariants.

No rich-text document model is introduced.

No image editing is implemented.

The URI system is reusable for future internal resources.

Future note links can be represented as:

[Note title](qp://note/<UUID>)

without changing the underlying identity when the note title changes.
```

---

# 74. Agent Deliverables

When implementation is complete, provide:

1. A concise architectural summary of what changed.
2. A list of modified/created files.
3. Database migration details.
4. Backend API/control-plane details.
5. Cloudinary direct-upload flow.
6. Encryption/envelope details.
7. Attachment state-machine description.
8. URI architecture description.
9. Backup/restore behavior.
10. Test coverage added.
11. Commands executed and their results.
12. Any assumptions or repository-specific deviations from this specification.

Do not claim a test passed unless it was actually run.

Do not claim direct Cloudinary upload works unless the implementation and tests demonstrate that architecture.

Do not claim zero-knowledge guarantees beyond what the actual implementation establishes.

The implementation should leave Quiet Paper with a coherent, extensible foundation where **images are just the first major consumer of a general internal-resource system**, while keeping Markdown canonical, synchronization offline-first, image data end-to-end encrypted, and Cloudinary completely outside the Vercel binary transport path.
