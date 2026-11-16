# Native Visual / Markdown re-audit — durable checkpoint

Date: 2026-11-16. Branch: `fix/visual-markdown-editor-input`.
Audited application source: `1bc137c`. This is an audit record; no production
fixes have been applied. The current local `AGENTS.md` requires relevant tests
only, rather than another full-suite run.

## Resume here after compaction

The real Linux GTK/Wayland EditorScreen was exercised using Hyprland native mouse
and keyboard events, an in-memory database, mock SharedPreferences, a separate
D-Bus session and temporary XDG directories. Four additional bugs are confirmed
below. Complete remaining fresh-process checks before finalizing coverage.

Evidence is preserved beside this report, rather than relying on `/tmp` or chat:

- `phase1-results.jsonl`: all 103 original observation records, including setup
  and exploratory records. Use the step names below to find authoritative cases.
- `phase1-errors.json`: captured Flutter exception messages and complete stacks.
- `snapshots/`: isolated application captures; no personal notes are present.
- `harness.dart.txt` and `driver.py.txt`: exact session harness and native-input
  driver. Other `*.py.txt` files preserve the executed audit sweeps.

The raw results contain exploratory observations and cumulative error arrays.
An error attached to a state is not necessarily from that state's case. Match
each error's `case` field, and apply the exclusions below.

## Confirmed new finding 5 — Visual click leaves the document caret on another block

Severity: high; formatting/insertion can affect the wrong part of the note.

Reproduction:

1. Open a Visual note containing `Before`, a checklist item `task`, then `Tail`.
2. Click at the end of `Tail` without typing or moving the caret with an arrow key.
3. Click the toolbar Divider button, then type `after` without another click.

Actual: the focused Tail field reports a caret at offset 4, but the authoritative
document selection still points to block 0 (`Before`), offset 0. The divider and
`after` are inserted after `Before`, above the checklist and `Tail`.

Expected: insertion follows the visibly clicked Tail caret.

Evidence: case 11, steps `pointer frame flushed Tail click`, `pointer frame
flushed divider click`, and `pointer frame flushed divider typing`. These were
recorded with no runtime errors. Additional repeats exist, including case 46;
prefer case 11 because it precedes the later mode-switch crash.

Control: case 13, `verified divider native caret movement before insertion` and
`verified divider continuation with synchronized caret`. Pressing Left then
Right after clicking Tail synchronizes the AST selection; the divider then lands
after Tail and continued typing works below it. The original divider continuation
focus fix passes with a synchronized document selection.

Likely investigation area, not a proven fix: `RichTextEditor._onFocusChanged`
publishes the active target, while selection reconciliation in
`_onTextControllerChanged` is gated on field focus. Check native click ordering.

## Confirmed new finding 6 — Visual code language selection loses typing focus

Severity: medium; subsequent keystrokes are silently dropped.

Reproduction:

1. Insert a Visual code block and type `print`.
2. Click its Plain Text language control and select Dart.
3. Immediately type `x` without clicking the code field again.

Actual: the language is saved as `dart`, but all body fields are unfocused and
the code remains `print`; `x` is lost. The initial code insertion/focus/save fix
itself passes.

Expected: the code field regains keyboard focus and its prior caret after the
language selector closes, allowing `printx` to be entered.

Evidence: case 15, `verified visual code immediate native typing` and `verified
visual code typing immediately after language choice`. Independently repeated
with an existing Dart block changed to Python in case 18, `confirmed visual
existing code language drops subsequent typing`.

Control: `confirmed visual code click restores typing after language choice`
shows that clicking the code field and typing x saves `printx` correctly.

Likely investigation area: `RichCodeBlock._changeLanguage` commits the selected
language but does not explicitly restore the code FocusNode.

## Confirmed new finding 7 — Markdown toolbar undo/redo loses typing focus

Severity: medium; subsequent keystrokes are silently dropped.

Reproduction:

1. In a fresh Markdown note, type `history probe`.
2. Click toolbar Undo, then toolbar Redo.
3. Immediately type `x` without clicking the body again.

Actual: Undo and Redo change and restore the saved content, but the restored body
is unfocused. The text remains `history probe`; the x is lost. Undo in the plain
note also reports selection -1 before Redo restores offset 13.

Expected: history leaves the body ready for keyboard input at the restored caret.

Evidence: case 17, steps `confirmed markdown plain before toolbar undo`,
`confirmed markdown plain toolbar undo`, `confirmed markdown plain redo loses
subsequent typing`. The same symptom occurs after code insertion in case 16,
`verified markdown code typing after history`.

Control: `confirmed markdown plain click restores subsequent typing` saves
`history probex`. The original first-code-insertion input failure is fixed:
`verified markdown first code typing` saves `codeprint` with native focus intact.

Likely investigation area: Markdown branches of `EditorScreen._undo` / `_redo`
restore values but do not explicitly restore the active body input focus.

## Confirmed new finding 8 — Switching an active Visual field to Markdown crashes

Severity: high; the editor becomes unusable/offscreen.

Confirmed native reproduction from a healthy window:

1. Open a Visual note containing ordinary text and a fenced Dart code block.
2. Click the code field and type `x` after `print(1)`.
3. Open More options and choose Edit Markdown.

Actual: Flutter reports `A TextEditingController was used after being disposed`.
The stack includes `ChangeNotifier.addListener`, `_MergingListenable.addListener`
and `_AnimatedState.didUpdateWidget`. The restored title/body have global
y-coordinates around 100118 / 100185. The Markdown content is saved, but the
rendered editor is broken.

Expected: switching mode preserves the edited content and renders a usable
Markdown editor with live controllers.

Evidence: case 44, `coverage edited visual code before switching mode` and
`coverage mode conversion after active code edit`; corresponding case 44 stacks
are in `phase1-errors.json`. Earlier, the same case successfully completed a
Visual → Markdown → Visual round trip before any field was activated.

A simple paragraph (`mode probe`) then reproduced a disposed
`_RichTextEditingController` and render overflow in case 45. That repeat used a
new note in the same process after the case 44 failure. A fresh-process minimal
paragraph repeat is still pending, so case 44 is the primary confirmation.

Likely investigation area: `_switchEditingStyle` disposes Visual field controllers
without resetting `_activeTargetController` before the Markdown toolbar starts
observing it. This is a different trigger from the previously fixed Visual
toolbar undo/redo crash.

## Additional observations — not yet confirmed as independent bugs

These must not be lost, but do not count them as confirmed until clean-process
reproduction:

- Case 49, Visual Tag then `nativeaudit`, saved `nativeaudit#` instead of
  `#nativeaudit`; the caret appears to return before the inserted marker. Markdown
  case 52 saved `#nativeaudit` correctly. Repeat Visual Tag in the fresh process;
  this may be related to finding 5's selection synchronization.
- Case 53, Visual Link Note inserted `[[` with caret offset 0, and no note picker
  labels appeared. Check whether typing a note name goes before the brackets and
  whether autocomplete opens in a healthy process.
- Case 47, Visual web-link insertion displayed `site` but saved content was still
  empty at the captured observation. Framework ancestor / duplicate GlobalKey
  assertions appeared in the same case. Repeat from a healthy process; do not
  infer a link persistence bug from this run alone.
- Cases 48 and 51 inserted math delimiters and the equation placeholder. Visual
  mode's captured caret was 0; Markdown's was 12. Rendering parity and native
  continuation after Visual math insertion remain unverified.
- Deactivated-ancestor lifecycle assertions appeared later in case 53. These may
  be fallout from the earlier broken widget tree, not another editor bug.

Cases 47–53 were executed after the confirmed mode-switch crash and are
provisional. A new process was launched specifically to recheck them.

## Completed native coverage

- Original Visual code insertion now focuses, accepts native typing, and saves
  code/language. Original Visual undo/redo no longer crashes in case 14; native
  keyboard undo, toolbar redo and subsequent typing all work.
- Original divider continuation focus works once the document selection matches
  the visible caret; finding 5 describes the newly discovered click-only failure.
- Original Markdown first-code insertion accepts and saves native typing.
- Heading levels 1–6 and paragraph conversion, bold, italic, strike, inline code,
  highlight, checklist/bullet/numbered/quote continuation were exercised in both
  modes. Fresh Visual H1 was repeated successfully in case 39.
- Visual and Markdown tables: native cell activation, two-cell edits, Tab
  navigation, Done and saved surrounding content passed in cases 42–43.
- A mixed heading/emphasis/checklist/code note round-tripped between modes before
  a Visual field was activated (case 44). Active-field mode switching fails as
  documented in finding 8. Full export has not been exercised.

## Excluded automation / harness problems

- Early synthetic mouse releases were not flushed until the next pointer motion.
  Those preliminary delayed-action records are not authoritative. The driver
  was corrected to send explicit native mouse down/up followed by pointer motion;
  replayed step names above identify the confirmed results.
- Case 20's first heading-menu action called a disposed RichDocumentController
  after a programmatic reset overlapped a popup from case 19. Closing popups and
  waiting before reset eliminated it; a fresh H1 check passed. This is excluded
  as a harness teardown problem, not a new production finding.
- After the mode-switch crash, reset/reuse of the same process was no longer
  considered sufficient isolation. Later provisional observations require a
  completely fresh native process.

## Live resume state and remaining work

The first process/window was closed after preserving its raw results and errors.
A second isolated process was launched immediately before the user requested
this checkpoint. It may still be running:

- Launcher exec session: `84193` (first session `76431` has exited). The second
  process was verified alive with case 0 / zero Flutter errors: PID `45540`.
- Probe endpoint: `http://127.0.0.1:38917/state`; `/reset` accepts JSON
  `{ "style": "visual" | "markdown", "content": "...", "title": "..." }`.
- Runtime logs: `/tmp/qp-native-editor-audit-runtime-phase2.log`.
- Harness `/tmp/qp_native_editor_audit.dart`; driver
  `/tmp/qp_native_audit_driver.py`. Hyprland reused window address
  `0x55e0433d3e30` for PID `45540`, so the driver currently matches. Recheck the
  address and PID after every restart before any native input.
- Settings/data/cache are under `/tmp/qp-native-editor-audit/`; database and
  preferences are in memory. Original evidence contains only synthetic notes.
- Query Hyprland clients through escalated execution; compositor sockets and
  native app launch are outside the filesystem sandbox. Only target the isolated
  audit window. `hyprctl eval 'hl.dispatch(hl.dsp....)'` is the current Lua API.

Next steps:

1. Check the second process is alive and has no errors; update the driver's
   window address and preserve phase-two results separately.
2. Recheck provisional Tag / Link Note / web-link observations in the fresh
   process. Confirm normal inserts before reproducing the crash again.
3. Optionally finish table insertion / attachment chooser entry points, recording
   exactly which paths were actually exercised. No imports, real recording,
   transcription, model downloads or full export have been verified this pass.
4. Reproduce minimal active-paragraph Visual → Markdown switching LAST, then
   close the audit window.
5. Restore the ordinary Linux bundle with
   `flutter build linux --debug --no-pub -t lib/main.dart`: the build directory
   currently contains the audit-only executable.
6. Run `flutter analyze` and relevant editor tests only, per the current
   `AGENTS.md`. Do not run the full suite for this audit-only task.
7. Update this report / root audit / HANDOFF and engineering log with final
   findings and validation; commit and push the audit documentation. The user
   requested auditing and recording findings, not implementing these new fixes.
