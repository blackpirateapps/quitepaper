import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Text encoding formats detected by Quiet Paper.
enum TextEncoding {
  utf8('UTF-8'),
  utf8Bom('UTF-8 (BOM)'),
  utf16Le('UTF-16 LE'),
  utf16Be('UTF-16 BE'),
  latin1('ISO-8859-1 / Latin-1'),
  unknown('Unknown');

  const TextEncoding(this.label);
  final String label;
}

/// Line ending styles detected in text documents.
enum LineEnding {
  lf('LF (Unix / macOS)'),
  crlf('CRLF (Windows)'),
  cr('CR (Classic Mac)'),
  mixed('Mixed'),
  none('None');

  const LineEnding(this.label);
  final String label;
}

/// Result of decoding raw attachment bytes into presentation-ready text.
@immutable
class DecodedTextResult {
  const DecodedTextResult({
    required this.text,
    required this.encoding,
    required this.lineEnding,
    required this.lineCount,
    required this.hasBom,
    required this.isTruncated,
    required this.totalByteSize,
    required this.loadedByteSize,
    this.isSuccess = true,
    this.errorMessage,
  });

  const DecodedTextResult.failure({
    required this.errorMessage,
    required this.totalByteSize,
  })  : text = '',
        encoding = TextEncoding.unknown,
        lineEnding = LineEnding.none,
        lineCount = 0,
        hasBom = false,
        isTruncated = false,
        loadedByteSize = 0,
        isSuccess = false;

  final String text;
  final TextEncoding encoding;
  final LineEnding lineEnding;
  final int lineCount;
  final bool hasBom;
  final bool isTruncated;
  final int totalByteSize;
  final int loadedByteSize;
  final bool isSuccess;
  final String? errorMessage;

  /// Formatted summary of line count and character count.
  String get statsSummary {
    if (!isSuccess) return 'Decoding failed';
    final lineLabel = lineCount == 1 ? '1 line' : '$lineCount lines';
    final charLabel = text.length == 1 ? '1 char' : '${text.length} chars';
    return '$lineLabel · $charLabel';
  }
}

/// High-performance, memory-safe text decoder with encoding detection, BOM handling,
/// line ending normalization in presentation, and large-file streaming bounds.
class AttachmentTextDecoder {
  const AttachmentTextDecoder._();

  /// Maximum file size loaded completely in-memory (10 MB).
  static const int maxFullViewerBytes = 10 * 1024 * 1024;

  /// Truncation preview limit for huge files (2 MB).
  static const int previewTruncationBytes = 2 * 1024 * 1024;

  /// Decodes raw plaintext [bytes] into a structured [DecodedTextResult].
  static DecodedTextResult decode(
    Uint8List rawBytes, {
    int? maxBytes,
  }) {
    if (rawBytes.isEmpty) {
      return const DecodedTextResult(
        text: '',
        encoding: TextEncoding.utf8,
        lineEnding: LineEnding.none,
        lineCount: 0,
        hasBom: false,
        isTruncated: false,
        totalByteSize: 0,
        loadedByteSize: 0,
      );
    }

    final totalBytes = rawBytes.length;
    final maxLimit = maxBytes ?? (totalBytes > maxFullViewerBytes ? previewTruncationBytes : totalBytes);
    final isTruncated = totalBytes > maxLimit;

    // Work on slice if truncated
    final bytes = isTruncated ? Uint8List.sublistView(rawBytes, 0, maxLimit) : rawBytes;

    // 1. Check for UTF-8 BOM: 0xEF, 0xBB, 0xBF
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      try {
        final slice = Uint8List.sublistView(bytes, 3);
        final text = utf8.decode(slice, allowMalformed: false);
        final lineEnding = _detectLineEnding(text);
        final lineCount = _countLines(text);
        return DecodedTextResult(
          text: text,
          encoding: TextEncoding.utf8Bom,
          lineEnding: lineEnding,
          lineCount: lineCount,
          hasBom: true,
          isTruncated: isTruncated,
          totalByteSize: totalBytes,
          loadedByteSize: bytes.length,
        );
      } catch (_) {}
    }

    // 2. Check for UTF-16 LE BOM: 0xFF, 0xFE
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      try {
        final slice = Uint8List.sublistView(bytes, 2);
        final text = _decodeUtf16Le(slice);
        final lineEnding = _detectLineEnding(text);
        final lineCount = _countLines(text);
        return DecodedTextResult(
          text: text,
          encoding: TextEncoding.utf16Le,
          lineEnding: lineEnding,
          lineCount: lineCount,
          hasBom: true,
          isTruncated: isTruncated,
          totalByteSize: totalBytes,
          loadedByteSize: bytes.length,
        );
      } catch (_) {}
    }

    // 3. Check for UTF-16 BE BOM: 0xFE, 0xFF
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      try {
        final slice = Uint8List.sublistView(bytes, 2);
        final text = _decodeUtf16Be(slice);
        final lineEnding = _detectLineEnding(text);
        final lineCount = _countLines(text);
        return DecodedTextResult(
          text: text,
          encoding: TextEncoding.utf16Be,
          lineEnding: lineEnding,
          lineCount: lineCount,
          hasBom: true,
          isTruncated: isTruncated,
          totalByteSize: totalBytes,
          loadedByteSize: bytes.length,
        );
      } catch (_) {}
    }

    // 4. Try standard UTF-8 without BOM
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      final lineEnding = _detectLineEnding(text);
      final lineCount = _countLines(text);
      return DecodedTextResult(
        text: text,
        encoding: TextEncoding.utf8,
        lineEnding: lineEnding,
        lineCount: lineCount,
        hasBom: false,
        isTruncated: isTruncated,
        totalByteSize: totalBytes,
        loadedByteSize: bytes.length,
      );
    } catch (_) {}

    // 5. Check if it might be UTF-16 LE or BE without BOM (pattern of alternating 0x00 bytes)
    if (_looksLikeUtf16Le(bytes)) {
      try {
        final text = _decodeUtf16Le(bytes);
        final lineEnding = _detectLineEnding(text);
        final lineCount = _countLines(text);
        return DecodedTextResult(
          text: text,
          encoding: TextEncoding.utf16Le,
          lineEnding: lineEnding,
          lineCount: lineCount,
          hasBom: false,
          isTruncated: isTruncated,
          totalByteSize: totalBytes,
          loadedByteSize: bytes.length,
        );
      } catch (_) {}
    }

    if (_looksLikeUtf16Be(bytes)) {
      try {
        final text = _decodeUtf16Be(bytes);
        final lineEnding = _detectLineEnding(text);
        final lineCount = _countLines(text);
        return DecodedTextResult(
          text: text,
          encoding: TextEncoding.utf16Be,
          lineEnding: lineEnding,
          lineCount: lineCount,
          hasBom: false,
          isTruncated: isTruncated,
          totalByteSize: totalBytes,
          loadedByteSize: bytes.length,
        );
      } catch (_) {}
    }

    // 6. Try Latin-1 / ISO-8859-1 fallback for legacy 8-bit text
    try {
      final text = latin1.decode(bytes);
      // Verify that the decoded text is mostly printable ASCII/Latin-1
      if (_isAcceptableLatin1(text)) {
        final lineEnding = _detectLineEnding(text);
        final lineCount = _countLines(text);
        return DecodedTextResult(
          text: text,
          encoding: TextEncoding.latin1,
          lineEnding: lineEnding,
          lineCount: lineCount,
          hasBom: false,
          isTruncated: isTruncated,
          totalByteSize: totalBytes,
          loadedByteSize: bytes.length,
        );
      }
    } catch (_) {}

    // 7. Decoding failed
    return DecodedTextResult.failure(
      errorMessage: "This file's text encoding isn't supported.",
      totalByteSize: totalBytes,
    );
  }

  static String _decodeUtf16Le(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  static String _decodeUtf16Be(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = (bytes[i] << 8) | bytes[i + 1];
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  static bool _looksLikeUtf16Le(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // In ASCII range UTF-16 LE, odd bytes are 0x00
    int zeroOdd = 0;
    final sample = bytes.length < 128 ? bytes.length : 128;
    for (int i = 1; i < sample; i += 2) {
      if (bytes[i] == 0x00) zeroOdd++;
    }
    return (zeroOdd / (sample / 2)) > 0.6;
  }

  static bool _looksLikeUtf16Be(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // In ASCII range UTF-16 BE, even bytes are 0x00
    int zeroEven = 0;
    final sample = bytes.length < 128 ? bytes.length : 128;
    for (int i = 0; i < sample; i += 2) {
      if (bytes[i] == 0x00) zeroEven++;
    }
    return (zeroEven / (sample / 2)) > 0.6;
  }

  static bool _isAcceptableLatin1(String text) {
    if (text.isEmpty) return true;
    int unprintable = 0;
    for (final rune in text.runes) {
      if (rune < 0x09 || (rune > 0x0D && rune < 0x20 && rune != 0x1B)) {
        unprintable++;
      }
    }
    return (unprintable / text.length) < 0.05;
  }

  static LineEnding _detectLineEnding(String text) {
    if (text.isEmpty) return LineEnding.none;
    final hasCrlf = text.contains('\r\n');
    final hasLf = text.replaceAll('\r\n', '').contains('\n');
    final hasCr = text.replaceAll('\r\n', '').contains('\r');

    if (hasCrlf && !hasLf && !hasCr) return LineEnding.crlf;
    if (hasLf && !hasCrlf && !hasCr) return LineEnding.lf;
    if (hasCr && !hasCrlf && !hasLf) return LineEnding.cr;
    if (hasCrlf || hasLf || hasCr) return LineEnding.mixed;
    return LineEnding.none;
  }

  static int _countLines(String text) {
    if (text.isEmpty) return 0;
    int count = 1;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        count++;
      } else if (text[i] == '\r') {
        if (i + 1 < text.length && text[i + 1] == '\n') {
          // CRLF counted by the \n
        } else {
          count++;
        }
      }
    }
    return count;
  }
}
