import '../domain/syntax_language.dart';
import 'syntax_language_registry.dart';

/// Resolves syntax languages for Markdown code fences and attached files.
class SyntaxLanguageResolver {
  SyntaxLanguageResolver({
    SyntaxLanguageRegistry? registry,
  }) : _registry = registry ?? SyntaxLanguageRegistry.instance;

  final SyntaxLanguageRegistry _registry;

  /// Resolves the [SyntaxLanguage] from a Markdown code fence info string (e.g. 'dart', '```python', 'json').
  ///
  /// Priority:
  /// 1. If [infoString] is null or empty, returns `null` (plain text, no guessing).
  /// 2. If infoString is 'text' / 'plaintext', returns `null` / plainText (plain text, no guessing).
  /// 3. Normalizes alias and checks registered grammars.
  /// 4. If unknown, returns an unsupported [SyntaxLanguage] instance with the raw identifier.
  SyntaxLanguage? resolveFromFence(String? infoString) {
    if (infoString == null) return null;
    final clean = infoString.trim().split(RegExp(r'\s+')).first;
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();
    if (lower == 'text' || lower == 'plaintext' || lower == 'txt' || lower == 'plain') {
      return SyntaxLanguage.plainText;
    }

    final matched = _registry.findByIdOrAlias(lower);
    if (matched != null) {
      return matched;
    }

    // Return custom unsupported representation
    return SyntaxLanguage(
      id: lower,
      name: clean,
      isSupported: false,
    );
  }

  /// Resolves the [SyntaxLanguage] for an attached code or text file.
  ///
  /// Priority:
  /// 1. Explicit user override [overrideLanguageId] (if specified)
  /// 2. MIME type [mimeType] (if known)
  /// 3. File extension [fileName] (if known)
  /// 4. Fallback to [SyntaxLanguage.plainText]
  SyntaxLanguage resolveForAttachment({
    String? overrideLanguageId,
    String? mimeType,
    String? fileName,
  }) {
    // 1. Explicit display override
    if (overrideLanguageId != null && overrideLanguageId.isNotEmpty) {
      final override = _registry.findByIdOrAlias(overrideLanguageId);
      if (override != null) return override;
      if (overrideLanguageId.toLowerCase() == 'text') return SyntaxLanguage.plainText;
    }

    // 2. MIME type
    if (mimeType != null && mimeType.isNotEmpty) {
      final fromMime = _registry.findByMimeType(mimeType);
      if (fromMime != null) return fromMime;
    }

    // 3. File extension
    if (fileName != null && fileName.isNotEmpty) {
      final dotIdx = fileName.lastIndexOf('.');
      if (dotIdx != -1 && dotIdx < fileName.length - 1) {
        final ext = fileName.substring(dotIdx + 1);
        final fromExt = _registry.findByExtension(ext);
        if (fromExt != null) return fromExt;
      }
    }

    return SyntaxLanguage.plainText;
  }
}
