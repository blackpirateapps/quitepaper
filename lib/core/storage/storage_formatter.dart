/// Canonical storage byte size formatting utility for Quiet Paper.
///
/// Uses standard decimal storage units matching backend quota semantics:
/// - 1 KB = 1,000 bytes
/// - 1 MB = 1,000,000 bytes
/// - 1 GB = 1,000,000,000 bytes
abstract class StorageFormatter {
  static const int _kb = 1000;
  static const int _mb = 1000 * 1000;
  static const int _gb = 1000 * 1000 * 1000;

  /// Formats [bytes] into a human-readable string (e.g. `0 B`, `8 KB`, `842 KB`, `1.2 MB`, `842 MB`, `1.4 GB`, `10 GB`).
  static String formatBytes(int bytes, {int maxDecimals = 1}) {
    if (bytes < 0) bytes = 0;

    if (bytes < _kb) {
      return '$bytes B';
    }

    if (bytes < _mb) {
      final kbValue = bytes / _kb;
      return '${_formatNumber(kbValue, maxDecimals)} KB';
    }

    if (bytes < _gb) {
      final mbValue = bytes / _mb;
      return '${_formatNumber(mbValue, maxDecimals)} MB';
    }

    final gbValue = bytes / _gb;
    return '${_formatNumber(gbValue, maxDecimals)} GB';
  }

  /// Formats [bytes] with up to 2 decimal places when precision is desired.
  static String formatBytesDetailed(int bytes) => formatBytes(bytes, maxDecimals: 2);

  /// Helper to format number with at most [maxDecimals] decimal places,
  /// omitting trailing `.0` for clean integer presentations (e.g. `1 GB` instead of `1.0 GB`).
  static String _formatNumber(double value, int maxDecimals) {
    if (maxDecimals <= 0) {
      return value.round().toString();
    }

    final fixed = value.toStringAsFixed(maxDecimals);
    if (fixed.endsWith('.0') || fixed.endsWith('.00')) {
      return value.toInt().toString();
    }

    // Strip trailing zeroes after decimal point if any
    if (fixed.contains('.')) {
      final trimmed = fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return trimmed;
    }

    return fixed;
  }
}
