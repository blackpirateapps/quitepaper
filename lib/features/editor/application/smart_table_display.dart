import 'package:intl/intl.dart';
import '../domain/smart_tables/formula_engine.dart';

/// Locale-aware presentation without converting a decimal value to double.
/// Intl supplies separators, digit shapes and currency/percent affixes only.
abstract final class SmartTableDisplay {
  static String format(CellValue value, dynamic config, {String? locale}) {
    if (value.number == null || config is! Map) return value.display;
    final type = config['type'];
    if (!const ['number', 'decimal', 'currency', 'percent'].contains(type)) {
      return value.display;
    }
    final requested = config['digits'];
    final digits = requested is int
        ? requested.clamp(0, 18)
        : type == 'currency'
        ? 2
        : type == 'number'
        ? null
        : 2;
    try {
      final number = type == 'percent'
          ? value.number! * TableDecimal.parse('100')
          : value.number!;
      final currency =
          config['currency'] is String &&
              RegExp(r'^[A-Z]{3}$').hasMatch(config['currency'])
          ? config['currency'] as String
          : 'USD';
      final f = type == 'currency'
          ? NumberFormat.simpleCurrency(
              locale: locale,
              name: currency,
              decimalDigits: digits,
            )
          : type == 'percent'
          ? NumberFormat.percentPattern(locale)
          : NumberFormat.decimalPattern(locale);
      final raw = digits == null ? number.toString() : number.toFixed(digits);
      final negative = raw.startsWith('-');
      final parts = (negative ? raw.substring(1) : raw).split('.');
      final pattern = f.symbols.DECIMAL_PATTERN.split('.').first.split(',');
      final primary = pattern.length > 1 ? pattern.last.length : 0;
      final secondary = pattern.length > 2
          ? pattern[pattern.length - 2].length
          : primary;
      var integer = parts.first;
      final groups = <String>[];
      var size = primary;
      while (size > 0 && integer.length > size) {
        groups.insert(0, integer.substring(integer.length - size));
        integer = integer.substring(0, integer.length - size);
        size = secondary;
      }
      groups.insert(0, integer);
      var output =
          groups.join(f.symbols.GROUP_SEP) +
          (parts.length > 1 ? '${f.symbols.DECIMAL_SEP}${parts[1]}' : '');
      final zero = f.symbols.ZERO_DIGIT.runes.single;
      if (zero != 48) {
        output = output.replaceAllMapped(
          RegExp(r'\d'),
          (m) => String.fromCharCode(zero + int.parse(m[0]!)),
        );
      }
      return '${negative ? f.negativePrefix : f.positivePrefix}$output${negative ? f.negativeSuffix : f.positiveSuffix}';
    } on FormulaFailure catch (e) {
      return e.code;
    } catch (_) {
      return value.display;
    }
  }
}
