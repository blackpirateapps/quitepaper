import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_font_manager.dart';

/// Semantic token types in highlighted source code.
enum CodeTokenType {
  plain,
  keyword,
  type,
  string,
  comment,
  number,
  punctuation,
}

/// A parsed code span with color styling.
class CodeToken {
  const CodeToken(this.text, this.type);
  final String text;
  final CodeTokenType type;
}

/// Lightweight, deterministic syntax highlighter for document-grade PDF code blocks.
class PdfCodeHighlighter {
  static const _dartKeywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'hide',
    'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync',
    'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with',
    'yield',
  };

  static const _jsKeywords = {
    'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'debugger', 'default', 'delete', 'do', 'else', 'enum', 'export', 'extends',
    'false', 'finally', 'for', 'from', 'function', 'get', 'if', 'implements',
    'import', 'in', 'instanceof', 'interface', 'let', 'new', 'null', 'of',
    'package', 'private', 'protected', 'public', 'return', 'set', 'static',
    'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof', 'var', 'void',
    'while', 'with', 'yield',
  };

  static const _pythonKeywords = {
    'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await', 'break',
    'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'finally',
    'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal',
    'not', 'or', 'pass', 'raise', 'return', 'try', 'while', 'with', 'yield',
  };

  static const _sqlKeywords = {
    'SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'UPDATE', 'DELETE', 'CREATE',
    'TABLE', 'ALTER', 'DROP', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'ON',
    'GROUP', 'BY', 'ORDER', 'HAVING', 'LIMIT', 'OFFSET', 'UNION', 'ALL',
    'AS', 'AND', 'OR', 'NOT', 'NULL', 'IS', 'IN', 'EXISTS', 'BETWEEN', 'LIKE',
    'INDEX', 'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES', 'VALUES', 'SET',
    'select', 'from', 'where', 'insert', 'into', 'update', 'delete', 'create',
    'table', 'alter', 'drop', 'join', 'left', 'right', 'inner', 'outer', 'on',
    'group', 'by', 'order', 'having', 'limit', 'offset', 'union', 'all',
    'as', 'and', 'or', 'not', 'null', 'is', 'in', 'exists', 'between', 'like',
  };

  /// Tokenizes a multi-line [code] string for the given [language].
  static List<List<CodeToken>> highlightLines(String code, String language) {
    final cleanLang = language.toLowerCase().trim();
    final rawLines = code.split('\n');

    final lines = <List<CodeToken>>[];
    for (final rawLine in rawLines) {
      lines.add(_highlightSingleLine(rawLine, cleanLang));
    }
    return lines;
  }

  static List<CodeToken> _highlightSingleLine(String line, String lang) {
    if (line.isEmpty) {
      return [const CodeToken('', CodeTokenType.plain)];
    }

    final tokens = <CodeToken>[];
    var i = 0;
    final len = line.length;

    Set<String> keywords;
    switch (lang) {
      case 'dart':
      case 'flutter':
        keywords = _dartKeywords;
        break;
      case 'js':
      case 'javascript':
      case 'ts':
      case 'typescript':
        keywords = _jsKeywords;
        break;
      case 'py':
      case 'python':
        keywords = _pythonKeywords;
        break;
      case 'sql':
        keywords = _sqlKeywords;
        break;
      default:
        keywords = _dartKeywords.union(_jsKeywords);
        break;
    }

    while (i < len) {
      // 1. Comments: // or # or --
      if ((line.startsWith('//', i)) ||
          (lang == 'python' && line[i] == '#') ||
          (lang == 'yaml' && line[i] == '#') ||
          (lang == 'sql' && line.startsWith('--', i))) {
        tokens.add(CodeToken(line.substring(i), CodeTokenType.comment));
        break;
      }

      // 2. Strings: "...", '...', `...`
      final char = line[i];
      if (char == '"' || char == "'" || char == '`') {
        final quoteChar = char;
        var endIdx = i + 1;
        while (endIdx < len) {
          if (line[endIdx] == '\\') {
            endIdx += 2;
            continue;
          }
          if (line[endIdx] == quoteChar) {
            endIdx++;
            break;
          }
          endIdx++;
        }
        tokens.add(CodeToken(line.substring(i, endIdx), CodeTokenType.string));
        i = endIdx;
        continue;
      }

      // 3. Numbers: 123, 0xFF, 3.14
      if (_isDigit(char) || (char == '-' && i + 1 < len && _isDigit(line[i + 1]))) {
        var endIdx = i + 1;
        while (endIdx < len && (_isAlphaNumericOrHex(line[endIdx]) || line[endIdx] == '.')) {
          endIdx++;
        }
        tokens.add(CodeToken(line.substring(i, endIdx), CodeTokenType.number));
        i = endIdx;
        continue;
      }

      // 4. Identifiers / Keywords / Types
      if (_isIdentifierStart(char)) {
        var endIdx = i + 1;
        while (endIdx < len && _isIdentifierPart(line[endIdx])) {
          endIdx++;
        }
        final word = line.substring(i, endIdx);
        if (keywords.contains(word)) {
          tokens.add(CodeToken(word, CodeTokenType.keyword));
        } else if (_isTypeIdentifier(word)) {
          tokens.add(CodeToken(word, CodeTokenType.type));
        } else {
          tokens.add(CodeToken(word, CodeTokenType.plain));
        }
        i = endIdx;
        continue;
      }

      // 5. Punctuation / Whitespace
      tokens.add(CodeToken(char, CodeTokenType.plain));
      i++;
    }

    return tokens;
  }

  static bool _isDigit(String char) {
    final c = char.codeUnitAt(0);
    return c >= 48 && c <= 57;
  }

  static bool _isAlphaNumericOrHex(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 48 && c <= 57) ||
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        char == 'x' ||
        char == 'X';
  }

  static bool _isIdentifierStart(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || char == '_' || char == r'$';
  }

  static bool _isIdentifierPart(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 48 && c <= 57) ||
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        char == '_' ||
        char == r'$';
  }

  static bool _isTypeIdentifier(String word) {
    if (word.isEmpty) return false;
    final first = word[0];
    return first == first.toUpperCase() && first != first.toLowerCase() && word.length > 1;
  }

  /// Converts a tokenized code line into a [pw.TextSpan].
  static pw.TextSpan buildLineSpan(
    List<CodeToken> tokens,
    PdfTypographyTheme typography,
    double fontSize,
  ) {
    final children = <pw.InlineSpan>[];

    for (final tok in tokens) {
      if (tok.text.isEmpty) continue;

      PdfColor color;
      pw.Font font = typography.mono;
      var isBold = false;
      var isItalic = false;

      switch (tok.type) {
        case CodeTokenType.keyword:
          color = PdfColor.fromHex('#7C3AED'); // Rich purple
          font = typography.monoBold;
          isBold = true;
          break;
        case CodeTokenType.type:
          color = PdfColor.fromHex('#0284C7'); // Light blue
          font = typography.monoBold;
          break;
        case CodeTokenType.string:
          color = PdfColor.fromHex('#15803D'); // Forest green
          break;
        case CodeTokenType.comment:
          color = PdfColor.fromHex('#6B7280'); // Muted grey
          font = typography.monoItalic;
          isItalic = true;
          break;
        case CodeTokenType.number:
          color = PdfColor.fromHex('#D97706'); // Warm amber
          break;
        case CodeTokenType.punctuation:
        case CodeTokenType.plain:
          color = PdfColor.fromHex('#1F2937'); // Slate dark
          break;
      }

      children.add(
        pw.TextSpan(
          text: tok.text,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            color: color,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
          ),
        ),
      );
    }

    return pw.TextSpan(children: children);
  }
}
