import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:highlight/languages/all.dart' as hl_all;
import '../application/syntax_highlight_cache.dart';
import '../application/syntax_highlighter.dart';
import '../domain/highlight_result.dart';
import '../domain/syntax_language.dart';
import '../domain/syntax_token.dart';
import '../domain/syntax_token_type.dart';

/// Concrete implementation of [SyntaxHighlighter] backed by the Dart `highlight` package.
/// Completely encapsulates the third-party dependency.
class HighlightPackageAdapter implements SyntaxHighlighter {
  HighlightPackageAdapter({
    SyntaxHighlightCache? cache,
    this.maxHighlightCharacters = 50000,
  }) : _cache = cache ?? SyntaxHighlightCache();

  final SyntaxHighlightCache _cache;

  /// Maximum source code character count before falling back to high-speed plain text.
  final int maxHighlightCharacters;

  static bool _languagesRegistered = false;

  static void _ensureLanguagesRegistered() {
    if (!_languagesRegistered) {
      hl.highlight.registerLanguages(hl_all.allLanguages);
      _languagesRegistered = true;
    }
  }

  @override
  HighlightResult highlight({
    required String source,
    required SyntaxLanguage language,
  }) {
    if (source.isEmpty) {
      return HighlightResult(
        language: language,
        sourceLength: 0,
        tokens: const [],
        isSuccess: true,
      );
    }

    // 1. Check if language is supported or is plain text or whitespace-only
    if (!language.isSupported || language.id == 'text' || source.trim().isEmpty) {
      return HighlightResult.plain(language: language, source: source);
    }

    // 2. Safeguard for extremely large source files (e.g. >50k characters)
    if (source.length > maxHighlightCharacters) {
      return HighlightResult.plain(language: language, source: source);
    }

    // 3. Check cache
    final cacheKey = SyntaxHighlightCache.buildKey(
      languageId: language.id,
      source: source,
      highlighterVersion: SyntaxHighlighter.version,
    );
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      _ensureLanguagesRegistered();

      // 4. Parse source with highlight engine
      final hlResult = hl.highlight.parse(
        source,
        language: language.id,
        autoDetection: false,
      );

      final nodes = hlResult.nodes;
      if (nodes == null || nodes.isEmpty) {
        final fallback = HighlightResult.plain(language: language, source: source);
        _cache.put(cacheKey, fallback);
        return fallback;
      }

      // 5. Flatten AST nodes into UTF-16 semantic tokens
      final tokens = <SyntaxToken>[];
      var currentOffset = 0;

      void traverse(List<hl.Node>? children, SyntaxTokenType? inheritedType) {
        if (children == null) return;
        for (final node in children) {
          final nodeType = _normalizeTokenType(node.className) ?? inheritedType;

          if (node.value != null) {
            final val = node.value!;
            final start = currentOffset;
            final end = min(source.length, currentOffset + val.length);

            if (end > start) {
              final type = nodeType ?? SyntaxTokenType.plain;
              tokens.add(SyntaxToken(
                start: start,
                end: end,
                type: type,
                text: val,
              ));
              currentOffset = end;
            }
          }

          if (node.children != null && node.children!.isNotEmpty) {
            traverse(node.children, nodeType);
          }
        }
      }

      traverse(nodes, null);

      // 6. Ensure any remaining source characters are covered
      if (currentOffset < source.length) {
        tokens.add(SyntaxToken(
          start: currentOffset,
          end: source.length,
          type: SyntaxTokenType.plain,
          text: source.substring(currentOffset),
        ));
      }

      // 7. Merge consecutive tokens of the same type for optimal rendering performance
      final mergedTokens = _mergeAdjacentTokens(tokens);

      final result = HighlightResult(
        language: language,
        sourceLength: source.length,
        tokens: mergedTokens,
        isSuccess: true,
      );

      _cache.put(cacheKey, result);
      return result;
    } catch (e, st) {
      debugPrint('Syntax highlighting error for ${language.id}: $e\n$st');
      final fallback = HighlightResult.plain(language: language, source: source);
      _cache.put(cacheKey, fallback);
      return fallback;
    }
  }

  static List<SyntaxToken> _mergeAdjacentTokens(List<SyntaxToken> tokens) {
    if (tokens.isEmpty) return const [];

    final merged = <SyntaxToken>[];
    for (final tok in tokens) {
      if (tok.length <= 0) continue;
      if (merged.isNotEmpty &&
          merged.last.end == tok.start &&
          merged.last.type == tok.type) {
        final prev = merged.removeLast();
        merged.add(SyntaxToken(
          start: prev.start,
          end: tok.end,
          type: prev.type,
          text: (prev.text != null && tok.text != null)
              ? '${prev.text}${tok.text}'
              : null,
        ));
      } else {
        merged.add(tok);
      }
    }
    return merged;
  }

  /// Deterministically maps third-party highlight class names into Quiet Paper's [SyntaxTokenType].
  static SyntaxTokenType? _normalizeTokenType(String? className) {
    if (className == null || className.isEmpty || className == 'null') {
      return null;
    }

    final lower = className.toLowerCase();

    // Direct mapping
    switch (lower) {
      case 'keyword':
      case 'selector-tag':
        return SyntaxTokenType.keyword;

      case 'string':
      case 'bullet':
        return SyntaxTokenType.string;

      case 'number':
        return SyntaxTokenType.number;

      case 'comment':
      case 'doctag':
      case 'quote':
        return SyntaxTokenType.comment;

      case 'function':
      case 'title.function':
      case 'title.function.invoke':
        return SyntaxTokenType.function;

      case 'title':
      case 'class':
      case 'title.class':
      case 'title.class.inherited':
      case 'type':
        return SyntaxTokenType.type;

      case 'variable':
      case 'template-variable':
      case 'params':
        return SyntaxTokenType.variable;

      case 'constant':
        return SyntaxTokenType.constant;

      case 'operator':
        return SyntaxTokenType.operator;

      case 'punctuation':
        return SyntaxTokenType.punctuation;

      case 'attr':
      case 'attribute':
      case 'property':
        return SyntaxTokenType.property;

      case 'tag':
      case 'name':
      case 'selector-id':
      case 'selector-class':
        return SyntaxTokenType.tag;

      case 'built_in':
      case 'builtin-name':
        return SyntaxTokenType.builtin;

      case 'literal':
      case 'symbol':
        return SyntaxTokenType.literal;

      case 'regexp':
        return SyntaxTokenType.regexp;

      case 'meta':
      case 'meta-keyword':
      case 'meta-string':
      case 'meta-subst':
      case 'annotation':
        return SyntaxTokenType.annotation;

      case 'section':
      case 'heading':
        return SyntaxTokenType.heading;

      case 'link':
        return SyntaxTokenType.link;

      case 'subst':
      case 'formula':
      case 'emphasis':
      case 'strong':
        return SyntaxTokenType.plain;

      default:
        // Compound classes like "hljs-keyword" or "title function"
        if (lower.contains('keyword')) return SyntaxTokenType.keyword;
        if (lower.contains('string')) return SyntaxTokenType.string;
        if (lower.contains('number')) return SyntaxTokenType.number;
        if (lower.contains('comment')) return SyntaxTokenType.comment;
        if (lower.contains('function')) return SyntaxTokenType.function;
        if (lower.contains('type') || lower.contains('class')) return SyntaxTokenType.type;
        if (lower.contains('built_in') || lower.contains('builtin')) return SyntaxTokenType.builtin;
        if (lower.contains('variable')) return SyntaxTokenType.variable;
        if (lower.contains('attr') || lower.contains('property')) return SyntaxTokenType.property;
        if (lower.contains('tag')) return SyntaxTokenType.tag;
        if (lower.contains('meta')) return SyntaxTokenType.annotation;

        return SyntaxTokenType.plain;
    }
  }
}
