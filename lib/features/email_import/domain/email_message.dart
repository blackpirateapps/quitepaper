import 'dart:typed_data';

/// Limits apply before decoding, and to every decoded MIME leaf.
class EmailLimits {
  const EmailLimits({
    this.rawBytes = 50 * 1024 * 1024,
    this.attachmentBytes = 25 * 1024 * 1024,
    this.totalAttachmentBytes = 50 * 1024 * 1024,
    this.bodyBytes = 10 * 1024 * 1024,
    this.parts = 200,
    this.depth = 20,
    this.headerBytes = 64 * 1024,
  });
  final int rawBytes, attachmentBytes, totalAttachmentBytes, bodyBytes;
  final int parts, depth, headerBytes;
  static const batchSize = 100;
}

class EmailImportException implements Exception {
  const EmailImportException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class EmailAttachment {
  const EmailAttachment({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.contentId,
    this.disposition,
  });
  final String fileName, mimeType;
  final Uint8List bytes;
  final String? contentId, disposition;
  bool get isInlineImage => contentId != null && mimeType.startsWith('image/');
}

/// An ephemeral preview. Never persist raw bytes outside the encrypted vault.
class EmailMessage {
  const EmailMessage({
    required this.subject,
    required this.sender,
    required this.markdown,
    required this.fingerprint,
    this.to = '',
    this.cc = '',
    this.bcc = '',
    this.replyTo = '',
    this.originalDate = '',
    this.sentAt,
    this.messageId,
    this.inReplyTo,
    this.references = const [],
    this.attachments = const [],
    this.rawBytes,
    this.rawHash,
    this.warnings = const [],
  });
  final String subject, sender, to, cc, bcc, replyTo, originalDate, markdown;
  final DateTime? sentAt;
  final String? messageId, inReplyTo, rawHash;
  final String fingerprint;
  final List<String> references, warnings;
  final List<EmailAttachment> attachments;
  final Uint8List? rawBytes;
  bool get isSharedContent => rawBytes == null;
  int get attachmentSize =>
      attachments.fold(0, (sum, item) => sum + item.bytes.length);
}

enum EmailImportMode { editable, archive, append }
