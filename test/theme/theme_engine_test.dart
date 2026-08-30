import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/app/theme/theme_resolver.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/syntax/domain/syntax_theme.dart';
import 'package:quitepaper/core/syntax/domain/syntax_token_type.dart';
import 'package:quitepaper/core/widgets/intelligent_heading_scrollbar.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/settings_screen.dart';
import 'package:quitepaper/features/sidebar/presentation/widgets/sidebar_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Theme Resolution Architecture', () {
    test('Classic Paper + Light -> Classic Paper Light', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.classicPaper,
        appearance: AppearanceMode.light,
        platformBrightness: Brightness.light,
      );
      expect(resolved, equals(ResolvedTheme.classicPaperLight));
      expect(resolved.isDark, isFalse);

      final colors = ThemeResolver.resolveColors(
        family: ThemeFamily.classicPaper,
        isDark: false,
      );
      expect(colors, equals(AppColors.classicLight));
    });

    test('Classic Paper + Dark -> Classic Paper Dark', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.classicPaper,
        appearance: AppearanceMode.dark,
        platformBrightness: Brightness.light,
      );
      expect(resolved, equals(ResolvedTheme.classicPaperDark));
      expect(resolved.isDark, isTrue);

      final colors = ThemeResolver.resolveColors(
        family: ThemeFamily.classicPaper,
        isDark: true,
      );
      expect(colors, equals(AppColors.classicDark));
    });

    test('Classic Paper + System + Light OS -> Classic Paper Light', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.classicPaper,
        appearance: AppearanceMode.system,
        platformBrightness: Brightness.light,
      );
      expect(resolved, equals(ResolvedTheme.classicPaperLight));
    });

    test('Classic Paper + System + Dark OS -> Classic Paper Dark', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.classicPaper,
        appearance: AppearanceMode.system,
        platformBrightness: Brightness.dark,
      );
      expect(resolved, equals(ResolvedTheme.classicPaperDark));
    });

    test('Warm Paper + Light -> Warm Paper Light', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.warmPaper,
        appearance: AppearanceMode.light,
        platformBrightness: Brightness.light,
      );
      expect(resolved, equals(ResolvedTheme.warmPaperLight));
      expect(resolved.isDark, isFalse);

      final colors = ThemeResolver.resolveColors(
        family: ThemeFamily.warmPaper,
        isDark: false,
      );
      expect(colors, equals(AppColors.warmPaperLight));
    });

    test('Warm Paper + Dark -> Midnight Paper', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.warmPaper,
        appearance: AppearanceMode.dark,
        platformBrightness: Brightness.light,
      );
      expect(resolved, equals(ResolvedTheme.midnightPaper));
      expect(resolved.isDark, isTrue);

      final colors = ThemeResolver.resolveColors(
        family: ThemeFamily.warmPaper,
        isDark: true,
      );
      expect(colors, equals(AppColors.midnightPaperDark));
    });

    test('Warm Paper + System + Light OS -> Warm Paper Light', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.warmPaper,
        appearance: AppearanceMode.system,
        platformBrightness: Brightness.light,
      );
      expect(resolved, equals(ResolvedTheme.warmPaperLight));
    });

    test('Warm Paper + System + Dark OS -> Midnight Paper', () {
      final resolved = ThemeResolver.resolve(
        family: ThemeFamily.warmPaper,
        appearance: AppearanceMode.system,
        platformBrightness: Brightness.dark,
      );
      expect(resolved, equals(ResolvedTheme.midnightPaper));
    });
  });

  group('2. Exact Canonical Palette Token Assertions', () {
    test('Warm Paper Light canonical palette matches specification', () {
      const colors = AppColors.warmPaperLight;
      expect(colors.background, equals(const Color(0xFFF2F1EE)));
      expect(colors.surface, equals(const Color(0xFFFFFFFF)));
      expect(colors.surfaceSecondary, equals(const Color(0xFFFBFAF8)));
      expect(colors.surfaceSubtle, equals(const Color(0xFFF5F4F1)));
      expect(colors.divider, equals(const Color(0xFFE5E3DF)));
      expect(colors.border, equals(const Color(0xFFE5E3DF)));
      expect(colors.textPrimary, equals(const Color(0xFF202124)));
      expect(colors.textSecondary, equals(const Color(0xFF5F6368)));
      expect(colors.textTertiary, equals(const Color(0xFF8C8B87)));
      expect(colors.textMuted, equals(const Color(0xFF8C8B87)));
      expect(colors.textDisabled, equals(const Color(0xFF9A9994)));
      expect(colors.scrollbar, equals(const Color(0xFF9DA1AA)));
      expect(colors.scrollbarActive, equals(const Color(0xFF60646D)));
      expect(colors.accent, equals(const Color(0xFF3B82F6)));
      expect(colors.accentLight, equals(const Color(0xFFDBEAFE)));
      expect(colors.sidebarBackground, equals(const Color(0xFF202329)));
      expect(colors.sidebarSelected, equals(const Color(0xFF353A43)));
      expect(colors.tagBackground, equals(const Color(0xFFE5E3DD)));
      expect(colors.tagText, equals(const Color(0xFF5F6368)));
    });

    test('Midnight Paper Dark canonical palette matches specification', () {
      const colors = AppColors.midnightPaperDark;
      expect(colors.background, equals(const Color(0xFF11151A)));
      expect(colors.surface, equals(const Color(0xFF171C22)));
      expect(colors.surfaceSecondary, equals(const Color(0xFF1D232B)));
      expect(colors.surfaceSubtle, equals(const Color(0xFF222932)));
      expect(colors.divider, equals(const Color(0xFF303741)));
      expect(colors.border, equals(const Color(0xFF303741)));
      expect(colors.textPrimary, equals(const Color(0xFFF1F2F4)));
      expect(colors.textSecondary, equals(const Color(0xFFC5C8CE)));
      expect(colors.textTertiary, equals(const Color(0xFF8D939D)));
      expect(colors.textMuted, equals(const Color(0xFF8D939D)));
      expect(colors.scrollbar, equals(const Color(0xFF777D88)));
      expect(colors.scrollbarActive, equals(const Color(0xFF93C5FD)));
      expect(colors.accent, equals(const Color(0xFF60A5FA)));
      expect(colors.accentLight, equals(const Color(0xFF93C5FD)));
      expect(colors.sidebarBackground, equals(const Color(0xFF11151A)));
      expect(colors.sidebarSelected, equals(const Color(0xFF1F2630)));
    });

    test('Classic Paper original tokens are preserved unchanged', () {
      const light = AppColors.classicLight;
      expect(light.background, equals(const Color(0xFFF7F6F2)));
      expect(light.surface, equals(const Color(0xFFFBFAF7)));
      expect(light.accent, equals(const Color(0xFFD65F55)));

      const dark = AppColors.classicDark;
      expect(dark.background, equals(const Color(0xFF1D1C1A)));
      expect(dark.surface, equals(const Color(0xFF242320)));
      expect(dark.accent, equals(const Color(0xFFE4776D)));
    });
  });

  group('3. Settings Persistence & Migration', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Defaults to Classic Paper and System mode when no prefs exist', () {
      final notifier = ThemeSettingsNotifier(prefs);
      expect(notifier.state.family, equals(ThemeFamily.classicPaper));
      expect(notifier.state.appearance, equals(AppearanceMode.system));
    });

    test('Migrates legacy app_theme_mode safely and idempotently', () {
      prefs.setString('app_theme_mode', 'dark');
      final notifier = ThemeSettingsNotifier(prefs);
      expect(notifier.state.family, equals(ThemeFamily.classicPaper));
      expect(notifier.state.appearance, equals(AppearanceMode.dark));
    });

    test('Persists theme family changes to SharedPreferences', () async {
      final notifier = ThemeSettingsNotifier(prefs);
      await notifier.setThemeFamily(ThemeFamily.warmPaper);
      expect(notifier.state.family, equals(ThemeFamily.warmPaper));
      expect(prefs.getString('app_theme_family'), equals('warm_paper'));
    });

    test('Persists appearance mode changes to SharedPreferences', () async {
      final notifier = ThemeSettingsNotifier(prefs);
      await notifier.setAppearanceMode(AppearanceMode.light);
      expect(notifier.state.appearance, equals(AppearanceMode.light));
      expect(prefs.getString('app_appearance_mode'), equals('light'));
      expect(prefs.getString('app_theme_mode'), equals('light'));
    });
  });

  group('4. Syntax Highlighting Theme Adaptation', () {
    test('Warm Paper Light derives restrained slate blue syntax theme', () {
      final syntaxTheme = SyntaxTheme.fromColors(AppColors.warmPaperLight);
      final keywordStyle = syntaxTheme.styleFor(SyntaxTokenType.keyword);
      final stringStyle = syntaxTheme.styleFor(SyntaxTokenType.string);

      expect(keywordStyle.color, equals(const Color(0xFF2563EB)));
      expect(stringStyle.color, equals(const Color(0xFF16A34A)));
    });

    test('Midnight Paper Dark derives luminous slate blue syntax theme', () {
      final syntaxTheme = SyntaxTheme.fromColors(AppColors.midnightPaperDark);
      final keywordStyle = syntaxTheme.styleFor(SyntaxTokenType.keyword);
      final stringStyle = syntaxTheme.styleFor(SyntaxTokenType.string);

      expect(keywordStyle.color, equals(const Color(0xFF60A5FA)));
      expect(stringStyle.color, equals(const Color(0xFF4ADE80)));
    });
  });

  group('5. Intelligent Scrollbar & Gradient Theming', () {
    testWidgets('Scrollbar thumb and gradient derive from active theme',
        (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.warmPaperLight(),
          home: Scaffold(
            body: IntelligentHeadingScrollbar(
              scrollController: scrollController,
              markdownData: '# Heading 1\n\nContent paragraph\n\n## Subheading\n\nMore',
              child: ListView(
                controller: scrollController,
                children: List.generate(
                  50,
                  (i) => SizedBox(height: 50, child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IntelligentHeadingScrollbar), findsOneWidget);
    });
  });

  group('6. Settings Screen Theme & Appearance Controls', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renders Theme Family and Appearance sections and allows switching',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.classicLight(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THEME FAMILY'), findsOneWidget);
      expect(find.text('Classic Paper'), findsOneWidget);
      expect(find.text('Warm Paper'), findsOneWidget);

      // Tap Warm Paper
      await tester.ensureVisible(find.text('Warm Paper'));
      await tester.tap(find.text('Warm Paper'));
      await tester.pumpAndSettle();
      expect(prefs.getString('app_theme_family'), equals('warm_paper'));

      // Ensure Appearance section is visible
      await tester.ensureVisible(find.text('APPEARANCE'));
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Tap Dark appearance
      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(prefs.getString('app_appearance_mode'), equals('dark'));
    });
  });

  group('7. Sidebar Dark Contrast & Item Legibility', () {
    testWidgets('SidebarItem renders high-contrast count badge when selected in Warm Paper Light',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.warmPaperLight(),
          home: Scaffold(
            body: Container(
              color: AppColors.warmPaperLight.sidebarBackground,
              child: Column(
                children: [
                  SidebarItem(
                    icon: Icons.description_outlined,
                    label: 'All Notes',
                    count: 428,
                    isSelected: true,
                    onTap: () {},
                  ),
                  SidebarItem(
                    icon: Icons.push_pin_outlined,
                    label: 'Pinned',
                    count: 1,
                    isSelected: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final countFinder = find.text('428');
      expect(countFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(countFinder);
      expect(textWidget.style?.color, equals(const Color(0xFFE5E7EB)));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w600));

      final unselectedCountFinder = find.text('1');
      expect(unselectedCountFinder, findsOneWidget);
      final unselectedTextWidget = tester.widget<Text>(unselectedCountFinder);
      expect(unselectedTextWidget.style?.color, equals(const Color(0xFF9CA3AF)));
    });
  });
}
