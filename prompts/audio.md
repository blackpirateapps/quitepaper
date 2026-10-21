# Engineering Implementation Brief: Quiet Paper Super Editor — Audio Journaling

## 1. Mission

Implement a production-quality **Audio Journaling feature inside Quiet Paper's Super Editor**.

Audio journaling must allow users to record voice memos, pause and resume recordings, give each recording a name, preserve its recording timestamp, insert multiple recordings into a single note, play recordings inline, seek through playback, and manage recordings as ordinary encrypted attachments.

The finished feature must feel like a native part of Quiet Paper rather than a separate recorder application.

The experience should be calm, minimal, responsive, offline-first, and privacy-focused. The implementation must reuse existing infrastructure wherever practical, preserve backward compatibility, and work across the application's supported platforms.

**This is an implementation task. Inspect the existing code, make the necessary changes, run the relevant tests, fix regressions, and provide a completion report. Do not stop after repository analysis or return only an implementation plan.**

---

## 2. Start by understanding the existing repository

Before writing code, inspect the current implementation and establish the actual repository state. The engineering handoff document describes the architecture, but the code currently present in the repository is authoritative.

Do not assume that any class, method, dependency, schema version, or behavior described below exists unchanged. Locate and verify each relevant component before deciding how to integrate the feature.

### A. Super Editor

Inspect these files and their dependencies:

- `lib/features/editor/presentation/widgets/quiet_super_editor.dart`
- `lib/features/editor/application/quiet_super_editor_controller.dart`
- `lib/features/editor/presentation/widgets/markdown_editor.dart`
- `lib/features/editor/presentation/editor_screen.dart`
- `lib/features/editor/presentation/widgets/rich_attachment_block.dart`
- `lib/features/editor/presentation/widgets/rich_editor_surface.dart`
- The current document-to-Markdown deserializer and serializer.
- The existing custom node/component builders and attachment block renderers.
- The existing editor toolbar, selection management, focus handling, document mutation requests, and undo/redo integration.

The current Super Editor implementation uses a block-based document model while retaining Markdown as the canonical persisted representation. It already supports custom rendering of attachment-related blocks.

The audio implementation must preserve this architecture.

### B. Generic encrypted attachments

Inspect the current attachment architecture, including:

- `lib/core/attachments/attachment_service.dart`
- `lib/core/attachments/attachment_crypto.dart`
- `lib/core/attachments/attachment_sync_service.dart`
- `lib/core/attachments/attachment_temp_storage.dart`
- `lib/core/attachments/presentation/quiet_attachment_card.dart`
- Attachment domain models and repository/provider files.
- Drift attachment table definitions and migrations in `lib/core/database/`.
- Backup models, serialization, restoration, and attachment export resolution.
- Attachment synchronization API clients and backend validation schemas where relevant.

Quiet Paper already has a generic encrypted-file attachment subsystem. The implementation uses client-side encryption, attachment metadata, local encrypted files, cloud uploads, and Markdown references using `qp://asset/<UUID>`.

The generic attachment subsystem is the preferred storage foundation for audio.

### C. Existing recording and speech recognition

Inspect:

- `lib/core/speech/infrastructure/audio_recorder_service.dart`
- `lib/core/speech/application/speech_recognition_service.dart`
- `lib/core/speech/application/speech_provider.dart`
- `lib/core/speech/domain/speech_session_state.dart`
- The existing `SpeechRecordingBar` and dictation integration in `EditorScreen` and `FormattingToolbar`.

The existing dictation system records temporary audio for transcription, with its own maximum-duration handling and temporary-file cleanup. It is not automatically a suitable audio journaling service as currently implemented.

Reuse its lower-level recording capabilities where appropriate, but do not couple the new feature to a lifecycle that deletes audio immediately after transcription.

### D. Platform support and dependencies

Inspect:

- `pubspec.yaml` and `pubspec.lock`.
- Android microphone permissions and application lifecycle integration.
- iOS microphone usage descriptions, if iOS is supported.
- macOS, Linux, Windows, and web platform support as declared by the actual project.
- Existing audio playback, media metadata, recording, temporary-storage, and background-task dependencies.
- Existing test fakes and dependency-injection patterns.

Determine which formats and recording behaviors are supported on the actual target platforms. Do not silently introduce an Android-only feature if the existing application supports multiple platforms.

### E. Existing adjacent functionality

Inspect the current implementations of:

- Image and generic file insertion into notes.
- Attachment cards in Markdown preview and other editor modes.
- `.qpbackup` creation and restoration.
- `.qpnote` or Markdown export.
- Public note sharing and attachment inclusion.
- Note deletion, undo, attachment deletion, and attachment reference resolution.
- Existing database migration and sync metadata conventions.

Do not duplicate functionality that already exists.

After this initial inspection, proceed with implementation. Do not wait for user confirmation.

---

## 3. Product definition and scope

### Primary user story

As a Quiet Paper user, I want to record a thought directly inside a note, name it, and revisit it later without leaving the writing environment.

I should be able to create several recordings within one note, continue using the editor after each recording, and reopen the note on another synchronized device to play the same recordings.

### Required in the first implementation

1. Start a voice recording from Super Editor.
2. Pause and resume recording.
3. Finish or cancel a recording.
4. Show a recording timer and live audio-level feedback.
5. Create and persist the recording as an encrypted attachment.
6. Insert an audio block at the intended position in the note.
7. Assign an editable recording title.
8. Preserve and display the original recording timestamp.
9. Support multiple recordings in one note.
10. Play and pause a saved recording inline.
11. Seek through playback and display elapsed and total duration.
12. Support renaming and safe removal of a recording block.
13. Preserve recordings when switching editor modes.
14. Support offline recording and playback.
15. Integrate with existing backup, export, and encrypted cloud synchronization.
16. Handle microphone permission failures, interruptions, low storage, invalid files, and interrupted application lifecycle events.
17. Maintain the existing note security model.
18. Add regression tests proving that current speech dictation and generic attachment behavior remain intact.

### Explicitly out of scope for the first release

Do not implement the following unless existing architecture requires a minimal change to support the core feature:

- Automatic transcription of journal recordings.
- Live speech-to-text while recording.
- A new transcription model or model download.
- Audio waveform trimming or editing.
- Noise reduction or effects processing.
- Cloud-based speech processing.
- A new journal database or audio library screen.
- A new backend storage provider.
- A mandatory new database table solely for audio.
- A public audio-hosting service independent of existing attachment infrastructure.

Transcription is a potential future enhancement. Keep the design extensible without making it a dependency of recording or playback.

---

## 4. Experience and visual design

Follow Quiet Paper's established warm editorial visual language and semantic theme system.

Use existing theme colors, typography, spacing, radii, buttons, and icon conventions. Support both light and dark themes, including the project's other theme families.

Avoid large Material cards, prominent gradients, noisy animations, excessive outlines, and a separate full-screen dashboard for ordinary recording tasks.

### 4.1 Starting a recording

Add a microphone action to the existing Super Editor attachment/action area. Inspect the current toolbar composition before choosing the exact location.

Use a clearly accessible tooltip and an appropriate existing icon family.

When tapped:

1. Verify that the note is editable and not password-locked or read-only.
2. Verify that no other application-level recording session is already active.
3. Request microphone permission if necessary.
4. Prepare the recorder and a secure app-private temporary output location.
5. Capture the current logical insertion point and document state needed to restore that point safely.
6. Begin recording after successful initialization.

Do not create an audio attachment or mutate persisted Markdown at the start of a recording.

If permission is denied, explain how the user can grant permission. If permission is permanently denied, offer the appropriate platform settings route when supported.

If the note is read-only or locked, disable the recording action consistently with existing editor behavior.

### 4.2 Active recording panel

Present a compact recording panel consistent with the existing editor's controls.

It must contain:

- A distinct recording indicator.
- Elapsed recording time.
- A live waveform or responsive audio-level visualization.
- Pause/resume.
- Finish recording.
- Cancel recording.

The recording timer must represent elapsed captured audio time, excluding periods when the user has paused.

Keep the visual design restrained and make the active recording state unmistakable.

Provide sensible accessibility labels, minimum touch targets, and responsive layouts.

The editor may dismiss its software keyboard while recording. If the user scrolls or views other parts of the same note, the recording state must remain stable.

Do not allow accidental toolbar actions or editor-mode changes to produce duplicate recording sessions or corrupt the recording.

### 4.3 Recording completion and naming

When the user taps Finish:

1. Stop the capture pipeline cleanly.
2. Finalize the audio container and file.
3. Validate the file and duration.
4. Reject an empty or invalid recording with useful feedback.
5. Enforce the existing attachment-size ceiling.
6. Encrypt and persist the completed file.
7. Obtain the persistent attachment identifier.
8. Insert the audio attachment reference into the note at the intended insertion position.
9. Trigger the existing autosave and attachment synchronization flows.
10. Render the finished audio card.

Provide a sensible automatic title, such as `Voice memo · 4:12 PM`, based on the recording's start time.

The title must be editable directly from the audio card, ideally through an inline rename interaction or a small editorial dialog consistent with other attachment actions.

Renaming must not re-encode the recording, change its identifier, or upload the same bytes again unnecessarily.

Use the existing attachment creation timestamp as the recording timestamp when that reliably represents the start of recording. If recording-start time and attachment-creation time differ materially, preserve the recording-start time separately using an approach compatible with the encryption architecture.

Store timestamps consistently and display them in the current user's local time.

### 4.4 Multiple recordings per note

A note may contain any number of independently stored recordings, subject to storage and existing attachment limits.

Each recording must have:

- A unique attachment identifier.
- Its own title.
- Its own timestamp.
- Its own audio file.
- Its own playback position and state.
- Its own duration.
- Its own rename and removal actions.

Starting a second recording must not overwrite or mutate the first.

Playing a second recording must stop or pause the previous recording, according to a single consistent playback policy. Prefer allowing only one active player across the application.

Keep recordings in document order.

### 4.5 Finished audio card

Create a dedicated audio attachment presentation component, for example `QuietAudioCard`, using actual repository naming conventions.

The card should display:

- An audio or microphone icon.
- The user-defined recording title.
- The recording timestamp in subdued secondary typography.
- A play/pause control.
- A seek bar or compact waveform with playback progress.
- The elapsed playback time and total duration.
- A restrained overflow action menu.
- A subtle offline/privacy indication where appropriate.

Prefer a progress bar in the initial release if reliable waveform extraction and caching would create unnecessary complexity.

Do not generate synthetic waveforms that imply actual recorded amplitude data.

If a waveform is displayed, derive it from actual audio samples, with bounded processing and sensible caching.

The title must wrap gracefully on small phones. Controls must remain usable at narrow widths and on desktop/tablet layouts.

The component must support all active Quiet Paper theme families.

### 4.6 Playback interaction

Implement reliable play, pause, seek, completion, and cleanup behavior.

Requirements:

- Update playback progress without causing unnecessary full-document rebuilds.
- Read the actual duration from the finalized media asset or trusted parsed media metadata.
- Handle seeking to the beginning and end of a recording.
- Handle an unavailable attachment, failed decryption, unsupported format, corrupt container, and a locked vault.
- Reset progress and update the UI when playback completes.
- Stop playback when another clip begins.
- Stop or release playback resources when the user navigates away or the player is disposed, subject to the chosen playback/background policy.
- Handle audio focus, interruptions, and route changes such as headphones being disconnected where the chosen platform APIs support them.

The initial target is reliable in-app foreground playback. Implement background playback only if the current architecture already supports it cleanly or it can be added without a disproportionate change.

Do not let playback silently continue after the user closes the relevant editing context.

---

## 5. Recording architecture and service boundaries

Implement a dedicated, testable audio journaling domain while reusing existing lower-level recording facilities whenever sensible.

Suggested conceptual components:

- `AudioJournalRecordingService`: owns microphone capture and recording lifecycle.
- `AudioJournalRecordingController` or equivalent Riverpod state controller.
- `AudioJournalAttachmentService` or a narrow adapter around the existing generic attachment pipeline.
- `AudioPlaybackService` or equivalent playback coordinator.
- `QuietAudioCard`: renders saved recordings.
- Existing Super Editor controller and document serializer: insert, rename, and remove audio blocks.

These names are suggestions, not a mandate. Follow established project naming and layering conventions.

### 5.1 Keep speech dictation independent

The existing `AudioRecorderService` and speech recognition stack serve a different purpose. They may use temporary PCM audio and delete it after transcription.

Do not accidentally change the existing dictation behavior while introducing persistent recordings.

If the lower-level recording service can be safely generalized, make its configuration explicit. For example, allow callers to specify recording mode, output format, maximum duration, auto-stop policy, and file cleanup ownership.

The existing dictation caller must preserve its current behavior unless an independently justified fix is needed.

Audio journaling must have persistent-output semantics. It must not automatically delete the finalized recording when a speech session ends.

If changing the shared recorder creates excessive coupling or regression risk, create a dedicated adapter/service that reuses the appropriate low-level plugin while keeping the lifecycle independent.

### 5.2 Recording state machine

Implement an explicit and testable lifecycle. A suitable state model is:

- `idle`
- `requestingPermission`
- `preparing`
- `recording`
- `paused`
- `finalizing`
- `encrypting`
- `saving`
- `failed`
- `interrupted`
- `completed`
- `cancelled`

You may simplify this if the implementation has a stronger existing state model, but transitions must be explicit.

Required invariants:

- Only one recording session can be active at once.
- Pause is valid only for a recording in progress.
- Resume is valid only for a paused recording.
- Finish cannot execute twice and must be idempotent or safely guarded.
- Cancel cannot leave a persisted attachment or dangling note reference.
- Failure must release microphone resources.
- Late asynchronous callbacks must not mutate disposed controllers or replace a newer session's state.
- A stale session must never overwrite another recording's temporary file.
- State changes must remain observable by the UI while the app lifecycle changes.

Add timeouts around operations that may otherwise leave the UI indefinitely busy.

### 5.3 Recording format and performance

Inspect the existing recording package and all supported application platforms before selecting the format.

Prefer a compact, broadly supported voice-recording format that does not require expensive transcoding. A compressed AAC-based format is a reasonable first candidate on compatible targets; use a different existing format if the project's platform matrix requires it.

Do not record long journal entries as raw PCM without evaluating the resulting storage cost.

The current generic attachment subsystem enforces a 50 MB file limit. Preserve that limit unless the repository has since introduced a newer authoritative policy.

Enforce size limits while recording where practical, not only after the file has filled the device's storage.

Handle maximum duration and size explicitly. Do not blindly inherit the dictation service's 60-second automatic stop.

Use file-backed or streamed recording output when supported rather than accumulating an unlimited audio buffer in RAM.

Do not perform expensive file hashing, encoding, or encryption on the Flutter UI isolate. Reuse existing non-blocking attachment ingestion and background-isolate techniques.

Do not introduce an additional codec/transcoding stack merely to obtain a waveform.

---

## 6. Encrypted attachment integration

This section is a security-critical requirement.

**Audio must follow the existing generic encrypted attachment architecture. Do not create an unencrypted parallel storage path.**

### 6.1 Attachment ingestion

After recording is finalized:

1. Validate the recorded file.
2. Determine and validate its MIME type and extension.
3. Create a unique attachment ID using the existing identifier conventions.
4. Route the bytes through the existing client-side attachment encryption mechanism.
5. Bind encryption to the attachment using the existing authenticated-data rules.
6. Persist the encrypted payload using the existing app-private storage conventions.
7. Create or update the local attachment record.
8. Connect the attachment to the current note according to the existing ownership/reference model.
9. Enqueue synchronization using the existing queue and upload-state conventions.
10. Delete the original temporary plaintext recording after encrypted persistence succeeds.

Use the existing `AttachmentCrypto`, including its current XChaCha20-Poly1305/QPA1 format, wherever that is the generic attachment contract.

Do not invent a separate audio cipher, master key, remote storage provider, or encryption envelope.

### 6.2 Generic file MIME type

Audio recordings should ordinarily use the existing generic file attachment kind with an appropriate MIME type, such as `audio/mp4` or `audio/mpeg`, according to the actual encoded format.

Do not add a new backend attachment kind named `audio` unless inspecting the existing system demonstrates that it is genuinely necessary and you implement backward-compatible validation and synchronization changes.

The existing attachment kind, MIME handling, and resource type mappings must remain coherent across local storage, cloud sync, backups, and export.

Crucially, do not route audio through image-import methods that trigger image OCR or image-specific processing.

### 6.3 Plaintext temporary-file handling

Recording requires a temporary output file. Playback may also require a short-lived decrypted file, depending on the selected audio player.

Use the existing secure temporary-storage manager or extend it appropriately.

Requirements:

- Store working files in app-private temporary directories.
- Use collision-resistant filenames that cannot overwrite another recording.
- Never use publicly accessible shared folders as the recording workspace.
- Do not persist plaintext recordings in the normal attachment vault.
- Remove recording buffers and temporary files after successful encryption.
- If encryption or persistence fails, retain a recoverable working file only as long as necessary to support explicit retry or recovery.
- Clean abandoned recording sessions and stale playback files safely on startup.
- Delete decrypted playback material promptly after playback is stopped and the media player releases the file.
- Do not assume that deleting a Dart `File` while a native player still holds it will work on every platform.
- Preserve the existing stale-file cleanup mechanism and do not weaken its security guarantees.
- Never log audio bytes, audio contents, decrypted paths, private clip titles, or transcripts.

Do not claim that a temporary plaintext file is encrypted at rest. Keep its lifetime and exposure tightly controlled.

### 6.4 Privacy of title and metadata

Audio journal titles and the recording's semantic content are private user data.

Inspect which existing attachment metadata fields are transmitted to the server in plaintext. Do not assume that all attachment metadata receives the same end-to-end encryption as a note's Markdown body.

Avoid putting the user's chosen recording title into a plaintext cloud filename field if that field is not encrypted. Use a neutral technical filename and keep the user-facing title inside the encrypted Markdown reference.

Use existing attachment timestamps if appropriate, recognizing the metadata exposure already present in that schema. If separate recording-start metadata is needed, place it inside encrypted note content or another appropriately encrypted payload rather than adding unnecessary sensitive cloud metadata.

---

## 7. Markdown representation and Super Editor node integration

The persisted Markdown representation is canonical. The custom audio card is a presentation and interaction layer, not a separate document format.

### 7.1 Canonical attachment reference

The expected base resource reference is the existing attachment URI:

`qp://asset/<UUID>`

The canonical Markdown link should use the user-facing clip title as its label, for example:

`[Morning reflections](qp://asset/550e8400-e29b-41d4-a716-446655440000)`

Use the project's current UUID and URI helpers rather than hardcoding a new format.

The Super Editor should identify this link as an audio attachment based on the resolved attachment's `mimeType` and current attachment metadata. Filename-based detection may serve as a fallback when metadata is not yet available, but must not be the sole reliable classification strategy.

### 7.2 Dedicated audio presentation

Extend the existing generic attachment block rendering flow.

For an `AttachmentBlock` referring to an audio MIME type, render `QuietAudioCard` instead of the generic file attachment card.

Reuse the shared audio card in Markdown preview and other compatible rendering surfaces so the resource behaves consistently across editor modes.

If the current Visual editor uses a separate block abstraction, implement the smallest compatible change so an audio resource does not become unrecognized or disappear.

Other generic file attachments must retain their existing presentation and behavior.

### 7.3 Serializer and deserializer invariants

This area is especially sensitive. Recent Super Editor work has addressed loss of attachment markers, custom-node promotion, raw HTML comment stripping, link normalization, and round-trip serialization.

Do not introduce a fragile HTML-comment sentinel or custom Markdown syntax without demonstrating that it survives the existing parsers and serializers.

Prefer the existing link-form attachment representation.

If additional metadata is needed, first determine whether the existing attachment record and the canonical Markdown representation already supply it. Extend the format only when necessary, and ensure the extension survives all editor modes.

The implementation must preserve these invariants:

- Existing Markdown notes open unchanged.
- Existing non-audio attachments are unaffected.
- Audio links are promoted to audio cards when metadata identifies them as audio.
- Ordinary links and non-audio file attachments remain ordinary links/cards as appropriate.
- Consecutive attachment blocks retain their order.
- Audio cards serialize back to stable Markdown resource references.
- Switching between Super Editor, Visual, and Markdown modes does not lose title, timestamp, attachment ID, or audio data.
- Raw Markdown source mode does not contain accidental JSON dumps, temporary paths, binary data, or other internal implementation details.
- Editing the text around an audio card does not corrupt its URI.
- Renaming a clip updates the link label without changing the attachment ID or destroying unrelated metadata.

Test actual document round trips; do not assume that calling a serializer with a custom node automatically yields correct Markdown.

### 7.4 Insertion position and undo/redo

Capture the logical insertion position before the keyboard is dismissed.

Use stable document positions, node identifiers, or the editor's supported selection transformation APIs as appropriate to the current implementation.

Do not rely solely on a raw character offset if Super Editor uses a richer selection model.

While recording:

- Preserve the selected insertion location.
- Keep the note's existing content intact.
- Avoid inserting a permanent attachment reference before an asset exists.
- Do not allow a note save to serialize a broken temporary URI.
- If edits, an external sync update, or a note switch invalidate the original insertion location, handle the condition safely.

After a recording is saved, insert the completed audio reference as a discrete logical edit and preserve surrounding text and block order.

Use the existing undo/redo system where possible. Undoing insertion should remove the audio reference but must not unexpectedly destroy encrypted data that is still referenced elsewhere. Redo should restore the reference without duplicating the audio bytes or creating a new attachment ID.

Cancelling should not create a document edit.

---

## 8. Playback resource resolution

Playback must use Quiet Paper's actual attachment resolver and encryption key manager.

Do not pass a `qp://` URI directly to a generic audio player and expect it to work.

The flow should be:

1. Resolve the attachment reference.
2. Verify that the attachment exists and is audio-compatible.
3. Check that the vault is unlocked as required.
4. Retrieve the encrypted local file or download the encrypted asset via the existing synchronization mechanism.
5. Decrypt using the existing attachment cryptography.
6. Validate the decrypted payload.
7. Prepare an approved ephemeral playback source.
8. Start the player.
9. Observe playback position, duration, buffering/errors, completion, and interruption state.
10. Dispose the native player and release resources.
11. Remove ephemeral plaintext material as soon as the player has released it.

If the attachment is still being downloaded, show an appropriate loading state and allow a retry.

If the user is offline and the encrypted attachment is already available locally, playback must work normally.

If the encrypted attachment is unavailable offline, show a clean unavailable state rather than leaving an infinite spinner.

If the vault is locked, display the appropriate locked state and never attempt decryption with a random or newly generated substitute key.

Use the existing key manager's locked-state contract.

Do not automatically delete or re-create the attachment on playback failures.

---

## 9. Attachment metadata, synchronization and storage

### 9.1 Avoid unnecessary schema changes

First determine what is already available on the attachment record, including ID, MIME type, filename, byte size, hash, local path, cloud identifiers, upload state, timestamps, and deletion state.

Reuse the existing fields.

Prefer deriving duration from the media container or playback service rather than adding a new database column solely for duration.

Persist additional metadata only when necessary for dependable behavior, and document why it cannot be derived or stored in an existing appropriate location.

If any schema change is justified:

- Increment the schema version correctly.
- Implement backward-compatible Drift migrations.
- Update generated code using the repository's normal build process.
- Preserve old notes and attachments.
- Update relevant models, serialization and database test fixtures.
- Ensure backup/restore compatibility.

### 9.2 Cloud sync

Use the existing encrypted attachment synchronization pipeline.

The audio ciphertext must be uploaded through the established attachment path, not through a new raw-audio API that bypasses encryption.

Cloud sync must preserve:

- Attachment identity.
- MIME type and appropriate generic attachment kind.
- Encrypted file bytes and integrity information.
- The link between the attachment and note, according to the existing ownership model.
- Existing upload states, retries, deletion handling, and metadata confirmation rules.

The recording must remain playable after synchronization to a second device.

A note pulled before the associated attachment finishes downloading should still render a valid loading or pending card.

Retries must not create duplicate cloud objects or duplicate attachment rows.

Do not introduce backend tables or API endpoints unless required by a verified gap in the existing attachment protocol.

### 9.3 Attachment size and duration

Retain the existing generic attachment 50 MB ceiling unless repository inspection shows that the authoritative current limit has changed.

Enforce limits before and during ingestion where possible.

If the active recorder can check output growth, stop safely before the limit is exceeded and explain why recording ended.

Do not allow an oversized file to be fully loaded into memory before discovering that it cannot be saved.

If a duration limit is necessary for platform or storage safety, make it an explicit audio journaling policy independent of dictation's current limit.

---

## 10. Backup, export, deletion and sharing

### 10.1 Local backup and restore

Extend existing backup behavior only if generic attachments are not already handled correctly.

A backup must preserve the recording's encrypted bytes and attachment identity using the current backup representation.

Restoration must preserve:

- The audio file byte-for-byte.
- Its attachment ID or correct restored-reference mapping.
- MIME type and filename metadata.
- The timestamp and title as represented by the existing metadata and encrypted note.
- The correct note association and upload state.

Restore must work without internet access.

Confirm that older backup formats still restore successfully.

### 10.2 Note export

Verify that existing `.qpnote` and Markdown export flows handle audio attachments correctly.

Markdown export should follow the existing attachment-export convention, resolving `qp://asset/<UUID>` into the proper relative attachment path and preserving the original media bytes after authorized decryption.

Use sanitized filenames and the existing collision-handling utility.

If an export format does not support audio embedding, provide a clear attachment reference or explicit omission behavior rather than generating a broken link.

### 10.3 Deletion and undo

Removing an audio block from a note must follow the existing attachment reference and ownership rules.

Do not permanently delete an attachment merely because a document block was removed if the attachment may still be referenced elsewhere or is subject to undo.

Use established archive, trash, soft-delete, reference counting, synchronization tombstone, or undo mechanisms as appropriate to the actual repository.

Confirm that deletion works consistently on the local device and after subsequent synchronization.

### 10.4 Public sharing privacy

This is mandatory.

The existing public-sharing implementation may resolve `qp://asset/<UUID>` attachments by decrypting and uploading plaintext copies.

A private voice recording must never become public silently because its parent note was shared.

Inspect the actual share flow and implement explicit audio-specific safeguards.

Default behavior:

- Exclude audio recordings from public shares.
- Display a clear notice when a note contains audio that will not be included.
- Do not leave a misleading playable card pointing at a private `qp://` resource in the public version.
- Render a clear omission indicator or use the share system's safe attachment omission convention.

If audio inclusion is explicitly supported, require deliberate user opt-in, clearly explain that the audio content will be uploaded in a form accessible under the public link's sharing permissions, and follow the existing sharing warning and upload workflow.

Do not weaken the privacy of existing attachments to make audio sharing easier.

---

## 11. Permission and lifecycle requirements

Implement robust platform-aware handling for:

- Microphone permission denied.
- Microphone permission permanently denied.
- Another application owning the microphone.
- Incoming phone calls and interruptions.
- Audio focus changes.
- App backgrounding or foregrounding.
- Navigation away from the editor.
- Editor disposal.
- Screen rotation and layout changes.
- Low storage.
- Maximum file size reached.
- Recorder startup timeout.
- Recorder finalization failure.
- Encryption failure.
- Attachment persistence failure.
- Cloud upload failure.
- Playback initialization failure.
- Decryption and integrity failures.
- Missing attachments.
- Vault lock during the recording or playback lifecycle.
- Device process death and app restart.

Never show the recording UI as active when the actual recorder is stopped.

If the application loses the foreground while recording, follow a deliberate policy consistent with platform support. If background capture is supported, request all necessary permissions and show the appropriate system indicator. Otherwise, stop or pause safely and notify the user.

For interrupted recordings, preserve the recoverable temporary file when possible and offer recovery on the next launch. Do not silently create an attachment that was never finalized or confirmed by the user.

Do not perform cleanup at a point where it can race with encryption or playback.

---

## 12. Formatting and user interaction details

### Rename

Provide an accessible rename action. Normalize and validate the title, avoid empty titles, and handle Unicode correctly.

A title change should update the canonical Markdown link label and trigger normal autosave. It should not change the audio payload or ID.

### Remove

Offer an appropriate delete/remove action. If removal could permanently delete an unreferenced attachment, follow established confirmation and undo conventions.

Removing an audio block must not remove neighboring paragraphs or change the ordering of other recordings.

### Duration formatting

Implement a reusable formatter for recording and playback durations.

Display stable human-readable values, for example:

- `00:08`
- `03:18`
- `1:04:32`

Avoid overflow and negative duration displays. Distinguish a live recording timer from an ended playback timer.

### Responsive layout and accessibility

Test small phones, wider phones, tablets, and desktop layouts supported by the repository.

Use the existing maximum-width and typography conventions.

All interactive controls need accessible labels, proper disabled states, useful tooltips where appropriate, and adequate touch targets.

Do not rely on color alone to indicate whether recording or playback is active.

---

## 13. Error handling and recoverability

All failures must leave the application in a coherent state.

### Recording fails

- Stop and release the recorder.
- Preserve a recoverable partial file if appropriate.
- Clearly explain that the recording was not saved.
- Offer retry or discard when safe.
- Do not insert a valid-looking attachment block pointing to a missing file.

### Encryption fails

- Do not write plaintext bytes into the normal encrypted attachment storage location.
- Do not report success before the encrypted file and metadata are durably committed.
- Keep a recoverable temporary file only when necessary and inform the user about the retry/discard choice.
- Clean up safely when the retry or discard is completed.

### Cloud sync fails

- Keep the locally encrypted attachment playable.
- Retain the normal pending/error synchronization state.
- Do not block playback merely because synchronization is unavailable.
- Allow the existing sync engine to retry without duplicating the attachment.

### Playback fails

- Release player resources.
- Remove decrypted temporary files when safe.
- Show a meaningful retry state.
- Preserve the original encrypted attachment and note reference.

Never suppress exceptions silently or log sensitive audio-related data.

---

## 14. Automated testing requirements

Add tests following the existing test structure, fake services, and naming conventions.

Do not depend on a physical microphone, a real Cloudinary account, a speech model download, or a real external audio player in unit and widget tests.

Provide dependency injection or narrow abstractions for recording, playback, attachment ingestion, filesystem access, and clocks wherever needed.

### A. Recording service tests

Test:

- Successful recording startup.
- Permission granted and denied.
- Recording timer updates.
- Pause and resume preserving elapsed duration.
- Finish creates one valid output.
- Duplicate finish requests do not create duplicate attachments.
- Cancel leaves no dangling attachment.
- Recorder startup and finalization timeouts.
- Invalid or empty audio output.
- File-size and configured duration limits.
- Interruption handling.
- Session recovery after simulated process interruption.
- Disposal and stale asynchronous callbacks.
- Concurrent attempts to start two recordings.
- Temporary-file cleanup.
- Current dictation behavior remains unchanged.

### B. Audio attachment tests

Test:

- Generic attachment ingestion for audio.
- MIME type and extension consistency.
- Encryption produces the expected QPA1 envelope.
- Decryption reproduces the exact original audio bytes.
- Authenticated decryption fails on tampering.
- Upload payloads contain ciphertext rather than plaintext audio.
- Size-limit enforcement.
- Failure cleanup and retry handling.
- No image OCR pipeline is invoked for audio.
- Metadata fields are handled according to the existing privacy model.

### C. Super Editor and Markdown tests

Test:

- Inserting an audio block at the beginning, middle, and end of a note.
- Preserving the original cursor/insertion location.
- Correct ordering of text, images, documents, generic attachments, and multiple audio cards.
- Multiple audio links with distinct UUIDs.
- Rendering audio as an audio card when attachment MIME type identifies it as audio.
- Rendering non-audio attachments exactly as before.
- Rename preserves URI and ID.
- Removal preserves neighboring content.
- Cancel causes no canonical document mutation.
- Finish inserts exactly one logical block.
- Undo and redo preserve references without duplicate asset creation.
- Super Editor → Markdown → Super Editor round trips.
- Super Editor → Visual → Super Editor round trips.
- Raw Markdown remains valid and contains no binary payloads or temporary paths.
- Older notes containing ordinary asset links still render correctly.
- Missing attachment metadata degrades gracefully.
- Consecutive audio blocks serialize and deserialize correctly.

### D. Playback widget and service tests

Test:

- Play and pause.
- Seeking and progress updates.
- Duration formatting.
- Playback completion.
- Starting another recording stops the previous one.
- Player disposal on navigation.
- Player error states.
- Locked-vault behavior.
- Missing and pending attachments.
- Temporary decrypted-file lifetime and cleanup.
- Dark and light theme rendering.
- Narrow-screen layout and responsive controls.

### E. Backup, export, sync, and sharing tests

Test:

- Local backup and restore preserve audio bytes and references.
- Restored recordings play offline.
- Export resolves the audio resource correctly.
- Existing generic attachment exports remain unchanged.
- Cross-device synchronization resolves audio metadata and ciphertext.
- Offline uploads remain queued correctly.
- Retry does not produce duplicate attachment records.
- Removal and undo do not unexpectedly destroy referenced audio.
- Public sharing excludes audio by default.
- Explicit inclusion requires clear user consent.
- Shared notes never contain unusable private resource references.

### F. Regression tests

Preserve the existing speech-recognition, transcription, generic attachment, image, document, Markdown, editor-mode, backup, and sync tests.

Do not delete, weaken, or skip old tests merely to make the new feature pass.

Where appropriate, add a regression test that proves dictation retains its existing maximum duration and cleanup semantics.

---

## 15. Performance and engineering quality

The feature must not make normal note editing sluggish.

- Use the existing background isolate or non-blocking attachment encryption path.
- Stream or file-back recording when supported.
- Avoid repeatedly resolving or decrypting the same attachment on every widget build.
- Avoid updating the entire editor document at high frequency just to refresh a timer or playback position.
- Keep a recording timer isolated from unrelated note state.
- Bound audio waveform data and processing work.
- Do not keep large decoded buffers alive unnecessarily.
- Avoid repeated attachment downloads when encrypted local bytes already exist.
- Make provider lifetimes explicit and avoid recreating a live recording service when another provider emits state changes.
- Ensure audio player and recorder resources are disposed according to lifecycle ownership.

Do not introduce unnecessary abstractions, dependencies, schema migrations, backend endpoints, or settings screens.

Follow the repository's current Riverpod, Drift, exception-handling, formatting, and testing conventions.

---

## 16. Implementation workflow

Execute the work in the following order.

### Phase 1 — Repository reconnaissance

Identify actual implementations of the recorder, generic attachment import, playback dependencies, attachment persistence, encryption, Super Editor node promotion, serialization, and public sharing.

Identify which requirements can be met without changing schemas or backend behavior.

### Phase 2 — Domain and recording foundation

Introduce the persistent audio journal recording lifecycle with testable state transitions, configurable recording settings, output finalization, recoverability, and error handling.

Preserve existing dictation behavior.

### Phase 3 — Attachment ingestion

Connect finalized recordings to the existing generic encrypted file attachment system.

Verify encryption, metadata persistence, local resolution, and background-safe ingestion before adding UI complexity.

### Phase 4 — Super Editor integration

Implement recording controls, logical cursor anchoring, attachment insertion, the audio card renderer, renaming, playback, removal, and undo/redo.

Ensure the underlying Markdown remains canonical.

### Phase 5 — Lifecycle, synchronization and privacy

Validate offline behavior, attachment syncing, backup/restore, export, attachment cleanup, and explicit public-sharing rules.

Make schema and backend changes only when proven necessary.

### Phase 6 — Verification and polish

Run new tests, existing focused tests, static analysis, and the full Flutter test suite.

Run backend tests if backend files were changed.

Fix failures caused by the feature. Check the final diff for unrelated edits, accidental dependency churn, generated-file issues, sensitive logging, and regressions.

Do not mark work complete while known failures introduced by the implementation remain.

---

## 17. Definition of done

The implementation is complete only when all applicable requirements below are satisfied.

### Recording

- [ ] A user can start recording from Super Editor.
- [ ] A user can pause, resume, finish, or cancel.
- [ ] The timer and active recording UI are correct.
- [ ] Interrupted and failed sessions clean up safely or provide recovery.
- [ ] Multiple recordings can be created in the same note.

### Audio journaling

- [ ] Every finalized recording has a unique resource ID, editable name, and preserved recording timestamp.
- [ ] Each audio block has a playable inline card.
- [ ] Playback, seeking, progress, duration, completion, and player disposal are correct.
- [ ] Starting a second playback does not leave the first playing unexpectedly.
- [ ] Naming or rearranging blocks does not alter the audio payload.

### Architecture

- [ ] Existing encrypted attachment infrastructure is reused.
- [ ] Audio is encrypted before normal attachment persistence or cloud upload.
- [ ] Audio never triggers image OCR.
- [ ] Markdown remains the canonical note representation.
- [ ] Super Editor and other supported modes round-trip audio references correctly.
- [ ] No unnecessary database or backend changes have been introduced.
- [ ] Existing dictation and attachment behavior remains intact.

### Privacy and durability

- [ ] The feature works offline for recording and locally available playback.
- [ ] Public sharing excludes recordings by default and cannot silently expose audio.
- [ ] Temporary plaintext files are cleaned up safely.
- [ ] Backup and restore preserve audio bytes and references.
- [ ] Export and cloud synchronization preserve expected audio behavior.
- [ ] Locked-vault behavior is correct.
- [ ] Failed uploads, interrupted recordings, and playback failures do not destroy valid local data.

### Quality

- [ ] Relevant new automated tests pass.
- [ ] Existing regression tests pass.
- [ ] `flutter analyze` reports no newly introduced issues.
- [ ] The full `flutter test` suite passes.
- [ ] Backend tests pass if backend code changed.
- [ ] Responsive light/dark UI and accessibility have been tested.
- [ ] The final diff contains no unrelated changes.

---

## 18. Final coding-agent report

At completion, provide a concise but technically meaningful report containing:

1. **Implemented behavior:** What a user can now do.
2. **Architecture:** How recording, attachment encryption, document insertion, and playback connect.
3. **Files changed:** New files, modified files, database migrations, backend files, and dependencies, grouped by responsibility.
4. **Persistence format:** The canonical Markdown representation and how audio metadata is preserved.
5. **Security:** How plaintext temporary files, encryption, cloud uploads, and public sharing are handled.
6. **Compatibility:** Confirmation of behavior across editor modes and existing generic attachments.
7. **Verification:** The commands executed and actual results for static analysis, focused tests, the full Flutter test suite, and backend tests where applicable.
8. **Remaining limitations:** Any platform-specific constraints, untested device behavior, or explicitly deferred work.

Be precise about the actual implementation and verification. Do not claim background recording, cross-device playback, platform support, or test success unless those behaviors were genuinely verified.

**Final directive:** Implement the complete audio journaling MVP in the existing Quiet Paper repository. Prefer reuse over duplication, canonical Markdown over a parallel document format, encrypted attachments over new storage infrastructure, and reliable lifecycle behavior over superficial UI shortcuts. Preserve all existing functionality while making audio recording feel like a natural, private, first-class part of Quiet Paper's Super Editor.
