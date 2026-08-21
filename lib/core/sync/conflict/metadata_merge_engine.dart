import '../../utils/tag_parser.dart';
import 'merge_result.dart';

class MetadataMergeEngine {
  const MetadataMergeEngine();

  /// 3-way Title Merge
  MergeResult<String> mergeTitle({
    required String? base,
    required String local,
    required String remote,
  }) {
    final cleanBase = base?.trim() ?? '';
    final cleanLocal = local.trim();
    final cleanRemote = remote.trim();

    // 1. Both identical
    if (cleanLocal == cleanRemote) {
      return MergeResult.clean(cleanLocal);
    }

    // 2. Base == Local -> Remote wins (local didn't change title)
    if (cleanBase == cleanLocal) {
      return MergeResult.clean(cleanRemote);
    }

    // 3. Base == Remote -> Local wins (remote didn't change title)
    if (cleanBase == cleanRemote) {
      return MergeResult.clean(cleanLocal);
    }

    // 4. Both changed differently from base -> Conflict
    return MergeResult.conflicted(
      mergedValue: cleanLocal,
      conflictType: ConflictType.title,
      explanation: 'Title changed on both devices: "$cleanLocal" vs "$cleanRemote"',
    );
  }

  /// 3-way Tags Set Merge
  MergeResult<List<String>> mergeTags({
    required List<String>? base,
    required List<String> local,
    required List<String> remote,
  }) {
    final baseSet = (base ?? [])
        .map(TagParser.normalizeTag)
        .where(TagParser.isValidTag)
        .toSet();

    final localSet = local
        .map(TagParser.normalizeTag)
        .where(TagParser.isValidTag)
        .toSet();

    final remoteSet = remote
        .map(TagParser.normalizeTag)
        .where(TagParser.isValidTag)
        .toSet();

    if (setEquals(localSet, remoteSet)) {
      return MergeResult.clean(localSet.toList()..sort());
    }

    final localAdded = localSet.difference(baseSet);
    final localRemoved = baseSet.difference(localSet);

    final remoteAdded = remoteSet.difference(baseSet);
    final remoteRemoved = baseSet.difference(remoteSet);

    // Apply additions and removals relative to base
    final mergedSet = Set<String>.from(baseSet);

    // Remove tags removed by either branch (if not re-added by the other)
    mergedSet.removeAll(localRemoved);
    mergedSet.removeAll(remoteRemoved);

    // Add independent additions from both branches
    mergedSet.addAll(localAdded);
    mergedSet.addAll(remoteAdded);

    final sortedTags = mergedSet.toList()..sort();
    return MergeResult.clean(sortedTags);
  }

  /// 3-way Lifecycle / Delete-vs-Edit check
  MergeResult<bool> mergeDeleteVsEdit({
    required bool baseDeleted,
    required bool localDeleted,
    required bool remoteDeleted,
    required bool localHasEdits,
    required bool remoteHasEdits,
  }) {
    // Both deleted -> deleted
    if (localDeleted && remoteDeleted) {
      return const MergeResult.clean(true);
    }

    // Neither deleted -> active
    if (!localDeleted && !remoteDeleted) {
      return const MergeResult.clean(false);
    }

    // Local deleted, remote edited
    if (localDeleted && !remoteDeleted) {
      if (remoteHasEdits) {
        return const MergeResult.conflicted(
          mergedValue: false,
          conflictType: ConflictType.deleteVsEdit,
          explanation: 'Note was deleted locally but edited on another device.',
        );
      } else {
        // Remote didn't edit -> local deletion wins
        return const MergeResult.clean(true);
      }
    }

    // Remote deleted, local edited
    if (!localDeleted && remoteDeleted) {
      if (localHasEdits) {
        return const MergeResult.conflicted(
          mergedValue: false,
          conflictType: ConflictType.deleteVsEdit,
          explanation: 'Note was deleted on another device but edited locally.',
        );
      } else {
        // Local didn't edit -> remote deletion wins
        return const MergeResult.clean(true);
      }
    }

    return const MergeResult.clean(false);
  }

  bool setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    return a.containsAll(b);
  }
}
