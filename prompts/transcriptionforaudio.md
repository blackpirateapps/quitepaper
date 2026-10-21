# Quiet Paper — Audio Journal Transcription
## Comprehensive Engineering Implementation Specification

## 1. Mission

Implement a complete, production-quality **on-device audio transcription feature for Quiet Paper's existing Audio Journaling system**, integrated into the Super Editor.

Quiet Paper already has an offline Whisper/whisper.cpp speech recognition subsystem, model management, recording infrastructure, encrypted attachment storage, Markdown-based notes, and cross-device synchronization.

The audio journaling feature has also been implemented separately. This task builds on those capabilities.

**Do not rebuild the audio recording feature. Do not replace the existing Whisper engine. Extend the current implementation to allow users to transcribe saved audio journal recordings, view and edit transcripts inside their audio cards, insert transcript copies into note bodies, and search the resulting text.**

The core product experience is:

1. The user records a voice memo inside Super Editor.
2. The recording is saved as an encrypted audio attachment.
3. The user taps **Transcribe audio** on that recording.
4. Quiet Paper processes the audio locally using the existing Whisper recognition infrastructure.
5. A transcript appears inside the same audio card.
6. The transcript can be expanded, edited, copied, or inserted into the ordinary Markdown body of the note.
7. The transcript persists across app restarts, editor-mode changes, backups, and encrypted cloud synchronization.
8. Transcript content becomes searchable locally without weakening the existing privacy model.

**The original audio must remain intact regardless of transcription, editing, cancellation, or regeneration.**

This is an implementation task. Inspect the repository, make the required changes, run the appropriate tests, fix regressions, and report actual results. Do not stop after proposing a design.

---

## 2. Product principles

Follow these rules throughout the implementation.

### 2.1 The recording remains the source of truth

A transcript is a companion to an audio recording, not a replacement.

Transcribing, editing, regenerating, or removing a transcript must never modify or re-encode the original audio attachment.

A transcription failure must never invalidate or delete an otherwise playable recording.

### 2.2 On-device processing only

Use the existing local Whisper engine. Audio must not be sent to a cloud transcription API, third-party speech recognition service, backend endpoint, or external AI service.

Internet access may be necessary for an explicitly initiated download of a missing recognition model, using Quiet Paper's existing model-management workflow. Audio itself must remain on-device throughout transcription.

Never fall back silently to cloud transcription.

### 2.3 Reuse existing infrastructure

Reuse the existing speech model manager, recognition engine, recording abstractions where appropriate, encrypted attachment service, key manager, editor state management, database, synchronization engine, and backup/export workflows.

Do not introduce a second copy of Whisper, a second model downloader, a new transcription backend, or a parallel attachment system.

### 2.4 Markdown remains canonical

Use Quiet Paper's current document and serialization architecture.

The transcript associated with an audio card must have a stable, reversible representation in the canonical note content or another explicitly encrypted and synchronized representation supported by the existing architecture.

The user must not lose transcript content when switching between Super Editor, Visual, and Markdown modes.

### 2.5 Manual changes are valuable user content

Whisper-generated text is editable user content once accepted. Never silently overwrite manual corrections during regeneration.

Record whether the transcript has been manually edited and provide an explicit, safe regeneration workflow.

### 2.6 No unnecessary UI complexity

Transcription is an action on an existing audio journal card. Do not create a separate full-screen transcription application unless the existing navigation architecture genuinely requires one.

Keep recording, playback, and transcript editing inside the audio card whenever practical.

---

## 3. Repository reconnaissance

Before changing code, inspect the actual current repository. The code in the working tree is authoritative; engineering handoff documents may describe earlier states.

### 3.1 Existing speech recognition subsystem

Inspect the current implementations and dependencies around:

- `lib/core/speech/infrastructure/audio_recorder_service.dart`
- `lib/core/speech/infrastructure/whisper_recognition_engine.dart`
- `lib/core/speech/infrastructure/speech_storage_service.dart`
- `lib/core/speech/application/speech_recognition_service.dart`
- `lib/core/speech/application/speech_model_manager.dart`
- `lib/core/speech/application/speech_provider.dart`
- `lib/core/speech/domain/speech_session_state.dart`
- The existing speech model descriptors, model selection, settings UI, and model download dialog.
- Existing native library/FFI integration and isolate dispatch.
- Existing speech engine interfaces, transcription APIs, and fake implementations.

Determine the current engine's actual input format, output types, language capabilities, model selection mechanism, timeout behavior, concurrency restrictions, and cleanup requirements.

The objective is to expose or reuse a suitable **transcribe-existing-audio-file** capability. Do not implement transcription by pretending that an already saved recording is a new dictation session.

If the recognition engine currently accepts only temporary WAV files, implement a safe local preparation step that converts the saved recording into the supported input format when necessary.

Do not assume that the audio journaling format is identical to the speech engine's accepted input format.

### 3.2 Existing Audio Journal implementation

Inspect the files added or modified for the preceding audio-journaling task, including:

- Recording service and state controller.
- Audio attachment ingestion and metadata.
- Audio player and playback controller.
- `QuietAudioCard` or its current equivalent.
- Super Editor toolbar and audio attachment block.
- Audio metadata serialization and deserialization.
- Audio rename, remove, undo, and redo logic.
- Temporary recording and playback file handling.

Extend these components. Do not create duplicate services or alternative audio cards unnecessarily.

### 3.3 Canonical note architecture

Inspect:

- `lib/features/editor/presentation/widgets/quiet_super_editor.dart`
- `lib/features/editor/application/quiet_super_editor_controller.dart`
- `lib/features/editor/presentation/widgets/markdown_editor.dart`
- `lib/features/editor/presentation/editor_screen.dart`
- Current audio and generic attachment node models.
- The custom Markdown-to-document deserializer and document-to-Markdown serializer.
- The Visual editor's document model and serialization pipeline.
- Frontmatter preservation and note autosave.
- Undo/redo and selection management.

Determine exactly how the current audio block survives serialization before deciding how its transcript should be represented.

### 3.4 Encryption, synchronization, and persistence

Inspect:

- Attachment encryption and decryption.
- The key manager and locked-vault behavior.
- Note encryption and sync serialization.
- Drift note and attachment tables.
- Existing FTS5 search implementation and search projection.
- Backup serialization and restoration.
- Generic attachment export.
- Public note sharing and attachment filtering.
- Attachment lifecycle, removal, reference resolution, and synchronization retries.

Identify the smallest compatible change that preserves all current guarantees.

### 3.5 Stop only for verified technical constraints

If a component differs from the expected architecture, adapt to the actual implementation. Do not blindly create files with the same names or duplicate existing abstractions.

If the repository lacks a functioning piece of the preceding audio feature, make the smallest required compatibility fix. Do not turn this task into a wholesale rewrite of Audio Journaling.

---

## 4. Required user experience

### 4.1 Audio card actions

Add contextual transcription actions to the existing audio card's overflow menu.

The menu should expose the appropriate action for the current transcript state:

| Transcript state | Primary action |
|---|---|
| No transcript | Transcribe audio |
| Preparing | Show preparation status |
| Transcribing | Show progress and allow cancellation |
| Available | View transcript / Edit transcript |
| Manually edited | View or edit transcript; Regenerate transcript |
| Failed | Retry transcription |
| Model unavailable | Open the existing model setup/download flow |
| Recording unavailable or vault locked | Show the relevant safe error/locked state |

Do not create redundant menu entries for actions that are already visible on the card.

If the transcript is available, the user should be able to expand or collapse it directly in the card.

The original recording remains playable while a transcript is available or being displayed.

### 4.2 Transcript display

When a transcript is available, the audio card displays a collapsible transcript area.

The expanded area should contain:

- The recognized text.
- An unobtrusive status label such as `Transcript`.
- The recognition language/model information where useful.
- An indication when the transcript was manually edited.
- An `Edit transcript` action.
- An `Insert into note` action.
- A `Regenerate transcript` action in the appropriate menu.
- An optional `Copy transcript` action.

Do not duplicate the entire transcript in another part of the note automatically.

The initial collapsed state should match the existing audio card's current presentation. Use a restrained expand/collapse affordance, with no large modal or excessive decoration.

Use existing Quiet Paper theme tokens and typography. Support dark mode, narrow phone layouts, tablets, desktop, and accessibility requirements.

### 4.3 Transcript editing

Allow the user to edit the transcript associated with the original recording.

Prefer inline editing in the expanded audio card if it fits the current Super Editor implementation cleanly. Otherwise, use a small editorial dialog or another existing text editing component.

Requirements:

- Preserve the entire transcript exactly until the user changes it.
- Support multiline text and Unicode.
- Preserve legitimate whitespace and paragraph breaks.
- Save edits through the canonical note editing/autosave mechanism.
- Use existing editor undo/redo mechanisms where practical.
- Mark the transcript as manually edited after user modifications.
- Do not mutate the audio attachment when the transcript changes.
- Ensure editing one audio card does not change another recording's transcript.

If an editable transcript is represented by a custom document node, ensure keyboard input, focus, selection, and scrolling work without destabilizing the surrounding Super Editor document.

### 4.4 Copy and insert actions

Provide two distinct user actions.

**Copy transcript**

Copies the complete transcript text to the clipboard without internal metadata, IDs, hidden markers, or Markdown transport syntax.

**Insert transcript into note**

Inserts an ordinary editable text copy into the note body at a clear, intentional location, preferably immediately after the audio card or at the active logical insertion point if this is already consistent with existing editor behavior.

The inserted copy must not be confused with the transcript associated with the audio card.

Renaming, editing, or regenerating the audio card's transcript must not unexpectedly overwrite the previously inserted copy. Likewise, modifying the inserted text must not mutate the original associated transcript.

Use a stable insertion transaction, preserve adjacent document blocks, trigger normal autosave, and integrate undo/redo.

Do not insert a transcript merely because transcription completes. Automatic insertion is not the default behavior.

### 4.5 Naming and timestamps

The transcript remains associated with the existing audio attachment ID.

Do not create a second audio object or duplicate recording when creating a transcript.

Preserve the recording title and timestamp across transcription and editing. Generate transcript metadata without overwriting the audio attachment's identity or creation information.

---

## 5. Transcription lifecycle and state management

Implement a dedicated and testable transcription lifecycle that is independent of the existing live dictation session.

Suggested state model:

- `notTranscribed`
- `checkingModel`
- `preparingAudio`
- `transcribing`
- `savingTranscript`
- `available`
- `edited`
- `cancelled`
- `failed`

Adapt these states to current Riverpod/service conventions.

Do not conflate temporary progress states with persisted transcript data. On restart, unfinished jobs should return to a safe, retryable state while preserving any previously saved transcript.

### 5.1 Required invariants

1. Only one transcription job per audio attachment may run at a time.
2. Do not start simultaneous jobs for the same attachment.
3. A second request for an already active job should attach to the current job or be rejected safely.
4. A cancellation request must not silently mutate or delete the audio.
5. Late asynchronous callbacks must not overwrite a newer transcript or modify a disposed controller.
6. A job must identify the audio attachment and its current document ownership/association.
7. A failed job must leave the previous valid transcript intact.
8. A failed job must not leave the UI permanently busy.
9. A successful job must persist atomically through the established note persistence mechanism.
10. A manual edit must never be overwritten by an in-flight transcription without explicit user consent.

Use request/session identifiers or equivalent generation guards where needed to prevent stale results.

Add appropriate timeouts and safe cancellation handling around model initialization, audio preparation, and transcription.

### 5.2 Job persistence

A long-running transcription may be interrupted by navigation, process death, or a device restart.

Do not require transcription to continue in the background for the initial release.

At minimum:

- Preserve already saved transcript content.
- Treat unfinished jobs as incomplete after a restart.
- Clean up temporary files safely.
- Permit retry without creating duplicate attachments.
- Prevent automatic re-execution loops when opening a note repeatedly.
- Ensure a stale progress state cannot remain indefinitely.

If a job-status record is necessary, prefer the existing persistence architecture and avoid persisting sensitive plaintext into metadata fields unnecessarily.

---

## 6. Whisper engine integration

### 6.1 Reuse existing models and model management

Use the current Whisper recognition engine and installed model.

Do not install a second speech engine or require another model download solely for audio journaling.

Use the current model manager to:

- Detect whether a usable model is installed.
- Resolve the selected/active model.
- Start the existing installation/download flow if the necessary model is absent.
- Surface model initialization and processing errors.
- Reuse model caching/initialization behavior when safe.
- Respect existing memory-pressure and native-resource management.

If multiple Whisper models are supported, use the current selected model or documented preference. Do not silently switch to another model without explaining the behavior.

If only certain languages are supported, make the limitation explicit.

### 6.2 Add a reusable file-transcription API if needed

The speech recognition subsystem should expose a suitable abstraction for transcribing an existing local audio file.

A possible contract is:

`Future<TranscriptionResult> transcribeFile(TranscriptionRequest request)`

This is illustrative; use the existing abstraction if it already provides equivalent behavior.

The request should include the audio source, relevant recognition options, cancellation mechanism if supported, and a progress callback or stream if the engine can report meaningful progress.

The result should include:

- Full recognized text.
- Recognition language.
- Engine/model identity and version where available.
- Optional timestamped segments, only when the engine actually returns them.
- Relevant completion metadata.
- Structured failure information.

Do not fabricate word-level or segment timestamps when the recognition engine does not provide them.

Do not confuse speech-engine recognition time with the recording's original timestamp.

### 6.3 Preserve dictation behavior

The existing dictation pipeline has a different purpose and lifecycle.

Do not accidentally:

- Remove the existing dictation duration limit.
- Change dictation insertion position.
- Modify dictation's temporary-audio cleanup contract.
- Change which model dictation uses.
- Change dictation permission behavior.
- Alter the existing speech recording bar.
- Introduce a new provider lifecycle bug that recreates a service mid-operation.
- Add transcription callbacks that affect dictation sessions.

If shared abstractions need modification, add explicit behavior rather than weakening old semantics.

Add regression tests for the pre-existing dictation workflow.

### 6.4 Model initialization and UI performance

Whisper recognition must not block the main UI isolate.

Reuse the existing FFI/isolate dispatch and model initialization patterns. Do not create a large number of redundant engine instances.

Ensure the model manager and transcription service have stable lifetimes throughout each operation.

If native engine execution is not safely cancellable once inference begins, support cancellation at the orchestration boundary, stop before starting another chunk, and discard the result when appropriate. Clean up the temporary resources when it is safe to do so.

---

## 7. Audio preparation, chunking, and memory safety

The existing audio journal recording format and the existing Whisper input format may differ.

Inspect the actual formats rather than hardcoding assumptions.

### 7.1 Prepare audio locally

The preferred pipeline is:

1. Resolve the existing encrypted audio attachment.
2. Confirm that the encryption key is available.
3. Decrypt into tightly controlled app-private temporary storage or use an existing safe in-memory path where supported.
4. Validate the input file and actual media duration.
5. Convert it locally to the format accepted by the current recognition engine if required.
6. Run recognition.
7. Persist the transcript using the established encrypted note mechanism.
8. Clean up temporary decrypted and converted files after they are no longer needed.

Never upload the source audio, converted audio, temporary waveform data, or transcript to the backend for recognition.

Do not modify the original audio attachment as a side effect of format conversion.

### 7.2 Long recordings

Voice recordings may be longer than short dictation sessions.

Do not assume that the complete recording can be loaded into RAM and transcribed in a single call safely.

Determine the current engine's memory and duration constraints.

If it cannot safely process the recording in one pass:

- Decode/resample in bounded buffers.
- Divide the audio into suitable sequential chunks.
- Include appropriate overlap/context where needed to prevent words being cut at chunk boundaries.
- Remove duplicate text introduced by overlapping chunks.
- Preserve the correct order of recognized content.
- Bound memory allocations.
- Yield to the event loop or execute work in existing background isolates.
- Honor cancellation between processing stages.
- Avoid losing early chunks if a later chunk fails.

Do not invent precise numerical progress percentages unless meaningful stage-level or chunk-level progress is available.

If a recording is too long or unsupported for safe processing, give the user a meaningful explanation and keep the original audio intact.

### 7.3 Transcript correctness

Use the actual final output from the existing Whisper engine.

Do not introduce invented text, silent auto-correction that changes meaning, or automatic summaries as part of transcription.

If punctuation or whitespace normalization is applied, keep it deterministic and minimal.

Avoid concatenating chunk results into malformed words or duplicating sentence fragments.

Treat empty recognition results as an explicit failure or no-speech outcome instead of persisting an apparently successful empty transcript.

---

## 8. Transcript persistence and canonical document representation

This is one of the most important architectural decisions.

The transcript must stay linked to the correct audio recording while remaining stable across all editor modes and synchronization.

### 8.1 Preserve the existing audio URI

The audio attachment must retain its existing `qp://asset/<UUID>` identity.

Do not create a duplicate attachment ID for a transcript.

Do not store transcript text inside the audio binary or alter the QPA1 attachment encryption envelope to append plaintext data.

### 8.2 Preferred persistence model

Prefer storing the associated transcript as part of the canonical note document representation using a structured audio attachment block that all existing serializers understand.

Extend the current audio block/node model as appropriate. Its structured data may include:

- Audio attachment ID/reference.
- User-facing audio title.
- Original recording timestamp.
- Transcript text, when available.
- Transcript state represented in the runtime model.
- Recognition language/model metadata that is safe and useful to persist.
- Whether the transcript has been manually edited.
- A schema/serialization version where needed.

Separate transient job progress from durable transcript content. Do not serialize `transcribing`, animation state, progress percentages, or transient filesystem paths into the note.

The exact implementation must fit the repository's existing serialization model. Do not create a parallel document format without a compelling and documented architectural reason.

### 8.3 Serialization requirements

The persisted representation must be deterministic and reversible.

It must correctly handle:

- Multiple audio blocks in one note.
- Multiple consecutive audio blocks.
- Unicode, emoji, and non-English text.
- Apostrophes, quotation marks, and Markdown punctuation.
- Blank lines and paragraphs.
- Markdown links and code within recognized speech.
- Text that resembles metadata delimiters.
- Empty or whitespace-only transcripts.
- Missing audio attachments.
- Old notes with no transcript.
- Partially available or older-format transcript metadata.

**Do not rely on hidden raw HTML comments as the only carrier of transcript metadata.** Existing Super Editor deserialization behavior may discard such comments or separate them from associated links.

Do not expose JSON dumps, encoded metadata blobs, filesystem paths, or internal object identifiers as ordinary UI text.

If a versioned custom Markdown extension is necessary, add a reversible parser/serializer for every supported editor mode. Ensure the extension degrades safely in ordinary Markdown renderers and document any interoperability limitations.

If an associated transcript cannot be represented reliably in canonical Markdown, use a dedicated encrypted transcript sidecar linked by the stable attachment ID. In that case, implement every required local persistence, encryption, synchronization, backup, restoration, and deletion behavior for that sidecar. Do not leave the transcript stored only in memory.

Choose one coherent architecture and complete it; do not implement competing sources of truth.

### 8.4 Editing and regeneration invariants

After transcription completes, the transcript becomes a durable part of the note.

Manual edits must:

- Update the authoritative saved transcript.
- Mark it as user-edited.
- Preserve the original audio.
- Trigger ordinary autosave.
- Participate in note encryption and synchronization.
- Survive app restart and mode switching.

Regeneration must never replace manually edited text automatically.

Use the following safe workflow:

1. User requests regeneration.
2. If no manual changes exist, allow an appropriate straightforward regeneration flow.
3. If the transcript was manually edited, show a confirmation explaining that regeneration will replace the edited transcript.
4. Preserve the current transcript until a new recognition result has succeeded and the user explicitly accepts replacement.
5. If regeneration fails or is cancelled, retain the previous transcript.
6. If the user declines replacement, leave the transcript unchanged.

Prefer staging a new transcript and offering **Replace transcript** or **Keep current** rather than destroying edited text before recognition starts.

Do not invalidate the previous transcript merely because the current recognition model differs from the original one.

---

## 9. Privacy, encryption, and temporary-file lifecycle

Privacy is a mandatory invariant, not an optional enhancement.

### 9.1 Audio privacy

- The original recording remains encrypted using the existing attachment encryption mechanism.
- Whisper receives audio locally.
- No audio bytes, recording content, transcript text, decrypted paths, or private recording titles are sent to remote processing services.
- No audio bytes or transcript content are written to debug logs or crash-reporting metadata.
- Cloud synchronization sends only the existing encrypted note/attachment payloads according to the current architecture.
- The original audio remains intact even if transcription fails.

### 9.2 Transcript privacy

Treat transcript text as sensitive note content.

When using the preferred canonical-note representation:

- Persist it through the existing note repository.
- Ensure cloud sync encrypts it using the current client-side note encryption mechanism.
- Do not place transcript plaintext into attachment filename columns, remote metadata fields, backend logs, analytics, or external APIs.
- Do not add a plaintext `transcript` column to a cloud database.
- Do not introduce a local unencrypted sidecar file that stores the transcript merely for search.

If using a transcript sidecar instead, encrypt the transcript client-side and bind it to the stable audio attachment/note identity through the existing cryptographic conventions. Encrypting the sidecar is mandatory; cloud storage must not be able to read its plaintext.

### 9.3 Temporary audio and converted files

Use the existing app-private temporary storage and cleanup mechanisms.

Requirements:

- Use collision-resistant temporary paths.
- Never write plaintext audio into the normal encrypted attachment vault.
- Remove plaintext/converted temporary files after the recognition engine has finished with them.
- Do not delete the temporary input while native recognition still depends on it.
- On failure, preserve the original encrypted attachment and clean up disposable files safely.
- On cancellation, stop further work where possible and clean up when the engine releases the file.
- Clean orphaned temporary files after process death or application restart.
- Handle decryption failure without generating a new encryption key or overwriting ciphertext.

### 9.4 Locked and password-protected notes

Do not transcribe when the required encryption key is unavailable.

Use the actual key manager's lock-state semantics.

For individually password-protected notes, follow the current unlock contract. Do not bypass note-level security merely because the app's general master key is unlocked.

Never decrypt an encrypted note envelope as though it were ordinary Markdown.

Search, edit, and regenerate behavior must respect the same security rules.

---

## 10. Transcript search integration

Once a transcript is persisted, it should become searchable through Quiet Paper's existing local global search.

Do not introduce a remote search API.

Inspect the existing two-tier search architecture before making changes.

### 10.1 Expected behavior

When a user searches for words spoken only in a recording:

- The parent note should appear in search results.
- The matched transcript text should provide a useful context snippet.
- The result should indicate that the match came from an audio transcript, where practical.
- Existing title, tags, ordinary Markdown content, document OCR, and image OCR results must continue to work.
- Multiple recordings in a single note must remain correctly associated with the same parent note.
- Searching by a transcript-only phrase must not require opening or manually transcribing the note again if the transcript is already persisted.

Do not add fabricated OCR or document metadata to represent an audio transcript.

### 10.2 Reuse existing indexing and ranking

Quiet Paper already has an FTS5 candidate-retrieval stage and a background-isolate fuzzy-ranking stage. Reuse these mechanisms.

If the canonical Markdown representation contains the transcript text, update the current search projection/Markdown mapping so:

- Transcript prose is searchable.
- Internal audio metadata, encoded markers, and UUIDs are not presented as content.
- Highlight spans and snippets map to the correct displayed transcript text.
- Audio card metadata does not drown out meaningful spoken words in search ranking.
- Search stays responsive and does not force audio decoding or Whisper inference at query time.

Do not transcribe recordings on demand just because a search query is entered.

### 10.3 Privacy-aware search

Respect the existing policies for:

- Password-protected notes.
- Trashed and deleted notes.
- Locked-vault state.
- Local-only records and encryption availability.
- In-memory decrypted caches, if any are used.

If the transcript exists only within an encrypted sidecar, query or decrypt it through the existing local search service in a bounded manner. Do not materialize decrypted transcript text into an inappropriate persistent plaintext FTS index.

Prefer in-memory decrypted search data while the relevant encryption state is available, following current OCR-search privacy patterns where appropriate.

Ensure cache invalidation when a transcript is edited, replaced, removed, or its parent note is deleted or locked.

---

## 11. Backup, export, synchronization, and public sharing

### 11.1 Local backups

Transcripts must survive existing `.qpbackup` creation and restore.

If the transcript lives in canonical note Markdown:

- Verify that the backup includes the transcript through the normal note content path.
- Verify that audio attachments remain included and correctly referenced.
- Preserve transcript-to-recording associations after restore.

If a separate encrypted sidecar is required:

- Extend backup serialization to preserve the encrypted transcript record.
- Restore it without losing the audio association.
- Support older backups without transcript data.
- Ensure restore works offline.

Do not store duplicate transcript copies in different backup fields without a clear need.

### 11.2 Encrypted synchronization

If the transcript is canonical note content, use the existing note encryption and synchronization pipeline.

If a separate sidecar is used, extend synchronization to push/pull the transcript's encrypted payload with consistent ownership, revision handling, deletion behavior, and retry semantics.

Verify that a second device can:

1. Pull the note.
2. Pull the audio attachment.
3. Display the transcript without rerunning recognition.
4. Edit and save the transcript.
5. Sync edits without corrupting or overwriting the original audio.

Do not cause duplicate audio uploads when only the transcript changes.

Avoid unnecessary backend migrations if the existing note-sync mechanism already handles the transcript correctly.

### 11.3 Export

Verify that `.qpnote`, Markdown, and the existing attachment export flow preserve transcripts correctly.

- A Markdown export should include human-readable transcript text in the appropriate representation.
- Audio should be exported as a proper attachment file where the format supports attachments.
- Relative resource references must resolve correctly.
- Internal IDs or hidden transport syntax must not appear as accidental transcript prose.
- Filename sanitization and collision handling must remain intact.

Do not silently drop associated transcript text from exported content.

### 11.4 Public sharing

This is a critical privacy requirement.

Quiet Paper's existing public sharing may rewrite internal attachment references and upload attachment content for public access.

The default public-share policy must **exclude both private audio recordings and their associated transcripts** unless the user explicitly opts in.

When audio is excluded:

- Do not leak the transcript as ordinary public note text merely because it is stored in the canonical audio block.
- Remove or replace the whole audio/transcript composite with a clear omission indicator.
- Do not leave a broken `qp://asset/<UUID>` reference in the public note.
- Preserve unrelated written content.

When the user explicitly chooses to include audio/transcripts, show a clear explanation that the selected content will be uploaded in a form accessible under the public link's sharing permissions. Use the existing share warning and consent flow where possible.

Never publish audio or transcript content silently.

Add regression tests for both the default exclusion behavior and explicit inclusion flow.

---

## 12. Progress, cancellation, and failure handling

### 12.1 UI states

Show useful progress states when the engine supports them:

- Checking model.
- Preparing audio.
- Transcribing on device.
- Saving transcript.
- Completed.
- Cancelled.
- Failed.

Do not display misleading progress percentages. If the engine supports reliable chunk-level progress, use it. Otherwise, provide an indeterminate indicator with a clear status label.

The rest of the note should remain usable as permitted by the existing editor architecture.

Avoid unnecessarily disabling unrelated note editing during transcription.

### 12.2 Cancellation

Cancellation must:

- Stop future transcription chunks where practical.
- Prevent results from a stale request being saved accidentally.
- Release engine/session resources when safe.
- Clean up temporary converted/decrypted files after the engine releases them.
- Preserve the original recording.
- Preserve the previous successful transcript.
- Avoid leaving a permanent `transcribing` state.

If the native engine cannot be interrupted safely mid-inference, implement cancellation at the task boundary and explicitly discard the eventual result if the user cancelled.

### 12.3 Error messages

Provide clear actionable errors for:

- No usable speech model installed.
- Model initialization failure.
- Audio attachment unavailable.
- Vault locked.
- Audio decryption or integrity failure.
- Unsupported or invalid audio format.
- Empty recording/no recognizable speech.
- Audio conversion failure.
- Recognition engine failure.
- Recording too long for the supported policy.
- Low disk space or temporary storage failure.
- Transcript persistence failure.
- Sync failure.
- Cancellation.

Keep raw stack traces, native-library messages, temporary paths, audio contents, and transcripts out of the UI and logs.

Use structured internal exceptions and concise user-facing messages.

A failed transcription must never look like a successful empty transcript.

---

## 13. Testing requirements

Implement tests using existing fake services, model manager fakes, attachment services, clock abstractions, and Riverpod provider overrides.

Do not require a physical microphone, real Whisper inference, network access, or an actual audio file download in ordinary unit/widget tests.

### 13.1 File-transcription service tests

Test:

- Transcribing an existing local audio file.
- Correct format preparation.
- Recognition result mapping.
- Supported and unsupported audio inputs.
- Empty/no-speech results.
- Missing model handling.
- Model initialization errors.
- Failure cleanup.
- Cancellation and stale-result rejection.
- Chunk processing and ordering for long recordings.
- Deduplication of overlapping chunk output when chunking is implemented.
- Stable service lifetime across provider notifications.
- No network transcription calls.

### 13.2 Transcript lifecycle tests

Test:

- `notTranscribed → transcribing → available`.
- `available → edited`.
- Regeneration failure preserves the existing transcript.
- Cancellation preserves the existing transcript.
- Edited transcript regeneration requires explicit replacement.
- Concurrent duplicate jobs are prevented.
- Repeated requests do not create duplicate transcript records.
- Retry after failure works.
- Interrupted jobs reset safely after simulated restart.
- Transient job states are not persisted as permanent document content.
- Editing a transcript does not alter audio bytes, ID, or timestamp.
- One recording's transcript cannot overwrite another's.

### 13.3 Audio card widget tests

Test:

- Transcribe action when no transcript exists.
- Existing transcript expansion/collapse.
- Processing progress and cancellation.
- Editable transcript interface.
- Manual edit indicator.
- Copy transcript.
- Insert transcript into note.
- Regenerate action.
- Replacement confirmation.
- Failure and retry states.
- Locked-note behavior.
- Missing attachment behavior.
- Loading and empty states.
- Light/dark themes.
- Accessibility labels and disabled states.
- Responsive layouts on narrow screens.

### 13.4 Serialization tests

This is mandatory.

Test deterministic round trips for:

- Audio blocks with no transcript.
- Audio blocks with a generated transcript.
- Audio blocks with a manually edited transcript.
- Multiple audio blocks in one note.
- Transcript content containing quotes, brackets, URLs, Markdown, and newlines.
- Unicode and non-English text.
- Empty transcripts.
- Transcript regeneration without changing the attachment ID.
- Switching Super Editor → Markdown → Super Editor.
- Switching Super Editor → Visual → Super Editor.
- Adjacent audio blocks.
- Audio blocks adjacent to ordinary text, images, and file attachments.
- Older documents without transcript metadata.
- Missing attachment metadata and graceful fallbacks.

Assert that IDs, text, timestamps, and metadata survive intact.

Do not accept a test that only asserts that the audio card exists visually while ignoring data loss across serializer/deserializer round trips.

### 13.5 Search tests

Test:

- Searching text that exists only in the associated transcript.
- Correct parent note attribution.
- Useful transcript context snippets.
- Audio transcript result classification, if included.
- Highlight mapping to the displayed transcript.
- Multiple audio transcripts in one note.
- Editing a transcript immediately updates local search results.
- Regeneration updates search results.
- Removing a transcript removes its contribution to search.
- No internal audio metadata appears in snippets.
- Password-protected and trashed note exclusion.
- No plaintext transcript is written to an inappropriate persistent search store.
- Existing OCR and ordinary note search remain correct.

### 13.6 Security, backup, synchronization, and sharing tests

Test:

- Original audio ciphertext is unchanged after transcription.
- Decrypted temporary audio is cleaned safely.
- Transcript plaintext is not sent over network calls.
- Transcript content is encrypted through existing note sync or an explicitly encrypted sidecar path.
- Backup and restore preserve transcript content and audio association.
- A second device can display a synced transcript without rerunning Whisper.
- Editing transcript content does not unnecessarily re-upload unchanged audio.
- Offline transcription works for available local audio and an installed model.
- Default public shares exclude both audio and its associated transcript.
- Explicit sharing requires consent and includes only the selected content.
- Failed transcription preserves the last valid transcript and original audio.

### 13.7 Existing regression suite

Keep current speech recognition, Audio Journal, generic attachment, Markdown, Super Editor, note editing, encryption, search, backup, synchronization, and sharing tests intact.

Do not delete or weaken old tests to make the new feature pass.

---

## 14. Performance and engineering constraints

- Never run expensive Whisper inference or audio conversion synchronously on the UI isolate.
- Reuse existing model residency and memory management.
- Do not repeatedly initialize Whisper for each card rebuild.
- Avoid materializing unbounded decoded audio or transcript data in memory.
- Avoid repeatedly decrypting the same attachment during progress updates.
- Use bounded chunks for long recordings where required.
- Do not calculate waveform data or decode the audio just to render transcript text.
- Avoid rebuilding the entire Super Editor document for every progress update.
- Keep transcription progress separate from persistent note state.
- Keep local search responsive and independent of Whisper inference.
- Use bounded or cancellable tasks and explicit cleanup ownership.
- Do not introduce additional audio/transcription dependencies unless the current stack demonstrably cannot perform the required task.
- Preserve all existing encryption, locking, and sync invariants.

Follow the repository's current Dart formatting, Riverpod, Drift, error-handling, and testing conventions.

---

## 15. Suggested implementation components

Adapt these suggestions to the actual repository; do not create duplicate abstractions if equivalent ones already exist.

### Recognition and application layer

- A reusable file-transcription operation on the existing speech recognition engine.
- A transcript result model.
- A transcription request/job model.
- A dedicated transcript orchestration service.
- A Riverpod provider/controller with explicit service lifetime.
- Progress and cancellation reporting.
- A safe temporary-audio preparation service if needed.

### Document and presentation layer

- An extension to the existing audio attachment block/node model to carry the transcript and edit state.
- A transcript section inside the existing audio card.
- An editor component for modifying the associated transcript.
- Actions for copying, inserting, and regenerating transcript text.
- Shared duration/language/status formatting where appropriate.

### Persistence and search

- Extend the canonical Markdown serializer/deserializer if the audio node is the preferred representation.
- Update search projection and Markdown offset mapping to index spoken text without leaking internal metadata.
- Extend backup/export/sync handling only where the selected persistence model requires it.
- Extend public sharing filters to treat audio plus its associated transcript as one privacy-sensitive unit.

---

## 16. Implementation phases

Execute the work in this order.

### Phase 1 — Audit existing architecture

Inspect the actual audio journaling, Whisper, document serialization, search, encryption, backup, sync, and sharing implementations.

Determine how the existing recognition engine accepts files and returns results.

Identify which transcript representation best fits the existing audio-node and Markdown model.

Do not ask the user to resolve ordinary implementation questions. Make the most compatible decision based on repository evidence.

### Phase 2 — Reusable file transcription

Expose or reuse the existing local Whisper API for an existing recording.

Implement audio preparation, model availability checks, progress, cancellation, temporary-file cleanup, and long-recording safety where required.

Test this service before integrating complex UI.

### Phase 3 — Transcript persistence

Implement a stable, versioned representation for a transcript associated with a specific audio attachment.

Preserve manual edits and protect existing transcript content during regeneration.

Verify round-trip behavior through Super Editor, Visual, and Markdown modes before proceeding.

### Phase 4 — Audio card UI

Integrate Transcribe, Edit, Copy, Insert, and Regenerate actions into the current audio card.

Implement transcript expansion/collapse and useful processing/failure states.

Keep recording and playback behavior unchanged.

### Phase 5 — Search

Integrate persisted transcripts into existing local search.

Preserve FTS5 candidate retrieval, background-isolate ranking, snippet/highlight mapping, locked-note handling, and existing OCR results.

### Phase 6 — Persistence and security integration

Verify note synchronization, attachment synchronization, backup/restore, export, attachment deletion, and public sharing.

Avoid schema/backend changes unless a verified technical requirement exists.

### Phase 7 — Verification and polish

Run focused tests, regression tests, static analysis, and the full test suite.

Fix implementation regressions and inspect the complete final diff.

Update the engineering handoff document according to current project conventions if that document is maintained in the working repository.

Do not claim completion while any known feature-related test failures remain.

---

## 17. Definition of done

The transcription feature is complete only when the relevant requirements below are satisfied.

### Recognition

- [ ] Existing saved audio can be transcribed with the current on-device Whisper infrastructure.
- [ ] No cloud speech recognition is introduced.
- [ ] Model management is reused.
- [ ] Audio format preparation is correct.
- [ ] Long recordings are handled safely or rejected with clear supported limits.
- [ ] Cancellation and errors release resources safely.
- [ ] Existing dictation behavior remains intact.

### Audio card experience

- [ ] Each audio card has Transcribe, View/Edit, Copy, Insert, and Regenerate actions as appropriate.
- [ ] Transcripts can be expanded and collapsed.
- [ ] Transcript text can be edited.
- [ ] Manually edited transcripts are not overwritten silently.
- [ ] Transcription failure preserves the previous transcript and audio.
- [ ] Copy produces clean text.
- [ ] Insert produces an independent ordinary-text copy.
- [ ] Multiple audio recordings have independent transcripts.

### Persistence and serialization

- [ ] Transcripts survive saving and reopening the note.
- [ ] They survive Super Editor, Visual, and Markdown mode switches.
- [ ] Round-trip serialization preserves transcript text, attachment IDs, timestamps, and edit state.
- [ ] No raw metadata blobs or temporary paths leak into normal presentation.
- [ ] Existing notes and non-audio attachments remain compatible.

### Search

- [ ] Words found only in transcripts can locate the correct parent note.
- [ ] Snippets and highlight spans display the correct text.
- [ ] Edits, regeneration, and removal update search correctly.
- [ ] Password-protected and trashed notes respect the existing search security model.
- [ ] Search does not invoke Whisper or network services.

### Privacy and durability

- [ ] Audio remains encrypted and unchanged by transcription.
- [ ] Temporary decrypted files are removed safely.
- [ ] Transcripts use the existing encrypted note-sync path or a fully encrypted alternative.
- [ ] Backup and restore preserve the transcript/audio association.
- [ ] A second device can display synchronized transcripts without rerunning transcription.
- [ ] Public sharing excludes audio and associated transcript text by default.
- [ ] Explicit inclusion requires clear consent.

### Engineering quality

- [ ] Unit, widget, serialization, search, security, and integration tests pass.
- [ ] Existing regression tests remain intact and pass.
- [ ] `flutter analyze` introduces no new issues.
- [ ] The full Flutter test suite passes.
- [ ] Backend tests pass if backend code was changed.
- [ ] Final changes contain no unrelated edits or accidental dependency churn.
- [ ] Remaining platform-specific limitations are documented honestly.

---

## 18. Required final implementation report

After completing the implementation, report:

1. **Features implemented:** Transcription, transcript editing, copying, insertion, regeneration, and search.
2. **Recognition integration:** Which existing Whisper engine/model interfaces were reused and how existing dictation remains compatible.
3. **Transcript persistence:** The canonical representation, serializer changes, edit-state tracking, and why the representation is safe across editor modes.
4. **Changed files:** New and modified source files, tests, migrations, generated code, dependencies, and backend changes if any.
5. **Privacy/security:** Temporary audio lifecycle, on-device processing, encrypted persistence, synchronization, and public-sharing policy.
6. **Search integration:** How transcript text participates in the current local search index and how sensitive notes are excluded.
7. **Verification:** Actual commands run and real pass/fail counts.
8. **Known limitations:** Untested devices, unsupported formats/languages, long-recording constraints, or deferred enhancements.

Do not claim real-device, background, or cross-platform behavior was verified unless it was actually tested.

## Final directive

Implement this transcription feature as a direct extension of Quiet Paper's existing Audio Journal, not as a replacement for it.

Reuse the existing Whisper model and recognition engine. Keep transcription local, the original recording immutable, transcripts editable, manual changes safe, search local, note serialization reversible, and public sharing opt-in.

The finished result should make a recording feel like a living journal entry: **the original voice is preserved, the transcript is readable and editable, and the user can move naturally between listening, reading, and writing without leaving Quiet Paper.**
