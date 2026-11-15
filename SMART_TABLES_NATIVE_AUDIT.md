# Smart Tables native laptop audit

Date: 2026-11-15. Branch: `fix/smart-tables-native`.
Application source under test: `96a6948`, prepared PR #4 Smart Tables/math
integration. The original checkout (`fix/visual-markdown-editor-input`, `4ea7481`)
does not contain Smart Tables. **No application fixes were made**, as requested.

## Current result

The completed live-app checks pass formulas, recalculation, persistence, summary
rows, calculated columns, range summaries, formatted currency, bulk undo/redo,
expanded-editor return history, mode reopening and error display. No independent
production correctness bug was confirmed in those checks.

Initial native mouse/keyboard sequences did not complete reliably. Their evidence
is retained below rather than discarded or presented as proven application bugs.
A stable-focus native replacement and one native Tab transition subsequently
passed. Complete rapid-click and hardware navigation certification remains open.

| ID | Observation | Current status |
| --- | --- | --- |
| ST-NATIVE-01 | Cell not active before immediate typing; activation appears later | Unconfirmed activation/timing issue; automation or focus targeting remains possible |
| ST-NATIVE-02 | Replacement input initially leaves cell/source unchanged | Not an independent confirmed bug: native typing passes after focus and selection are verified |
| ST-NATIVE-03 | First save changes two newlines before table to four | Stable formatting normalization on subsequent reopen/edit; not cumulative corruption |
| ST-DRIVER-01 | VM-assigned INR appears in dialog but Apply retains USD | Driver/onChanged path limitation; real native keyboard entry and Apply persist INR correctly |

## Method and isolation

Opened the actual `EditorScreen` in a Linux GTK debug window under this laptop's
Hyprland/Wayland session. The temporary Dart entrypoint uses a dedicated SQLite
profile at `/tmp/qp-smart-table-native-profile` and mock preferences. Note writes
are isolated from personal notes. The installed app was not replaced.

Dart VM service extensions inspect widget text, cell focus/selection, table
projections, metadata and saved content. Separate fixture extensions reset/reopen
synthetic notes. Native keystrokes and pointer events use Hyprland. Additional
VM-driven checks invoke actual mounted widget callbacks and table controllers in
the running window; these are distinguished from native input below. No
WidgetTester runs drive the live window.

Launch:

```sh
dbus-run-session -- flutter run -d linux --no-pub -t /tmp/qp_tables_native.dart
```

The separate D-Bus session matters: the runner's `G_APPLICATION_DEFAULT_FLAGS`
caused an ordinary launch to activate the installed single-instance application,
preventing a new debugger connection. That first launch is a test-launch issue,
not a table failure. The isolated instance successfully exposes its Dart VM.

A second `flutter attach -d linux --no-dds --debug-url=<current VM service URL>
-t /tmp/qp_tables_native.dart` process supplies hot reload/restart. Source
expression `evaluate` returned “No compilation service available”; registered
Dart service extensions work and were used instead. Reloaded code is only the
/tmp fixture, not production editor code.

## Fixture

```markdown
Before table.

| Item | Qty | Unit price | Total |
| --- | ---: | ---: | ---: |
| Paper | 2 | 125 | =B2*C2 |
| Pens | 3 | 40 | =B3*C3 |
| Total | | | =SUM(D2:D3) |

After table.
```

[Initial native render](handoff/audits/smart-tables-native/initial-render.png)
correctly shows 250, 120 and 370. Saved source retains the formulas. This fixture's
last row is initially an ordinary formula row; automatic summary behavior is
checked separately by creating a designated row through the real menu callback.

## ST-NATIVE-01 — Activation not ready before immediate typing

Status: needs controlled native reproduction. Impact if confirmed: high for the
basic click-to-edit workflow. Do not assign a production cause yet.

Attempted twice:

1. Load the fixture in Super Editor mode.
2. Read the rendered B2 `2` coordinates from the live widget tree.
3. Move the pointer and click B2.
4. Inspect state after the scripted settling interval.
5. Send native Ctrl+A and `4`.

The first `click Qty B2` snapshots still contain an inactive table view and no
cell field. In the first attempt, it stays inactive after typing. A later
unrelated diagnostic click targeting the app menu coincides with B2 becoming
active, but its field has no primary focus. In the repeated attempt, B2 finally
appears active/focused after typing, still containing 2.

Expected: activation and input ownership precede normal subsequent keystrokes.
Expected after typing 4: D2 = 500 and D4 = 620.

Evidence: ordered `click Qty B2`, `native edit B2 from 2 to 4`, and
`diagnostic app menu click` entries in
[observations.json](handoff/audits/smart-tables-native/observations.json), plus the
[activation screenshot](handoff/audits/smart-tables-native/delayed-cell-activation.png).

Possible explanations to separate: compositor event timing, window resizing or
background focus, SuperEditor gesture ownership, and the newly mounted cell's
focus/input handoff. A 350 ms pointer-motion pause did not make the initial full
sequence pass. This alone does not establish that an ordinary human click fails.

Next: keep the test window explicitly foregrounded; verify the initial cell and
focus before every key; timestamp the click and focus transition; repeat manually.
Do not treat events sent while Codex/another window has native focus as proof of
an application keyboard bug.

## ST-NATIVE-02 — Initial replacement failure, later stable-focus pass

The repeated failed attempt reports B2 focused with text 2, caret offset 1,
results 250/370, and unchanged saved source after the attempted Ctrl+A/4 sequence.
This is a real failed automated end-to-end attempt, but focus may have arrived
only after those events.

A separate probe explicitly foregrounded the window, waited for B2 primary focus,
sent native Ctrl+A, verified a selection from 0 to 1, then sent native 4. This
**passed without application changes**: field/source B2 = 4, D2 = 500 and D4 = 620,
with both original formulas retained. See
[stable-focus native edit](handoff/audits/smart-tables-native/stable-focus-native-edit.png)
and the corresponding before/after observations.

One focused native Tab retry passed B2→C2 with C2 selected. Another sequence made
an unexpected transition from a changed initial/focus state and timed out while
waiting for the assumed cell. Retain that as unresolved driver/navigation
coverage, not an independent confirmed Tab bug. Shift+Tab, Enter, Escape, arrows
and rapid typing are not fully certified by these native attempts.

## ST-NATIVE-03 — One-time source spacing normalization

The first cell save changes `Before table.\n\n|` to
`Before table.\n\n\n\n|`. This is a visible source-formatting difference worth
retaining for review of normalization policy. It is not proven content loss.

Two subsequent actual editor reopen/edit cycles (B2 = 5 then 6) retain four
newlines; spacing does not grow on those repetitions. Formula results 745 and
870 and saved raw formulas are correct. Do not report cumulative blank-line
corruption based on the initial observation.

## ST-DRIVER-01 — Currency probe false positive

VM-driven field assignment showed INR in the currency dialog, but Apply retained
USD. The driver initially omitted normal user onChanged behavior; adding a
callback to the hot-reloaded driver still did not certify that path.

A separate native keyboard probe clicked the real currency field, selected its
text, typed INR, then invoked the actual Apply callback. It **passed**: metadata
stores `currency: INR` and displayed results are ₹500.00, ₹120.00, ₹50.00 and
₹670.00. Raw formulas remain unchanged. See
[native INR result](handoff/audits/smart-tables-native/native-inr-format.png).
This is not a confirmed currency engine/dialog bug. Use native text entry or a
verified EditableText user-input path for future form-field probes.

## Completed live-app callback checks

The following run inside the real native window via `ext.qpTables.action` and
read-only state inspection. Menu/confirmation tests invoke the actual widget
callbacks; controller tests invoke the mounted table controller. They certify
live integration, not physical pointer/clipboard behavior for every operation.

| Check | Observed result |
| --- | --- |
| Formula/raw-source editing | B2 changes recalculate results while `=B2*C2` and SUM source remain stored |
| SQLite save/reopen | Values, formulas and metadata survive repeated note reopen |
| Dart hot restart | Reloading the saved note by ID restores exact source, summary and calculated-column intent |
| Create summary through Smart Tables menu callback | Designated final SUM row displays 620 |
| Calculated-column confirmation | Actual confirmation stores template `=B2*C2` |
| Append before summary through bounded paste operation | Notebook / 1 / 50 receives `=B4*C4`; summary expands to `=SUM(D2:D4)` and displays 670 |
| Atomic bulk undo/redo | One undo restores exact prior source, dimensions and metadata; redo restores Notebook and 670 |
| Select data column through actual menu callback | Quick summary shows Sum 670, Count 3 |
| Expanded editor return | Editing quantity to 7 yields ₹1,045.00 on return; one inline undo restores ₹670.00 and redo restores ₹1,045.00 |
| Reopen Markdown mode | Raw formulas/annotation and formatted totals remain available in its hybrid table editor |
| Reopen legacy Visual mode | Formula cells, summary/calculated intent and INR presentation render correctly |
| Dark Super Editor | Formula editing and INR results render correctly; screenshot inspected |
| Error and literal display | `=1/0` → #DIV/0!, two-cell cycle → #CYCLE!, apostrophe-leading formula displays literally |

Screenshots: [summary/calculated column](handoff/audits/smart-tables-native/summary-calculated-column.png),
[dark formatted table](handoff/audits/smart-tables-native/dark-formatted-table.png).

## Remaining limits

- Complete native rapid click/type and hardware navigation remain unresolved.
- Full native OS clipboard round trips, table creation from the top toolbar,
  every row/column menu operation, percentage/decimal dialog choices and manual
  narrow-window resizing were not exhaustively checked here.
- Mode reopening was checked; edits in every mode followed by every conversion
  direction are not claimed as complete live coverage.
- Android, real multi-device networking, exports, screen readers and actual
  process kill/relaunch remain outside this laptop session. Persistence across a
  real Dart isolate hot restart and SQLite reload was checked.
- The private D-Bus session reports AT-SPI and libsecret/keyring warnings. Secure
  fallback resolves into the temporary profile; no personal-note writes or
  application runtime exceptions were observed. Do not call those environment
  warnings formula errors or claim screen-reader certification.

## Durable evidence and resumption

Artifacts contain only synthetic test notes. Ordered observations retain all
failed and successful attempts; later results above supersede tentative early
interpretations.

- [observations.json](handoff/audits/smart-tables-native/observations.json)
- [fixture.dart.txt](handoff/audits/smart-tables-native/fixture.dart.txt)
- [native_control.py.txt](handoff/audits/smart-tables-native/native_control.py.txt)
- [initial failing native script](handoff/audits/smart-tables-native/native_basic.py.txt)
- [VM core audit script](handoff/audits/smart-tables-native/vm_audit.py.txt)
- [VM remaining checks](handoff/audits/smart-tables-native/vm_remaining.py.txt)
- [saved-note resume reference](handoff/audits/smart-tables-native/resume-note.json)

Temporary working files keep the same names under `/tmp/qp_tables_*`.
Runtime log: `/tmp/qp-tables-native.log`; attach log:
`/tmp/qp-tables-native-attach.log`; initial native output:
`/tmp/qp-tables-native-basic.log`; passing core/remaining VM output:
`/tmp/qp-tables-vm-audit.log` and `/tmp/qp-tables-vm-remaining.log`.

VM extensions: `ext.qpTables.state`, `.reset`, `.reopen`, `.action`.
Read the current VM service URL from the runtime log; its access token is not
committed. Re-discover the live Hyprland instance and select the window by the VM
process PID, not the shared application class. Native input must explicitly
foreground this test window and confirm focus/state before assertions.

The synthetic main table is left open for inspection. The build directory
contains the fixture executable; close it and rebuild `lib/main.dart` before
using that bundle as a normal app. **The user requested logging findings without fixes during this pass.**

## Verification for this audit-only change

- `flutter analyze --no-pub`: no issues (21.7 seconds).
- `flutter test --no-pub test/editor/smart_tables`: all 32 passed.
- Full test suite not run, as instructed.
- `git diff --check`: clean.
- Production editor, calculation, storage and sync files are unchanged. The
  repository changes are this audit, handoff links/log and synthetic evidence.
