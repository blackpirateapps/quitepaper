import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TypographySettings', () {
    test('default settings have expected values', () {
      const settings = TypographySettings();
      expect(settings.headingFontFamily, isNull);
      expect(settings.bodyFontFamily, isNull);
      expect(settings.codeFontFamily, equals('monospace'));
      expect(settings.fontSize, equals(18.0));
      expect(settings.lineHeight, equals(1.6));
      expect(settings.letterSpacing, equals(0.0));
      expect(settings.paragraphWidth, equals(ParagraphWidth.medium));
      expect(settings.paragraphIndent, equals(0.0));
    });

    test('proportional scale calculations are accurate', () {
      const settings = TypographySettings(fontSize: 18.0);
      expect(settings.scaledHeading1Size, equals(26.0));
      expect(settings.scaledHeading2Size, equals(22.0));
      expect(settings.scaledHeading3Size, equals(19.0));
      expect(settings.scaledHeading4Size, equals(18.0));
      expect(settings.scaledHeading5Size, equals(17.0));
      expect(settings.scaledHeading6Size, equals(16.0));
      expect(settings.scaledTitleSize, equals(30.0));
      expect(settings.scaledCodeSize, equals(15.0));
    });

    test('serialization and deserialization roundtrip preserves all values', () {
      const original = TypographySettings(
        headingFontFamily: 'Playfair Display',
        bodyFontFamily: 'Lora',
        codeFontFamily: 'Fira Code',
        fontSize: 20.0,
        lineHeight: 1.8,
        letterSpacing: 0.5,
        paragraphWidth: ParagraphWidth.narrow,
        paragraphIndent: 16.0,
        customFonts: ['Custom-Sans'],
      );

      final json = original.toJson();
      final restored = TypographySettings.fromJson(json);

      expect(restored.headingFontFamily, equals('Playfair Display'));
      expect(restored.bodyFontFamily, equals('Lora'));
      expect(restored.codeFontFamily, equals('Fira Code'));
      expect(restored.fontSize, equals(20.0));
      expect(restored.lineHeight, equals(1.8));
      expect(restored.letterSpacing, equals(0.5));
      expect(restored.paragraphWidth, equals(ParagraphWidth.narrow));
      expect(restored.paragraphIndent, equals(16.0));
      expect(restored.customFonts, equals(['Custom-Sans']));
    });

    test('copyWith updates specified fields correctly', () {
      const settings = TypographySettings();
      final updated = settings.copyWith(
        fontSize: 22.0,
        paragraphWidth: ParagraphWidth.full,
      );

      expect(updated.fontSize, equals(22.0));
      expect(updated.paragraphWidth, equals(ParagraphWidth.full));
      expect(updated.lineHeight, equals(1.6));
    });
  });

  group('TypographySettingsNotifier', () {
    test('loads default settings and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = TypographySettingsNotifier();

      expect(notifier.state.fontSize, equals(18.0));

      notifier.setFontSize(22.0);
      expect(notifier.state.fontSize, equals(22.0));

      notifier.setLineHeight(1.8);
      expect(notifier.state.lineHeight, equals(1.8));

      notifier.setLetterSpacing(0.2);
      expect(notifier.state.letterSpacing, equals(0.2));

      notifier.setParagraphWidth(ParagraphWidth.full);
      expect(notifier.state.paragraphWidth, equals(ParagraphWidth.full));

      notifier.setHeadingFontFamily('Merriweather');
      expect(notifier.state.headingFontFamily, equals('Merriweather'));

      notifier.setBodyFontFamily('Inter');
      expect(notifier.state.bodyFontFamily, equals('Inter'));

      notifier.setCodeFontFamily('JetBrains Mono');
      expect(notifier.state.codeFontFamily, equals('JetBrains Mono'));

      notifier.resetToDefault();
      expect(notifier.state.fontSize, equals(18.0));
      expect(notifier.state.lineHeight, equals(1.6));
      expect(notifier.state.letterSpacing, equals(0.0));
      expect(notifier.state.headingFontFamily, isNull);
      expect(notifier.state.bodyFontFamily, isNull);
      expect(notifier.state.codeFontFamily, equals('monospace'));
    });
  });
}
