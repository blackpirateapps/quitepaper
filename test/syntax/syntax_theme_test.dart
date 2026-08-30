import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/syntax/domain/syntax_theme.dart';
import 'package:quitepaper/core/syntax/domain/syntax_token_type.dart';

void main() {
  group('SyntaxTheme', () {
    test('creates light and dark themes from AppColors with distinctive token styles', () {
      final lightColors = AppColors.light;
      final lightTheme = SyntaxTheme.fromColors(lightColors);

      final darkColors = AppColors.dark;
      final darkTheme = SyntaxTheme.fromColors(darkColors);

      // Verify each token type resolves to a valid TextStyle
      for (final type in SyntaxTokenType.values) {
        final lightStyle = lightTheme.styleFor(type);
        final darkStyle = darkTheme.styleFor(type);

        expect(lightStyle, isNotNull);
        expect(darkStyle, isNotNull);
        expect(lightStyle.color, isNotNull);
        expect(darkStyle.color, isNotNull);
      }

      // Keywords have subtle bolding
      expect(lightTheme.styleFor(SyntaxTokenType.keyword).fontWeight, equals(FontWeight.w600));
      expect(darkTheme.styleFor(SyntaxTokenType.keyword).fontWeight, equals(FontWeight.w600));

      // Comments have italic styling
      expect(lightTheme.styleFor(SyntaxTokenType.comment).fontStyle, equals(FontStyle.italic));
      expect(darkTheme.styleFor(SyntaxTokenType.comment).fontStyle, equals(FontStyle.italic));
    });
  });
}
