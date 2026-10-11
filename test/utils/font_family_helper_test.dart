import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/font_family_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const base = TextStyle(fontSize: 16);

  group('FontFamilyHelper.getTextStyle Bengali fallback', () {
    test('null family carries Kalpurush fallback', () {
      final style = FontFamilyHelper.getTextStyle(fontFamily: null, baseStyle: base);
      expect(style.fontFamilyFallback, contains(kBengaliFallbackFamily));
    });

    test('System Sans carries Kalpurush fallback', () {
      final style =
          FontFamilyHelper.getTextStyle(fontFamily: 'System Sans', baseStyle: base);
      expect(style.fontFamilyFallback, contains(kBengaliFallbackFamily));
    });

    test('System Serif resolves to serif with Kalpurush fallback', () {
      final style =
          FontFamilyHelper.getTextStyle(fontFamily: 'System Serif', baseStyle: base);
      expect(style.fontFamily, 'serif');
      expect(style.fontFamilyFallback, contains(kBengaliFallbackFamily));
    });

    test('monospace (code) keeps monospace primary with Kalpurush fallback', () {
      final style =
          FontFamilyHelper.getTextStyle(fontFamily: 'monospace', baseStyle: base);
      expect(style.fontFamily, 'monospace');
      expect(style.fontFamilyFallback, contains(kBengaliFallbackFamily));
    });

    test('a Google font name carries Kalpurush fallback', () {
      final style =
          FontFamilyHelper.getTextStyle(fontFamily: 'Roboto', baseStyle: base);
      expect(style.fontFamilyFallback, contains(kBengaliFallbackFamily));
    });

    test('Kalpurush is a fallback only, never the primary family', () {
      // Regression: Kalpurush must not shadow the chosen Latin font. The primary
      // family stays what was requested; Kalpurush only trails in the fallback.
      final serif =
          FontFamilyHelper.getTextStyle(fontFamily: 'System Serif', baseStyle: base);
      expect(serif.fontFamily, 'serif');
      expect(serif.fontFamily, isNot(kBengaliFallbackFamily));

      final mono =
          FontFamilyHelper.getTextStyle(fontFamily: 'monospace', baseStyle: base);
      expect(mono.fontFamily, 'monospace');
      expect(mono.fontFamilyFallback, contains(kBengaliFallbackFamily));
    });

    test('fallback is appended idempotently when style already has it', () {
      final once = FontFamilyHelper.getTextStyle(fontFamily: 'Roboto', baseStyle: base);
      final twice = FontFamilyHelper.getTextStyle(
        fontFamily: 'Roboto',
        baseStyle: once,
      );
      final occurrences =
          (twice.fontFamilyFallback ?? const <String>[]).where((f) => f == kBengaliFallbackFamily).length;
      expect(occurrences, 1);
    });
  });

  group('Active Bengali content font', () {
    tearDown(() => setActiveBengaliContentFont(null));

    test('defaults to Kalpurush only when no font is selected', () {
      setActiveBengaliContentFont(null);
      expect(kContentFontFallback, <String>['Kalpurush']);
    });

    test('selected Bengali font leads the chain, Kalpurush trails', () {
      setActiveBengaliContentFont('Kolpona');
      expect(kContentFontFallback, <String>['Kolpona', 'Kalpurush']);

      final style = FontFamilyHelper.getTextStyle(fontFamily: 'Roboto', baseStyle: base);
      expect(style.fontFamily, isNot('Kolpona')); // Latin primary unaffected
      expect(style.fontFamilyFallback, containsAllInOrder(<String>['Kolpona', 'Kalpurush']));
    });

    test('selecting the bundled Kalpurush family clears the override', () {
      setActiveBengaliContentFont('Kalpurush');
      expect(kContentFontFallback, <String>['Kalpurush']);
      expect(activeBengaliContentFont, isNull);
    });

    test('the Bengali faces are advertised as hosted downloads', () {
      expect(FontFamilyHelper.hostedFonts, containsAll(FontFamilyHelper.bengaliFonts));
      expect(FontFamilyHelper.bengaliFonts, contains('Kolpona'));
    });
  });
}
