import 'package:flutter/foundation.dart';
import 'conflict_region.dart';

enum ConflictType {
  content,
  title,
  metadata,
  deleteVsEdit,
}

@immutable
class MergeResult<T> {
  const MergeResult({
    required this.isClean,
    required this.mergedValue,
    this.conflictType,
    this.conflictRegions = const [],
    this.explanation,
  });

  const MergeResult.clean(this.mergedValue)
      : isClean = true,
        conflictType = null,
        conflictRegions = const [],
        explanation = null;

  const MergeResult.conflicted({
    required this.mergedValue,
    required this.conflictType,
    this.conflictRegions = const [],
    this.explanation,
  }) : isClean = false;

  final bool isClean;
  final T mergedValue;
  final ConflictType? conflictType;
  final List<ConflictRegion> conflictRegions;
  final String? explanation;

  bool get hasConflicts => !isClean || conflictRegions.isNotEmpty;
  bool get requiresManual => !isClean;
}
