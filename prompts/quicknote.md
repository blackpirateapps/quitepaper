# Implementation Specification: Quiet Paper Android Quick Capture

## Role and objective

You are a senior Flutter, Dart, Kotlin, and Android engineer working directly in the Quiet Paper codebase.

Your task is to **implement a production-ready Android Quick Capture feature end to end**, including a compact home-screen widget, a dedicated lightweight capture screen, Android Share menu integration, recoverable local drafts, lifecycle-safe persistence, and comprehensive automated tests.

Do not merely provide a plan, examples, pseudocode, or architectural recommendations. Inspect the repository, implement the feature in the working tree, run the applicable checks, fix regressions, and document the results.

Make reasonable implementation decisions independently. Do not stop to ask questions that can be resolved by inspecting the codebase. If a proposed detail conflicts with existing architecture or platform behavior, adapt it to the current implementation while preserving the required user experience.

The repository's actual source code is authoritative. Read the existing engineering handoff documentation, but verify its descriptions and paths against the current code before making changes.

---

# 1. Product vision

Quiet Paper is an offline-first, privacy-focused notes application built with Flutter and Dart. Its architecture includes:

- Drift and SQLite for local persistence.
- Riverpod for application state management.
- An existing note repository and application/domain layers.
- A Markdown-aware editor and automatic title behavior.
- Autosave and application lifecycle handling.
- Client-side encryption and a zero-knowledge cloud synchronization system.
- A native Android application entry point and an existing webpage-sharing/Web Clipper flow.
- An established warm editorial visual design, including light and dark themes.

Quick Capture should make saving a thought or a piece of shared text nearly instantaneous.

The core product principle is:

**Capture the thought. Save it locally. Close immediately. Let the user organize it later, if ever.**

The feature must feel native to Quiet Paper. It must not introduce a separate note format, duplicate the main editor, require additional configuration, or turn ordinary writing into a workflow.

## In scope

Implement:

1. A compact, one-button Android home-screen widget.
2. A dedicated Flutter Quick Capture route.
3. Android text and URL sharing into the same capture route.
4. Local-first note creation through the existing persistence architecture.
5. Local-only draft recovery for interrupted captures.
6. Safe handling of Android activity launches, intent delivery, keyboard state, application lifecycle, and task navigation.
7. Appropriate error handling, accessibility, tests, and documentation.

## Out of scope for this release

Do not implement:

- An editable text field embedded inside the Android widget.
- A separate inbox or task-management system.
- AI summaries, automatic rewriting, or automatic tagging.
- Cloud storage of unfinished drafts.
- A new backend API, database service, or encryption protocol.
- Image and multiple-file sharing as a new capture workflow.
- A new reminder or notification system.
- A new navigation framework or a large application architecture rewrite.
- An additional app shortcut unless the existing architecture requires it to complete this task.

Preserve existing full-page article clipping, image/document attachments, OCR, note version history, encryption, sync conflict handling, backups, and normal editor workflows.

---

# 2. Mandatory repository reconnaissance

Before implementation, inspect the existing project and determine the actual state of these components:

1. `pubspec.yaml`, Flutter version constraints, dependency versions, and platform configuration.
2. Android `MainActivity`, its superclass, launch mode, task behavior, Android manifest, package/application ID, minimum SDK, and Gradle configuration.
3. The existing route/navigation system and the earliest safe point at which the Flutter application can process launch requests.
4. `lib/main.dart` and current provider initialization order.
5. The notes domain model, note repository, note-creation service, ID generation, title rules, timestamps, tag handling, and persistence transactions.
6. `lib/core/database/app_database.dart`, its current schema version, migration strategy, DAO conventions, and database tests.
7. Existing autosave, draft recovery, editor state, application lifecycle observers, and note-version creation behavior.
8. `lib/core/sync/sync_engine.dart` and the code paths that queue new notes for synchronization.
9. Master-key initialization, vault locking, secure-storage behavior, and protected-note handling.
10. `lib/core/web_clipper/share_intent_handler.dart`, `ReceiveSharingIntent` or equivalent plugin integration, Android intent filters, and the current Web Clipper URL-sharing path.
11. Existing UI theme tokens, typography, spacing, accessible button components, and widget-test conventions.
12. Existing Android widget implementations, if any, and any native-to-Flutter communication already present.

Search the entire repository for existing draft, capture, share-intent, widget, and navigation implementations before introducing new ones.

**Reuse existing services and conventions wherever possible.** Do not create a parallel note-writing path merely because Quick Capture has a simpler interface.

Do not assume the database schema version, current app version, Android namespace, plugin versions, or route framework based on an old document. Read the actual files first.

Record a brief internal implementation checklist, then proceed with the implementation without waiting for approval.

---

# 3. Android home-screen widget

## 3.1 Visual and interaction specification

Build a compact rectangular widget with:

- Quiet Paper branding or its existing app icon.
- The label `Quiet Paper`.
- A single prominent action labeled `Capture a thought`.
- A restrained warm-paper design consistent with the application.
- Light/dark resource handling where appropriate for the actual Android widget implementation.
- Correct accessibility semantics and a sufficiently large touch target.
- A sensible minimum widget size and resizing behavior for supported launchers.

The widget must not display note titles, previews, captured content, account details, or synchronization metadata.

Its only job is to open Quick Capture.

Do not implement an embedded editor, a scrolling note list, periodic refresh, network requests, background polling, or note-content rendering.

## 3.2 Native Android implementation

Inspect the project's current Android structure and choose the simplest production-compatible widget implementation.

Prefer native Android `RemoteViews` and Kotlin with an `AppWidgetProvider` when no compatible widget framework already exists. Reuse an existing widget framework if the repository already has one that is appropriate.

Create the necessary:

- Widget provider class.
- Widget layout resources.
- App-widget provider metadata.
- Required manifest registration.
- Appropriate icon, background, dimensions, and strings.
- Launch intent or existing routing bridge into Flutter.
- Focused tests for widget configuration and launch behavior.

Follow current project conventions for namespaces and package names. Do not invent a second application entry point or duplicate the Flutter application initialization.

Use an explicit `PendingIntent` that targets the appropriate application activity or existing native launch bridge. Select request codes, intent identity, and activity flags deliberately. Use safe mutability settings compatible with the supported Android versions.

Do not introduce a broadcast receiver that exists only to forward the widget tap to another activity if a direct activity `PendingIntent` can handle it.

Do not weaken exported-component protections, introduce unrelated permissions, or add a new background service.

If the existing activity configuration makes direct widget routing unsafe, implement the minimal native routing adjustment and document the reason.

## 3.3 Widget launch behavior

When the widget is tapped:

1. Bring Quiet Paper to the foreground.
2. Deliver a widget-origin capture request exactly once.
3. Open the Quick Capture route directly.
4. Display the text input and request keyboard focus.
5. Avoid flashing the library, settings, splash-like intermediate routes, or unrelated screens unnecessarily.
6. Preserve normal application initialization, database initialization, and encryption lifecycle requirements.

Support both a cold application launch and a widget tap when the application already exists in memory or in the background.

Repeated widget taps must not create duplicate routes or discard content from an existing capture.

Do not assume that an explicit intent or the presence of a Flutter route automatically guarantees the correct Android task behavior. Verify the actual launch mode and navigation stack.

---

# 4. Quick Capture screen

## 4.1 Visual hierarchy

Implement a dedicated, lightweight Flutter screen using existing Quiet Paper theme tokens and UI components.

The layout should contain only:

- A small header labeled `Quick Capture`.
- A close button in the top-left corner.
- A clear `Save` button in the top-right corner.
- One multiline text input.
- A subtle optional recovery affordance if an unfinished draft exists.
- Minimal, nonintrusive status/error text only when necessary.

Use the existing app colors and typography. Respect dynamic light/dark appearance and accessibility settings.

Do not add a title field, a tag editor, a folder chooser, a formatting toolbar, a Markdown preview, a word counter, a note-list browser, or a settings button.

The capture content is the note body. The regular Quiet Paper editor can be used later for refinement.

## 4.2 Keyboard and focus

On first entry:

- Populate any incoming shared content before requesting focus.
- After the route's first frame and controller initialization, focus the text field.
- Request the Android software keyboard without requiring a second tap.
- Prevent repeated keyboard requests when the app resumes or an unrelated activity briefly takes focus.
- Preserve cursor and selection state across ordinary widget rebuilds and supported configuration changes.

Handle devices with a physical keyboard. The input must remain usable even when the software keyboard is unavailable.

Keep the Save action accessible when the IME is visible. Do not let the keyboard cover the primary action or the last editable lines.

Use a multiline text field with sensible scroll behavior. Support Unicode, emoji, line breaks, pasted text, and long captures without inappropriate length truncation.

Do not run expensive Markdown parsing, article extraction, network requests, or full note indexing synchronously on every keystroke.

## 4.3 Save and close

The primary action is `Save`.

For nonempty content:

1. Validate the body as meaningful text without destructively normalizing it.
2. Enter a saving state and disable duplicate submissions.
3. Commit the note locally through the existing creation/persistence pipeline.
4. Ensure the committed note is eligible for normal local search, note linking, note history behavior, backups, and cloud synchronization as applicable.
5. Remove the completed capture's recoverable draft.
6. Confirm that the local database operation succeeded.
7. Close Quick Capture immediately.
8. Allow synchronization and noncritical background processing to continue independently.

The screen should not wait for cloud authentication refreshes, network connectivity, remote sync acknowledgment, OCR, article extraction, or unrelated background tasks after local persistence has succeeded.

If local persistence fails, keep the text visible, preserve the recoverable draft when possible, show a clear error, and allow retry.

Never close the screen and claim success before local persistence has succeeded.

### Empty capture

If the content is empty or whitespace-only, do not create a note.

Disable or otherwise make the Save action unavailable for empty content. Closing an empty capture should immediately return to the originating context without creating a blank note.

### Existing title and note semantics

Reuse the application's existing automatic title generation and note initialization behavior.

Do not independently reimplement title truncation, Markdown parsing, timestamps, tag extraction, note IDs, or note initialization when existing helpers already provide this behavior.

For ordinary thoughts, preserve the content as the canonical note body.

For shared URLs, do not fetch webpage metadata merely to populate a title. Use existing title/source conventions and the information already provided by Android.

Do not add automatic tags unless required by an existing, explicit import convention that applies to this flow.

---

# 5. Android Share menu integration

## 5.1 Existing integration must be preserved

The repository already has a Web Clipper and an Android share-intent handling path. Inspect the actual implementation and extend it instead of adding competing intent filters or parallel share handlers.

Preserve full article clipping, webpage extraction, optional snapshots, image ingestion, offline document storage, and the existing URL-handling capabilities.

The intended behavior is:

- **Plain-text sharing:** open Quick Capture.
- **Quoted text:** open Quick Capture with the quoted text prefilled.
- **URL-only sharing:** open Quick Capture with the URL prefilled.
- **Text plus URL:** preserve the text and source information.
- **Full webpage clipping:** remain available as a deliberate secondary action.

When an incoming URL is detected, provide a small optional action such as `Clip full article` if it can be integrated cleanly with the existing Web Clipper. Do not automatically launch the full article-clipping workflow just because a URL was shared.

Do not make networking a prerequisite for saving a URL or quotation.

## 5.2 Supported Android intents

Support the appropriate existing and new handling for:

- `Intent.ACTION_SEND` with `text/plain`.
- Existing supported URL/view intents, according to the current codebase.
- Existing share-plugin delivery mechanisms.
- Initial intents received during cold starts.
- Subsequent intents received by an already-running activity.

Inspect the current plugin's behavior before modifying intent filters. Ensure that the plugin and any native intent handling have a single coherent handoff into the Flutter capture coordinator.

Do not add multiple competing consumers that each create a capture screen for the same incoming share.

## 5.3 Content normalization rules

Build a small, testable normalization layer that converts the actual Android payload into a capture request.

Handle the text, URL, and optional subject fields supported by the current integration.

Rules:

1. Preserve shared text and meaningful line breaks.
2. Treat whitespace-only content as empty.
3. Do not silently summarize, rewrite, strip Markdown, or normalize away meaningful content.
4. If the same URL appears in both the text and a separate URI field, do not append it twice.
5. Preserve the original shared text when the URL is already embedded in it.
6. Use an incoming subject as a title hint only if it is consistent with existing note-creation conventions.
7. Avoid duplicate content when the platform supplies both a textual URL and a separate URL field.
8. Never silently convert malformed or unsupported input into a blank note.
9. Do not fetch remote webpage content in the content-normalization phase.
10. Establish a documented, sensible maximum payload size consistent with the project's normal input handling, and handle oversized input explicitly rather than truncating it silently.

Keep untrusted incoming values out of diagnostic logs.

## 5.4 Another share arrives during capture

If an additional share is delivered while the capture screen already contains text:

- Do not overwrite the current text.
- Do not silently change the current capture's source.
- Preserve the current session as a recoverable draft.
- Make the new item available through a restrained, explicit switch/continue action.
- Ensure that a user can save either capture without losing the other.

Avoid spawning multiple overlapping capture routes or displaying modal dialogs for routine delivery events.

---

# 6. Android task and navigation behavior

Returning to the correct place is a core feature requirement.

### Widget-origin capture

After Save, close the capture experience and return to the launcher, not to the main Quiet Paper library.

### Share-origin capture

After Save, close the capture experience and allow Android's normal task stack to return the user to the application from which the content was shared, where the launch path permits this.

### Cancel/close

The close action follows the same source-aware return behavior. Empty captures should close immediately. Nonempty captures must first be preserved as recoverable drafts.

### Existing application task

Handle these launch modes correctly:

- App not running.
- App process running but activity stopped.
- App activity already visible.
- Main activity receiving a new intent.
- Capture route already present.
- Quick Capture already open with unsaved content.

Do not use `CLEAR_TASK`, `finishAndRemoveTask`, aggressive task resets, or `SystemNavigator.pop` indiscriminately. Such APIs may destroy an existing navigation stack or produce different behavior depending on the launch source.

Inspect the actual Android task stack and activity launch configuration. Implement source-aware navigation that meets the user-visible requirements without unnecessarily relaunching or forcibly opening other applications.

Where native lifecycle handling is necessary, keep it minimal and explain its purpose in the code.

Ensure the incoming widget/share request is delivered once even when Android calls `onCreate` versus `onNewIntent`. If the activity implementation requires updating its current intent for plugin compatibility, handle that explicitly.

Never relaunch the originating app manually. Allow Android to manage the source application's task stack.

Add the relevant Android tests and a documented manual test procedure for task-stack behavior.

---

# 7. Local draft recovery

Draft recovery is essential because Android may kill an application's process without giving Flutter an opportunity to run asynchronous cleanup.

Implement recoverable drafts through the existing local data architecture.

## 7.1 Storage

Inspect current draft/autosave support before adding a schema. Reuse it if it has the required semantics.

If no suitable mechanism exists, create a minimal local-only Drift persistence mechanism with an appropriate schema migration.

A draft record should contain the minimum data required for safe recovery, potentially including:

- A unique capture-session ID.
- A stable intended note ID.
- Current content.
- Capture source, such as widget or share.
- Optional source URL and title hint.
- Cursor/selection state if it can be preserved reliably.
- Created and updated timestamps.

Follow current Drift naming, migration, DAO, and testing conventions.

Drafts must never be inserted into the ordinary notes table merely because they exist. They must not enter the cloud sync queue, appear as completed notes in search, or be sent to the backend before the user explicitly saves them.

Do not store draft content in `SharedPreferences`, widget metadata, external files, notification text, or debug logs.

Keep the draft mechanism local to the installation and ensure that draft records cannot accidentally be treated as normal synced notes.

## 7.2 Autosaving a draft

Persist edits using a short debounce, approximately 250–400 ms, and flush the latest content on appropriate lifecycle transitions and before closing a nonempty capture.

These timings are initial design targets, not reasons to compromise correctness.

Important requirements:

- Serialize draft writes, or use a sequence/revision mechanism that prevents stale asynchronous writes from overwriting newer text.
- Flush the latest controller value rather than a stale captured value.
- Dispose of timers, controllers, focus nodes, and lifecycle observers safely.
- Avoid synchronous disk I/O on the UI thread.
- Do not rely solely on `AppLifecycleState` callbacks to protect data.
- Do not claim absolute crash safety for characters that have not yet been persisted.
- Use a transient native saved-state mechanism only as a complement to durable local recovery, not as a replacement.

No plaintext draft should be exposed outside the application's normal private data boundary.

## 7.3 Recovering an unfinished draft

On a fresh capture launch, never replace a new thought or shared payload automatically with an older draft.

If unfinished drafts exist, show a small optional `Resume unfinished capture` affordance.

The user must be able to begin a new capture without losing the older draft.

If multiple nonempty drafts are supported, provide a restrained way to choose among them without inventing a full inbox. Do not automatically delete user-written drafts because a count limit or age threshold was reached.

Define and test how an unfinished draft is distinguished from a completed note.

## 7.4 Draft and note commitment

Generate a stable target note ID for each capture session.

Make retries safe. If Android interrupts the application after the database commit but before the UI closes, a repeated save must not insert a second note.

Where feasible with the existing repository architecture, commit the note and remove its draft in a single database transaction.

If existing note-creation side effects require a separate transaction boundary, design a recoverable state transition that preserves idempotency and never loses the user's text.

Use the normal note repository and domain service. Do not duplicate repository business rules inside the capture screen.

Ensure normal note-link indexing, tags, timestamps, dirty state, sync metadata, and note history semantics behave as they would for a note created using the standard application.

---

# 8. Synchronization and privacy requirements

Quick Capture must reuse Quiet Paper's existing sync architecture.

After a successful local save:

- The note is stored locally first.
- Normal dirty-state and synchronization-queue behavior is applied.
- The existing engine handles synchronization when available.
- Network failures do not invalidate a successful local save.
- The capture screen closes without waiting for cloud acknowledgment.

Do not add a backend endpoint, a second sync queue, plaintext transmission path, or a parallel encryption implementation.

Inspect how the current repository and sync engine handle:

- New note creation.
- Generated note IDs.
- Dirty flags and server revisions.
- Sync queue insertion.
- Retry and idempotency keys.
- Note versions and initial history behavior.
- Authentication or encryption being unavailable.
- Local-only operation when the user has not signed into cloud sync.

**Preserve Quiet Paper's cryptographic boundaries.** Use the existing crypto/key-management architecture and never copy key material into widget state, intent extras, logs, or draft metadata.

Do not expose captured text or draft text in widget previews, launcher metadata, analytics, notifications, or verbose exception messages.

If the vault is locked under the existing application policy, follow the normal unlock flow without leaking incoming content. Preserve any necessary temporary content only within the approved private recovery mechanism. If unlocking is cancelled, do not create a note or silently discard the input when recovery is possible.

Do not alter the application's ordinary sign-out, device-revocation, backup, or local data-erasure semantics.

---

# 9. Error handling and edge cases

Implement explicit behavior for the following cases.

| Scenario | Expected behavior |
|---|---|
| Empty input | Save remains unavailable; closing creates no note. |
| Whitespace-only input | Treated as empty. |
| Unicode, emoji, and multiline text | Preserved correctly. |
| Long content | Remains editable and scrollable; avoid pathological allocation or synchronous full-document processing. |
| URL-only share | URL appears in the capture field. |
| Text and URL arrive together | Preserve content without duplication. |
| Malformed share | Graceful fallback, no crash, no blank note. |
| Repeated Save taps | Single commit; further taps disabled while saving. |
| Duplicate request delivery | One capture session per delivery; no competing routes. |
| Another share during unsaved capture | Existing content retained; new content does not overwrite it. |
| Rotation or configuration change | Text, cursor, request source, and session ID preserved. |
| Keyboard hidden or hardware keyboard present | Capture remains fully usable. |
| App backgrounded | Best-effort immediate draft flush. |
| Process killed | Restore persisted draft on the next capture entry. |
| App resumed | Do not create a second route or repeatedly reopen the keyboard. |
| Database write failure | Keep input visible, report failure, allow retry. |
| Storage exhausted | No false success; retain content in memory and recovery storage if possible. |
| Offline operation | Local capture succeeds without network. |
| Authentication refresh failure | Local save succeeds whenever the local vault is available. |
| Sync failure | Save remains successful; retry is managed by the existing sync system. |
| Crash after commit | Recovery must identify an already committed session and avoid duplicate creation. |
| Vault locked | Use the existing unlock policy and avoid unprotected staging of incoming text. |
| Unsupported file/image share | Explicit graceful handling; no crash or silent empty note. |
| Interrupted article clipping | Existing Web Clipper behavior remains intact. |
| Unfinished draft already exists | New capture is not overwritten; recovery remains available. |

Use appropriate structured internal errors, but do not log note content, incoming share payloads, passwords, master keys, encryption material, or recovery secrets.

Never catch errors silently if doing so hides a failure that could cause data loss.

---

# 10. Architecture and code quality

The implementation should have clear separation between:

1. Native Android widget and launch integration.
2. Incoming intent/share normalization.
3. Capture request/session state.
4. Flutter capture UI.
5. Local draft storage and recovery.
6. Existing note persistence and synchronization.

Keep the design proportional to the feature. Do not build a large generic workflow engine for two entry points.

Follow the current package structure and naming conventions.

Use typed immutable request/state models where appropriate. For example, a capture request may include a request ID, origin, optional initial content, optional source URI, and optional subject. Adapt this to the project's established patterns rather than mechanically introducing names.

Ensure:

- There is a single owner of each active capture session.
- Request delivery is separated from persistence.
- UI state does not become the source of truth for database commits.
- Draft writes cannot race with one another.
- Note creation is idempotent.
- Navigation and activity lifecycle handling are testable.
- Errors remain visible and actionable.
- All asynchronous work is cancellable or lifecycle-safe where appropriate.
- Existing repository APIs are extended thoughtfully rather than bypassed.
- Public interfaces and comments accurately describe their semantics.

Prefer the smallest dependency footprint that fits the architecture.

Do not introduce a new plugin solely for a capability already supported by the current Android or Flutter setup.

If a schema change is needed, increment the actual current Drift schema version correctly, implement an upgrade-safe migration, and add migration regression coverage. Do not assume a hardcoded previous version from the engineering handoff.

Do not update the app version merely because a feature is added unless the repository's established release process requires it.

---

# 11. Automated testing requirements

Add meaningful tests as part of the implementation. Do not treat compilation alone as sufficient.

## 11.1 Dart unit tests

Test the capture request and content-normalization layer, including:

- Empty and whitespace-only text.
- Plain text and quoted text.
- URL-only content.
- Subject/title hints.
- Text that includes the URL already.
- Separate text and URI fields.
- Meaningful line breaks and Unicode.
- Malformed input and size limits.
- Multiple incoming requests.
- Stable session IDs and retry behavior.

Test the capture controller/application service for:

- Opening an empty session.
- Opening a prefilled share session.
- Editing and draft persistence.
- Debounced updates arriving out of order.
- Flushing the latest state.
- Successful save and draft deletion.
- Failed save and recovery retention.
- Duplicate submissions.
- Recovery after a simulated interruption.
- Empty capture closure.
- A second incoming request while another capture contains unsaved text.

## 11.2 Database and migration tests

Verify:

- New draft persistence and retrieval.
- Correct schema migration from the repository's supported existing database versions.
- Drafts are excluded from the normal notes query and search index.
- Drafts do not enter the sync queue.
- Save and draft removal maintain the intended consistency invariant.
- Retrying a completed session cannot create duplicate notes.
- Existing note CRUD, tags, link indexing, note versions, and migrations remain correct.

Reuse the application's established database test infrastructure and in-memory SQLite connection facilities where appropriate.

## 11.3 Flutter widget tests

Verify:

- Correct Quick Capture hierarchy.
- Keyboard-focus request when the route becomes ready.
- Text entry and cursor handling.
- Save disabled for empty input.
- Save-in-progress state blocks duplicate taps.
- Successful local-save response triggers the appropriate close behavior.
- A failed save keeps the editor visible with the content intact.
- Draft recovery is visible without overwriting new content.
- Incoming share content is prefilled correctly.
- A later incoming share cannot overwrite existing unsaved text.
- The interface remains usable at narrow device sizes.
- Theme, semantics, screen-reader labels, and keyboard visibility do not break the primary action.

## 11.4 Android integration tests

Where the repository's test infrastructure permits, verify:

- Widget provider registration and widget metadata.
- Widget `PendingIntent` targets the intended entry point.
- Cold launch through a widget intent.
- Warm launch and `onNewIntent` behavior.
- `ACTION_SEND` text intent handling.
- Interaction with the existing receive-sharing-intent plugin.
- Duplicate route prevention.
- Correct task return behavior for widget-origin and share-origin flows.
- Compatible intent flags and mutability settings.
- Correct manifest declarations and exported-component security.
- No runtime permission is requested for basic Quick Capture.

If device/emulator instrumentation cannot be executed in the environment, add the appropriate test scaffolding and explicitly document the missing runtime verification. Do not claim unexecuted tests passed.

## 11.5 Regression tests

Verify that existing functionality still works:

- The standard note editor and autosave.
- Markdown import and note creation.
- Web Clipper and offline webpage snapshots.
- Attachments and documents.
- Local search and OCR search.
- Encryption and key unlocking.
- Cloud synchronization and offline queue behavior.
- Note version history and recovery.
- Backup and restore.
- Existing application launch and navigation flows.

---

# 12. Performance and reliability

Quick Capture should have minimal latency and negligible idle overhead.

- The widget should not run background polling.
- The entry screen should not fetch remote content.
- Avoid loading the entire note library solely to render a capture surface.
- Do not block the first usable capture frame on cloud synchronization.
- Debounce draft writes, while preserving the latest content across normal lifecycle transitions.
- Keep expensive background processing outside the text-input path.
- Ensure save operations use the existing efficient persistence path.
- Do not leak controllers, event subscriptions, timers, lifecycle observers, or Android listeners.
- Do not create multiple competing capture coordinators during activity recreation.
- Avoid unnecessary widget updates and repetitive app rebuilds.

Profile or reason through cold-start and warm-start paths, including database/provider initialization. The capture UI should appear as early as safely possible without bypassing required initialization.

Do not sacrifice persistence correctness for a marginally faster transition.

---

# 13. Security and platform compatibility

Inspect the current Android minimum/target SDK and follow supported platform APIs.

Ensure that:

- The app-widget provider is declared correctly.
- Widget intents cannot be abused to bypass vault initialization or the normal unlock policy.
- Incoming intents are treated as untrusted data.
- Text and URI lengths are bounded.
- No unintended file URI is opened or imported automatically.
- No new broad storage permission is requested.
- Sensitive content is not embedded in widget metadata or notification text.
- Existing manifest intent filters remain compatible with the Web Clipper.
- All Android 12+ `PendingIntent` mutability requirements are respected.
- Existing package names, build flavors, release configuration, and app identifiers remain intact.
- Native code and Flutter code agree on the request schema and lifecycle semantics.

Do not put secrets, key material, decrypted note content, or recoverable drafts into Android intent extras unless they are transient handoff data that cannot reasonably be passed otherwise. Prefer a minimal session identifier when a durable handoff is required.

No note content should be transmitted to a remote service as part of basic Quick Capture.

---

# 14. Documentation requirements

Update the project's engineering handoff document with a concise, accurate feature section documenting:

1. The widget implementation and Android registration.
2. How widget launches are routed into Flutter.
3. How Android shares are normalized and routed.
4. How the Quick Capture state is managed.
5. How local draft recovery works.
6. What guarantees note creation idempotency.
7. How the feature reuses normal persistence and synchronization.
8. Lifecycle and task-return decisions.
9. New files and database schema changes.
10. Commands used to validate the implementation.
11. Any known limitation that could not be resolved or tested.

Update the existing share-handling documentation rather than writing duplicate documentation that contradicts it.

Do not claim a security guarantee, test result, or behavior unless the implementation actually provides it.

---

# 15. Required implementation workflow

Execute the following workflow in order.

### Phase 1: Inspect

Read the actual repository files, map the current launch/share/persistence paths, identify the authoritative APIs, and confirm the existing behavior that must be preserved.

### Phase 2: Design minimally

Choose the smallest architecture that supports the exact behavior above. Identify any required Drift migration, native widget files, route changes, and share-handler changes.

### Phase 3: Implement

Implement the Android widget, capture route, incoming share flow, recovery storage, idempotent persistence, and source-aware navigation. Write code, not just design documents.

### Phase 4: Test

Run the relevant tests during development. Add missing tests and fix failures before continuing.

### Phase 5: Validate

Run the repository's applicable commands, including:

- `flutter analyze`
- `flutter test`
- Drift code generation if the schema or generated database code changed
- Android debug build
- Android release build where the environment supports it
- Relevant backend tests if backend files were touched

Use the exact commands and build flavors defined by the current repository. Do not modify unrelated infrastructure merely to get a green build.

Inspect the final diff for accidental unrelated changes, insecure logging, manifest regressions, missing resources, and generated-code consistency.

### Phase 6: Report

At completion, summarize:

- What was implemented.
- Important architectural decisions.
- Files created and modified.
- Database migration changes, if any.
- Test and build commands actually executed, with accurate results.
- Remaining limitations or unverified device-specific behavior.

Do not report a test as passing unless it ran successfully in the current environment. If a command fails for environmental reasons, distinguish that from a product-code failure.

---

# 16. Definition of done

The feature is complete only when all applicable criteria below are satisfied.

- [ ] A user can add the compact Quick Capture widget to an Android launcher.
- [ ] Tapping it opens Quick Capture directly.
- [ ] The keyboard is automatically focused without repeated focus requests.
- [ ] A user can type a thought and save it with one clear action.
- [ ] Saving creates a normal Quiet Paper note using the existing persistence architecture.
- [ ] A successful local save closes capture without waiting for the network.
- [ ] Widget-origin capture returns to the launcher without leaving the library visible.
- [ ] Sharing plain text, quotations, and URLs opens the same capture screen with content prefilled.
- [ ] Share-origin capture returns through the normal Android task stack to the originating context where the launch path permits it.
- [ ] The existing full Web Clipper flow remains accessible and functional.
- [ ] Draft recovery prevents avoidable loss when the process is interrupted.
- [ ] Starting a new capture never overwrites an unfinished draft.
- [ ] Failed local saves do not produce false success or silently discard input.
- [ ] Duplicate save attempts and retried commits cannot create duplicate notes.
- [ ] Drafts remain local-only and do not enter sync until a normal note is committed.
- [ ] Existing zero-knowledge encryption and synchronization boundaries remain intact.
- [ ] Android cold-start, warm-start, intent-delivery, keyboard, and task-navigation cases have been addressed and tested to the extent supported by the environment.
- [ ] Existing functionality has appropriate regression coverage.
- [ ] `flutter analyze` and the applicable Flutter test suite pass, or any environmental blocker is accurately documented.
- [ ] The Android application builds successfully in the supported build configuration, or the environmental blocker is accurately documented.
- [ ] The engineering handoff documentation is updated.
- [ ] No unrelated refactoring, permissions, backend changes, or new product workflows have been introduced.

## Final instruction

**Implement the complete feature in the repository. Do not stop after reconnaissance, do not return only a proposal, and do not omit draft recovery or Android task lifecycle handling.**

Favor boring, explicit, testable mechanisms over clever abstractions. Preserve Quiet Paper's existing architecture and behavior. The finished feature should make capturing a thought feel effortless while keeping persistence, privacy, and recovery dependable.
