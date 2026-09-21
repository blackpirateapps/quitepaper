import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for initial launch command-line arguments (passed on Linux and desktop CLI).
final initialLaunchArgsProvider = Provider<List<String>>((ref) => const []);

/// Helper to parse and evaluate command-line arguments on desktop platforms.
class CliArgsHelper {
  const CliArgsHelper._();

  /// Finds the first argument that is an existing markdown file (.md, .markdown, .txt)
  static String? findMarkdownFile(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith('-')) continue;
      final lower = arg.toLowerCase();
      if (lower.endsWith('.md') || lower.endsWith('.markdown') || lower.endsWith('.txt')) {
        return arg;
      }
    }
    return null;
  }

  /// Checks if any argument matches the given flag (e.g. `--new-note` or `-n`).
  static bool hasFlag(List<String> args, String flag, [String? shortAlias]) {
    final flagClean = flag.replaceFirst(RegExp(r'^-+'), '');
    final effectiveShort = shortAlias ?? (flagClean == 'new-note' ? 'n' : null);
    return args.any((a) {
      if (a == flag || a == '--$flagClean' || a == '-$flagClean') return true;
      if (effectiveShort != null && (a == effectiveShort || a == '-${effectiveShort.replaceFirst(RegExp(r'^-+'), '')}')) {
        return true;
      }
      return false;
    });
  }
}
