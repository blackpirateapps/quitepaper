import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../infrastructure/highlight_package_adapter.dart';
import 'syntax_highlight_cache.dart';
import 'syntax_highlighter.dart';
import 'syntax_language_registry.dart';
import 'syntax_language_resolver.dart';

/// Provider for the shared tokenization cache.
final syntaxHighlightCacheProvider = Provider<SyntaxHighlightCache>((ref) {
  return SyntaxHighlightCache(maxEntries: 120);
});

/// Provider for the [SyntaxHighlighter] singleton engine.
final syntaxHighlighterProvider = Provider<SyntaxHighlighter>((ref) {
  final cache = ref.watch(syntaxHighlightCacheProvider);
  return HighlightPackageAdapter(cache: cache);
});

/// Provider for the [SyntaxLanguageRegistry].
final syntaxLanguageRegistryProvider = Provider<SyntaxLanguageRegistry>((ref) {
  return SyntaxLanguageRegistry.instance;
});

/// Provider for the [SyntaxLanguageResolver].
final syntaxLanguageResolverProvider = Provider<SyntaxLanguageResolver>((ref) {
  final registry = ref.watch(syntaxLanguageRegistryProvider);
  return SyntaxLanguageResolver(registry: registry);
});

/// Temporary presentation override provider for attachment viewers (attachmentId -> languageId).
final attachmentLanguageOverrideProvider =
    StateProvider.family<String?, String>((ref, attachmentId) => null);
