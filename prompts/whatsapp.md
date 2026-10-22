# Quiet Paper — Production-Ready WhatsApp Chat Formatter

## Mission

You are the senior Flutter engineer responsible for implementing a complete, production-ready WhatsApp paste formatter inside Quiet Paper.

You have access to the Quiet Paper source repository, the project engineering handoff document (`HANDOFF.md` or its equivalent), and a screenshot of the approved interactive design mockup.

**Your job is to verify the existing repository, implement the feature in the real application, and validate it before finishing. Do not stop at an audit, design, plan, prototype, or proposed code.**

Do not deliver mockups, placeholder widgets, demo-only behavior, incomplete scaffolding, deferred implementation steps, or a list of instructions for somebody else to execute. Complete the implementation in the available workspace.

If a necessary external dependency or environment limitation genuinely prevents an operation, finish every other feasible part of the implementation, run all available relevant checks, and report the precise limitation. Never falsely claim success.

---

## 1. Phase One: Audit the Actual Repository

Before modifying anything, inspect the actual repository and establish how the application currently works.

### Verify the repository

1. Find the repository root and read its applicable `AGENTS.md`, contributor instructions, README, engineering handoff documents, and relevant architectural documentation.
2. Inspect the current Git branch and working tree. Identify pre-existing modifications and untracked files. Never overwrite or discard the user's work.
3. Inspect the actual Flutter and Dart versions, `pubspec.yaml`, dependency constraints, project test configuration, and supported platforms.
4. Verify the current source instead of assuming that the handoff document perfectly reflects the codebase.
5. Identify the actual implementation and integration points for:
   - `MarkdownEditor` and its text controller.
   - `MarkdownEditingController`, the Markdown tokenizer/parser, and input formatter.
   - The existing editor screen and text insertion workflow.
   - Native context-menu actions and hardware keyboard shortcuts, including paste.
   - `UndoRedoManager` and its snapshot/selection semantics.
   - Autosave and dirty-state tracking.
   - Editor preview mode and Markdown rendering.
   - Riverpod providers and application state.
   - Existing `SharedPreferences` usage and persistent user preferences.
   - Widget and unit testing conventions.

Names above come from the project's documented architecture and are search targets, not assumptions. Follow the current implementation where it differs.

Read enough surrounding code to understand the full data flow before making changes. Identify the relevant invariants and any existing regressions that your changes could trigger.

**Do not finish after reporting the audit. Proceed directly to implementation.**

## 2. Product Specification

Implement a native-feeling WhatsApp chat formatting workflow inside the existing Quiet Paper editor.

The user frequently copies conversations from WhatsApp and pastes text resembling:

```text
[21/10, 11:04 pm] Sam 3: Yeshh
[21/10, 11:04 pm] Sam 3: That's so sexyyy
[21/10, 11:04 pm] Sam 3: 😭😭😭😭 you're using her voice note
[21/10, 11:14 pm] BlackPirate: Shes goat
[21/10, 11:14 pm] BlackPirate: Yessh
[21/10, 11:17 pm] BlackPirate: im starting to understand why iphone apps take more space than their android counterpart.
[21/10, 11:51 pm] Sam 3: I agree
[21/10, 11:51 pm] Sam 3: And what did you understand
[22/10, 5:06 am] BlackPirate: IPhone apps have attention to detail so they have much more code than usual
[22/10, 5:18 am] BlackPirate: Lemme do the public site of urs first.
```

The application should recognize the pasted conversation and offer to format it into a readable, editorially styled Markdown transcript.

The core flow is:

1. The user pastes a WhatsApp conversation into a note.
2. Quiet Paper detects that the newly pasted text is probably a WhatsApp export.
3. A subtle, dismissible inline suggestion appears: “WhatsApp conversation detected,” with a message count and a **Preview** action.
4. The user opens a preview and reviews the transformed conversation and available options.
5. The user explicitly chooses **Apply format**.
6. Only the intended pasted range is transformed. All unrelated note content stays intact.
7. The edit enters the existing undo, autosave, and note-version workflows.
8. The user can undo the formatting or dismiss the suggestion without applying it.

Never automatically transform a paste. Never mutate the note merely because detection succeeded.

## 3. Approved Design Direction

Use the supplied interactive mockup screenshot as a visual reference and inspect the actual application's existing UI before implementation.

The feature must feel like an organic extension of Quiet Paper, not an independent application or generic chat formatter.

Preserve these established design characteristics:

- Warm off-white and paper-toned backgrounds.
- Restrained coral accents.
- Fine, low-contrast dividers.
- Minimal elevation and restrained rounded corners.
- Editorial typography consistent with the existing note editor.
- Generous whitespace and clear typographic hierarchy.
- Existing iconography, spacing tokens, theme colors, and responsive layout conventions.

### Inline detection suggestion

The detection notice should be integrated into the existing editor's layout. It should be noticeable enough to discover, but substantially quieter than a conventional notification banner.

It should contain a restrained conversation icon, a concise detection label, a message count when reliable, and a Preview action. Dismissal should be easy.

Avoid large colored cards, oversized illustrations, decorative hero sections, chat bubbles in the actual note, and unnecessary full-screen navigation.

### Preview interface

The preview should use an existing modal, sheet, dialog, or responsive editor-side panel where appropriate. Verify the current navigation and layout architecture before selecting the integration point.

The preview should show the transformed transcript using the application's actual typography and Markdown conventions.

Include:

- A compact title or descriptive header.
- A readable, date-grouped transcript.
- Clearly distinguishable sender names.
- Every message timestamp.
- A subtle indication when some lines could not be confidently parsed.
- Formatting options with restrained controls.
- An explicit primary action: **Apply format**.
- A cancellation or close action that leaves the original text unchanged.

On phones, the interface must adapt to the available width and software keyboard. On desktop and tablet, it should integrate into the existing three-pane editor rather than introducing an unrelated page layout.

The screenshot is a design guide, not an excuse to hardcode a static rendering. Build the real interface with real state and working controls.

## 4. Parsing and Format Recognition

Build a deterministic, locally executed parser capable of handling the user's supplied format and common WhatsApp exported-chat formats with 12-hour and 24-hour timestamps.

Support realistic variations, including:

- Bracketed timestamps such as `[21/10, 11:04 pm]`.
- Non-breaking and narrow non-breaking spaces.
- AM/PM case variations.
- 24-hour times.
- Common exported-chat headers in which the date and time are followed by a sender separator rather than enclosing brackets.
- Optional year and seconds fields where supported by the recognized format.
- LF and CRLF line endings.
- Sender names containing spaces and other normal punctuation.
- Message bodies containing colons, emojis, Unicode text, URLs, and Markdown-sensitive characters.
- Messages spanning multiple lines.
- Multiple consecutive messages from the same sender.
- Date transitions.
- Common media placeholders and system messages.

Do not attempt to support every possible localized WhatsApp format through one enormous regular expression. Implement clear, independently testable recognition strategies.

Do not make unnecessary assumptions about regional date conventions. Preserve the original date label instead of silently converting an ambiguous date into a different date.

### Parser architecture

Implement a dedicated parser with immutable or otherwise safely managed result models. Adapt the precise names and file placement to the repository's conventions.

The parsed representation should provide, as needed:

- The recognized original date text.
- The original timestamp text.
- The sender name.
- The exact message body.
- The original source range.
- Parse confidence or equivalent recognition status.
- Unrecognized or ambiguous lines and their original ordering.

Use a real parser model rather than embedding detection, parsing, Markdown generation, and UI state in the editor widget.

### Message boundaries and continuation lines

A recognized message header starts a message. Subsequent lines without a recognized header normally belong to that message until the next recognized header.

However, system messages, malformed headers, standalone notices, and other unrecognized content must not disappear. Where the parser cannot confidently classify a line, preserve it in the result and mark the parsing uncertainty.

Preserve the user's source text. Do not normalize spelling, punctuation, emojis, capitalization, or message content.

### Safe detection

Use a confidence threshold to avoid triggering the feature for ordinary notes that happen to contain timestamps or bracketed text.

Test the detection criteria against representative real chat samples. Prefer no suggestion over an incorrect suggestion.

When uncertain content exists, show a concise warning such as “Some lines couldn't be identified and will be preserved.”

Never invent a sender, timestamp, date, or message boundary.

## 5. Markdown Formatting Rules

Generate ordinary Markdown compatible with Quiet Paper's current editor and preview renderer.

The required structure is:

1. Group messages by their original date, using headings for date boundaries.
2. Group consecutive messages from the same sender on that date.
3. Display sender names as visually distinct labels.
4. Preserve every individual message timestamp.
5. Preserve message ordering exactly.
6. Preserve all message text, emojis, links, newlines, and media placeholders.
7. Preserve unrecognized material without silently discarding or reordering it.

A representative output is:

```markdown
### 21/10

**Sam 3**
_11:04 pm_ · Yeshh
_11:04 pm_ · That's so sexyyy
_11:04 pm_ · 😭😭😭😭 you're using her voice note

**BlackPirate**
_11:14 pm_ · Shes goat
_11:14 pm_ · Yessh
```

This example illustrates the formatting direction; the implementation must handle all parsed messages, not just this fragment.

### Markdown escaping and rendering integrity

Message contents must remain readable exactly as the original text intended.

Do not let a message accidentally become a heading, checkbox, blockquote, list item, emphasis span, or code block merely because it contains Markdown-looking text.

Implement appropriate escaping or use the project's established Markdown helpers, with tests confirming that escaped text renders correctly. Do not introduce transformations that corrupt URLs, Unicode, emoji, or intended line breaks.

Use the existing Markdown rendering implementation and theme styles. Do not create a second Markdown renderer or a separate rich-text data format.

Keep the original source text recoverable through undo.

## 6. Paste Detection and Editor Integration

This is one of the most important parts of the implementation.

Do not implement detection as a generic listener that treats every text change as a paste.

Inspect the real Flutter input architecture and identify a reliable way to identify pasted content and its intended insertion or replacement range.

Account for the actual paste entry points supported by the application:

- Native mobile text-selection/context-menu paste.
- Hardware keyboard paste shortcuts where supported.
- Any custom paste action already implemented in the editor.
- Other editor pathways that demonstrably produce paste events.

Reuse existing abstractions where possible.

If Flutter's standard editing APIs do not expose paste provenance directly in a particular pathway, implement the narrowest reliable alternative for that pathway. Document the trade-off and test it. Do not read or poll the system clipboard merely to guess that a paste occurred.

Avoid triggering on ordinary typing, cursor movement, selection changes, programmatic Markdown formatting, undo/redo, or keyboard IME composing updates.

If a pasted region is inserted inside a larger note, recognize and track the candidate region without modifying surrounding text.

If the current implementation cannot reliably identify a paste range, do not use a broad whole-document diff as an excuse to modify arbitrary content. Add appropriate range validation and conservative fallbacks.

### Stale suggestion protection

A pending suggestion must be associated with the exact candidate content and its editor context.

Before opening the preview and again before applying, confirm that the target text still matches the detected range.

If the user has edited or replaced that range, discard or recompute the stale suggestion. Never silently overwrite newer edits.

If the user dismisses the suggestion, do not immediately display the same suggestion again for the identical pasted region.

Prevent recursive detection when the formatter applies its own programmatic text update.

## 7. Atomic Editing, Undo, Autosave, and Version History

The transformation must integrate with the existing editor behavior rather than bypass it.

Before implementing the apply operation, inspect the current controller, text selection mapping, undo manager, editor notifier, repository, and autosave lifecycle.

When the user applies formatting:

- Replace only the intended source range.
- Preserve all text outside that range.
- Compute and restore a valid caret or selection position after the transformed text.
- Maintain the Markdown editor's source-character-to-cursor mapping invariant.
- Record one logical, atomic undo operation for the transformation.
- Ensure Redo restores the formatted result.
- Mark the note dirty using the existing mechanism.
- Allow the existing autosave and note-version workflow to process the change normally.
- Ensure ordinary edits and existing formatting operations remain unaffected.

Do not update SQLite directly from the preview UI or create a separate save pathway for this feature.

Do not interfere with Android IME composition, native undo behavior outside the established history manager, selection-aware toolbar operations, or existing editor keyboard shortcuts.

If the existing undo manager needs a small, reusable API enhancement to record an atomic replacement, implement and test that enhancement rather than simulating undo with ad hoc string replacement.

## 8. Title Behavior

Implement the approved title policy:

- Formatting an existing note must never silently change its title.
- For a new untitled note, the application may propose a descriptive title based on the detected conversation.
- The user must explicitly approve the proposed title before it is applied.
- Cancelling title editing leaves the title unchanged.
- Empty or ambiguous participant information must yield a safe generic suggestion instead of fabricated information.

Do not couple title generation to the Markdown heading unless the existing application architecture explicitly uses that approach. Respect Quiet Paper's current distinction between note titles and note bodies.

Verify whether the current editor supports pending new drafts and whether title changes are autosaved. Implement through the existing lifecycle.

## 9. Persistent Formatting Preferences

Persist the approved formatting preferences locally on the device using the application's existing preference conventions.

The chosen defaults are:

- Detection and preview before applying: enabled.
- Sender names: shown.
- Date headings: enabled.
- Consecutive same-sender messages grouped by date: enabled.
- Every message timestamp: preserved.
- Existing note title: never automatically overwritten.
- New untitled-note title: suggestion requires approval.
- Supported formats: supplied bracketed format plus common WhatsApp export formats.
- Unrecognized lines: preserved, with warnings when necessary.

Store only preference data. Do not store message content, parsed transcripts, or clipboard contents in preferences.

Use a versioned key if consistent with project conventions, and provide sensible defaults for existing installations without requiring a migration.

The formatter must remain usable offline. Preferences must survive application restarts.

If the feature needs additional options in its preview, make them meaningful and connect them to the real transformation; do not add decorative or inert controls.

## 10. Suggested Component Boundaries

Use the repository's current directory conventions. The following is a proposed separation of responsibilities, not a requirement to duplicate existing infrastructure.

- A WhatsApp chat parser for detection, parsing, and uncertainty reporting.
- A message/result model for source ranges and message metadata.
- A Markdown formatter that transforms parsed results into safe Markdown.
- A paste-detection coordinator integrated with the editor's actual paste flow.
- An inline detection suggestion.
- A preview UI with real formatting controls and Apply/Cancel behavior.
- A preference model/provider for persisted formatting settings.
- A narrow editor integration point for atomic range replacement and undo.

Avoid large, monolithic widgets. Keep parsing and formatting pure where possible so they can be exhaustively unit tested.

Do not introduce unnecessary dependencies or restructure unrelated editor architecture.

## 11. Production-Quality Test Requirements

Add meaningful tests to the repository's existing testing conventions. Do not merely modify old assertions to make failing tests pass.

### Parser unit tests

Cover:

- The exact user-supplied sample, including narrow non-breaking spaces.
- Bracketed 12-hour timestamps.
- Common 24-hour exports.
- Supported optional year and seconds variants.
- Sender names with spaces.
- Multiple consecutive messages from one sender.
- Date transitions.
- Multiline messages.
- Colons inside message bodies.
- Emojis, non-Latin Unicode, URLs, and unusual punctuation.
- CRLF and LF inputs.
- System notices and media placeholders.
- Unrecognized headers and ambiguous text.
- Malformed and incomplete input.
- Empty input and input that should not trigger detection.
- Message ordering and exact text preservation.

### Formatter unit tests

Cover:

- Date-heading generation and grouping.
- Timestamp preservation for every message.
- Group boundaries when the sender changes or the date changes.
- Whitespace preservation.
- Markdown-looking message text.
- Safe treatment of lists, headings, checkboxes, code fences, and formatting delimiters inside message bodies.
- Lossless treatment of Unicode and emoji.
- Preservation and positioning of unrecognized material.
- Consistent output on repeated formatting.
- Correct preservation of the source text required for undo.

### Editor and widget tests

Cover:

- A real paste triggers the suggestion.
- Ordinary typing does not trigger a suggestion.
- Selection changes and IME composition do not trigger it.
- Pasting over selected text.
- Pasting inside an existing note.
- Preview accurately reflecting the intended transformation.
- Changing options updating the preview.
- Applying formatting changes only the intended region.
- Cancelling or dismissing leaving the text unchanged.
- Unknown-line warnings appearing when appropriate.
- A title suggestion never overwriting an existing note title.
- Atomic undo and redo.
- Autosave and dirty-state integration.
- Stale suggestion invalidation.
- Repeated pastes and duplicate-prompt suppression.
- Preferences surviving provider/application reconstruction.
- Phone, tablet, and desktop layouts without overflow.
- Theme compatibility in both light and dark modes.
- Existing editor features remaining operational.

Use fake repositories and isolated test databases where appropriate. Do not access production credentials or real user data during tests.

## 12. Accessibility, Performance, and Reliability

The feature must remain local-first and lightweight.

- No network requests or backend changes.
- No cloud API dependency.
- No clipboard polling.
- No expensive parsing on every character typed.
- No blocking operations on the UI thread for realistic chat sizes.
- No forced title changes or data loss.
- Accessible action labels and keyboard navigation.
- Adequate touch targets and readable text.
- Correct software-keyboard handling and scroll behavior.
- Stable theme-aware rendering.
- Clear, nontechnical feedback when parsing is incomplete.

Avoid premature optimization. Parsing should happen once for a candidate paste and be reused for preview and formatting while its source remains unchanged.

## 13. Regression and Security Requirements

Preserve existing Quiet Paper invariants:

- Markdown is the canonical note representation.
- Editing maintains accurate source indices and selection positions.
- Existing autosave and persistence remain the sole path for saving edits.
- No plaintext transcript is copied to logs or persistent preferences.
- E2EE encryption and synchronization remain unchanged.
- Existing notes require no schema migration.
- Existing versions and conflict handling remain functional.
- No user data outside the selected paste range is modified.

Do not reformat unrelated source files or make broad architectural changes just to accommodate this feature.

Inspect any potentially sensitive debugging or error-reporting paths. Avoid logging actual chat messages.

## 14. Final Verification — Mandatory

After implementation:

1. Run the focused parser, formatter, and editor tests.
2. Run the full Flutter test suite.
3. Run `flutter analyze`.
4. Run any relevant code generation commands only if the actual implementation requires them.
5. Run a production-relevant build or platform-specific checks supported by the available environment.
6. Fix all failures introduced by the feature.
7. Inspect the final diff for unintended changes, generated artifacts, accidental secrets, debug logging, temporary code, and unrelated modifications.
8. Check both light and dark themes and representative phone and wide-screen layouts through available widget or integration tests.

Do not claim a command passed unless it was actually executed and its exit status verified.

Do not weaken existing tests, remove relevant regression coverage, suppress analysis warnings indiscriminately, or omit failures from the final report.

If some environment-dependent check cannot run, state the exact command and concrete reason. Do not represent an untested result as production-verified.

### Definition of done

The task is complete only when:

- The real editor detects qualifying WhatsApp pastes.
- The suggestion and preview work with real input.
- The approved transformations can be applied and undone.
- Unknown material is preserved and flagged.
- User preferences persist.
- The feature uses the existing editor, Markdown, persistence, and sync architecture.
- Automated regression tests exist and relevant tests pass.
- Static analysis is clean, or pre-existing unrelated issues are clearly identified.
- The final source diff contains the actual completed implementation, not a proposal.

## 15. Required Final Response

After finishing the work, provide a concise implementation report covering:

1. The relevant architecture you verified before implementation.
2. The features implemented and the important behavioral details.
3. The exact files changed and why.
4. The tests added and commands actually executed, including their results.
5. Any remaining limitations, with precise reasons.
6. Any relevant build or environment checks that could not run.

Be explicit about any deviation from the approved requirements.

**Begin now. Inspect the repository, implement the feature end to end, run verification, and report the actual result. Do not stop at planning or ask for approval for the already-specified product behavior.**
