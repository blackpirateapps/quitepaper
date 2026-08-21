import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../crypto/crypto_service.dart';
import '../../database/app_database.dart';
import 'conflict_region.dart';
import 'merge_result.dart';

enum ConflictState {
  detected,
  autoMerged,
  manualRequired,
  resolving,
  resolved,
}

enum ConflictResolutionType {
  auto,
  manual,
  keepMine,
  keepTheirs,
  keepBoth,
  delete,
  restore,
}

@immutable
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.noteId,
    this.baseRevision = 0,
    this.localRevision = 0,
    this.remoteRevision = 0,
    this.conflictType = ConflictType.content,
    this.state = ConflictState.detected,
    required this.createdAt,
    this.resolvedAt,
    this.resolutionRevision,
    this.resolutionType,
    this.basePlaintext,
    this.localPlaintext,
    this.remotePlaintext,
    this.localIsDeleted = false,
    this.remoteIsDeleted = false,
    this.conflictRegions = const [],
    this.resolvedContent,
    this.resolvedTitle,
    this.resolvedTags,
    this.explanation,
  });

  final String id;
  final String noteId;
  final int baseRevision;
  final int localRevision;
  final int remoteRevision;
  final ConflictType conflictType;
  final ConflictState state;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final int? resolutionRevision;
  final ConflictResolutionType? resolutionType;

  final NotePlaintext? basePlaintext;
  final NotePlaintext? localPlaintext;
  final NotePlaintext? remotePlaintext;
  final bool localIsDeleted;
  final bool remoteIsDeleted;
  final List<ConflictRegion> conflictRegions;

  final String? resolvedContent;
  final String? resolvedTitle;
  final List<String>? resolvedTags;
  final String? explanation;

  bool get isResolved => state == ConflictState.resolved || state == ConflictState.autoMerged;
  bool get requiresManualResolution => state == ConflictState.manualRequired;

  String get effectiveDisplayTitle {
    if (resolvedTitle != null && resolvedTitle!.trim().isNotEmpty) {
      return resolvedTitle!.trim();
    }
    if (localPlaintext != null && localPlaintext!.title.trim().isNotEmpty) {
      return localPlaintext!.title.trim();
    }
    if (remotePlaintext != null && remotePlaintext!.title.trim().isNotEmpty) {
      return remotePlaintext!.title.trim();
    }
    if (basePlaintext != null && basePlaintext!.title.trim().isNotEmpty) {
      return basePlaintext!.title.trim();
    }
    return 'Untitled Note';
  }

  SyncConflict copyWith({
    String? id,
    String? noteId,
    int? baseRevision,
    int? localRevision,
    int? remoteRevision,
    ConflictType? conflictType,
    ConflictState? state,
    DateTime? createdAt,
    DateTime? resolvedAt,
    int? resolutionRevision,
    ConflictResolutionType? resolutionType,
    NotePlaintext? basePlaintext,
    NotePlaintext? localPlaintext,
    NotePlaintext? remotePlaintext,
    bool? localIsDeleted,
    bool? remoteIsDeleted,
    List<ConflictRegion>? conflictRegions,
    String? resolvedContent,
    String? resolvedTitle,
    List<String>? resolvedTags,
    String? explanation,
  }) {
    return SyncConflict(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      baseRevision: baseRevision ?? this.baseRevision,
      localRevision: localRevision ?? this.localRevision,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      conflictType: conflictType ?? this.conflictType,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionRevision: resolutionRevision ?? this.resolutionRevision,
      resolutionType: resolutionType ?? this.resolutionType,
      basePlaintext: basePlaintext ?? this.basePlaintext,
      localPlaintext: localPlaintext ?? this.localPlaintext,
      remotePlaintext: remotePlaintext ?? this.remotePlaintext,
      localIsDeleted: localIsDeleted ?? this.localIsDeleted,
      remoteIsDeleted: remoteIsDeleted ?? this.remoteIsDeleted,
      conflictRegions: conflictRegions ?? this.conflictRegions,
      resolvedContent: resolvedContent ?? this.resolvedContent,
      resolvedTitle: resolvedTitle ?? this.resolvedTitle,
      resolvedTags: resolvedTags ?? this.resolvedTags,
      explanation: explanation ?? this.explanation,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'baseRevision': baseRevision,
        'localRevision': localRevision,
        'remoteRevision': remoteRevision,
        'conflictType': conflictType.name,
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
        if (resolutionRevision != null)
          'resolutionRevision': resolutionRevision,
        if (resolutionType != null) 'resolutionType': resolutionType!.name,
        if (basePlaintext != null) 'basePlaintext': basePlaintext!.toJson(),
        if (localPlaintext != null) 'localPlaintext': localPlaintext!.toJson(),
        if (remotePlaintext != null)
          'remotePlaintext': remotePlaintext!.toJson(),
        'localIsDeleted': localIsDeleted,
        'remoteIsDeleted': remoteIsDeleted,
        'conflictRegions': conflictRegions.map((r) => r.toJson()).toList(),
        if (resolvedContent != null) 'resolvedContent': resolvedContent,
        if (resolvedTitle != null) 'resolvedTitle': resolvedTitle,
        if (resolvedTags != null) 'resolvedTags': resolvedTags,
        if (explanation != null) 'explanation': explanation,
      };

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    final typeName = json['conflictType'] as String? ?? 'content';
    final conflictType = ConflictType.values.firstWhere(
      (v) => v.name == typeName,
      orElse: () => ConflictType.content,
    );

    final stateName = json['state'] as String? ?? 'detected';
    final state = ConflictState.values.firstWhere(
      (v) => v.name == stateName,
      orElse: () => ConflictState.detected,
    );

    final resTypeName = json['resolutionType'] as String?;
    final resolutionType = resTypeName != null
        ? ConflictResolutionType.values.firstWhere(
            (v) => v.name == resTypeName,
            orElse: () => ConflictResolutionType.manual,
          )
        : null;

    final rawRegions = json['conflictRegions'] as List? ?? [];
    final conflictRegions = rawRegions
        .map((r) => ConflictRegion.fromJson(r as Map<String, dynamic>))
        .toList();

    return SyncConflict(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      baseRevision: json['baseRevision'] as int? ?? 0,
      localRevision: json['localRevision'] as int? ?? 0,
      remoteRevision: json['remoteRevision'] as int? ?? 0,
      conflictType: conflictType,
      state: state,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      resolutionRevision: json['resolutionRevision'] as int?,
      resolutionType: resolutionType,
      basePlaintext: json['basePlaintext'] != null
          ? NotePlaintext.fromJson(
              json['basePlaintext'] as Map<String, dynamic>)
          : null,
      localPlaintext: json['localPlaintext'] != null
          ? NotePlaintext.fromJson(
              json['localPlaintext'] as Map<String, dynamic>)
          : null,
      remotePlaintext: json['remotePlaintext'] != null
          ? NotePlaintext.fromJson(
              json['remotePlaintext'] as Map<String, dynamic>)
          : null,
      localIsDeleted: json['localIsDeleted'] as bool? ?? false,
      remoteIsDeleted: json['remoteIsDeleted'] as bool? ?? false,
      conflictRegions: conflictRegions,
      resolvedContent: json['resolvedContent'] as String?,
      resolvedTitle: json['resolvedTitle'] as String?,
      resolvedTags: (json['resolvedTags'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      explanation: json['explanation'] as String?,
    );
  }

  factory SyncConflict.fromEntity(SyncConflictEntity entity) {
    Map<String, dynamic> data = {};
    try {
      if (entity.dataJson.isNotEmpty) {
        data = jsonDecode(entity.dataJson) as Map<String, dynamic>;
      }
    } catch (_) {}

    final mergedJson = {
      ...data,
      'id': entity.id,
      'noteId': entity.noteId,
      'baseRevision': entity.baseRevision,
      'localRevision': entity.localRevision,
      'remoteRevision': entity.remoteRevision,
      'conflictType': entity.conflictType,
      'state': entity.state,
      'createdAt': entity.createdAt.toIso8601String(),
      if (entity.resolvedAt != null)
        'resolvedAt': entity.resolvedAt!.toIso8601String(),
      if (entity.resolutionRevision != null)
        'resolutionRevision': entity.resolutionRevision,
      if (entity.resolutionType != null)
        'resolutionType': entity.resolutionType,
    };

    return SyncConflict.fromJson(mergedJson);
  }

  String toDataJson() {
    return jsonEncode(toJson());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncConflict &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          noteId == other.noteId &&
          baseRevision == other.baseRevision &&
          localRevision == other.localRevision &&
          remoteRevision == other.remoteRevision &&
          conflictType == other.conflictType &&
          state == other.state &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      noteId.hashCode ^
      baseRevision.hashCode ^
      localRevision.hashCode ^
      remoteRevision.hashCode ^
      conflictType.hashCode ^
      state.hashCode ^
      createdAt.hashCode;
}
