# Checklist fix verification

CL-09: fresh isolated Linux debug process; native Enter/type at the original 65ms-per-key driver delay produces exactly Seed and t1 through t40. All 41 task texts, destination focus/caret and saved JSON verified; no Flutter runtime errors. Raw snapshot: `cl09-native.jsonl.gz`. The regression also injects queued old-buffer updates and asserts the mounted EditableText state survives each split.

CL-10: native Ctrl+V at the end of Alpha yields exactly Alpha, Beta, checked Gamma, Neighbor. Verified saved JSON after four seconds, correct Gamma caret and exact tasks after reopening. Both observations have zero Flutter errors; see `cl10-native.jsonl.gz`.

CL-12: the original 250-task native control (ten Down presses, 350ms extra between keys) reaches Task 0010 at offset 9. Verified every original label remains exact and zero Flutter errors; see `cl12-native.jsonl.gz`. Selection-only reconciliation skips the full surface; navigation retains the active input client. Widget coverage also checks each repeat event, reverse navigation and the same EditableText state.

CL-11: both ordinary and folded lists retain the exact Tail paragraph and its offset-zero caret after native Home; saved Markdown stays unchanged. All four before/after observations have zero Flutter errors; see `cl11-native.jsonl.gz`. The pre-fix nonfolded control reproduced `. TailTail`.

Replay scripts `cl09-native.py.txt`, `cl10-native.py.txt`, `cl11-native.py.txt` and `cl12-native.py.txt` use the preserved `native-replay/harness.dart.txt`, `qp_checklist_driver3.py.txt`, `qp_checklist_helpers3.py.txt` and isolated-process launcher. Extract them to /tmp with their .txt suffixes removed, build the harness target, launch its isolated synthetic-note window and run each case after the server/window is ready. These scripts assert exact content/focus instead of only row counts. Native scope is Linux debug under Hyprland; physical mobile/CJK sessions and release profiling were not run.

Per-fix local verification used only relevant test files, plus `flutter analyze`
with no diagnostics. No full local suite was run. CL-11's final Super Editor run
passes 65 tests. A follow-up run of `editor_image_upload_compression_test.dart`
and `dual_mode_editor_screen_test.dart` passes all 32 tests after an earlier full
CI run (`7e927e2`, run 43838102377) timed out in the image-compression widget test.
That CI failure was `pumpAndSettle` after a fixed 200ms wait, not a checklist
assertion. Latest-commit full-suite status is available in GitHub Actions.
