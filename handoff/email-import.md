# Email import

Email import is implemented on `feat/email-import`. It preserves selected messages
as ordinary editable notes, using existing repositories, encrypted assets, search,
backup and sync. It does not connect to mail accounts or fetch remote email content.

## Entry points

- Drop one or more `.eml` files onto the Linux workspace or editor.
- Settings → Backup & Import → Import Email selects multiple files; the all-files
  action supports generic extensions when content inspection identifies email.
- Ctrl+Shift+I opens the picker; Ctrl/Cmd+Shift+P exposes searchable commands.
- Linux desktop metadata registers email MIME types and initial `.eml` arguments.
- Android SEND, SEND_MULTIPLE and VIEW route supported email files through the same
  preview. Shared text opens Quick Capture with explicit Save as Email. URL-only
  shares retain ordinary capture/web clipping.

The preview offers editable title/tags, metadata, attachments, duplicate review,
new editable note plus original, original-only archive, or explicit append target.
Shared content has no fabricated original and cannot select archive-only mode.
Mixed batches identify rejected filenames and permit valid items to continue.
Cancellation preserves completed imports and rolls back incomplete preparation.

## Implementation boundaries

`lib/features/email_import/application/email_input.dart` normalizes paths/file URIs
and bounded reads. `email_parser.dart` walks MIME ranges in a worker, using
enough_mail 3.0.0 codecs for RFC headers/parameters/charsets. It supports ordinary
mixed/alternative/related/nested messages, encoded headers/filenames, binary parts,
attached emails and CID images. Attached messages remain assets, not extra notes.
`email_html_converter.dart` checks complexity before DOM allocation and converts
safe structure to Markdown without rendering HTML or loading remote resources.

`email_import_gateway.dart` supplies injectable application boundaries.
`email_import_service.dart` handles encrypted preparation, canonical note creation,
source identities, duplicates, append revision checks and rollback.
`email_import_screen.dart` retains one full preview at a time and sequentially
processes batches. Other entries retain summaries and source fingerprints.
`email_import_launcher.dart` connects navigation, active-editor reconciliation,
list refresh and normal encrypted sync after confirmed commits.

`EmailEditorBridge` flushes existing edits before preview and adopts committed
appends, including earlier completed items when a batch is canceled. Rich appends
splice parsed blocks into AST JSON; Super Editor retains original nodes/caret.
Imported notes disable automatic remote-link preview fetching when opened.

## Storage, provenance and synchronization

Drift schema 22 adds `notes.import_sources` with an empty-array default, a derived
`note_import_source_index`, and `email_import_preparations`. `NoteImportSource`
version 1 preserves hashes, canonical fingerprint, identifiers/thread references,
original metadata, UTC import timestamp and asset IDs. The canonical collection
travels inside encrypted NotePlaintext and through backups and QPNote exports.
The v22 migration reconciles either earlier v21 layout (templates or email import),
preserving existing template snapshots, favorites, notes and provenance.

`saveNote` maintains the derived duplicate index transactionally. Source identities
union during save/merge; older client envelopes cannot erase locally retained
sources and schedule an encrypted repair push when necessary. A source-only
backup merge preserves newer note text and timestamps. The index can be rebuilt
from canonical source records. No email import endpoint or plaintext email fields
were added to the backend.

Fresh UUIDs are journaled before encrypted file preparation. Note/asset metadata,
tags, FTS and journal removal commit together. Failures remove newly prepared
ciphertext; unsuccessful deletion retains the journal for later recovery before
the next import preview. Never run recovery concurrently with another import.
Email assets do not preload the plaintext cache or start OCR.

## Offline encryption setup

Email import works without Cloud Sync or an account. Before testing the unlock
state, the gateway awaits key initialization. For a signed-out notebook with no
wrapped key and no existing encrypted attachment/document rows, it calls
`KeyManager.ensureLocalKey()`. This creates one random 256-bit key and persists it
through the existing platform secure storage before exposing it to encryption.
Concurrent requests share creation; subsequent previews and restarts reuse the
same key. No cloud request or account setup is required.

Existing wrapped/locked vaults are not replaced or unlocked automatically. Storage
read/write failures fail closed; preparation errors retain the selected source and
offer Retry. A real lock/logout still clears all pending source data. Generation
checks prevent delayed initialization from restoring a cleared preview. Key loading
is idempotent, and locking during startup or key creation prevents a late unlock.
Clearing keys waits for pending local persistence before deleting stored material.

Creating a new cloud vault wraps the same local key. Password/recovery unlock of a
different existing cloud vault is rejected before replacing a device-only key, to
avoid stranding encrypted local assets. Combining differently keyed vaults requires
an explicit migration and is not implemented. Existing auth error handling locks
the local session on unsuccessful sign-in; restarting restores its device key.

Device-only keys remain in this installation's secure storage. Existing backups
preserve encrypted asset bytes, but do not export the vault master key; moving
those assets to another installation requires the same key. A backup password
protects the backup envelope and does not replace the asset key. Cross-device
recovery of a device-only key is not supplied by this fix. Do not clear app storage
or uninstall as a workaround for an import failure.

## Android lifecycle and temporary files

`IncomingShareReceiver.kt` streams ContentResolver data on a serial worker while
URI grants are valid. Provider names never control staging paths. Copies use
private UUID directories and owner-only access; acknowledgment removes them after
completion/cancellation, and the next activity initialization removes interrupted
copies. URI permissions are not persisted. Filesystem deletion is not a guarantee
of secure erasure on SSDs or journaled filesystems.

The installed sharing plugin otherwise makes an extra unbounded copy. MainActivity
passes it sanitized Android intents while the existing Dart ShareIntentHandler
consumes the bounded native request. Request IDs deduplicate initial/event delivery;
serial routing waits for active drafts/previews. Secure cache clearing invalidates
pending requests and clears preview bodies, source paths and filename errors.
No new storage permissions or broad binary Open With filter were added.

## Limits and verification boundaries

- Raw message: 50 MiB; decoded attachment: 25 MiB; combined decoded attachments:
  50 MiB; decoded UTF-8 body: 10 MiB.
- At most 200 MIME parts, 20 MIME nesting levels and 100 emails per batch.
- Headers are bounded to 64 KiB. HTML has token, nesting and element-size budgets.
- Existing cloud policies remain independent of local import limits. Assets over
  the current 10 MB cloud limit remain local/pending; the preview explains this.
- Outlook MSG, MBOX, PST/OST and mailbox/account access are unsupported.
- desktop_drop provides coordinates but no hover filenames, so email recognition
  happens on drop. Existing generic editor drop feedback remains.
- Physical Android chooser/provider/lifecycle and Linux file-manager/Flatpak replay
  remain unverified. Packaging builders were unavailable; no sandbox grants changed.

See [the engineering report](../docs/email-import/engineering-report.md),
[implementation record](../docs/email-import/implementation.md), engineering logs
334–342 and [focused validation script](../tool/verify_email_import.sh).
