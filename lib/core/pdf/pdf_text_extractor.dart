import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../ocr/ocr_models.dart';

/// Result of extracting embedded text layer from a PDF document.
@immutable
class PdfTextExtractionResult {
  const PdfTextExtractionResult({
    required this.hasUsableText,
    this.pages = const [],
    this.extractedText = '',
  });

  /// Whether a usable text layer was present in the PDF.
  /// If `false`, callers should fall back to on-device OCR.
  final bool hasUsableText;

  /// Structured pages extracted from PDF text streams.
  final List<OcrPage> pages;

  /// Combined plain text across all pages.
  final String extractedText;
}

/// Abstract contract for inspecting and extracting embedded text layers from PDF files.
abstract class PdfTextExtractor {
  Future<PdfTextExtractionResult> extractText(Uint8List pdfBytes);
}

/// Production-grade PDF text layer extractor supporting:
/// - Uncompressed and FlateDecode / Zlib compressed streams
/// - Object streams (/Type /ObjStm) and Cross-Reference streams (/Type /XRef)
/// - Font encodings (WinAnsi, MacRoman, Standard, PDFDoc, Custom Differences)
/// - Font /ToUnicode CMaps (beginbfchar, beginbfrange, CIDs)
/// - Hexadecimal (<...>) and literal ((...)) strings with escapes & octals
/// - Text positioning operators (BT, ET, Tf, Td, TD, Tm, T*, TL, Tc, Tw, Tz)
/// - Text display operators (Tj, TJ with kerning spacing, ', ")
/// - Layout reconstruction, word spacing synthesis, and paragraph formatting
class DefaultPdfTextExtractor implements PdfTextExtractor {
  const DefaultPdfTextExtractor();

  @override
  Future<PdfTextExtractionResult> extractText(Uint8List pdfBytes) async {
    try {
      if (pdfBytes.length < 10) {
        return const PdfTextExtractionResult(hasUsableText: false);
      }

      final parser = _PdfDocumentParser(pdfBytes);
      return parser.extractAllPagesText();
    } catch (e, st) {
      debugPrint('[QuietPaper OCR] PdfTextExtractor extraction error: $e\n$st');
      return const PdfTextExtractionResult(hasUsableText: false);
    }
  }
}

// =============================================================================
// PDF Document Parser & Structural Extraction Engine
// =============================================================================

class _PdfDocumentParser {
  _PdfDocumentParser(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;

  final Map<_PdfRef, _PdfIndirectObject> _objects = {};
  final Map<_PdfRef, _PdfFont> _fontCache = {};

  PdfTextExtractionResult extractAllPagesText() {
    // 1. Index all indirect objects
    _indexAllObjects();

    if (_objects.isEmpty) {
      // Fallback: try raw content stream scan
      return _extractFromRawStreamsFallback();
    }

    // 2. Locate Page Tree
    final pageRefs = _findPageReferences();

    if (pageRefs.isEmpty) {
      return _extractFromRawStreamsFallback();
    }

    final pages = <OcrPage>[];
    final fullDocBuffer = StringBuffer();

    for (var i = 0; i < pageRefs.length; i++) {
      final pageRef = pageRefs[i];
      final pageNum = i + 1;
      final pageObj = _resolveObject(pageRef);

      if (pageObj == null || pageObj.value is! Map<String, dynamic>) {
        continue;
      }

      final pageDict = pageObj.value as Map<String, dynamic>;
      final ocrPage = _processPage(pageNum, pageDict);
      if (ocrPage != null && ocrPage.plainText.trim().isNotEmpty) {
        pages.add(ocrPage);
        if (fullDocBuffer.isNotEmpty) fullDocBuffer.writeln('\n');
        fullDocBuffer.write(ocrPage.plainText.trim());
      }
    }

    final combinedText = fullDocBuffer.toString().trim();
    final hasUsable = pages.isNotEmpty && _hasMeaningfulText(combinedText);

    return PdfTextExtractionResult(
      hasUsableText: hasUsable,
      pages: pages,
      extractedText: combinedText,
    );
  }

  bool _hasMeaningfulText(String text) {
    if (text.isEmpty) return false;
    final words = text.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    // At least 1 word with printable characters
    return words.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Object Indexing & Resolution
  // ---------------------------------------------------------------------------

  void _indexAllObjects() {
    final length = bytes.length;
    var offset = 0;

    while (offset < length - 6) {
      // Find `N M obj` pattern
      if (_isDigit(bytes[offset])) {
        final objStart = offset;
        final num = _readInt(offset);
        if (num != null) {
          offset = _skipWhitespace(num.nextOffset);
          if (offset < length && _isDigit(bytes[offset])) {
            final gen = _readInt(offset);
            if (gen != null) {
              offset = _skipWhitespace(gen.nextOffset);
              if (offset + 3 <= length &&
                  bytes[offset] == 0x6F && // 'o'
                  bytes[offset + 1] == 0x62 && // 'b'
                  bytes[offset + 2] == 0x6A && // 'j'
                  (offset + 3 == length || _isDelimiterOrWs(bytes[offset + 3]))) {
                offset += 3;
                final ref = _PdfRef(num.value, gen.value);
                final parsed = _parseObjectValue(offset);
                _objects[ref] = _PdfIndirectObject(
                  ref: ref,
                  offset: objStart,
                  value: parsed.value,
                  streamBytes: parsed.streamBytes,
                  streamDict: parsed.streamDict,
                );
                offset = parsed.nextOffset;
                continue;
              }
            }
          }
        }
        offset = objStart + 1;
        continue;
      }
      offset++;
    }

    // Process object streams (/Type /ObjStm)
    final objStreams = _objects.values
        .where((obj) => obj.streamDict != null && _getName(obj.streamDict!['/Type']) == '/ObjStm')
        .toList();

    for (final objStm in objStreams) {
      _unpackObjectStream(objStm);
    }
  }

  void _unpackObjectStream(_PdfIndirectObject objStm) {
    try {
      final dict = objStm.streamDict!;
      final n = _asInt(dict['/N']) ?? 0;
      final first = _asInt(dict['/First']) ?? 0;
      final decompressed = _decompressStream(objStm.streamBytes, dict);

      if (decompressed == null || decompressed.isEmpty || n <= 0) return;

      final headerParser = _PdfDocumentParser(decompressed);
      var pos = 0;
      final entries = <({int objNum, int offset})>[];

      for (var i = 0; i < n; i++) {
        pos = headerParser._skipWhitespace(pos);
        final numObj = headerParser._readInt(pos);
        if (numObj == null) break;
        pos = numObj.nextOffset;
        pos = headerParser._skipWhitespace(pos);
        final offObj = headerParser._readInt(pos);
        if (offObj == null) break;
        pos = offObj.nextOffset;
        entries.add((objNum: numObj.value, offset: first + offObj.value));
      }

      for (final entry in entries) {
        if (entry.offset < decompressed.length) {
          final parsed = headerParser._parseObjectValue(entry.offset);
          final ref = _PdfRef(entry.objNum, 0);
          if (!_objects.containsKey(ref)) {
            _objects[ref] = _PdfIndirectObject(
              ref: ref,
              offset: entry.offset,
              value: parsed.value,
              streamBytes: parsed.streamBytes,
              streamDict: parsed.streamDict,
            );
          }
        }
      }
    } catch (_) {}
  }

  _PdfIndirectObject? _resolveObject(dynamic refOrObj) {
    if (refOrObj is _PdfRef) {
      return _objects[refOrObj];
    }
    return null;
  }

  dynamic _dereference(dynamic val) {
    if (val is _PdfRef) {
      final obj = _objects[val];
      return obj?.value;
    }
    return val;
  }

  // ---------------------------------------------------------------------------
  // Page Tree Resolution
  // ---------------------------------------------------------------------------

  List<_PdfRef> _findPageReferences() {
    // 1. Try resolving Catalog -> Pages -> Kids
    for (final obj in _objects.values) {
      if (obj.value is Map<String, dynamic>) {
        final dict = obj.value as Map<String, dynamic>;
        if (_getName(dict['/Type']) == '/Catalog' || dict.containsKey('/Pages')) {
          final pagesRef = dict['/Pages'];
          final resolvedPages = _resolvePagesNode(pagesRef);
          if (resolvedPages.isNotEmpty) {
            return resolvedPages;
          }
        }
      }
    }

    // 2. Direct scan for all objects with /Type /Page
    final directPages = <_PdfRef>[];
    for (final entry in _objects.entries) {
      if (entry.value.value is Map<String, dynamic>) {
        final dict = entry.value.value as Map<String, dynamic>;
        if (_getName(dict['/Type']) == '/Page') {
          directPages.add(entry.key);
        }
      }
    }

    if (directPages.isNotEmpty) {
      return directPages;
    }

    // 3. Fallback: Objects containing /Contents and /MediaBox
    for (final entry in _objects.entries) {
      if (entry.value.value is Map<String, dynamic>) {
        final dict = entry.value.value as Map<String, dynamic>;
        if (dict.containsKey('/Contents') || dict.containsKey('/MediaBox')) {
          directPages.add(entry.key);
        }
      }
    }

    return directPages;
  }

  List<_PdfRef> _resolvePagesNode(dynamic nodeRef) {
    final results = <_PdfRef>[];
    final nodeObj = _resolveObject(nodeRef);
    if (nodeObj == null || nodeObj.value is! Map<String, dynamic>) {
      return results;
    }

    final dict = nodeObj.value as Map<String, dynamic>;
    final type = _getName(dict['/Type']);

    if (type == '/Page') {
      if (nodeRef is _PdfRef) results.add(nodeRef);
      return results;
    }

    final kids = dict['/Kids'];
    if (kids is List) {
      for (final kid in kids) {
        if (kid is _PdfRef) {
          final kidObj = _resolveObject(kid);
          final kidDict = kidObj?.value is Map<String, dynamic> ? kidObj!.value as Map<String, dynamic> : null;
          final kidType = _getName(kidDict?['/Type']);
          if (kidType == '/Pages' || kidDict?.containsKey('/Kids') == true) {
            results.addAll(_resolvePagesNode(kid));
          } else {
            results.add(kid);
          }
        }
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Page Content Stream & Layout Processing
  // ---------------------------------------------------------------------------

  OcrPage? _processPage(int pageNumber, Map<String, dynamic> pageDict) {
    // MediaBox / CropBox
    var mediaBox = _parseBox(pageDict['/MediaBox']) ?? _parseBox(pageDict['/CropBox']);
    if (mediaBox == null) {
      // Check parent /Pages node for inherited MediaBox
      final parent = _resolveObject(pageDict['/Parent']);
      if (parent?.value is Map<String, dynamic>) {
        mediaBox = _parseBox((parent!.value as Map<String, dynamic>)['/MediaBox']);
      }
    }
    mediaBox ??= const _Box(0, 0, 595.28, 841.89); // Default A4

    // Resources & Fonts
    final resources = _resolveResources(pageDict);
    final fonts = _resolveFonts(resources);

    // Concatenate all /Contents streams
    final contentBytes = _extractContentBytes(pageDict['/Contents']);
    if (contentBytes.isEmpty) {
      return null;
    }

    // Execute Content Stream Text Interpreter
    final fragments = _executeContentStream(contentBytes, fonts, mediaBox);
    if (fragments.isEmpty) {
      return null;
    }

    // Reconstruct Layout, Lines, Words, and Paragraphs
    return _assembleOcrPage(pageNumber, fragments, mediaBox);
  }

  Map<String, dynamic> _resolveResources(Map<String, dynamic> pageDict) {
    dynamic res = pageDict['/Resources'];
    res = _dereference(res);
    if (res is Map<String, dynamic>) return res;

    // Check parent
    final parent = _resolveObject(pageDict['/Parent']);
    if (parent?.value is Map<String, dynamic>) {
      dynamic parentRes = (parent!.value as Map<String, dynamic>)['/Resources'];
      parentRes = _dereference(parentRes);
      if (parentRes is Map<String, dynamic>) return parentRes;
    }

    return {};
  }

  Map<String, _PdfFont> _resolveFonts(Map<String, dynamic> resources) {
    final fonts = <String, _PdfFont>{};
    dynamic fontDict = resources['/Font'];
    fontDict = _dereference(fontDict);

    if (fontDict is Map<String, dynamic>) {
      for (final entry in fontDict.entries) {
        final fontRef = entry.value;
        if (fontRef is _PdfRef && _fontCache.containsKey(fontRef)) {
          fonts[entry.key] = _fontCache[fontRef]!;
          continue;
        }

        final fontObj = _resolveObject(fontRef) ?? (fontRef is Map<String, dynamic> ? _PdfIndirectObject(ref: const _PdfRef(0, 0), offset: 0, value: fontRef) : null);
        if (fontObj != null && fontObj.value is Map<String, dynamic>) {
          final font = _parseFont(fontObj.value as Map<String, dynamic>);
          fonts[entry.key] = font;
          if (fontRef is _PdfRef) {
            _fontCache[fontRef] = font;
          }
        }
      }
    }

    return fonts;
  }

  _PdfFont _parseFont(Map<String, dynamic> fontDict) {
    final baseFont = _getName(fontDict['/BaseFont']) ?? '';
    final subtype = _getName(fontDict['/Subtype']) ?? '';
    dynamic encoding = fontDict['/Encoding'];
    encoding = _dereference(encoding);

    Map<int, String>? toUnicodeMap;
    dynamic toUnicodeRef = fontDict['/ToUnicode'];
    final toUnicodeObj = _resolveObject(toUnicodeRef);
    if (toUnicodeObj != null && toUnicodeObj.streamBytes != null) {
      final decompressed = _decompressStream(toUnicodeObj.streamBytes, toUnicodeObj.streamDict);
      if (decompressed != null && decompressed.isNotEmpty) {
        toUnicodeMap = _parseToUnicodeCMap(decompressed);
      }
    }

    Map<int, String>? differences;
    String? baseEncodingName;

    if (encoding is Map<String, dynamic>) {
      baseEncodingName = _getName(encoding['/BaseEncoding']);
      final diffs = encoding['/Differences'];
      if (diffs is List) {
        differences = _parseDifferences(diffs);
      }
    } else if (encoding is String) {
      baseEncodingName = encoding;
    }

    return _PdfFont(
      baseFont: baseFont,
      subtype: subtype,
      baseEncoding: baseEncodingName,
      differences: differences,
      toUnicode: toUnicodeMap,
    );
  }

  Map<int, String> _parseToUnicodeCMap(Uint8List cmapBytes) {
    final map = <int, String>{};
    try {
      final text = latin1.decode(cmapBytes, allowInvalid: true);

      // 1. beginbfchar ... endbfchar
      final bfCharRegex = RegExp(r'beginbfchar\s*(.*?)\s*endbfchar', dotAll: true);
      for (final match in bfCharRegex.allMatches(text)) {
        final block = match.group(1) ?? '';
        final charPairs = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>').allMatches(block);
        for (final cp in charPairs) {
          final srcHex = cp.group(1)!;
          final dstHex = cp.group(2)!;
          final srcCode = int.tryParse(srcHex, radix: 16);
          if (srcCode != null) {
            map[srcCode] = _hexToUnicode(dstHex);
          }
        }
      }

      // 2. beginbfrange ... endbfrange (Format 1: <start> <end> <destStart>)
      final bfRangeRegex = RegExp(r'beginbfrange\s*(.*?)\s*endbfrange', dotAll: true);
      for (final match in bfRangeRegex.allMatches(text)) {
        final block = match.group(1) ?? '';

        // Form A: <src1> <src2> <dstStart>
        final rangeA = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>').allMatches(block);
        for (final r in rangeA) {
          final start = int.tryParse(r.group(1)!, radix: 16);
          final end = int.tryParse(r.group(2)!, radix: 16);
          final dstStart = int.tryParse(r.group(3)!, radix: 16);
          if (start != null && end != null && dstStart != null && end >= start) {
            for (var c = start; c <= end; c++) {
              final targetCode = dstStart + (c - start);
              map[c] = String.fromCharCode(targetCode);
            }
          }
        }

        // Form B: <src1> <src2> [ <dst1> <dst2> ... ]
        final rangeB = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*\[(.*?)\]', dotAll: true).allMatches(block);
        for (final r in rangeB) {
          final start = int.tryParse(r.group(1)!, radix: 16);
          final end = int.tryParse(r.group(2)!, radix: 16);
          final arrayContent = r.group(3) ?? '';
          final hexItems = RegExp(r'<([0-9a-fA-F]+)>').allMatches(arrayContent).map((m) => m.group(1)!).toList();
          if (start != null && end != null) {
            for (var idx = 0; idx < hexItems.length && (start + idx) <= end; idx++) {
              map[start + idx] = _hexToUnicode(hexItems[idx]);
            }
          }
        }
      }
    } catch (_) {}
    return map;
  }

  String _hexToUnicode(String hex) {
    if (hex.length % 4 == 0 && hex.length >= 4) {
      final codeUnits = <int>[];
      for (var i = 0; i < hex.length; i += 4) {
        final cu = int.tryParse(hex.substring(i, i + 4), radix: 16);
        if (cu != null) codeUnits.add(cu);
      }
      return String.fromCharCodes(codeUnits);
    } else if (hex.length % 2 == 0) {
      final codeUnits = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        final cu = int.tryParse(hex.substring(i, i + 2), radix: 16);
        if (cu != null) codeUnits.add(cu);
      }
      return String.fromCharCodes(codeUnits);
    }
    return '';
  }

  Map<int, String> _parseDifferences(List diffs) {
    final map = <int, String>{};
    var currentCode = 0;
    for (final item in diffs) {
      if (item is int) {
        currentCode = item;
      } else if (item is String && item.startsWith('/')) {
        final glyphName = item.substring(1);
        final unicode = _adobeGlyphList[glyphName];
        if (unicode != null) {
          map[currentCode] = unicode;
        }
        currentCode++;
      }
    }
    return map;
  }

  Uint8List _extractContentBytes(dynamic contents) {
    final bytesList = <int>[];

    void appendStream(dynamic item) {
      _PdfIndirectObject? obj;
      if (item is _PdfRef) {
        obj = _resolveObject(item);
      } else if (item is _PdfIndirectObject) {
        obj = item;
      }

      if (obj != null && obj.streamBytes != null) {
        final decomp = _decompressStream(obj.streamBytes, obj.streamDict);
        if (decomp != null && decomp.isNotEmpty) {
          bytesList.addAll(decomp);
          bytesList.add(0x20); // space separator
        }
      }
    }

    if (contents is _PdfRef) {
      final resolved = _resolveObject(contents);
      if (resolved?.value is List) {
        for (final item in (resolved!.value as List)) {
          appendStream(item);
        }
      } else {
        appendStream(contents);
      }
    } else if (contents is List) {
      for (final item in contents) {
        appendStream(item);
      }
    } else {
      appendStream(contents);
    }

    return Uint8List.fromList(bytesList);
  }

  Uint8List? _decompressStream(Uint8List? rawBytes, Map<String, dynamic>? dict) {
    if (rawBytes == null || rawBytes.isEmpty) return null;
    if (dict == null) return rawBytes;

    dynamic filter = dict['/Filter'];
    filter = _dereference(filter);

    final filters = <String>[];
    if (filter is List) {
      for (final f in filter) {
        final name = _getName(f);
        if (name != null) filters.add(name);
      }
    } else {
      final name = _getName(filter);
      if (name != null) filters.add(name);
    }

    var currentBytes = rawBytes;

    for (final f in filters) {
      if (f == '/FlateDecode' || f == '/Fl') {
        try {
          currentBytes = Uint8List.fromList(zlib.decode(currentBytes));
        } catch (_) {
          try {
            currentBytes = Uint8List.fromList(ZLibDecoder(raw: true).convert(currentBytes));
          } catch (_) {
            return rawBytes;
          }
        }

        // Apply PNG Predictor if specified
        final decodeParms = dict['/DecodeParms'];
        if (decodeParms is Map<String, dynamic>) {
          final predictor = _asInt(decodeParms['/Predictor']) ?? 1;
          final columns = _asInt(decodeParms['/Columns']) ?? 1;
          final colors = _asInt(decodeParms['/Colors']) ?? 1;
          final bits = _asInt(decodeParms['/BitsPerComponent']) ?? 8;
          if (predictor >= 10 && predictor <= 15) {
            currentBytes = _unpredictPng(currentBytes, columns, colors, bits);
          }
        }
      } else if (f == '/ASCIIHexDecode' || f == '/AHx') {
        currentBytes = _decodeAsciiHex(currentBytes);
      } else if (f == '/ASCII85Decode' || f == '/A85') {
        currentBytes = _decodeAscii85(currentBytes);
      }
    }

    return currentBytes;
  }

  Uint8List _unpredictPng(Uint8List src, int columns, int colors, int bits) {
    final bytesPerPixel = ((colors * bits) + 7) ~/ 8;
    final bytesPerLine = ((columns * colors * bits) + 7) ~/ 8;
    final rowStride = bytesPerLine + 1;
    final rowCount = src.length ~/ rowStride;
    if (rowCount <= 0) return src;

    final output = Uint8List(rowCount * bytesPerLine);
    final prevRow = Uint8List(bytesPerLine);

    for (var r = 0; r < rowCount; r++) {
      final filter = src[r * rowStride];
      final srcRow = src.sublist(r * rowStride + 1, (r + 1) * rowStride);
      final destRow = Uint8List(bytesPerLine);

      for (var c = 0; c < bytesPerLine; c++) {
        final raw = srcRow[c];
        final left = c >= bytesPerPixel ? destRow[c - bytesPerPixel] : 0;
        final up = prevRow[c];
        final upLeft = c >= bytesPerPixel ? prevRow[c - bytesPerPixel] : 0;

        int val;
        switch (filter) {
          case 0: // None
            val = raw;
            break;
          case 1: // Sub
            val = (raw + left) & 0xFF;
            break;
          case 2: // Up
            val = (raw + up) & 0xFF;
            break;
          case 3: // Average
            val = (raw + ((left + up) >> 1)) & 0xFF;
            break;
          case 4: // Paeth
            val = (raw + _paeth(left, up, upLeft)) & 0xFF;
            break;
          default:
            val = raw;
        }
        destRow[c] = val;
      }

      output.setRange(r * bytesPerLine, (r + 1) * bytesPerLine, destRow);
      prevRow.setAll(0, destRow);
    }

    return output;
  }

  int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  Uint8List _decodeAsciiHex(Uint8List src) {
    final buffer = <int>[];
    var high = -1;
    for (final b in src) {
      if (b == 0x3E) break; // '>'
      final digit = _hexDigit(b);
      if (digit >= 0) {
        if (high < 0) {
          high = digit;
        } else {
          buffer.add((high << 4) | digit);
          high = -1;
        }
      }
    }
    if (high >= 0) {
      buffer.add(high << 4);
    }
    return Uint8List.fromList(buffer);
  }

  Uint8List _decodeAscii85(Uint8List src) {
    final buffer = <int>[];
    var count = 0;
    var tuple = 0;

    for (var i = 0; i < src.length; i++) {
      final b = src[i];
      if (b == 0x7E) break; // '~>'
      if (b == 0x7A && count == 0) {
        // 'z'
        buffer.addAll([0, 0, 0, 0]);
        continue;
      }
      if (b >= 0x21 && b <= 0x75) {
        tuple = tuple * 85 + (b - 0x21);
        count++;
        if (count == 5) {
          buffer.add((tuple >> 24) & 0xFF);
          buffer.add((tuple >> 16) & 0xFF);
          buffer.add((tuple >> 8) & 0xFF);
          buffer.add(tuple & 0xFF);
          tuple = 0;
          count = 0;
        }
      }
    }

    if (count > 1) {
      for (var i = 0; i < 5 - count; i++) {
        tuple = tuple * 85 + 84;
      }
      for (var i = 0; i < count - 1; i++) {
        buffer.add((tuple >> (24 - i * 8)) & 0xFF);
      }
    }

    return Uint8List.fromList(buffer);
  }

  // ---------------------------------------------------------------------------
  // Content Stream Text Operator Interpreter
  // ---------------------------------------------------------------------------

  List<_TextFragment> _executeContentStream(
    Uint8List contentBytes,
    Map<String, _PdfFont> fonts,
    _Box mediaBox,
  ) {
    final fragments = <_TextFragment>[];
    final tokenizer = _ContentStreamTokenizer(contentBytes);

    _Matrix ctm = const _Matrix();
    final ctmStack = <_Matrix>[];

    _Matrix tm = const _Matrix();
    _Matrix tlm = const _Matrix();
    var fontSize = 12.0;
    _PdfFont? activeFont;
    var leading = 0.0;
    var wordSpacing = 0.0;
    var charSpacing = 0.0;
    var horizScale = 100.0;

    final operands = <dynamic>[];

    while (tokenizer.hasNext()) {
      final token = tokenizer.nextToken();
      if (token == null) break;

      if (token is _Operator) {
        final op = token.name;

        switch (op) {
          case 'q':
            ctmStack.add(ctm);
            break;
          case 'Q':
            if (ctmStack.isNotEmpty) {
              ctm = ctmStack.removeLast();
            }
            break;
          case 'cm':
            if (operands.length >= 6) {
              final a = _toDouble(operands[0]);
              final b = _toDouble(operands[1]);
              final c = _toDouble(operands[2]);
              final d = _toDouble(operands[3]);
              final e = _toDouble(operands[4]);
              final f = _toDouble(operands[5]);
              ctm = ctm.multiply(_Matrix(a, b, c, d, e, f));
            }
            break;
          case 'BT':
            tm = const _Matrix();
            tlm = const _Matrix();
            break;
          case 'ET':
            break;
          case 'Tf':
            if (operands.length >= 2) {
              final fontName = _getName(operands[0]) ?? '';
              fontSize = _toDouble(operands[1]).abs();
              if (fontSize <= 0) fontSize = 12.0;
              activeFont = fonts[fontName];
            }
            break;
          case 'TL':
            if (operands.isNotEmpty) {
              leading = _toDouble(operands.last);
            }
            break;
          case 'Tw':
            if (operands.isNotEmpty) {
              wordSpacing = _toDouble(operands.last);
            }
            break;
          case 'Tc':
            if (operands.isNotEmpty) {
              charSpacing = _toDouble(operands.last);
            }
            break;
          case 'Tz':
            if (operands.isNotEmpty) {
              horizScale = _toDouble(operands.last);
              if (horizScale <= 0) horizScale = 100.0;
            }
            break;
          case 'Td':
            if (operands.length >= 2) {
              final tx = _toDouble(operands[0]);
              final ty = _toDouble(operands[1]);
              tlm = tlm.multiply(_Matrix(1, 0, 0, 1, tx, ty));
              tm = tlm;
            }
            break;
          case 'TD':
            if (operands.length >= 2) {
              final tx = _toDouble(operands[0]);
              final ty = _toDouble(operands[1]);
              leading = -ty;
              tlm = tlm.multiply(_Matrix(1, 0, 0, 1, tx, ty));
              tm = tlm;
            }
            break;
          case 'Tm':
            if (operands.length >= 6) {
              final a = _toDouble(operands[0]);
              final b = _toDouble(operands[1]);
              final c = _toDouble(operands[2]);
              final d = _toDouble(operands[3]);
              final e = _toDouble(operands[4]);
              final f = _toDouble(operands[5]);
              tm = _Matrix(a, b, c, d, e, f);
              tlm = tm;
            }
            break;
          case 'T*':
            tlm = tlm.multiply(_Matrix(1, 0, 0, 1, 0, -leading));
            tm = tlm;
            break;
          case 'Tj':
            if (operands.isNotEmpty) {
              final strToken = operands.last;
              _recordText(
                strToken,
                activeFont,
                fontSize,
                horizScale,
                wordSpacing,
                charSpacing,
                tm,
                ctm,
                mediaBox,
                fragments,
              );
            }
            break;
          case "'":
            tlm = tlm.multiply(_Matrix(1, 0, 0, 1, 0, -leading));
            tm = tlm;
            if (operands.isNotEmpty) {
              _recordText(
                operands.last,
                activeFont,
                fontSize,
                horizScale,
                wordSpacing,
                charSpacing,
                tm,
                ctm,
                mediaBox,
                fragments,
              );
            }
            break;
          case '"':
            if (operands.length >= 3) {
              wordSpacing = _toDouble(operands[0]);
              charSpacing = _toDouble(operands[1]);
              tlm = tlm.multiply(_Matrix(1, 0, 0, 1, 0, -leading));
              tm = tlm;
              _recordText(
                operands[2],
                activeFont,
                fontSize,
                horizScale,
                wordSpacing,
                charSpacing,
                tm,
                ctm,
                mediaBox,
                fragments,
              );
            }
            break;
          case 'TJ':
            if (operands.isNotEmpty && operands.last is List) {
              final arr = operands.last as List;
              for (final item in arr) {
                if (item is _PdfRawString) {
                  _recordText(
                    item,
                    activeFont,
                    fontSize,
                    horizScale,
                    wordSpacing,
                    charSpacing,
                    tm,
                    ctm,
                    mediaBox,
                    fragments,
                  );
                } else if (item is num) {
                  final kern = item.toDouble();
                  final displacement = -kern / 1000.0 * fontSize * (horizScale / 100.0);
                  tm = tm.multiply(_Matrix(1, 0, 0, 1, displacement, 0));
                  if (kern <= -150 && fragments.isNotEmpty) {
                    fragments.last.hadKerningSpace = true;
                  }
                }
              }
            }
            break;
        }

        operands.clear();
      } else {
        operands.add(token);
      }
    }

    return fragments;
  }

  void _recordText(
    dynamic strToken,
    _PdfFont? font,
    double fontSize,
    double horizScale,
    double wordSpacing,
    double charSpacing,
    _Matrix tm,
    _Matrix ctm,
    _Box mediaBox,
    List<_TextFragment> fragments,
  ) {
    if (strToken is! _PdfRawString) return;

    final decoded = font != null
        ? font.decode(strToken.bytes, isHex: strToken.isHex)
        : _defaultDecode(strToken.bytes);

    if (decoded.isEmpty) return;

    // Compute coordinate via combined Matrix
    final combined = tm.multiply(ctm);
    final userX = combined.e;
    final userY = combined.f;

    // Approximate width and height in points
    final scaleFactor = horizScale / 100.0;
    final approxWidth = (_calculateStringWidth(decoded, fontSize) * scaleFactor).clamp(1.0, 2000.0);
    final approxHeight = (fontSize * combined.d.abs()).clamp(2.0, 200.0);

    // Map to Normalized Page Coordinates [0.0, 1.0] (top-left origin)
    final normX = ((userX - mediaBox.x0) / mediaBox.width).clamp(0.0, 1.0);
    final normY = ((mediaBox.y1 - userY - approxHeight) / mediaBox.height).clamp(0.0, 1.0);
    final normW = (approxWidth / mediaBox.width).clamp(0.001, 1.0);
    final normH = (approxHeight / mediaBox.height).clamp(0.001, 0.5);

    fragments.add(
      _TextFragment(
        text: decoded,
        normX: normX,
        normY: normY,
        normW: normW,
        normH: normH,
        fontSize: fontSize,
      ),
    );

    // Advance Text Matrix horizontally by width
    tm = tm.multiply(_Matrix(1, 0, 0, 1, approxWidth, 0));
  }

  static double _calculateStringWidth(String text, double fontSize) {
    var total = 0.0;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if ('iljtfIr!|:;\',.-()[]`'.contains(char)) {
        total += 0.28;
      } else if ('mwMW—@%&'.contains(char)) {
        total += 0.78;
      } else if ('ABCDEFGHJKLMNOPQRSTUVXYZ'.contains(char)) {
        total += 0.60;
      } else if (char == ' ') {
        total += 0.28;
      } else {
        total += 0.48;
      }
    }
    return total * fontSize;
  }

  String _defaultDecode(Uint8List bytes) {
    return _unescapePdfString(latin1.decode(bytes, allowInvalid: true));
  }

  // ---------------------------------------------------------------------------
  // Layout Assembly: Grouping into Lines, Words, Paragraphs
  // ---------------------------------------------------------------------------

  OcrPage _assembleOcrPage(
    int pageNumber,
    List<_TextFragment> fragments,
    _Box mediaBox,
  ) {
    // 1. Sort fragments top to bottom
    fragments.sort((a, b) {
      final dy = a.normY.compareTo(b.normY);
      if (dy != 0) return dy;
      return a.normX.compareTo(b.normX);
    });

    // 2. Group fragments into horizontal visual lines
    final visualLines = <List<_TextFragment>>[];
    List<_TextFragment>? currentLine;
    var currentLineY = 0.0;

    for (final frag in fragments) {
      if (currentLine == null) {
        currentLine = [frag];
        currentLineY = frag.normY;
        visualLines.add(currentLine);
      } else {
        final deltaY = (frag.normY - currentLineY).abs();
        final threshold = (frag.normH * 0.45).clamp(0.005, 0.025);
        if (deltaY <= threshold) {
          currentLine.add(frag);
        } else {
          currentLine = [frag];
          currentLineY = frag.normY;
          visualLines.add(currentLine);
        }
      }
    }

    final ocrLines = <OcrLine>[];
    final lineStrings = <String>[];

    for (final lineFrags in visualLines) {
      // Sort left to right
      lineFrags.sort((a, b) => a.normX.compareTo(b.normX));

      final lineBuffer = StringBuffer();
      final ocrWords = <OcrWord>[];

      for (var f = 0; f < lineFrags.length; f++) {
        final frag = lineFrags[f];
        if (f > 0) {
          final prev = lineFrags[f - 1];
          final gap = frag.normX - (prev.normX + prev.normW);
          final spaceThreshold = (0.08 * (frag.fontSize / mediaBox.width)).clamp(0.0003, 0.003);
          if (prev.hadKerningSpace || gap > spaceThreshold || frag.normX > (prev.normX + prev.normW * 0.90)) {
            if (!lineBuffer.toString().endsWith(' ') && !frag.text.startsWith(' ')) {
              lineBuffer.write(' ');
            }
          }
        }
        lineBuffer.write(frag.text);

        // Build word objects
        final words = frag.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        for (var w = 0; w < words.length; w++) {
          final word = words[w];
          final wordX = (frag.normX + (w / math.max(1, words.length)) * frag.normW).clamp(0.0, 1.0);
          final wordW = (frag.normW / math.max(1, words.length)).clamp(0.001, 1.0);
          ocrWords.add(
            OcrWord(
              text: word,
              bounds: NormalizedRect(
                x: wordX,
                y: frag.normY,
                width: wordW,
                height: frag.normH,
              ),
              confidence: 1.0,
            ),
          );
        }
      }

      final lineText = lineBuffer.toString().trim();
      if (lineText.isNotEmpty) {
        lineStrings.add(lineText);
        final minX = lineFrags.map((f) => f.normX).reduce(math.min);
        final minY = lineFrags.map((f) => f.normY).reduce(math.min);
        final maxX = lineFrags.map((f) => f.normX + f.normW).reduce(math.max);
        final maxY = lineFrags.map((f) => f.normY + f.normH).reduce(math.max);

        ocrLines.add(
          OcrLine(
            text: lineText,
            bounds: NormalizedRect(
              x: minX,
              y: minY,
              width: (maxX - minX).clamp(0.01, 1.0),
              height: (maxY - minY).clamp(0.005, 0.5),
            ),
            words: ocrWords,
          ),
        );
      }
    }

    // 3. Group lines into coherent Paragraphs (OcrBlock)
    final blocks = <OcrBlock>[];
    final fullPageBuffer = StringBuffer();

    if (ocrLines.isNotEmpty) {
      final currentBlockLines = <OcrLine>[ocrLines.first];

      for (var l = 1; l < ocrLines.length; l++) {
        final prevLine = ocrLines[l - 1];
        final currLine = ocrLines[l];
        final lineGap = currLine.bounds.y - (prevLine.bounds.y + prevLine.bounds.height);
        final isParagraphBreak = lineGap > (prevLine.bounds.height * 1.35);

        if (isParagraphBreak) {
          final blockText = currentBlockLines.map((line) => line.text).join('\n');
          blocks.add(
            OcrBlock(
              text: blockText,
              bounds: _computeEnclosingBounds(currentBlockLines.map((l) => l.bounds).toList()),
              lines: List.of(currentBlockLines),
            ),
          );
          if (fullPageBuffer.isNotEmpty) fullPageBuffer.write('\n\n');
          fullPageBuffer.write(blockText);
          currentBlockLines.clear();
        }

        currentBlockLines.add(currLine);
      }

      if (currentBlockLines.isNotEmpty) {
        final blockText = currentBlockLines.map((line) => line.text).join('\n');
        blocks.add(
          OcrBlock(
            text: blockText,
            bounds: _computeEnclosingBounds(currentBlockLines.map((l) => l.bounds).toList()),
            lines: List.of(currentBlockLines),
          ),
        );
        if (fullPageBuffer.isNotEmpty) fullPageBuffer.write('\n\n');
        fullPageBuffer.write(blockText);
      }
    }

    return OcrPage(
      pageNumber: pageNumber,
      plainText: fullPageBuffer.toString().trim(),
      width: mediaBox.width.toInt(),
      height: mediaBox.height.toInt(),
      source: OcrSource.embeddedPdfText,
      blocks: blocks,
    );
  }

  NormalizedRect _computeEnclosingBounds(List<NormalizedRect> boxes) {
    if (boxes.isEmpty) return const NormalizedRect(x: 0, y: 0, width: 1, height: 1);
    final minX = boxes.map((b) => b.x).reduce(math.min);
    final minY = boxes.map((b) => b.y).reduce(math.min);
    final maxX = boxes.map((b) => b.x + b.width).reduce(math.max);
    final maxY = boxes.map((b) => b.y + b.height).reduce(math.max);
    return NormalizedRect(
      x: minX,
      y: minY,
      width: (maxX - minX).clamp(0.01, 1.0),
      height: (maxY - minY).clamp(0.01, 1.0),
    );
  }

  // ---------------------------------------------------------------------------
  // Fallback Raw Stream Extractor
  // ---------------------------------------------------------------------------

  PdfTextExtractionResult _extractFromRawStreamsFallback() {
    try {
      final pdfString = latin1.decode(bytes, allowInvalid: true);
      final btEtRegex = RegExp(r'BT\s*(.*?)\s*ET', dotAll: true);
      final tjRegex = RegExp(r'\((.*?)\)\s*Tj');
      final arrayTjRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);

      final matches = btEtRegex.allMatches(pdfString).toList();
      if (matches.isEmpty) {
        return const PdfTextExtractionResult(hasUsableText: false);
      }

      final extractedLines = <String>[];

      for (final match in matches) {
        final blockContent = match.group(1) ?? '';
        for (final tj in tjRegex.allMatches(blockContent)) {
          final raw = tj.group(1);
          if (raw != null && raw.trim().isNotEmpty) {
            extractedLines.add(_unescapePdfString(raw));
          }
        }
        for (final arrayMatch in arrayTjRegex.allMatches(blockContent)) {
          final inner = arrayMatch.group(1) ?? '';
          final strRegex = RegExp(r'\((.*?)\)');
          final parts = <String>[];
          for (final sm in strRegex.allMatches(inner)) {
            final part = sm.group(1);
            if (part != null && part.isNotEmpty) {
              parts.add(_unescapePdfString(part));
            }
          }
          if (parts.isNotEmpty) {
            extractedLines.add(parts.join(' '));
          }
        }
      }

      final cleanLines = extractedLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (cleanLines.isEmpty) {
        return const PdfTextExtractionResult(hasUsableText: false);
      }

      final fullText = cleanLines.join('\n');
      final page = OcrPage(
        pageNumber: 1,
        plainText: fullText,
        width: 1000,
        height: 1414,
        source: OcrSource.embeddedPdfText,
        blocks: [
          OcrBlock(
            text: fullText,
            bounds: const NormalizedRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            lines: cleanLines.map((l) => OcrLine(text: l, bounds: const NormalizedRect(x: 0.05, y: 0.05, width: 0.90, height: 0.04), words: const [])).toList(),
          ),
        ],
      );

      return PdfTextExtractionResult(
        hasUsableText: true,
        pages: [page],
        extractedText: fullText,
      );
    } catch (_) {
      return const PdfTextExtractionResult(hasUsableText: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Low-Level Tokenizer & Helpers
  // ---------------------------------------------------------------------------

  ({dynamic value, Uint8List? streamBytes, Map<String, dynamic>? streamDict, int nextOffset})
      _parseObjectValue(int startOffset) {
    var offset = _skipWhitespace(startOffset);
    final parsed = _parseDirectValue(offset);
    offset = parsed.nextOffset;
    offset = _skipWhitespace(offset);

    // Check for attached stream
    if (offset + 6 <= bytes.length &&
        bytes[offset] == 0x73 && // 's'
        bytes[offset + 1] == 0x74 && // 't'
        bytes[offset + 2] == 0x72 && // 'r'
        bytes[offset + 3] == 0x65 && // 'e'
        bytes[offset + 4] == 0x61 && // 'a'
        bytes[offset + 5] == 0x6D) { // 'm'
      offset += 6;
      if (offset < bytes.length && bytes[offset] == 0x0D) offset++; // \r
      if (offset < bytes.length && bytes[offset] == 0x0A) offset++; // \n

      final streamStart = offset;
      final dict = parsed.value is Map<String, dynamic> ? parsed.value as Map<String, dynamic> : null;
      final declaredLen = _asInt(dict?['/Length']);

      if (declaredLen != null && declaredLen > 0 && streamStart + declaredLen <= bytes.length) {
        final streamData = bytes.sublist(streamStart, streamStart + declaredLen);
        var afterStream = streamStart + declaredLen;
        afterStream = _skipWhitespace(afterStream);
        if (afterStream + 9 <= bytes.length &&
            bytes[afterStream] == 0x65 &&
            bytes[afterStream + 1] == 0x6E &&
            bytes[afterStream + 2] == 0x64 &&
            bytes[afterStream + 3] == 0x73 &&
            bytes[afterStream + 4] == 0x74 &&
            bytes[afterStream + 5] == 0x72 &&
            bytes[afterStream + 6] == 0x65 &&
            bytes[afterStream + 7] == 0x61 &&
            bytes[afterStream + 8] == 0x6D) {
          afterStream += 9;
        }
        return (
          value: parsed.value,
          streamBytes: streamData,
          streamDict: dict,
          nextOffset: afterStream,
        );
      }

      var streamEnd = -1;

      // Find endstream
      for (var i = streamStart; i <= bytes.length - 9; i++) {
        if (bytes[i] == 0x65 &&
            bytes[i + 1] == 0x6E &&
            bytes[i + 2] == 0x64 &&
            bytes[i + 3] == 0x73 &&
            bytes[i + 4] == 0x74 &&
            bytes[i + 5] == 0x72 &&
            bytes[i + 6] == 0x65 &&
            bytes[i + 7] == 0x61 &&
            bytes[i + 8] == 0x6D) {
          streamEnd = i;
          offset = i + 9;
          break;
        }
      }

      if (streamEnd >= streamStart) {
        var trimmedEnd = streamEnd;
        if (trimmedEnd > streamStart && bytes[trimmedEnd - 1] == 0x0A) trimmedEnd--;
        if (trimmedEnd > streamStart && bytes[trimmedEnd - 1] == 0x0D) trimmedEnd--;

        final streamData = bytes.sublist(streamStart, trimmedEnd);
        return (
          value: parsed.value,
          streamBytes: streamData,
          streamDict: dict,
          nextOffset: offset,
        );
      }
    }

    return (
      value: parsed.value,
      streamBytes: null,
      streamDict: null,
      nextOffset: offset,
    );
  }

  ({dynamic value, int nextOffset}) _parseDirectValue(int offset) {
    offset = _skipWhitespace(offset);
    if (offset >= bytes.length) return (value: null, nextOffset: offset);

    final b = bytes[offset];

    // Dictionary << ... >>
    if (b == 0x3C && offset + 1 < bytes.length && bytes[offset + 1] == 0x3C) {
      return _parseDictionary(offset);
    }

    // Array [ ... ]
    if (b == 0x5B) {
      return _parseArray(offset);
    }

    // Hex String < ... >
    if (b == 0x3C) {
      return _parseHexString(offset);
    }

    // Literal String ( ... )
    if (b == 0x28) {
      return _parseLiteralString(offset);
    }

    // Name /Name
    if (b == 0x2F) {
      return _parseName(offset);
    }

    // Number or Reference
    if (_isDigit(b) || b == 0x2D || b == 0x2B || b == 0x2E) {
      // '-' '+' '.'
      return _parseNumberOrRef(offset);
    }

    // Boolean true / false / null
    if (b == 0x74 && offset + 4 <= bytes.length && latin1.decode(bytes.sublist(offset, offset + 4)) == 'true') {
      return (value: true, nextOffset: offset + 4);
    }
    if (b == 0x66 && offset + 5 <= bytes.length && latin1.decode(bytes.sublist(offset, offset + 5)) == 'false') {
      return (value: false, nextOffset: offset + 5);
    }
    if (b == 0x6E && offset + 4 <= bytes.length && latin1.decode(bytes.sublist(offset, offset + 4)) == 'null') {
      return (value: null, nextOffset: offset + 4);
    }

    // Unknown word
    final start = offset;
    while (offset < bytes.length && !_isDelimiterOrWs(bytes[offset])) {
      offset++;
    }
    return (value: latin1.decode(bytes.sublist(start, offset)), nextOffset: offset);
  }

  ({Map<String, dynamic> value, int nextOffset}) _parseDictionary(int startOffset) {
    var offset = startOffset + 2; // skip '<<'
    final dict = <String, dynamic>{};

    while (offset < bytes.length - 1) {
      offset = _skipWhitespace(offset);
      if (offset >= bytes.length) break;

      if (bytes[offset] == 0x3E && offset + 1 < bytes.length && bytes[offset + 1] == 0x3E) {
        offset += 2; // skip '>>'
        break;
      }

      final keyParsed = _parseName(offset);
      final key = keyParsed.value;
      offset = keyParsed.nextOffset;

      offset = _skipWhitespace(offset);
      if (offset >= bytes.length) break;

      final valParsed = _parseDirectValue(offset);
      dict[key] = valParsed.value;
      offset = valParsed.nextOffset;
    }

    return (value: dict, nextOffset: offset);
  }

  ({List<dynamic> value, int nextOffset}) _parseArray(int startOffset) {
    var offset = startOffset + 1; // skip '['
    final list = <dynamic>[];

    while (offset < bytes.length) {
      offset = _skipWhitespace(offset);
      if (offset >= bytes.length) break;

      if (bytes[offset] == 0x5D) {
        // ']'
        offset++;
        break;
      }

      final valParsed = _parseDirectValue(offset);
      list.add(valParsed.value);
      offset = valParsed.nextOffset;
    }

    return (value: list, nextOffset: offset);
  }

  ({_PdfRawString value, int nextOffset}) _parseLiteralString(int startOffset) {
    var offset = startOffset + 1; // skip '('
    final buffer = <int>[];
    var depth = 1;

    while (offset < bytes.length && depth > 0) {
      final b = bytes[offset];
      if (b == 0x5C) {
        // '\' escape
        offset++;
        if (offset >= bytes.length) break;
        final esc = bytes[offset];
        if (esc == 0x6E) {
          buffer.add(0x0A); // \n
        } else if (esc == 0x72) {
          buffer.add(0x0D); // \r
        } else if (esc == 0x74) {
          buffer.add(0x09); // \t
        } else if (esc == 0x62) {
          buffer.add(0x08); // \b
        } else if (esc == 0x66) {
          buffer.add(0x0C); // \f
        } else if (esc == 0x28) {
          buffer.add(0x28); // \(
        } else if (esc == 0x29) {
          buffer.add(0x29); // \)
        } else if (esc == 0x5C) {
          buffer.add(0x5C); // \\
        } else if (_isOctalDigit(esc)) {
          var octal = esc - 0x30;
          if (offset + 1 < bytes.length && _isOctalDigit(bytes[offset + 1])) {
            offset++;
            octal = (octal << 3) + (bytes[offset] - 0x30);
            if (offset + 1 < bytes.length && _isOctalDigit(bytes[offset + 1])) {
              offset++;
              octal = (octal << 3) + (bytes[offset] - 0x30);
            }
          }
          buffer.add(octal & 0xFF);
        } else {
          buffer.add(esc);
        }
      } else if (b == 0x28) {
        // '('
        depth++;
        buffer.add(b);
      } else if (b == 0x29) {
        // ')'
        depth--;
        if (depth > 0) buffer.add(b);
      } else {
        buffer.add(b);
      }
      offset++;
    }

    return (
      value: _PdfRawString(Uint8List.fromList(buffer), isHex: false),
      nextOffset: offset,
    );
  }

  ({_PdfRawString value, int nextOffset}) _parseHexString(int startOffset) {
    var offset = startOffset + 1; // skip '<'
    final hexChars = <int>[];

    while (offset < bytes.length) {
      final b = bytes[offset];
      if (b == 0x3E) {
        // '>'
        offset++;
        break;
      }
      if (_hexDigit(b) >= 0) {
        hexChars.add(b);
      }
      offset++;
    }

    if (hexChars.length % 2 != 0) {
      hexChars.add(0x30); // '0'
    }

    final raw = Uint8List(hexChars.length ~/ 2);
    for (var i = 0; i < raw.length; i++) {
      final h = _hexDigit(hexChars[i * 2]);
      final l = _hexDigit(hexChars[i * 2 + 1]);
      raw[i] = (h << 4) | l;
    }

    return (
      value: _PdfRawString(raw, isHex: true),
      nextOffset: offset,
    );
  }

  ({String value, int nextOffset}) _parseName(int startOffset) {
    var offset = startOffset;
    if (offset < bytes.length && bytes[offset] == 0x2F) offset++; // '/'
    final start = startOffset; // preserve leading '/'

    while (offset < bytes.length && !_isDelimiterOrWs(bytes[offset])) {
      offset++;
    }

    return (
      value: latin1.decode(bytes.sublist(start, offset)),
      nextOffset: offset,
    );
  }

  ({dynamic value, int nextOffset}) _parseNumberOrRef(int startOffset) {
    var offset = startOffset;
    final num1 = _readInt(offset);

    if (num1 != null) {
      offset = num1.nextOffset;
      final wsOffset = _skipWhitespace(offset);
      if (wsOffset < bytes.length && _isDigit(bytes[wsOffset])) {
        final num2 = _readInt(wsOffset);
        if (num2 != null) {
          final afterGen = _skipWhitespace(num2.nextOffset);
          if (afterGen < bytes.length && bytes[afterGen] == 0x52 && // 'R'
              (afterGen + 1 == bytes.length || _isDelimiterOrWs(bytes[afterGen + 1]))) {
            return (
              value: _PdfRef(num1.value, num2.value),
              nextOffset: afterGen + 1,
            );
          }
        }
      }
    }

    // Regular number
    offset = startOffset;
    final start = offset;
    while (offset < bytes.length && !_isDelimiterOrWs(bytes[offset])) {
      offset++;
    }
    final numStr = latin1.decode(bytes.sublist(start, offset));
    final intVal = int.tryParse(numStr);
    if (intVal != null) return (value: intVal, nextOffset: offset);
    final dblVal = double.tryParse(numStr);
    return (value: dblVal ?? numStr, nextOffset: offset);
  }

  int _skipWhitespace(int offset) {
    while (offset < bytes.length) {
      final b = bytes[offset];
      if (b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x0C || b == 0x00) {
        offset++;
      } else if (b == 0x25) {
        // '%' comment
        while (offset < bytes.length && bytes[offset] != 0x0A && bytes[offset] != 0x0D) {
          offset++;
        }
      } else {
        break;
      }
    }
    return offset;
  }

  ({int value, int nextOffset})? _readInt(int offset) {
    final start = offset;
    while (offset < bytes.length && _isDigit(bytes[offset])) {
      offset++;
    }
    if (offset == start) return null;
    final val = int.tryParse(latin1.decode(bytes.sublist(start, offset)));
    return val != null ? (value: val, nextOffset: offset) : null;
  }

  _Box? _parseBox(dynamic val) {
    val = _dereference(val);
    if (val is List && val.length >= 4) {
      final x0 = _toDouble(val[0]);
      final y0 = _toDouble(val[1]);
      final x1 = _toDouble(val[2]);
      final y1 = _toDouble(val[3]);
      return _Box(x0, y0, x1, y1);
    }
    return null;
  }

  static bool _isDigit(int b) => b >= 0x30 && b <= 0x39;
  static bool _isOctalDigit(int b) => b >= 0x30 && b <= 0x37;
  static int _hexDigit(int b) {
    if (b >= 0x30 && b <= 0x39) return b - 0x30;
    if (b >= 0x41 && b <= 0x46) return b - 0x41 + 10;
    if (b >= 0x61 && b <= 0x66) return b - 0x61 + 10;
    return -1;
  }

  static bool _isDelimiterOrWs(int b) {
    return b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x0C || b == 0x00 ||
        b == 0x28 || b == 0x29 || b == 0x3C || b == 0x3E || b == 0x5B || b == 0x5D ||
        b == 0x7B || b == 0x7D || b == 0x2F || b == 0x25;
  }

  static String? _getName(dynamic val) {
    if (val is String && val.startsWith('/')) return val;
    return null;
  }

  static int? _asInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  static String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }
}

// =============================================================================
// Content Stream Tokenizer
// =============================================================================

class _ContentStreamTokenizer {
  _ContentStreamTokenizer(this.bytes);

  final Uint8List bytes;
  int _offset = 0;

  bool hasNext() {
    _skipWs();
    return _offset < bytes.length;
  }

  dynamic nextToken() {
    _skipWs();
    if (_offset >= bytes.length) return null;

    final b = bytes[_offset];

    // Literal String ( ... )
    if (b == 0x28) {
      return _readLiteralString();
    }

    // Hex String < ... >
    if (b == 0x3C) {
      return _readHexString();
    }

    // Array [ ... ]
    if (b == 0x5B) {
      return _readArray();
    }

    // Name /Name
    if (b == 0x2F) {
      final start = _offset;
      _offset++;
      while (_offset < bytes.length && !_PdfDocumentParser._isDelimiterOrWs(bytes[_offset])) {
        _offset++;
      }
      return latin1.decode(bytes.sublist(start, _offset));
    }

    // Number or Keyword / Operator
    final start = _offset;
    while (_offset < bytes.length && !_PdfDocumentParser._isDelimiterOrWs(bytes[_offset])) {
      _offset++;
    }

    final tokenStr = latin1.decode(bytes.sublist(start, _offset));
    final numVal = num.tryParse(tokenStr);
    if (numVal != null) {
      return numVal;
    }

    return _Operator(tokenStr);
  }

  _PdfRawString _readLiteralString() {
    _offset++; // skip '('
    final buffer = <int>[];
    var depth = 1;

    while (_offset < bytes.length && depth > 0) {
      final b = bytes[_offset];
      if (b == 0x5C) {
        _offset++;
        if (_offset >= bytes.length) break;
        final esc = bytes[_offset];
        if (esc == 0x6E) {
          buffer.add(0x0A);
        } else if (esc == 0x72) {
          buffer.add(0x0D);
        } else if (esc == 0x74) {
          buffer.add(0x09);
        } else if (esc == 0x62) {
          buffer.add(0x08);
        } else if (esc == 0x66) {
          buffer.add(0x0C);
        } else if (esc == 0x28) {
          buffer.add(0x28);
        } else if (esc == 0x29) {
          buffer.add(0x29);
        } else if (esc == 0x5C) {
          buffer.add(0x5C);
        } else if (_PdfDocumentParser._isOctalDigit(esc)) {
          var octal = esc - 0x30;
          if (_offset + 1 < bytes.length && _PdfDocumentParser._isOctalDigit(bytes[_offset + 1])) {
            _offset++;
            octal = (octal << 3) + (bytes[_offset] - 0x30);
            if (_offset + 1 < bytes.length && _PdfDocumentParser._isOctalDigit(bytes[_offset + 1])) {
              _offset++;
              octal = (octal << 3) + (bytes[_offset] - 0x30);
            }
          }
          buffer.add(octal & 0xFF);
        } else {
          buffer.add(esc);
        }
      } else if (b == 0x28) {
        depth++;
        buffer.add(b);
      } else if (b == 0x29) {
        depth--;
        if (depth > 0) buffer.add(b);
      } else {
        buffer.add(b);
      }
      _offset++;
    }

    return _PdfRawString(Uint8List.fromList(buffer), isHex: false);
  }

  _PdfRawString _readHexString() {
    _offset++; // skip '<'
    final hexChars = <int>[];

    while (_offset < bytes.length) {
      final b = bytes[_offset];
      if (b == 0x3E) {
        _offset++;
        break;
      }
      if (_PdfDocumentParser._hexDigit(b) >= 0) {
        hexChars.add(b);
      }
      _offset++;
    }

    if (hexChars.length % 2 != 0) {
      hexChars.add(0x30);
    }

    final raw = Uint8List(hexChars.length ~/ 2);
    for (var i = 0; i < raw.length; i++) {
      final h = _PdfDocumentParser._hexDigit(hexChars[i * 2]);
      final l = _PdfDocumentParser._hexDigit(hexChars[i * 2 + 1]);
      raw[i] = (h << 4) | l;
    }

    return _PdfRawString(raw, isHex: true);
  }

  List<dynamic> _readArray() {
    _offset++; // skip '['
    final list = <dynamic>[];

    while (hasNext()) {
      _skipWs();
      if (_offset >= bytes.length) break;
      if (bytes[_offset] == 0x5D) {
        _offset++;
        break;
      }
      final item = nextToken();
      if (item != null) list.add(item);
    }

    return list;
  }

  void _skipWs() {
    while (_offset < bytes.length) {
      final b = bytes[_offset];
      if (b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x0C || b == 0x00) {
        _offset++;
      } else if (b == 0x25) {
        while (_offset < bytes.length && bytes[_offset] != 0x0A && bytes[_offset] != 0x0D) {
          _offset++;
        }
      } else {
        break;
      }
    }
  }
}

// =============================================================================
// Helper Models & Matrices
// =============================================================================

@immutable
class _PdfRef {
  const _PdfRef(this.num, this.gen);
  final int num;
  final int gen;

  @override
  bool operator ==(Object other) => other is _PdfRef && other.num == num && other.gen == gen;

  @override
  int get hashCode => Object.hash(num, gen);

  @override
  String toString() => '$num $gen R';
}

class _PdfIndirectObject {
  _PdfIndirectObject({
    required this.ref,
    required this.offset,
    required this.value,
    this.streamBytes,
    this.streamDict,
  });

  final _PdfRef ref;
  final int offset;
  final dynamic value;
  final Uint8List? streamBytes;
  final Map<String, dynamic>? streamDict;
}

class _PdfRawString {
  _PdfRawString(this.bytes, {required this.isHex});
  final Uint8List bytes;
  final bool isHex;
}

class _Operator {
  const _Operator(this.name);
  final String name;
}

class _Box {
  const _Box(this.x0, this.y0, this.x1, this.y1);
  final double x0;
  final double y0;
  final double x1;
  final double y1;

  double get width => (x1 - x0).abs().clamp(1.0, 10000.0);
  double get height => (y1 - y0).abs().clamp(1.0, 10000.0);
}

class _Matrix {
  const _Matrix([
    this.a = 1.0,
    this.b = 0.0,
    this.c = 0.0,
    this.d = 1.0,
    this.e = 0.0,
    this.f = 0.0,
  ]);

  final double a, b, c, d, e, f;

  _Matrix multiply(_Matrix o) {
    return _Matrix(
      a * o.a + b * o.c,
      a * o.b + b * o.d,
      c * o.a + d * o.c,
      c * o.b + d * o.d,
      e * o.a + f * o.c + o.e,
      e * o.b + f * o.d + o.f,
    );
  }
}

class _TextFragment {
  _TextFragment({
    required this.text,
    required this.normX,
    required this.normY,
    required this.normW,
    required this.normH,
    required this.fontSize,
  });

  final String text;
  final double normX;
  final double normY;
  final double normW;
  final double normH;
  final double fontSize;
  bool hadKerningSpace = false;
}

class _PdfFont {
  _PdfFont({
    required this.baseFont,
    required this.subtype,
    this.baseEncoding,
    this.differences,
    this.toUnicode,
  });

  final String baseFont;
  final String subtype;
  final String? baseEncoding;
  final Map<int, String>? differences;
  final Map<int, String>? toUnicode;

  String decode(Uint8List bytes, {bool isHex = false}) {
    if (toUnicode != null && toUnicode!.isNotEmpty) {
      final buffer = StringBuffer();
      var i = 0;
      while (i < bytes.length) {
        // Try 2-byte CID code first
        if (i + 1 < bytes.length) {
          final code2 = (bytes[i] << 8) | bytes[i + 1];
          if (toUnicode!.containsKey(code2)) {
            buffer.write(toUnicode![code2]);
            i += 2;
            continue;
          }
        }
        // Try 1-byte code
        final code1 = bytes[i];
        if (toUnicode!.containsKey(code1)) {
          buffer.write(toUnicode![code1]);
          i++;
          continue;
        }

        // Fallback byte
        buffer.writeCharCode(code1);
        i++;
      }
      return buffer.toString();
    }

    if (subtype == '/Type0' || (isHex && bytes.length % 2 == 0 && bytes.length >= 2)) {
      // UTF-16BE / CID Identity
      final codeUnits = <int>[];
      for (var i = 0; i < bytes.length; i += 2) {
        final cu = (bytes[i] << 8) | bytes[i + 1];
        if (cu != 0) codeUnits.add(cu);
      }
      if (codeUnits.isNotEmpty) {
        return String.fromCharCodes(codeUnits);
      }
    }

    final buffer = StringBuffer();
    for (final b in bytes) {
      if (differences != null && differences!.containsKey(b)) {
        buffer.write(differences![b]);
      } else if (baseEncoding == '/WinAnsiEncoding' || baseEncoding == null) {
        buffer.write(_winAnsiMap[b] ?? String.fromCharCode(b));
      } else {
        buffer.writeCharCode(b);
      }
    }

    return buffer.toString();
  }
}

// =============================================================================
// Standard Encodings & Adobe Glyph List Maps
// =============================================================================

const Map<int, String> _winAnsiMap = {
  128: '\u20AC', // Euro
  130: '\u201A', // Single Low-9 Quotation Mark
  131: '\u0192', // Latin Small Letter F with Hook
  132: '\u201E', // Double Low-9 Quotation Mark
  133: '\u2026', // Horizontal Ellipsis
  134: '\u2020', // Dagger
  135: '\u2021', // Double Dagger
  136: '\u02C6', // Modifier Letter Circumflex Accent
  137: '\u2030', // Per Mille Sign
  138: '\u0160', // Latin Capital Letter S with Caron
  139: '\u2039', // Single Left-Pointing Angle Quotation Mark
  140: '\u0152', // Latin Capital Ligature OE
  142: '\u017D', // Latin Capital Letter Z with Caron
  145: '\u2018', // Left Single Quotation Mark
  146: '\u2019', // Right Single Quotation Mark
  147: '\u201C', // Left Double Quotation Mark
  148: '\u201D', // Right Double Quotation Mark
  149: '\u2022', // Bullet
  150: '\u2013', // En Dash
  151: '\u2014', // Em Dash
  152: '\u02DC', // Small Tilde
  153: '\u2122', // Trade Mark Sign
  154: '\u0161', // Latin Small Letter S with Caron
  155: '\u203A', // Single Right-Pointing Angle Quotation Mark
  156: '\u0153', // Latin Small Ligature OE
  158: '\u017E', // Latin Small Letter Z with Caron
  159: '\u0178', // Latin Capital Letter Y with Diaeresis
};

const Map<String, String> _adobeGlyphList = {
  'space': ' ',
  'exclam': '!',
  'quotedbl': '"',
  'numbersign': '#',
  'dollar': '\$',
  'percent': '%',
  'ampersand': '&',
  'quotesingle': "'",
  'parenleft': '(',
  'parenright': ')',
  'asterisk': '*',
  'plus': '+',
  'comma': ',',
  'hyphen': '-',
  'period': '.',
  'slash': '/',
  'zero': '0',
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
  'colon': ':',
  'semicolon': ';',
  'less': '<',
  'equal': '=',
  'greater': '>',
  'question': '?',
  'at': '@',
  'bracketleft': '[',
  'backslash': '\\',
  'bracketright': ']',
  'asciicircum': '^',
  'underscore': '_',
  'grave': '`',
  'braceleft': '{',
  'bar': '|',
  'braceright': '}',
  'asciitilde': '~',
  'quoteleft': '\u2018',
  'quoteright': '\u2019',
  'quotedblleft': '\u201C',
  'quotedblright': '\u201D',
  'bullet': '\u2022',
  'endash': '\u2013',
  'emdash': '\u2014',
  'ellipsis': '\u2026',
  'copyright': '\u00A9',
  'registered': '\u00AE',
  'trademark': '\u2122',
  'degree': '\u00B0',
  'plusminus': '\u00B1',
  'multiply': '\u00D7',
  'divide': '\u00F7',
  'cent': '\u00A2',
  'pound': '\u00A3',
  'yen': '\u00A5',
  'euro': '\u20AC',
  'section': '\u00A7',
  'paragraph': '\u00B6',
  'dagger': '\u2020',
  'daggerdbl': '\u2021',
  'fi': 'fi',
  'fl': 'fl',
  'oe': '\u0153',
  'OE': '\u0152',
  'ae': '\u00E6',
  'AE': '\u00C6',
  'germandbls': '\u00DF',
};
