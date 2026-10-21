# Quiet Paper — Production Implementation Prompt
## Fully Offline On-Device Speech-to-Text Using the FUTO English Voice Model

You are working inside the existing **Quiet Paper Flutter application**.

Read the complete current engineering handoff and inspect the existing codebase before making changes. Treat the existing architecture as the source of truth.

Implement a **fully functional, production-ready, offline speech-to-text feature** integrated into the existing editor.

The feature must use the following model as its only currently supported speech model:

```text
https://dl.keyboard.futo.org/voice-input-english-39.bin
```

The model license has already been reviewed and approved for use in Quiet Paper.

Do not add support for any other speech model at this time.

The implementation must be real and functional. Do not create mock transcription, placeholder inference code, fake progress, fake model installation state, or UI-only functionality.

---

# 1. Product Objective

Add offline speech-to-text to Quiet Paper so the user can dictate text directly into the note editor.

The intended user experience is:

```text
User taps microphone
        ↓
Microphone permission if necessary
        ↓
Check speech model
        ↓
If missing:
    Download model
        ↓
Model verified and installed
        ↓
Start recording
        ↓
User speaks
        ↓
User taps stop
        ↓
Local on-device transcription
        ↓
Transcript inserted at current editor position
        ↓
Normal editor/autosave pipeline continues
        ↓
Temporary audio is discarded
```

After the model is installed:

**No network connection is required for transcription.**

Audio must never be sent to:

- Vercel
- Turso
- Cloudinary
- Firebase
- a third-party speech API
- any remote transcription service

The transcription pipeline must operate entirely on the user's device.

---

# 2. Core Privacy Requirement

Quiet Paper is an offline-first, zero-knowledge notes application.

The existing architecture explicitly keeps note contents local and encrypts them before synchronization. Do not weaken that architecture.

Speech recognition must follow the same philosophy.

The intended data flow is:

```text
Microphone
    ↓
Temporary local audio buffer
    ↓
Local speech recognition runtime
    ↓
Transcript text
    ↓
Existing Markdown editor
    ↓
Canonical Markdown
    ↓
Normal local persistence/encryption/sync
```

The audio recording is temporary and must be deleted after transcription unless an explicit future recording-storage feature is implemented.

Do not save voice recordings as note attachments.

Do not upload recordings anywhere.

Do not add cloud transcription.

Do not add analytics containing speech content.

Do not log transcripts or recorded audio.

Do not print raw audio/model input into debug logs in release builds.

---

# 3. Existing Architecture Must Remain Intact

The current application is:

- Flutter
- Riverpod
- Drift SQLite
- offline-first
- Markdown as canonical note content
- client-side encryption
- zero-knowledge cloud sync
- Bear-inspired editorial UI

The editor already has:

- Markdown as the single canonical source
- `MarkdownEditingController`
- Markdown parser/tokenizer
- formatting utilities
- keyboard shortcuts
- selection-aware formatting toolbar
- interactive checklists
- code blocks
- tables
- note links
- images/attachments
- autosave
- undo/redo
- WYSIWYG/Markdown editing architecture

Do not rewrite unrelated editor functionality.

Do not change the note schema for speech recognition.

Do not store speech-model state in the notes table.

Do not create a second note-content representation.

---

# 4. Speech Recognition Architecture

Create a dedicated speech subsystem rather than embedding speech logic directly into `EditorScreen`.

Use clear separation between:

### Model management

Responsible for:

- model availability
- download
- storage
- verification
- installation
- deletion
- versioning
- disk-space checks
- integrity checks

### Audio capture

Responsible for:

- microphone permission
- recording
- audio format
- buffering
- stopping
- interruption handling
- temporary-file lifecycle

### Inference engine

Responsible for:

- loading the model
- initializing native inference
- feeding audio
- performing transcription
- returning transcript results
- releasing native resources

### Editor integration

Responsible for:

- opening speech UI
- preserving insertion position
- inserting transcript
- undo/redo
- autosave
- WYSIWYG/Markdown compatibility

Use platform-native code through Flutter platform channels / FFI / an appropriate native integration mechanism where required.

---

# 5. Important Model/Runtime Requirement

The provided URL is the model:

```text
https://dl.keyboard.futo.org/voice-input-english-39.bin
```

Do not assume that Flutter/Dart can execute this binary directly.

Before implementing inference:

1. Determine the model format.
2. Determine the compatible FUTO speech-recognition inference runtime.
3. Inspect the model metadata/header when necessary.
4. Use the actual compatible runtime/native implementation.
5. Integrate that runtime into the Android application properly.
6. Ensure ARM64 operation is fully supported.
7. Ensure the application can actually perform real transcription from microphone audio.

If the compatible FUTO runtime is available as source code, library, native binary, FFI interface, or another officially usable mechanism, integrate it properly.

Do not substitute a completely unrelated ASR engine merely because it can download a `.bin`.

Do not invent an API.

Do not implement a fake `transcribe()` function returning test text.

The finished application must actually transcribe spoken English using the supplied model.

If native integration is required, implement all required:

- Kotlin/Java code
- C/C++/NDK code
- FFI bindings
- JNI bridges
- Gradle configuration
- CMake configuration
- Flutter bindings

necessary for a complete working implementation.

Do not leave this subsystem behind an unimplemented interface.

---

# 6. Future-Proof the Architecture Without Adding More Models

Only this model should be shipped/supported now:

```text
FUTO English Voice Input 39
```

However, do not hard-code the editor UI to a specific implementation.

Use a model abstraction such as:

```dart
abstract class SpeechModelDescriptor {
  String get id;
  String get name;
  String get language;
  int get sizeBytes;
  String get version;
}
```

and:

```dart
abstract class SpeechRecognitionEngine {
  Future<void> initialize(...);
  Future<void> dispose();
  Future<String> transcribe(...);
}
```

Only one concrete implementation is required now.

Do not expose a multi-model picker to the user yet.

The architecture should make adding another model later straightforward without requiring an editor rewrite.

---

# 7. Model Identity

Create a stable model ID, for example:

```text
futo_voice_input_english_39
```

Do not identify the installed model solely by filename.

Record/derive:

- model ID
- model version
- filename
- file size
- SHA-256 checksum
- download URL
- installation status

Do not use mutable URLs without tracking model version.

The exact expected file size and SHA-256 must be determined from the actual model download during implementation.

Do not leave fake values such as:

```text
SHA256_HERE
SIZE_HERE
```

in the finished implementation.

---

# 8. Model Download

The model must be downloaded on demand.

Do not bundle the `.bin` model inside the APK.

The normal APK installation must not include the full speech model.

The first use flow is:

```text
User taps microphone
        ↓
No model installed
        ↓
Show download prompt
        ↓
User explicitly chooses Download
        ↓
Download model
        ↓
Verify integrity
        ↓
Atomically install
        ↓
Ready
        ↓
Begin recording
```

Do not automatically consume a large amount of storage without user consent.

---

# 9. Download UX

Use Quiet Paper's existing warm editorial design.

Do not use a generic noisy Material download dialog.

Example:

```text
Offline Speech Recognition

Quiet Paper can transcribe your voice
entirely on this device.

Download the English speech model once.
Afterward, transcription works offline.

English Voice Model
~XXX MB

[ Download ]
```

The real size must be displayed from verified model metadata.

During download:

```text
Downloading Speech Model

████████████████░░░░  82%

XXX MB of XXX MB

You only need to download this once.
```

Show:

- progress percentage
- downloaded bytes
- total bytes where known
- cancel action

Do not show fake indeterminate progress when actual byte progress is available.

---

# 10. Download Robustness

Implement production-grade download handling.

Requirements:

- streamed download
- bounded memory usage
- write to temporary file
- support cancellation
- handle app interruption
- handle network loss
- safely recover from interrupted download
- verify final checksum
- atomically rename into installed-model location
- never mark a partial file as installed
- safely replace an older model only after the new model is verified
- clean up invalid partial downloads

Use a temporary filename such as:

```text
voice-input-english-39.bin.part
```

and only rename to the final installed path after verification.

Do not load the entire model download into RAM.

---

# 11. Storage Location

Store the model in the application's persistent local data directory.

Do not store it inside the database.

Do not store it inside note content.

Do not store it in the temporary cache directory if the OS may purge it.

Use an application-private model directory, conceptually:

```text
<app data>/models/speech/
```

Example:

```text
models/
  speech/
    futo_voice_input_english_39/
      voice-input-english-39.bin
      metadata.json
```

Use the project's platform-appropriate application documents/support directory.

Do not ask the user for general filesystem permission simply to store this model.

---

# 12. Model Verification

After download:

```text
download
  ↓
close file
  ↓
calculate SHA-256
  ↓
compare with expected checksum
  ↓
if valid:
    install atomically
else:
    delete invalid file
    show integrity failure
```

Do not initialize the inference engine with an unverified model.

If verification fails:

```text
Speech model verification failed.

The downloaded model appears to be
incomplete or corrupted.

Please try again.
```

Do not silently continue.

---

# 13. Model Deletion

Provide a Settings option:

```text
Settings
  → Editor
      → Speech Recognition
```

with:

```text
English Voice Model
Installed
XXX MB

Delete Model
```

Deleting the model:

- must never delete notes
- must never affect note content
- must never affect attachments
- must never affect encryption keys
- must never affect sync data

If the model is currently loaded, gracefully release it before deletion.

Require appropriate confirmation for deletion because the model may be large.

After deletion:

```text
Not installed
```

The next microphone use returns to the download flow.

---

# 14. Disk Space Handling

Before downloading:

- determine available storage where the platform allows it
- compare against required model size
- account for temporary download space
- account for installed model space

A failed download because of insufficient storage must produce a clear user-facing explanation.

Do not crash.

Do not leave corrupted model files.

---

# 15. Microphone Button

Add a microphone/audio icon to the existing editor interaction surface.

Use the existing Quiet Paper icon-button conventions.

Do not redesign the entire editor toolbar.

The microphone should be visually secondary to writing.

It should feel like another input method, not an AI feature.

Do not label it "AI".

Use terminology such as:

```text
Speech to Text
```

or:

```text
Dictation
```

Use an accessible tooltip/content description such as:

```text
Dictate
```

---

# 16. Microphone Button Placement

The microphone action should live alongside the editor's existing bottom formatting controls.

Normal state:

```text
B   I   S   Code   Link   ...          🎙
```

Use the existing toolbar's spacing, icon sizes, hit areas, theme tokens, and responsive behavior.

Do not create a second toolbar.

Do not cause horizontal overflow on small phones.

Ensure the microphone remains comfortably touchable.

---

# 17. Recording Flow

When the user taps the microphone:

### Step 1

Check microphone permission.

If permission has not been requested, request it at this point only.

Do not request microphone access during app startup.

### Step 2

Check model.

If model is missing:

show the download prompt.

### Step 3

Load/initialize the local speech model.

### Step 4

Begin microphone recording.

---

# 18. Keyboard Behavior During Recording

When recording begins:

**dismiss the software keyboard.**

Do not leave the keyboard visible while the user is speaking.

However, keep the editor/document visible.

Do not navigate to a separate full-screen recording page.

The user should still be able to see the note and understand where the transcript will be inserted.

Example:

```text
┌──────────────────────────────────────┐
│ My Note                         ⋯    │
│                                      │
│ I need to finish the editor |       │
│                                      │
│                                      │
│                                      │
│              ● Listening             │
│                00:08                 │
│                                      │
│          Tap to stop recording       │
│                                      │
└──────────────────────────────────────┘
```

Do not make the recording UI visually dominant.

---

# 19. Preserve the Insertion Position

This is critical.

When recording starts, capture the logical editor insertion location/selection.

The user may be in:

- WYSIWYG mode
- Markdown mode

The speech system must not alter the document before transcription is complete.

The insertion position must remain associated with the intended source location.

For example:

```text
This is a sentence|
```

Start recording.

After transcription:

```text
This is a sentence and this is the dictated text.
```

The transcript must be inserted at the captured location.

Do not blindly append transcripts to the end of the document.

---

# 20. Selection Behavior

If text is selected when the user begins dictation, use a predictable replacement rule.

Recommended behavior:

**The selected range is replaced by the transcript.**

Example:

```text
This is [the old text] here.
```

User taps dictate and says:

> the new text

Result:

```text
This is the new text here.
```

Capture the source selection before dismissing the keyboard or starting audio.

Do not lose the selection merely because focus/keyboard state changes.

---

# 21. WYSIWYG Mode Compatibility

Speech input must be editor-architecture agnostic.

The speech subsystem returns plain transcript text.

It must not know how Markdown is rendered.

For WYSIWYG mode:

```text
Speech engine
      ↓
plain transcript
      ↓
source-aware insertion layer
      ↓
canonical Markdown
      ↓
WYSIWYG projection updates
```

The user must never see raw Markdown inserted merely because speech occurred.

---

# 22. Markdown Mode Compatibility

In Markdown mode the same transcript must be inserted into the canonical Markdown editor.

The existing Markdown editing behavior remains active.

Do not create a separate speech-specific Markdown editor.

Speech insertion must use the same underlying text mutation pipeline used by normal typing/paste wherever practical.

---

# 23. Formatting Boundary Compatibility

If the insertion point is inside formatted Markdown, use the existing source-aware editor insertion behavior.

For example:

```markdown
**Hello |world**
```

and the user dictates:

```text
beautiful
```

the source mutation must preserve the appropriate Markdown structure.

Do not flatten surrounding formatting.

Do not generate invalid Markdown.

The speech subsystem itself must remain unaware of these semantics; the editor source-mutation layer handles them.

---

# 24. Transcript Insertion

After successful transcription:

1. obtain transcript text
2. normalize only what is explicitly necessary
3. insert it at the captured source selection
4. update the editor controller
5. restore the new caret position
6. invoke the existing change/autosave pipeline
7. allow normal undo/redo to treat the insertion as an edit

Do not bypass `MarkdownEditingController`.

Do not directly mutate the database from the speech layer.

Do not create a second autosave path.

---

# 25. Transcript Normalization

Do not aggressively alter recognition output.

Preserve the speech engine's punctuation/capitalization.

Only apply minimal normalization necessary for natural editor insertion, such as context-aware whitespace.

Avoid producing:

```text
sentence..Next
```

or:

```text
sentenceNext
```

when natural insertion requires a separator.

Be careful around:

- beginning of paragraph
- end of paragraph
- existing spaces
- newlines
- Markdown syntax boundaries

Do not automatically add a period unless the model itself provides one.

Do not rewrite the transcript through an AI service.

---

# 26. Recording UI

During recording, replace the normal bottom formatting toolbar with a minimal recording control.

Recommended appearance:

```text
──────────────────────────────────────

             ● Listening
               00:08

          Tap to stop recording

──────────────────────────────────────
```

The recording indicator should have a subtle pulse/breathe animation.

Do not use a giant waveform.

Do not use flashy equalizer animations.

Do not create visual noise.

Quiet Paper should remain calm and editorial.

---

# 27. Recording Timer

Show recording duration.

Format naturally:

```text
00:04
00:18
01:07
```

Do not allow a runaway recording session.

Implement a sensible maximum recording duration appropriate to device memory/processing constraints.

Make the constant configurable internally.

When the maximum is reached:

- stop recording
- transcribe automatically
- show the transcription state

Do not silently discard the recording.

---

# 28. Stop Recording

When the user taps the recording control:

```text
Listening
    ↓
stop audio capture
    ↓
release microphone
    ↓
begin transcription
```

Do not wait for network access.

Do not ask for another confirmation.

---

# 29. Transcription UI

After recording stops, keep the keyboard hidden.

Do not immediately restore the keyboard.

Show:

```text
──────────────────────────────────────

            Transcribing…

             ███████████░░

──────────────────────────────────────
```

The document remains visible.

The user should understand that the transcript is being generated locally.

You may use wording such as:

```text
Transcribing on device…
```

but keep it subtle.

Do not make the user think network communication is happening.

---

# 30. Keyboard Restoration

After transcription completes:

- insert the transcript
- restore normal editor presentation
- restore the caret after the inserted text
- do not automatically reopen the software keyboard

The keyboard should remain hidden.

If the user taps the editor, normal keyboard focus returns.

This avoids a distracting layout jump.

---

# 31. Model Loading

Do not initialize the speech model from scratch for every microphone press if doing so causes unnecessary latency.

Maintain a managed loaded-engine state while appropriate.

The model manager should be able to:

```text
notLoaded
loading
ready
transcribing
disposed
error
```

Release resources when appropriate, especially when:

- the editor is disposed
- the app backgrounds for a meaningful period
- the user logs out
- memory pressure requires it

Do not keep excessive native resources alive indefinitely.

---

# 32. App Lifecycle

Handle:

- app backgrounding
- app termination
- incoming phone calls
- another application acquiring microphone
- Bluetooth audio route changes where relevant
- microphone interruptions
- permission revocation
- screen lock
- navigation away from the editor

If recording is interrupted:

- stop safely
- release microphone
- preserve already-recorded audio where practical
- either resume safely or move to transcription
- never leave the microphone active accidentally
- never leak native resources

If the recording cannot be recovered, tell the user clearly.

---

# 33. Permission Handling

Request microphone permission only when needed.

If denied:

```text
Microphone access is disabled.

Enable microphone access in
Quiet Paper's system settings.
```

Provide the platform-appropriate route to application settings when available.

If permanently denied:

- do not repeatedly prompt
- do not crash
- do not block ordinary note editing

Speech recognition must remain optional.

---

# 34. Temporary Audio Files

Prefer in-memory buffering when practical and safe.

If the native inference implementation requires a temporary audio file:

- create it in the app-private temporary directory
- never expose it publicly
- never upload it
- give it a unique filename
- delete it after transcription
- delete it after any error
- delete it when recording is cancelled
- clean orphaned temporary files on next startup

Do not add temporary audio to the note attachment system.

---

# 35. No Audio History

Do not create:

- recording history
- voice-note library
- automatic audio attachments
- speech recordings in backups
- audio sync
- audio Cloudinary uploads

The output of this feature is text.

The default lifecycle is:

```text
audio
  ↓
transcript
  ↓
audio deleted
```

---

# 36. Undo/Redo

Speech insertion must behave like one normal editing operation.

Example:

```text
Before:
Hello|

Dictate:
world

After:
Hello world|
```

Ctrl/Cmd+Z or normal Undo should remove the dictated insertion as a coherent edit.

Do not create dozens of undo steps for individual recognized tokens.

Do not bypass the editor's existing undo stack.

---

# 37. Autosave

After transcript insertion:

- use the existing editor change notification
- use existing autosave debounce
- do not add a second save mechanism

The existing application already uses automatic saving and flushes on lifecycle/focus changes.

Speech transcription must integrate naturally with this behavior.

---

# 38. Sync and Encryption

No new backend functionality is required.

After transcript insertion, the resulting canonical Markdown is handled normally:

```text
Markdown
   ↓
SQLite
   ↓
client-side encryption
   ↓
sync
```

Speech recognition itself must never participate in cloud sync.

Do not add model state or transcript history to encrypted note payloads.

---

# 39. Settings Integration

Add:

```text
Settings
  → EDITOR
      → Speech Recognition
```

Use the existing iOS Grouped Table / Bear-inspired Settings UI.

Do not introduce Material cards.

The row should look native to the existing Settings screen.

---

# 40. Speech Settings Screen

Provide:

```text
Speech Recognition

Offline transcription
Transcribe speech directly on your device.

English Voice Model
Installed
XXX MB

Delete Model
```

When not installed:

```text
English Voice Model
Not downloaded

Download Model
```

Do not show model variants because only one model is currently supported.

Do not show unsupported languages.

---

# 41. Settings Copy

Use calm language.

Preferred terminology:

```text
Offline Speech Recognition
```

or:

```text
Speech to Text
```

Avoid:

```text
AI Voice Engine
AI Dictation Pro
Smart AI Speech
```

Quiet Paper should treat this as a utility, not an AI marketing feature.

---

# 42. Model Status

The Settings UI must accurately reflect actual state.

States:

```text
Not installed
Downloading
Installed
Loading
Error
```

Do not display "Installed" before:

- the file exists
- the checksum has been verified
- metadata has been committed

Do not display "Ready" when the native runtime cannot load the model.

---

# 43. Model Download Cancellation

If the user cancels:

- stop the download
- close the stream
- clean up partial data as appropriate
- retain a resumable partial file only if resumability is implemented correctly
- otherwise delete the partial file
- return to "Not installed"

Do not mark the model installed.

---

# 44. Error Handling

Implement explicit user-facing errors for:

### Network unavailable during download

```text
The speech model couldn't be downloaded.

Check your connection and try again.
```

### Download interrupted

```text
The download was interrupted.

Please try again.
```

### Integrity failure

```text
The speech model could not be verified.

Please download it again.
```

### Insufficient storage

```text
There isn't enough storage to install
the speech model.
```

### Microphone permission denied

```text
Microphone access is required for dictation.
```

### Runtime initialization failure

```text
Offline speech recognition couldn't be started.

The speech model may be unavailable
or incompatible with this device.
```

### Transcription failure

```text
The speech could not be transcribed.

Your note was not changed.
```

Do not show stack traces to users.

---

# 45. Failure Atomicity

A failed transcription must not partially mutate the note.

The sequence must be:

```text
record
  ↓
transcribe
  ↓
validate non-empty result
  ↓
insert
```

not:

```text
record
  ↓
partially insert intermediate recognition output
  ↓
transcription fails
```

For the initial implementation, use final-result insertion rather than live partial-result insertion unless the chosen runtime makes stable streaming recognition genuinely safe.

---

# 46. Empty Transcription

If the user records silence or the model returns an empty result:

- do not modify the note
- restore normal editor state
- release audio/model resources
- do not create an undo entry
- do not trigger a meaningful note save

Optionally provide a subtle message:

```text
No speech detected.
```

Do not show an error for normal silence.

---

# 47. Offline Guarantee After Installation

Once the model is installed:

The microphone → transcription workflow must work with:

```text
Wi-Fi OFF
Mobile Data OFF
```

No HTTP request should be required.

The model URL is used only for installation/download.

The transcript pipeline itself must have zero network dependency.

---

# 48. Network Architecture

Do not add speech-transcription endpoints to:

- backend/src/api
- Vercel
- Turso
- Cloudinary
- Firebase

The current backend must remain unaware of speech content.

Do not send telemetry containing speech data.

---

# 49. Model Download Network Security

The download URL is:

```text
https://dl.keyboard.futo.org/voice-input-english-39.bin
```

Use HTTPS only.

Validate:

- HTTPS
- successful HTTP status
- content length where available
- expected checksum
- final model format

Do not follow arbitrary user-supplied model URLs.

The model URL should be compiled into the supported model definition or controlled by a trusted configuration mechanism.

---

# 50. Release Packaging

Do not include the large model in the normal APK assets.

The application package should contain only the necessary speech inference runtime/native binaries.

The model is downloaded after explicit user action.

Ensure the native runtime works with the Android architectures supported by Quiet Paper.

The current project produces:

- arm64-v8a
- armeabi-v7a
- x86_64
- universal

The speech implementation must be handled consistently with the project's existing release architecture.

If a particular architecture cannot support the inference runtime, detect that explicitly and provide a clear explanation rather than crashing.

Do not silently ship a broken microphone button.

---

# 51. ARM64 Priority

ARM64 Android devices are the primary optimization target.

Ensure:

- model loading succeeds
- audio conversion succeeds
- inference succeeds
- memory use is reasonable
- transcription does not freeze Flutter UI

The UI isolate must never be blocked by expensive inference.

Run native model inference off the Flutter UI thread/isolate as appropriate.

---

# 52. Performance

Speech recognition is CPU and memory intensive.

The implementation must:

- avoid blocking the UI thread
- avoid unnecessary audio copies
- avoid repeatedly loading the model
- avoid holding duplicate copies of model memory
- release temporary buffers promptly
- prevent runaway allocations
- keep the editor responsive during inference

The editor must remain visually responsive while the speech engine transcribes.

A "Transcribing…" state must not mean the entire Flutter UI freezes.

---

# 53. Model Loading Memory

Do not load the model multiple times simultaneously.

Guard initialization:

```text
initialize()
initialize()
initialize()
```

must not create three native model instances.

Use a single managed engine instance.

Handle concurrent microphone taps safely.

---

# 54. Concurrency

Prevent invalid states such as:

```text
recording + recording
```

or:

```text
transcribing + recording
```

or:

```text
downloading + deleting model
```

The speech controller should have a clear state machine.

For example:

```dart
enum SpeechSessionState {
  idle,
  checkingModel,
  downloadingModel,
  loadingEngine,
  recording,
  transcribing,
  inserting,
  error,
}
```

UI actions must be derived from this state.

---

# 55. Double-Tap Protection

Rapidly tapping the microphone must not start multiple recordings.

While recording:

- microphone action means Stop

During transcription:

- disable starting another recording

While downloading:

- do not allow recording

While model initialization is underway:

- prevent duplicate initialization

---

# 56. Editor Focus Management

Before recording:

1. capture source selection
2. dismiss keyboard
3. begin recording

During recording:

- do not mutate the note

After transcription:

1. insert transcript
2. restore editor selection
3. keep keyboard hidden
4. restore normal toolbar

Do not cause focus to unexpectedly move into another widget.

---

# 57. WYSIWYG Source Mapping

The speech feature must work with the new WYSIWYG editor architecture.

The editor may visually hide Markdown syntax.

The speech subsystem must therefore never use visual offsets as its source-of-truth insertion location.

Capture/use the editor's canonical source selection/mapping.

The correct flow is:

```text
visual caret
    ↓
source selection mapping
    ↓
record
    ↓
transcript
    ↓
source mutation
    ↓
visual projection refresh
```

This must work even when the visible document hides:

- heading markers
- list markers
- bold delimiters
- italic delimiters
- link syntax
- code delimiters
- quote markers

---

# 58. Markdown Mode

When Markdown editing style is active:

Speech inserts text into the existing Markdown text field.

Do not create a visually different insertion pipeline.

All current Markdown parser behavior must remain intact.

---

# 59. Read-Only Mode

If the note is read-only:

- microphone should be disabled or hidden according to existing editor action conventions
- recording must never mutate the document
- do not request microphone permission merely because a read-only note was opened

Prefer disabling the dictate action.

---

# 60. Password-Protected Notes

For unlocked password-protected notes:

speech works normally.

For locked notes:

- speech action must be unavailable
- do not request microphone permission
- do not load the speech model

Respect the existing note-security state.

---

# 61. Unsaved New Drafts

Speech insertion into a new draft must work.

Example:

```text
Empty note
↓
tap microphone
↓
"Shopping list for tomorrow"
↓
transcript inserted
↓
existing auto-title behavior
↓
normal autosave
```

Do not require the note to already exist in the database.

The existing empty-draft lifecycle must remain intact.

---

# 62. Auto-Titling

Speech-generated text is normal editor content.

If the note uses automatic title generation from the first line, speech insertion must participate naturally.

Do not create a separate speech-generated title.

Do not add metadata saying the title came from speech.

---

# 63. Frontmatter Interaction

Speech must never insert transcript text inside YAML frontmatter accidentally.

In WYSIWYG mode, the Properties section is separate from body editing.

The insertion point should always correspond to a valid body editing location.

If a user somehow has a source selection within raw frontmatter in Markdown mode, do not silently corrupt YAML.

Follow safe editor semantics.

Prefer preventing speech insertion into frontmatter altogether or requiring the user to move the caret into the body.

---

# 64. No Speech Content in Logs

Audit all logging around:

- audio capture
- transcript result
- errors
- model execution

Never log full transcripts.

Never log raw audio bytes.

Do not include speech text in analytics.

In debug mode, log only safe operational metadata such as:

```text
recording started
recording stopped
audio duration: 8.2s
model loaded
transcription completed
transcript length: 82 chars
```

Even in debug mode, do not print the actual transcript by default.

---

# 65. Accessibility

The microphone button must expose:

```text
Dictate
```

Recording state:

```text
Stop recording
```

Transcription state:

```text
Transcribing
```

Model download control:

```text
Download offline speech model
```

Do not rely only on color or animation to communicate recording state.

---

# 66. Theme Support

Use existing Quiet Paper theme tokens.

The speech UI must work in:

- system theme
- light paper
- dark paper
- the existing theme engine
- future themes

Do not hardcode colors.

Use:

- `AppColors`
- `AppTypography`
- `AppSpacing`
- `AppRadii`

where appropriate.

No independent speech color system.

---

# 67. Typography

Use the existing typography settings for all editor text.

The speech UI itself should use normal application typography tokens.

Do not introduce a new font.

---

# 68. No Blur Loading

Do not use blur-based loading screens or model-download placeholders.

Use clean:

- progress
- text
- restrained animation
- existing Quiet Paper loading conventions

---

# 69. Native Platform Integration

If the chosen FUTO inference runtime requires native platform code:

Keep the Flutter-facing API simple.

For example:

```text
Flutter
  ↓
SpeechRecognitionService
  ↓
MethodChannel / FFI
  ↓
Native speech runtime
  ↓
FUTO model
```

Do not leak native implementation details throughout the editor UI.

Keep native interop isolated within the speech feature/core subsystem.

---

# 70. Suggested Project Structure

Follow the project's existing architecture conventions.

A reasonable structure is:

```text
lib/
  core/
    speech/
      domain/
        speech_model.dart
        speech_session.dart
        speech_result.dart
      application/
        speech_model_manager.dart
        speech_recognition_service.dart
        speech_controller.dart
      infrastructure/
        speech_runtime.dart
        speech_platform.dart
        speech_storage.dart
        speech_downloader.dart
      presentation/
        speech_download_dialog.dart
        speech_settings_section.dart
```

The exact names are up to the implementation.

Do not blindly create every file if existing architecture provides better locations.

Native Android code should be isolated under the existing Android project structure.

---

# 71. Riverpod Integration

Use the application's existing Riverpod patterns.

Expose appropriate providers for:

- speech settings/state
- model installation state
- model manager
- speech recognition service/controller

Do not create global mutable singletons scattered throughout the app.

Make lifecycle explicit.

---

# 72. Persisted Settings

Use the application's existing preferences/settings architecture.

Persist:

- speech recognition enabled/available state only if necessary
- model installation metadata
- selected/current model ID if architecture requires it

Since there is currently only one model, there is no meaningful user model-selection preference yet.

Do not store:

- audio
- transcript history
- speech sessions
- recording timestamps

unless required by normal ephemeral application state.

---

# 73. Downloaded Model Metadata

Persist verified model metadata locally.

Example:

```json
{
  "modelId": "futo_voice_input_english_39",
  "version": "39",
  "filename": "voice-input-english-39.bin",
  "sizeBytes": 0,
  "sha256": "actual verified hash"
}
```

The final implementation must contain real metadata.

Do not leave example values.

---

# 74. Update Strategy

Do not automatically replace the installed model merely because the download URL eventually changes.

The model identity/version must be explicit.

For this implementation, support:

```text
futo_voice_input_english_39
```

Only.

The architecture may support future model updates, but do not invent additional models now.

---

# 75. Editor UI State Machine

The normal editor toolbar state:

```text
NORMAL
```

Recording:

```text
RECORDING
```

Transcribing:

```text
TRANSCRIBING
```

After completion:

```text
NORMAL
```

During RECORDING:

- keyboard hidden
- formatting toolbar replaced by recording controls

During TRANSCRIBING:

- keyboard hidden
- recording controls replaced by transcription state
- document remains visible
- editing mutations should be blocked until completion unless the implementation can safely support them

After completion:

- transcript inserted
- normal toolbar restored
- keyboard remains hidden
- caret positioned after inserted text

---

# 76. Cancel Recording

Provide a clear way to cancel recording before transcription.

Recommended:

```text
Cancel
```

or equivalent subtle control.

Cancellation must:

- stop microphone
- discard temporary audio
- restore editor UI
- restore existing caret/selection
- not modify note
- not create undo entry

Do not confuse "Stop" with "Cancel".

Stop means:

```text
record → transcribe
```

Cancel means:

```text
record → discard
```

---

# 77. Transcript Insertion Animation

Do not animate individual words.

When transcription completes:

- update the document normally
- allow the existing editor rendering to refresh naturally

A subtle caret transition is acceptable.

Do not create distracting typewriter animation.

---

# 78. Recording Indicator

Use a restrained visual indicator.

For example:

```text
● Listening
```

with a subtle opacity/scale pulse.

Do not use:

- giant red circles
- full-screen waveform
- glowing neon effects
- large animated sound visualization

This is Quiet Paper.

---

# 79. Model Download During First Dictation

After the user approves the model download:

1. download
2. verify
3. initialize
4. request/use microphone as appropriate
5. start recording

Avoid forcing the user through multiple redundant screens.

If microphone permission was already granted, proceed directly.

---

# 80. Permission + Model Ordering

Recommended first-use order:

```text
Tap Dictate
      ↓
Microphone permission
      ↓
Model download prompt
      ↓
Download model
      ↓
Initialize
      ↓
Record
```

If microphone permission is denied, do not download a large model unnecessarily.

If the model is missing, don't download it until the user has explicitly indicated they want speech recognition.

---

# 81. Background Network Download

Do not require background download support for V1.

If the app leaves the foreground during model download:

- safely cancel or pause according to implementation capability
- never corrupt the model
- restore a truthful UI state on resume

Do not pretend the download continued if it didn't.

---

# 82. No Automatic Model Download on App Launch

Never download the model:

- during startup
- silently in background
- during note synchronization
- during first login
- during installation

The user must explicitly initiate it.

---

# 83. Testing — Unit Tests

Add tests for:

### Model manager

- missing model
- installed model
- metadata
- checksum verification
- invalid checksum
- partial download
- cancellation
- deletion
- corrupted model
- incorrect file size

### State machine

- idle → recording
- recording → transcribing
- transcribing → idle
- recording → cancelled
- error recovery
- duplicate start prevention

### Selection

- collapsed caret
- selection replacement
- source offset preservation
- WYSIWYG source mapping
- Markdown mode insertion

### Empty result

- no document modification
- no undo entry

### Transcript insertion

- insertion at middle
- insertion at end
- insertion at start
- replacement of selected text
- newline handling
- whitespace handling
- formatted Markdown boundaries

---

# 84. Widget Tests

Test:

- microphone button visible in editable mode
- microphone disabled in read-only mode
- microphone disabled for locked notes
- microphone hidden/disabled while transcribing
- keyboard dismissal when recording begins
- recording UI
- timer
- stop behavior
- cancel behavior
- transcription UI
- successful insertion
- error UI
- model download dialog
- download progress
- model-installed state
- model-delete confirmation
- Settings integration

---

# 85. Integration Tests

Test the complete real flow on a supported Android device/emulator where practical:

```text
Install app
↓
Open note
↓
Tap microphone
↓
Download model
↓
Model verification
↓
Start recording
↓
Record speech
↓
Stop
↓
Transcribe
↓
Insert
↓
Autosave
↓
Reload note
↓
Text remains correct
```

Where automated audio injection is practical, use deterministic test audio.

Do not rely exclusively on mocked speech results for production validation.

---

# 86. Real Model Verification

Before declaring the feature complete, actually run the supplied model through the integrated runtime.

Record or provide known English speech.

Verify that:

```text
audio
↓
FUTO model
↓
real transcript
```

works on an actual supported Android architecture.

Do not mark implementation complete merely because:

```text
model downloaded = true
```

The feature is complete only when real speech becomes real text.

---

# 87. Performance Validation

Measure:

- model download time
- model load time
- recording startup latency
- transcription latency
- peak RAM
- UI responsiveness
- battery/CPU behavior for typical short dictation

Test with:

- short sentence
- 30-second dictation
- longer paragraph

The editor must remain usable and responsive around the inference operation.

---

# 88. Security Validation

Verify:

- microphone data never leaves the device
- no transcription network requests
- no audio uploads
- no transcript analytics
- model download uses HTTPS
- checksum validation is enforced
- model files are stored privately
- temporary recordings are deleted
- locked/read-only notes cannot be accidentally modified
- no speech content appears in application logs

---

# 89. Existing Feature Regression Testing

Do not regress:

- Markdown editor
- WYSIWYG editor
- Markdown/source mapping
- frontmatter
- Properties
- formatting toolbar
- keyboard shortcuts
- checklists
- tables
- code blocks
- note links
- images
- autosave
- undo/redo
- version history
- read-only mode
- note password protection
- sync
- encryption
- backup/restore
- themes
- typography
- large-document optimization

Speech recognition is an addition to the editor, not a replacement for existing functionality.

---

# 90. Commands / Verification

Run the project's existing verification commands.

At minimum:

```bash
flutter analyze
flutter test
```

Run Android build verification appropriate to the project's current Gradle/Flutter setup.

If native code is introduced:

- verify debug build
- verify release build
- verify each supported Android architecture relevant to the native runtime
- verify APK packaging

Do not leave analyzer warnings or native compilation errors.

---

# 91. Documentation

Update the engineering handoff/documentation with:

- speech architecture
- model identity
- model URL
- model runtime
- model checksum
- model storage location
- download lifecycle
- permissions
- offline guarantee
- audio lifecycle
- native integration
- supported platforms/architectures
- known runtime requirements
- model update procedure

Do not document hypothetical functionality that was not implemented.

---

# 92. Final UX Requirements

The finished feature should feel like this:

### First use

```text
Tap 🎙
    ↓
"Download the English speech model"
    ↓
Download
    ↓
Listening...
```

### Normal use afterward

```text
Tap 🎙
    ↓
Listening...
    ↓
Stop
    ↓
Transcribing…
    ↓
Text appears at caret
```

No network.

No AI branding.

No separate screen.

No unnecessary configuration.

No audio history.

No giant waveform.

No keyboard while recording.

No automatic keyboard reopening after transcription.

---

# 93. Final Product Principles

The implementation must follow these principles:

### 1. Offline first

Once the model is installed, speech recognition works without an internet connection.

### 2. Private by default

Audio stays on the device.

### 3. Markdown remains canonical

Speech is simply another way of entering text.

### 4. Editor remains the source-of-truth integration point

Speech does not bypass the editor.

### 5. Model downloads are explicit

Never silently consume hundreds of MB.

### 6. Model management is robust

Verify before install, clean up failures, and handle interrupted downloads correctly.

### 7. Quiet Paper remains quiet

The feature should feel like a natural input method, not a noisy AI experience.

### 8. No shortcuts

No fake transcription.

No mock engine in production.

No placeholder runtime.

No hardcoded pretend model state.

No unimplemented TODO flow.

The finished feature must be usable end-to-end on a real supported Android device.

---

# 94. Definition of Done

This task is complete only when:

- the FUTO English model at the provided URL is downloaded successfully
- its integrity is verified using a real checksum
- the compatible FUTO inference runtime is integrated
- native inference actually runs
- real English speech is transcribed
- transcription occurs fully on-device
- the model is not bundled into the APK
- first-use model download works
- model deletion works
- microphone permission is handled correctly
- recording works
- cancellation works
- transcription works
- keyboard hides during recording
- keyboard stays hidden during transcription
- keyboard does not automatically reopen afterward
- editor/document remains visible during recording
- transcript inserts at the correct source position
- WYSIWYG mode works
- Markdown mode works
- formatting boundaries remain correct
- selection replacement works
- undo/redo works
- autosave works
- read-only mode is respected
- locked notes are respected
- audio is discarded after use
- no audio or transcript is sent to a server
- no speech content appears in logs
- model download is resumable/recoverable or safely restartable
- corrupt models cannot be installed
- insufficient storage is handled
- app lifecycle interruptions are handled
- UI remains responsive during inference
- `flutter analyze` passes cleanly
- `flutter test` passes
- Android release builds successfully
- the implementation is documented in the engineering handoff

Do not stop at the UI.

Do not stop at model download.

Do not stop at a mocked service.

The final result must be a **real, production-ready offline speech-to-text feature using the supplied FUTO model**.