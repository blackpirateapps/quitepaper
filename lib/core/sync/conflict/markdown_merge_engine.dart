import 'dart:math' as math;
import 'conflict_region.dart';
import 'merge_result.dart';

class MarkdownMergeEngine {
  const MarkdownMergeEngine();

  /// Performs a deterministic 3-way merge on Markdown document content.
  MergeResult<String> merge({
    required String? base,
    required String local,
    required String remote,
  }) {
    // Fast path: local and remote are identical
    if (local == remote) {
      return MergeResult.clean(local);
    }

    // Fast path: base is empty / null
    if (base == null || base.isEmpty) {
      if (local.isEmpty) return MergeResult.clean(remote);
      if (remote.isEmpty) return MergeResult.clean(local);
      if (local == remote) return MergeResult.clean(local);
      return MergeResult.conflicted(
        mergedValue: local,
        conflictType: ConflictType.content,
        conflictRegions: [
          ConflictRegion(
            id: 'region_root',
            baseText: '',
            localText: local,
            remoteText: remote,
            startLine: 1,
            endLine: math.max(local.split('\n').length, remote.split('\n').length),
          ),
        ],
        explanation: 'Both devices created different initial note contents.',
      );
    }

    // Fast path: local unchanged from base
    if (base == local) {
      return MergeResult.clean(remote);
    }

    // Fast path: remote unchanged from base
    if (base == remote) {
      return MergeResult.clean(local);
    }

    final baseLines = _splitLines(base);
    final localLines = _splitLines(local);
    final remoteLines = _splitLines(remote);

    // Compute diffs against base
    final localEdits = _diff(baseLines, localLines);
    final remoteEdits = _diff(baseLines, remoteLines);

    final mergedLines = <String>[];
    final conflictRegions = <ConflictRegion>[];
    var currentLine = 1;
    var regionCounter = 1;

    final n = baseLines.length;

    // Handle insertions before base index 0
    final localPre = localEdits.insertionsBefore[0] ?? [];
    final remotePre = remoteEdits.insertionsBefore[0] ?? [];
    if (localPre.isNotEmpty || remotePre.isNotEmpty) {
      final res = _mergeInsertions(localPre, remotePre);
      if (res.isClean) {
        mergedLines.addAll(res.lines);
        currentLine += res.lines.length;
      } else {
        final region = ConflictRegion(
          id: 'region_$regionCounter',
          baseText: '',
          localText: localPre.join('\n'),
          remoteText: remotePre.join('\n'),
          startLine: currentLine,
          endLine: currentLine + localPre.length,
        );
        regionCounter++;
        conflictRegions.add(region);
        mergedLines.addAll(localPre);
        currentLine += localPre.length;
      }
    }

    // Walk through each base line
    var i = 0;
    while (i < n) {
      final localEdit = localEdits.lineEdits[i];
      final remoteEdit = remoteEdits.lineEdits[i];

      final localChanged = localEdit != null;
      final remoteChanged = remoteEdit != null;

      if (!localChanged && !remoteChanged) {
        // Both unchanged
        mergedLines.add(baseLines[i]);
        currentLine++;
        i++;
      } else if (localChanged && !remoteChanged) {
        // Only local changed
        mergedLines.addAll(localEdit.replacementLines);
        currentLine += localEdit.replacementLines.length;
        i += localEdit.baseCount;
      } else if (!localChanged && remoteChanged) {
        // Only remote changed
        mergedLines.addAll(remoteEdit.replacementLines);
        currentLine += remoteEdit.replacementLines.length;
        i += remoteEdit.baseCount;
      } else {
        // Both changed starting at i
        // Find extent of collision across overlapping base counts
        final localSpan = localEdit!.baseCount;
        final remoteSpan = remoteEdit!.baseCount;
        final maxSpan = math.max(localSpan, remoteSpan);

        final baseSlice = baseLines.sublist(i, i + maxSpan);
        final localSlice = _collectBranchSlice(i, maxSpan, localEdits);
        final remoteSlice = _collectBranchSlice(i, maxSpan, remoteEdits);

        if (_listEquals(localSlice, remoteSlice)) {
          mergedLines.addAll(localSlice);
          currentLine += localSlice.length;
        } else if (_isAllChecklists(baseSlice) &&
            baseSlice.length == localSlice.length &&
            baseSlice.length == remoteSlice.length) {
          final mergedChecklist = _mergeChecklistLines(baseSlice, localSlice, remoteSlice);
          if (mergedChecklist != null) {
            mergedLines.addAll(mergedChecklist);
            currentLine += mergedChecklist.length;
          } else {
            final region = ConflictRegion(
              id: 'region_$regionCounter',
              baseText: baseSlice.join('\n'),
              localText: localSlice.join('\n'),
              remoteText: remoteSlice.join('\n'),
              startLine: currentLine,
              endLine: currentLine + localSlice.length,
            );
            regionCounter++;
            conflictRegions.add(region);
            mergedLines.addAll(localSlice);
            currentLine += localSlice.length;
          }
        } else {
          final region = ConflictRegion(
            id: 'region_$regionCounter',
            baseText: baseSlice.join('\n'),
            localText: localSlice.join('\n'),
            remoteText: remoteSlice.join('\n'),
            startLine: currentLine,
            endLine: currentLine + localSlice.length,
          );
          regionCounter++;
          conflictRegions.add(region);
          mergedLines.addAll(localSlice);
          currentLine += localSlice.length;
        }

        i += maxSpan;
      }

      // Handle insertions after base line i (which is insertionsBefore[i])
      final localPost = localEdits.insertionsBefore[i] ?? [];
      final remotePost = remoteEdits.insertionsBefore[i] ?? [];
      if (localPost.isNotEmpty || remotePost.isNotEmpty) {
        final res = _mergeInsertions(localPost, remotePost);
        if (res.isClean) {
          mergedLines.addAll(res.lines);
          currentLine += res.lines.length;
        } else {
          final region = ConflictRegion(
            id: 'region_$regionCounter',
            baseText: '',
            localText: localPost.join('\n'),
            remoteText: remotePost.join('\n'),
            startLine: currentLine,
            endLine: currentLine + localPost.length,
          );
          regionCounter++;
          conflictRegions.add(region);
          mergedLines.addAll(localPost);
          currentLine += localPost.length;
        }
      }
    }

    final mergedContent = mergedLines.join('\n');

    if (conflictRegions.isEmpty) {
      return MergeResult.clean(mergedContent);
    } else {
      return MergeResult.conflicted(
        mergedValue: mergedContent,
        conflictType: ConflictType.content,
        conflictRegions: conflictRegions,
        explanation: '${conflictRegions.length} conflicting section(s) detected.',
      );
    }
  }

  List<String> _splitLines(String text) {
    if (text.isEmpty) return [];
    final normalized = text.replaceAll('\r\n', '\n');
    return normalized.split('\n');
  }

  ({bool isClean, List<String> lines}) _mergeInsertions(
    List<String> local,
    List<String> remote,
  ) {
    if (local.isEmpty) return (isClean: true, lines: remote);
    if (remote.isEmpty) return (isClean: true, lines: local);
    if (_listEquals(local, remote)) return (isClean: true, lines: local);

    // Independent insertions at same anchor point: combine both without duplicating identical lines
    final combined = List<String>.from(local);
    for (final line in remote) {
      if (!combined.contains(line)) {
        combined.add(line);
      }
    }
    return (isClean: true, lines: combined);
  }

  List<String> _collectBranchSlice(int start, int count, _BranchEdits edits) {
    final result = <String>[];
    var curr = start;
    while (curr < start + count) {
      final edit = edits.lineEdits[curr];
      if (edit != null) {
        result.addAll(edit.replacementLines);
        curr += edit.baseCount;
      } else {
        // Unchanged base line
        result.add(edits.baseLines[curr]);
        curr++;
      }
    }
    return result;
  }

  List<String>? _mergeChecklistLines(
    List<String> base,
    List<String> local,
    List<String> remote,
  ) {
    if (base.length != local.length || base.length != remote.length) {
      return null;
    }

    final result = <String>[];
    final checklistRegex = RegExp(r'^(\s*[-*+]\s+\[)([ xX])(\]\s+.*)$');

    for (var i = 0; i < base.length; i++) {
      final b = base[i];
      final l = local[i];
      final r = remote[i];

      if (l == r) {
        result.add(l);
        continue;
      }

      final bMatch = checklistRegex.firstMatch(b);
      final lMatch = checklistRegex.firstMatch(l);
      final rMatch = checklistRegex.firstMatch(r);

      if (bMatch != null && lMatch != null && rMatch != null) {
        final bPrefix = bMatch.group(1)!;
        final bSuffix = bMatch.group(3)!;
        final lPrefix = lMatch.group(1)!;
        final lSuffix = lMatch.group(3)!;
        final rPrefix = rMatch.group(1)!;
        final rSuffix = rMatch.group(3)!;

        if (bPrefix == lPrefix && bPrefix == rPrefix && bSuffix == lSuffix && bSuffix == rSuffix) {
          final bState = bMatch.group(2)!;
          final lState = lMatch.group(2)!;
          final rState = rMatch.group(2)!;

          if (bState == lState) {
            result.add(r);
          } else if (bState == rState) {
            result.add(l);
          } else {
            result.add(lState.toLowerCase() == 'x' ? l : r);
          }
          continue;
        }
      }

      if (b == l) {
        result.add(r);
      } else if (b == r) {
        result.add(l);
      } else {
        return null;
      }
    }

    return result;
  }

  _BranchEdits _diff(List<String> base, List<String> branch) {
    final n = base.length;
    final m = branch.length;

    final insertionsBefore = <int, List<String>>{};
    final lineEdits = <int, _LineEdit>{};

    if (n == 0) {
      insertionsBefore[0] = branch;
      return _BranchEdits(baseLines: base, insertionsBefore: insertionsBefore, lineEdits: lineEdits);
    }

    // Compute LCS
    final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (base[i - 1] == branch[j - 1]) {
          lcs[i][j] = lcs[i - 1][j - 1] + 1;
        } else {
          lcs[i][j] = math.max(lcs[i - 1][j], lcs[i][j - 1]);
        }
      }
    }

    // Find matches
    final matches = <({int baseIdx, int branchIdx})>[];
    var i = n;
    var j = m;
    while (i > 0 && j > 0) {
      if (base[i - 1] == branch[j - 1]) {
        matches.add((baseIdx: i - 1, branchIdx: j - 1));
        i--;
        j--;
      } else if (lcs[i - 1][j] >= lcs[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    final sortedMatches = matches.reversed.toList();

    var lastBase = 0;
    var lastBranch = 0;

    for (final match in sortedMatches) {
      final bIdx = match.baseIdx;
      final brIdx = match.branchIdx;

      if (bIdx == lastBase && brIdx > lastBranch) {
        // Pure insertion before bIdx
        final ins = branch.sublist(lastBranch, brIdx);
        insertionsBefore[bIdx] = (insertionsBefore[bIdx] ?? [])..addAll(ins);
      } else if (bIdx > lastBase) {
        // Deletion or modification of base[lastBase..bIdx]
        final rep = branch.sublist(lastBranch, brIdx);
        lineEdits[lastBase] = _LineEdit(
          baseStart: lastBase,
          baseCount: bIdx - lastBase,
          replacementLines: rep,
        );
      }

      lastBase = bIdx + 1;
      lastBranch = brIdx + 1;
    }

    if (lastBase < n) {
      final rep = branch.sublist(lastBranch, m);
      lineEdits[lastBase] = _LineEdit(
        baseStart: lastBase,
        baseCount: n - lastBase,
        replacementLines: rep,
      );
    } else if (lastBranch < m) {
      final ins = branch.sublist(lastBranch, m);
      insertionsBefore[n] = (insertionsBefore[n] ?? [])..addAll(ins);
    }

    return _BranchEdits(
      baseLines: base,
      insertionsBefore: insertionsBefore,
      lineEdits: lineEdits,
    );
  }

  bool _isAllChecklists(List<String> lines) {
    final re = RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+');
    return lines.isNotEmpty && lines.every((l) => re.hasMatch(l));
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _LineEdit {
  const _LineEdit({
    required this.baseStart,
    required this.baseCount,
    required this.replacementLines,
  });

  final int baseStart;
  final int baseCount;
  final List<String> replacementLines;
}

class _BranchEdits {
  const _BranchEdits({
    required this.baseLines,
    required this.insertionsBefore,
    required this.lineEdits,
  });

  final List<String> baseLines;
  final Map<int, List<String>> insertionsBefore;
  final Map<int, _LineEdit> lineEdits;
}
