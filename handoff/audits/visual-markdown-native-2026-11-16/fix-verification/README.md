# Native fix verification — November 16, 2026

Application source: `443bc87` on `fix/visual-markdown-editor-input`. All eight
findings (5–12) pass their original native failure sequences. The isolated
GTK/Wayland EditorScreen used an in-memory database, mock SharedPreferences,
a separate D-Bus session and temporary XDG directories. No personal note data
or installed application files were changed.

[`native-results.jsonl`](native-results.jsonl) contains 20 observations across
12 cases, including one excluded click-timing observation and a deliberate
repeat. Every observation has an empty Flutter error array. Match both case and
step; each reset starts a new synthetic note.

| Finding | Native proof |
| --- | --- |
| 12 | Case 2: valid saved JSON before Math, supported AST insertion afterward, immediate formula typing; JSON decoding succeeds throughout |
| 11 | Case 3: empty-note Math focuses its formula field, selects offsets 0–8, immediately types and saves `x` |
| 5 | Case 4: click Tail without arrow movement synchronizes block 2/offset 4; Divider and `after` land below Tail |
| 6 | Cases 6–7: settled Dart selection retains `printx`; cancelling the picker retains input and saves `printxy` |
| 7 | Case 8: plain Markdown Undo retains focused offset 0; Redo and native typing save `history probex`. Case 9 repeats with code fences |
| 9 | Case 10: menu Tag and immediate native typing save `#nativeaudit` |
| 10 | Case 11: menu Link Note saves `[[Other`; selecting Other note replaces the query with its `qp://note/audit-reference` link |
| 8 | Cases 12–13: edited paragraph and code switch through More options → Edit Markdown; continued native typing saves, body stays onscreen, no disposed-controller exceptions |

Case 5 is excluded from language-selection verification: the driver clicked
before the language picker animation settled and chose Plain Text instead of
Dart. It still retained code typing, but its language assertion failed. Case 6
repeated deliberately with settled coordinates; batch 2 was then repeated with
an explicit animation wait and every assertion passed. No Flutter runtime
failure occurred, so a process restart was unnecessary. An exploratory attempt
to select Python stopped because that row was outside the visible picker list;
it produced no recorded observation and did not mutate the document.

The preserved driver discovers the audit executable window by its exact `/proc`
executable path, rather than reusing the old audit's window address. Replay
scripts are `batch1.py.txt`, `batch2.py.txt`, and `batch3.py.txt`; they import the
preserved `driver.py.txt` (copy to `qp_native_fixes_driver.py` before use). The
original `../harness.dart.txt` was copied to a temporary Dart target for building.

Automated validation: `flutter analyze --no-pub` has no issues. Only the three
relevant files were run: rich document controller (15 tests), Visual stability
(15), and dual-mode EditorScreen (22). All 52 distinct tests pass across the
per-fix runs; no full test suite was run. Earlier per-fix counts and commands are
recorded with each resolution and engineering logs 287–295.

Visual Math uses the existing editable code input with `language: math`, exports
as a math fence and retains valid rich JSON. Its placeholder is selected for
replacement. Rendered Visual formula parity is outside this fix pass; Super
Editor retains its separate formula component. The original audit's remaining
attachment/speech/export/table/platform coverage limits also remain unchanged.

The isolated audit process group was terminated after verification. The ordinary
`lib/main.dart` Linux debug bundle was rebuilt successfully afterward.


## CI code-insertion focus follow-up

The reported code-insertion focus failure at test line 172 matches the
intermediate version around `59cdc03`. Publishing the field selection on every
focus gain could overwrite the AST's programmatic code-block destination.
`74aa61a` restricts reconciliation to tap completion, preserving programmatic
focus. The [GitHub run for that correction](https://github.com/blackpirateapps/quitepaper/actions/runs/43818439696)
completed successfully; its log explicitly records the reported Visual code
insertion/history test passing. No additional production change was needed.

Rechecked source `53539aa`: `flutter analyze --no-pub` is clean;
`flutter test --no-pub test/editor/dual_mode_editor_screen_test.dart
test/editor/visual_editor_stability_test.dart` passes all 37 relevant tests.
The full suite was not rerun locally. Newer CI runs were still in progress when
this follow-up was recorded; the successful run cited above is for `74aa61a`.
