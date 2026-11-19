import 'dart:convert';

/// Authoritative provenance travels inside the encrypted note payload.
class NoteImportSource {
  const NoteImportSource({
    required this.fingerprint,
    required this.importedAt,
    required this.subject,
    required this.sender,
    this.inputType = 'eml',
    this.rawHash,
    this.messageId,
    this.originalDate,
    this.sourceAssetId,
    this.attachmentAssetIds = const [],
    this.inReplyTo,
    this.references = const [],
  });
  final String fingerprint, subject, sender, inputType;
  final DateTime importedAt;
  final String? rawHash, messageId, originalDate, sourceAssetId, inReplyTo;
  final List<String> attachmentAssetIds, references;
  String get identity =>
      '$inputType:${rawHash ?? fingerprint}:${sourceAssetId ?? ''}';
  Map<String, dynamic> toJson() => {
    'version': 1,
    'kind': 'email',
    'inputType': inputType,
    'rawHash': rawHash,
    'messageId': messageId,
    'fingerprint': fingerprint,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'originalDate': originalDate,
    'sourceAssetId': sourceAssetId,
    'attachmentAssetIds': attachmentAssetIds,
    'subject': subject,
    'sender': sender,
    'inReplyTo': inReplyTo,
    'references': references,
  };
  factory NoteImportSource.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['kind'] != 'email') {
      throw const FormatException('Unsupported import source');
    }
    return NoteImportSource(
      fingerprint: json['fingerprint'] as String,
      importedAt: DateTime.parse(json['importedAt'] as String).toUtc(),
      subject: json['subject'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      inputType: json['inputType'] as String? ?? 'eml',
      rawHash: json['rawHash'] as String?,
      messageId: json['messageId'] as String?,
      originalDate: json['originalDate'] as String?,
      sourceAssetId: json['sourceAssetId'] as String?,
      inReplyTo: json['inReplyTo'] as String?,
      attachmentAssetIds: (json['attachmentAssetIds'] as List? ?? [])
          .cast<String>(),
      references: (json['references'] as List? ?? []).cast<String>(),
    );
  }
  static List<NoteImportSource> decode(Object? value) {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded == null) return const [];
    return (decoded as List)
        .map(
          (e) => NoteImportSource.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  static List<NoteImportSource> union(Iterable<NoteImportSource> sources) {
    final indexed = <String, NoteImportSource>{};
    for (final source in sources) {
      final prior = indexed[source.identity];
      if (prior == null || source.importedAt.isAfter(prior.importedAt)) {
        indexed[source.identity] = source;
      }
    }
    return indexed.values.toList()
      ..sort((a, b) => a.identity.compareTo(b.identity));
  }

  @override
  bool operator ==(Object other) =>
      other is NoteImportSource &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());
  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
