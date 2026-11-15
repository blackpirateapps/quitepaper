/// Offline, bounded spreadsheet arithmetic. This library has no Flutter,
/// persistence, network, locale, or executable-expression dependencies.
library;

class FormulaFailure implements Exception {
  const FormulaFailure(this.code);
  final String code;
}

/// Fixed decimal: 18 fractional digits, at most 48 integer digits. Every
/// multiplication/division rounds half away from zero to 18 places.
class TableDecimal implements Comparable<TableDecimal> {
  TableDecimal._(this.units) {
    if (units.abs().toString().length > 66) {
      throw const FormulaFailure('#LIMIT!');
    }
  }
  static final scale = BigInt.from(10).pow(18);
  static final zero = TableDecimal._(BigInt.zero);
  final BigInt units;

  static TableDecimal parse(String raw) {
    if (raw.length > 80 ||
        !RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(raw)) {
      throw const FormulaFailure('#VALUE!');
    }
    final negative = raw.startsWith('-');
    final parts = raw.replaceFirst(RegExp(r'^[+-]'), '').split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > 18) throw const FormulaFailure('#LIMIT!');
    final units =
        BigInt.parse(parts[0].isEmpty ? '0' : parts[0]) * scale +
        BigInt.parse(fraction.padRight(18, '0'));
    return TableDecimal._(negative ? -units : units);
  }

  static BigInt _rounded(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) throw const FormulaFailure('#DIV/0!');
    final negative = numerator.isNegative != denominator.isNegative;
    final n = numerator.abs(), d = denominator.abs();
    var q = n ~/ d;
    if ((n % d) * BigInt.two >= d) q += BigInt.one;
    return negative ? -q : q;
  }

  TableDecimal operator +(TableDecimal other) =>
      TableDecimal._(units + other.units);
  TableDecimal operator -(TableDecimal other) =>
      TableDecimal._(units - other.units);
  TableDecimal operator -() => TableDecimal._(-units);
  TableDecimal operator *(TableDecimal other) =>
      TableDecimal._(_rounded(units * other.units, scale));
  TableDecimal operator /(TableDecimal other) =>
      TableDecimal._(_rounded(units * scale, other.units));
  @override
  int compareTo(TableDecimal other) => units.compareTo(other.units);

  String toFixed(int digits) {
    digits = digits.clamp(0, 18);
    final divisor = BigInt.from(10).pow(18 - digits);
    final rounded = _rounded(units, divisor);
    final s = rounded.abs().toString().padLeft(digits + 1, '0');
    return '${rounded.isNegative ? '-' : ''}${digits == 0 ? s : '${s.substring(0, s.length - digits)}.${s.substring(s.length - digits)}'}';
  }

  @override
  String toString() {
    final s = toFixed(
      18,
    ).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s == '-0' ? '0' : s;
  }
}

class CellAddress {
  const CellAddress(
    this.row,
    this.column, {
    this.absoluteRow = false,
    this.absoluteColumn = false,
  });
  final int row, column; // Zero based, including header.
  final bool absoluteRow, absoluteColumn;
  static final pattern = RegExp(r'^(\$?)([A-Za-z]{1,4})(\$?)([1-9]\d{0,6})$');
  static CellAddress parse(String s) {
    final m = pattern.firstMatch(s);
    if (m == null) throw const FormulaFailure('#REF!');
    var col = 0;
    for (final c in m[2]!.toUpperCase().codeUnits) {
      col = col * 26 + c - 64;
    }
    return CellAddress(
      int.parse(m[4]!) - 1,
      col - 1,
      absoluteRow: m[3] == r'$',
      absoluteColumn: m[1] == r'$',
    );
  }

  static String columnName(int column) {
    var n = column + 1, out = '';
    while (n > 0) {
      n--;
      out = String.fromCharCode(65 + n % 26) + out;
      n ~/= 26;
    }
    return out;
  }

  String get key => '$row:$column';
  String get label => '${columnName(column)}${row + 1}';
  CellAddress at(int r, int c) => CellAddress(
    r,
    c,
    absoluteRow: absoluteRow,
    absoluteColumn: absoluteColumn,
  );
  @override
  String toString() =>
      '${absoluteColumn ? r'$' : ''}${columnName(column)}${absoluteRow ? r'$' : ''}${row + 1}';
}

/// Rewrites tokens, never values. Anchors affect copying but still follow
/// structural insertions/deletions, just as ordinary A1 references do.
abstract final class FormulaReferences {
  static final _references = RegExp(
    r'(?<![A-Za-z0-9_])\$?[A-Za-z]{1,4}\$?[1-9]\d{0,6}(?![A-Za-z0-9_])',
  );
  static String rewrite(
    String raw,
    CellAddress? Function(CellAddress) transform,
  ) {
    if (!raw.trimLeft().startsWith('=')) return raw;
    return raw.replaceAllMapped(_references, (m) {
      final ref = transform(CellAddress.parse(m[0]!));
      return ref == null || ref.row < 0 || ref.column < 0
          ? '#REF!'
          : ref.toString();
    });
  }

  static String shift(String raw, int rows, int columns) => rewrite(
    raw,
    (a) => a.at(
      a.row + (a.absoluteRow ? 0 : rows),
      a.column + (a.absoluteColumn ? 0 : columns),
    ),
  );

  static String structure(
    String raw, {
    required bool rows,
    required int index,
    required bool delete,
  }) {
    if (!raw.trimLeft().startsWith('=')) return raw;
    // Shrink ranges when deleting an endpoint; a fully deleted range is #REF!.
    final ranges = RegExp(
      r'(\$?[A-Za-z]{1,4}\$?[1-9]\d{0,6})\s*:\s*(\$?[A-Za-z]{1,4}\$?[1-9]\d{0,6})',
    );
    final saved = <String>[];
    String? mapRange(CellAddress a, CellAddress b) {
      int coordinate(CellAddress c) => rows ? c.row : c.column;
      var x = coordinate(a), y = coordinate(b);
      final forward = x <= y;
      var low = forward ? x : y, high = forward ? y : x;
      if (delete) {
        if (low == high && low == index) return null;
        if (low > index) low--;
        if (high >= index) high--;
      } else {
        if (low >= index) low++;
        if (high >= index) high++;
      }
      x = forward ? low : high;
      y = forward ? high : low;
      return '${rows ? a.at(x, a.column) : a.at(a.row, x)}:${rows ? b.at(y, b.column) : b.at(b.row, y)}';
    }

    final masked = raw.replaceAllMapped(ranges, (m) {
      saved.add(
        mapRange(CellAddress.parse(m[1]!), CellAddress.parse(m[2]!)) ?? '#REF!',
      );
      return '@${saved.length - 1}@';
    });
    final rewritten = rewrite(masked, (a) {
      final v = rows ? a.row : a.column;
      if (delete && v == index) return null;
      final n = v + (v >= index ? (delete ? -1 : 1) : 0);
      return rows ? a.at(n, a.column) : a.at(a.row, n);
    });
    return rewritten.replaceAllMapped(
      RegExp(r'@(\d+)@'),
      (m) => saved[int.parse(m[1]!)],
    );
  }
}

enum CellValueKind { number, text, blank, error }

class CellValue {
  const CellValue._(this.kind, this.number, this.text);
  factory CellValue.numeric(TableDecimal n) =>
      CellValue._(CellValueKind.number, n, '');
  const CellValue.text(String text) : this._(CellValueKind.text, null, text);
  const CellValue.error(String error)
    : this._(CellValueKind.error, null, error);
  const CellValue.blank() : this._(CellValueKind.blank, null, '');
  final CellValueKind kind;
  final TableDecimal? number;
  final String text;
  String get display => number?.toString() ?? text;
}

sealed class _Expr {}

class _Number extends _Expr {
  _Number(this.value);
  final TableDecimal value;
}

class _Ref extends _Expr {
  _Ref(this.address);
  final CellAddress address;
}

class _Range extends _Expr {
  _Range(this.start, this.end);
  final CellAddress start, end;
}

class _Unary extends _Expr {
  _Unary(this.op, this.child);
  final String op;
  final _Expr child;
}

class _Binary extends _Expr {
  _Binary(this.op, this.left, this.right);
  final String op;
  final _Expr left, right;
}

class _Call extends _Expr {
  _Call(this.name, this.args);
  final String name;
  final List<_Expr> args;
}

class _Error extends _Expr {
  _Error(this.code);
  final String code;
}

class _Parser {
  _Parser(String source) {
    if (source.length > 2048) throw const FormulaFailure('#LIMIT!');
    final pattern = RegExp(
      r'\s+|#REF!|\$?[A-Za-z]+\$?\d+|[A-Za-z]+|(?:\d+(?:\.\d*)?|\.\d+)|[+*/(),:\-]',
    );
    var offset = 0;
    while (offset < source.length) {
      final m = pattern.matchAsPrefix(source, offset);
      if (m == null) throw const FormulaFailure('#PARSE!');
      if (m[0]!.trim().isNotEmpty) tokens.add(m[0]!);
      offset = m.end;
    }
    if (tokens.length > 512) throw const FormulaFailure('#LIMIT!');
  }
  final tokens = <String>[];
  int index = 0, depth = 0;
  String get current => index < tokens.length ? tokens[index] : '';
  bool take(String s) {
    if (current != s) return false;
    index++;
    return true;
  }

  _Expr parse() {
    final out = expression();
    if (current.isNotEmpty) throw const FormulaFailure('#PARSE!');
    return out;
  }

  _Expr expression([int precedence = 0]) {
    if (++depth > 64) throw const FormulaFailure('#LIMIT!');
    _Expr left;
    if (take('+')) {
      left = _Unary('+', expression(3));
    } else if (take('-')) {
      left = _Unary('-', expression(3));
    } else if (take('(')) {
      left = expression();
      if (!take(')')) throw const FormulaFailure('#PARSE!');
    } else if (take('#REF!')) {
      left = _Error('#REF!');
    } else {
      final t = current;
      index++;
      if (RegExp(r'^[\d.]').hasMatch(t)) {
        left = _Number(TableDecimal.parse(t));
      } else if (CellAddress.pattern.hasMatch(t)) {
        left = _Ref(CellAddress.parse(t));
      } else if (RegExp(r'^[A-Za-z]+$').hasMatch(t) && take('(')) {
        final args = <_Expr>[];
        if (!take(')')) {
          do {
            var arg = expression();
            if (take(':')) {
              final end = current;
              index++;
              if (arg is! _Ref || !CellAddress.pattern.hasMatch(end)) {
                throw const FormulaFailure('#PARSE!');
              }
              arg = _Range(arg.address, CellAddress.parse(end));
            }
            args.add(arg);
          } while (take(','));
          if (!take(')')) throw const FormulaFailure('#PARSE!');
        }
        left = _Call(t.toUpperCase(), args);
      } else {
        throw const FormulaFailure('#PARSE!');
      }
    }
    while (true) {
      final op = current;
      final p = op == '+' || op == '-'
          ? 1
          : op == '*' || op == '/'
          ? 2
          : 0;
      if (p <= precedence) break;
      index++;
      left = _Binary(op, left, expression(p));
    }
    depth--;
    return left;
  }
}

/// Table-scoped expression, dependency and result cache. update() invalidates
/// changed cells and their downstream dependents; structural edits reset caches.
class FormulaEngine {
  FormulaEngine(List<List<String>> rows) {
    update(rows);
  }
  static const maxCells = 10000, maxWork = 100000, maxDependencyDepth = 128;
  List<List<String>> _rows = const [];
  final _asts = <String, _Expr>{};
  final _values = <String, CellValue>{};
  final _dependencies = <String, Set<String>>{};
  final _visiting = <String>{};
  int _work = 0;
  bool _oversized = false;

  void update(List<List<String>> rows) {
    final structural =
        rows.length != _rows.length ||
        rows.asMap().entries.any(
          (e) => e.key >= _rows.length || e.value.length != _rows[e.key].length,
        );
    if (structural) {
      _values.clear();
      _dependencies.clear();
    } else {
      final dirty = <String>{};
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          if (rows[r][c] != _rows[r][c]) dirty.add('$r:$c');
        }
      }
      var changed = true;
      while (changed) {
        changed = false;
        for (final entry in _dependencies.entries) {
          if (!dirty.contains(entry.key) && entry.value.any(dirty.contains)) {
            dirty.add(entry.key);
            changed = true;
          }
        }
      }
      for (final key in dirty) {
        _values.remove(key);
        _dependencies.remove(key);
      }
    }
    _oversized =
        rows.fold<int>(0, (sum, row) => sum + row.length) > maxCells ||
        rows.any((row) => row.length > 256);
    _rows = List.unmodifiable(rows.map((r) => List<String>.unmodifiable(r)));
    if (_asts.length > maxCells) _asts.clear();
    _work = 0;
  }

  CellValue value(int row, int column) {
    final address = CellAddress(row, column);
    return _values[address.key] ?? _cell(address);
  }

  CellValue _cell(CellAddress a) {
    if (++_work > maxWork || _oversized) {
      return const CellValue.error('#LIMIT!');
    }
    if (a.row < 0 ||
        a.row >= _rows.length ||
        a.column < 0 ||
        a.column >= _rows[a.row].length) {
      return const CellValue.error('#REF!');
    }
    if (_visiting.contains(a.key)) return const CellValue.error('#CYCLE!');
    if (_values.containsKey(a.key)) return _values[a.key]!;
    if (_visiting.length >= maxDependencyDepth) {
      return const CellValue.error('#LIMIT!');
    }
    final raw = _rows[a.row][a.column].trim();
    CellValue result;
    if (raw.isEmpty) {
      result = const CellValue.blank();
    } else if (raw.startsWith("'=")) {
      result = CellValue.text(raw.substring(1));
    } else if (raw.startsWith('=')) {
      _visiting.add(a.key);
      _dependencies[a.key] = {};
      try {
        final expr = _asts.putIfAbsent(
          raw,
          () => _Parser(raw.substring(1)).parse(),
        );
        result = CellValue.numeric(_numeric(_eval(expr, a.key)));
      } on FormulaFailure catch (e) {
        result = CellValue.error(e.code);
      } finally {
        _visiting.remove(a.key);
      }
    } else {
      try {
        result = CellValue.numeric(TableDecimal.parse(raw));
      } on FormulaFailure catch (e) {
        result = e.code == '#LIMIT!' && RegExp(r'^[+-]?[\d.]+$').hasMatch(raw)
            ? CellValue.error(e.code)
            : CellValue.text(raw);
      }
    }
    _values[a.key] = result;
    return result;
  }

  TableDecimal _numeric(CellValue value) {
    if (value.kind == CellValueKind.error) throw FormulaFailure(value.text);
    if (value.kind == CellValueKind.blank) return TableDecimal.zero;
    if (value.number == null) throw const FormulaFailure('#VALUE!');
    return value.number!;
  }

  CellValue _read(CellAddress ref, String owner) {
    _dependencies[owner]!.add(ref.key);
    return _cell(ref);
  }

  CellValue _eval(_Expr expr, String owner) {
    if (++_work > maxWork) throw const FormulaFailure('#LIMIT!');
    switch (expr) {
      case _Number():
        return CellValue.numeric(expr.value);
      case _Error():
        throw FormulaFailure(expr.code);
      case _Ref():
        return _read(expr.address, owner);
      case _Unary():
        final n = _numeric(_eval(expr.child, owner));
        return CellValue.numeric(expr.op == '-' ? -n : n);
      case _Binary():
        final l = _numeric(_eval(expr.left, owner)),
            r = _numeric(_eval(expr.right, owner));
        return CellValue.numeric(switch (expr.op) {
          '+' => l + r,
          '-' => l - r,
          '*' => l * r,
          _ => l / r,
        });
      case _Range():
        throw const FormulaFailure('#PARSE!');
      case _Call():
        if (!const [
          'SUM',
          'AVERAGE',
          'MIN',
          'MAX',
          'COUNT',
        ].contains(expr.name)) {
          throw const FormulaFailure('#PARSE!');
        }
        final values = <TableDecimal>[];
        void include(CellValue v) {
          if (v.kind == CellValueKind.error) throw FormulaFailure(v.text);
          if (v.number != null) values.add(v.number!);
        }
        for (final arg in expr.args) {
          if (arg is _Range) {
            final r0 = arg.start.row < arg.end.row
                ? arg.start.row
                : arg.end.row;
            final r1 = arg.start.row > arg.end.row
                ? arg.start.row
                : arg.end.row;
            final c0 = arg.start.column < arg.end.column
                ? arg.start.column
                : arg.end.column;
            final c1 = arg.start.column > arg.end.column
                ? arg.start.column
                : arg.end.column;
            if ((r1 - r0 + 1) * (c1 - c0 + 1) > maxCells) {
              throw const FormulaFailure('#LIMIT!');
            }
            if (r1 >= _rows.length ||
                c1 >= (_rows.isEmpty ? 0 : _rows.first.length)) {
              throw const FormulaFailure('#REF!');
            }
            for (var r = r0; r <= r1; r++) {
              for (var c = c0; c <= c1; c++) {
                include(_read(CellAddress(r, c), owner));
              }
            }
          } else {
            include(_eval(arg, owner));
          }
        }
        return CellValue.numeric(aggregate(expr.name, values));
    }
  }

  static TableDecimal aggregate(String operation, List<TableDecimal> values) {
    if (operation == 'COUNT') return TableDecimal.parse('${values.length}');
    if (values.isEmpty && operation != 'SUM') {
      throw FormulaFailure(operation == 'AVERAGE' ? '#DIV/0!' : '#VALUE!');
    }
    final sum = values.fold(TableDecimal.zero, (a, b) => a + b);
    return switch (operation) {
      'SUM' => sum,
      'AVERAGE' => sum / TableDecimal.parse('${values.length}'),
      'MIN' => values.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
      'MAX' => values.reduce((a, b) => a.compareTo(b) > 0 ? a : b),
      _ => throw const FormulaFailure('#PARSE!'),
    };
  }
}
