import 'package:flutter/foundation.dart';

enum ConflictRegionResolution {
  unresolved,
  useLocal,
  useRemote,
  custom,
}

@immutable
class ConflictRegion {
  const ConflictRegion({
    required this.id,
    required this.baseText,
    required this.localText,
    required this.remoteText,
    this.startLine = 0,
    this.endLine = 0,
    this.resolution = ConflictRegionResolution.unresolved,
    this.customText,
  });

  final String id;
  final String baseText;
  final String localText;
  final String remoteText;
  final int startLine;
  final int endLine;
  final ConflictRegionResolution resolution;
  final String? customText;

  bool get isResolved => resolution != ConflictRegionResolution.unresolved;

  String get effectiveText {
    switch (resolution) {
      case ConflictRegionResolution.useLocal:
        return localText;
      case ConflictRegionResolution.useRemote:
        return remoteText;
      case ConflictRegionResolution.custom:
        return customText ?? localText;
      case ConflictRegionResolution.unresolved:
        return localText;
    }
  }

  ConflictRegion copyWith({
    String? id,
    String? baseText,
    String? localText,
    String? remoteText,
    int? startLine,
    int? endLine,
    ConflictRegionResolution? resolution,
    String? customText,
  }) {
    return ConflictRegion(
      id: id ?? this.id,
      baseText: baseText ?? this.baseText,
      localText: localText ?? this.localText,
      remoteText: remoteText ?? this.remoteText,
      startLine: startLine ?? this.startLine,
      endLine: endLine ?? this.endLine,
      resolution: resolution ?? this.resolution,
      customText: customText ?? this.customText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'baseText': baseText,
        'localText': localText,
        'remoteText': remoteText,
        'startLine': startLine,
        'endLine': endLine,
        'resolution': resolution.name,
        if (customText != null) 'customText': customText,
      };

  factory ConflictRegion.fromJson(Map<String, dynamic> json) {
    final resName = json['resolution'] as String? ?? 'unresolved';
    final resolution = ConflictRegionResolution.values.firstWhere(
      (v) => v.name == resName,
      orElse: () => ConflictRegionResolution.unresolved,
    );

    return ConflictRegion(
      id: json['id'] as String,
      baseText: json['baseText'] as String? ?? '',
      localText: json['localText'] as String? ?? '',
      remoteText: json['remoteText'] as String? ?? '',
      startLine: json['startLine'] as int? ?? 0,
      endLine: json['endLine'] as int? ?? 0,
      resolution: resolution,
      customText: json['customText'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictRegion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          baseText == other.baseText &&
          localText == other.localText &&
          remoteText == other.remoteText &&
          startLine == other.startLine &&
          endLine == other.endLine &&
          resolution == other.resolution &&
          customText == other.customText;

  @override
  int get hashCode =>
      id.hashCode ^
      baseText.hashCode ^
      localText.hashCode ^
      remoteText.hashCode ^
      startLine.hashCode ^
      endLine.hashCode ^
      resolution.hashCode ^
      customText.hashCode;
}
