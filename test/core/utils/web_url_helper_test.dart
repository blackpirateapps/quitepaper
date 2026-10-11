import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/web_url_helper.dart';

void main() {
  group('isSingleWebUrl', () {
    test('plain https URL is true', () {
      expect(isSingleWebUrl('https://example.com'), isTrue);
      expect(isSingleWebUrl('https://example.com/a/b?c=d#e'), isTrue);
    });

    test('plain http URL is true', () {
      expect(isSingleWebUrl('http://example.com'), isTrue);
    });

    test('scheme matching is case-insensitive', () {
      expect(isSingleWebUrl('HTTPS://example.com'), isTrue);
      expect(isSingleWebUrl('Http://Example.com'), isTrue);
    });

    test('trailing/leading whitespace and newline are trimmed first', () {
      expect(isSingleWebUrl('  https://example.com  '), isTrue);
      expect(isSingleWebUrl('https://example.com\n'), isTrue);
      expect(isSingleWebUrl('\n\thttps://example.com\t\n'), isTrue);
    });

    test('non-http(s) schemes are false', () {
      expect(isSingleWebUrl('qp://note/x'), isFalse);
      expect(isSingleWebUrl('mailto:a@b.com'), isFalse);
      expect(isSingleWebUrl('ftp://example.com'), isFalse);
    });

    test('multi-line payload is false', () {
      expect(isSingleWebUrl('https://a.com\nhttps://b.com'), isFalse);
    });

    test('URL embedded in a sentence is false', () {
      expect(isSingleWebUrl('see https://example.com for details'), isFalse);
      expect(isSingleWebUrl('https://example.com now'), isFalse);
    });

    test('interior whitespace is false', () {
      expect(isSingleWebUrl('https://exa mple.com'), isFalse);
    });

    test('empty string is false', () {
      expect(isSingleWebUrl(''), isFalse);
      expect(isSingleWebUrl('   '), isFalse);
    });
  });

  group('normalizeWebUrl', () {
    test('returns the trimmed URL for a single web URL', () {
      expect(normalizeWebUrl('  https://example.com  '), 'https://example.com');
      expect(normalizeWebUrl('http://example.com\n'), 'http://example.com');
    });

    test('returns null when not a single web URL', () {
      expect(normalizeWebUrl('qp://note/x'), isNull);
      expect(normalizeWebUrl('mailto:a@b.com'), isNull);
      expect(normalizeWebUrl('see https://example.com here'), isNull);
      expect(normalizeWebUrl(''), isNull);
    });
  });
}
