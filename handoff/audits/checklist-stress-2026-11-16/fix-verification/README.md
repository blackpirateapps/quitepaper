# Checklist fix verification

CL-09: fresh isolated Linux debug process; native Enter/type at the original 65ms-per-key driver delay produces exactly Seed and t1 through t40. All 41 task texts, destination focus/caret and saved JSON verified; no Flutter runtime errors. Raw snapshot: `cl09-native.jsonl.gz`. The regression also injects queued old-buffer updates and asserts the mounted EditableText state survives each split.

CL-10: native Ctrl+V at the end of Alpha yields exactly Alpha, Beta, checked Gamma, Neighbor. Verified saved JSON after four seconds, correct Gamma caret and exact tasks after reopening. Both observations have zero Flutter errors; see `cl10-native.jsonl.gz`.

CL-12: the original 250-task native control (ten Down presses, 350ms extra between keys) reaches Task 0010 at offset 9. Verified every original label remains exact and zero Flutter errors; see `cl12-native.jsonl.gz`. Selection-only reconciliation skips the full surface; navigation retains the active input client. Widget coverage also checks each repeat event, reverse navigation and the same EditableText state.
