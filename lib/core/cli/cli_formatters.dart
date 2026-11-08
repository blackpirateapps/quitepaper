import 'dart:io';

/// Formatter for CLI output (ANSI colors, terminal widths, relative dates).
class CliFormatters {
  const CliFormatters._();

  static bool _noColor = false;

  static void setNoColor(bool noColor) {
    _noColor = noColor;
  }

  static bool get useColor {
    if (_noColor) return false;
    if (Platform.environment.containsKey('NO_COLOR')) return false;
    return stdout.hasTerminal;
  }

  // ANSI escape codes
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _dim = '\x1B[2m';
  static const _cyan = '\x1B[36m';
  static const _yellow = '\x1B[33m';
  static const _blue = '\x1B[34m';
  static const _green = '\x1B[32m';
  static const _red = '\x1B[31m';
  static const _magenta = '\x1B[35m';

  static String bold(String s) => useColor ? '$_bold$s$_reset' : s;
  static String dim(String s) => useColor ? '$_dim$s$_reset' : s;
  static String cyan(String s) => useColor ? '$_cyan$s$_reset' : s;
  static String yellow(String s) => useColor ? '$_yellow$s$_reset' : s;
  static String blue(String s) => useColor ? '$_blue$s$_reset' : s;
  static String green(String s) => useColor ? '$_green$s$_reset' : s;
  static String red(String s) => useColor ? '$_red$s$_reset' : s;
  static String magenta(String s) => useColor ? '$_magenta$s$_reset' : s;

  /// Formats relative human-friendly timestamp (e.g. "just now", "15m ago", "2h ago", "yesterday", "Oct 24").
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final y = dateTime.year.toString().padLeft(4, '0');
      final m = dateTime.month.toString().padLeft(2, '0');
      final d = dateTime.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
  }

  /// Truncates string to [maxLength], appending ellipsis if shortened.
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    if (maxLength <= 3) return text.substring(0, maxLength);
    return '${text.substring(0, maxLength - 3)}...';
  }
}
