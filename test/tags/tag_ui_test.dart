import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tags/application/phosphor_catalog_service.dart';
import 'package:quitepaper/features/tags/application/tag_icon_preferences_service.dart';
import 'package:quitepaper/features/tags/application/tag_providers.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:quitepaper/features/tags/presentation/tag_browser_screen.dart';
import 'package:quitepaper/features/tags/presentation/tag_detail_screen.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_color_picker_sheet.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_icon_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final testTags = [
    Tag(
      id: 'tag-1',
      name: 'pinned-tag',
      icon: 'bookmark',
      color: 'coral',
      isPinned: true,
      pinnedOrder: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      noteCount: 4,
    ),
    Tag(
      id: 'tag-2',
      name: 'work',
      icon: 'briefcase',
      color: 'sage',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
      noteCount: 12,
    ),
    Tag(
      id: 'tag-3',
      name: 'ideas',
      icon: 'bulb',
      color: 'amber',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: DateTime(2026, 1, 3),
      updatedAt: DateTime(2026, 1, 3),
      noteCount: 0, // Unused tag
    ),
  ];

  Widget createTestApp(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        allTagsProvider.overrideWith((ref) => Stream.value(testTags)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: child,
      ),
    );
  }

  group('Tag Browser and Detail Screen Tests', () {
    testWidgets('TagBrowserScreen renders PINNED and ALL TAGS sections and handles search', (tester) async {
      await tester.pumpWidget(createTestApp(const TagBrowserScreen()));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Tags'), findsOneWidget);

      // Check sections
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('ALL TAGS'), findsOneWidget);

      // Check tag names
      expect(find.text('#pinned-tag'), findsOneWidget);
      expect(find.text('#work'), findsOneWidget);
      expect(find.text('#ideas'), findsOneWidget);

      // Note count badges
      expect(find.text('4'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // Test search
      await tester.tap(find.byTooltip('Search tags'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'work');
      await tester.pumpAndSettle();

      expect(find.text('#work'), findsOneWidget);
      expect(find.text('#pinned-tag'), findsNothing);
    });

    testWidgets('TagDetailScreen renders tag header, color, note count, and empty state', (tester) async {
      final tag = testTags[0];

      await tester.pumpWidget(
        createTestApp(
          TagDetailScreen(tagId: tag.id),
          overrides: [
            tagNotesStreamProvider(tag.name).overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check title and hero
      expect(find.text('#pinned-tag'), findsNWidgets(2)); // AppBar + Hero
      expect(find.text('0 notes'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);

      // Check empty state
      expect(find.text('No notes with #pinned-tag'), findsOneWidget);
      expect(find.text('New Note with Tag'), findsOneWidget);
    });

    testWidgets('TagDetailScreen displays associated notes when present', (tester) async {
      final tag = testTags[0];
      final sampleNote = Note(
        id: 'n1',
        title: 'Important Project Note',
        content: 'Content with #pinned-tag',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: [tag.name],
      );

      await tester.pumpWidget(
        createTestApp(
          TagDetailScreen(tagId: tag.id),
          overrides: [
            tagNotesStreamProvider(tag.name).overrideWith(
              (ref) => Stream.value([sampleNote]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 note'), findsOneWidget);
      expect(find.text('Important Project Note'), findsOneWidget);
    });

    testWidgets('TagIconPickerSheet renders categories, suggestions, and selects icon', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const sampleJson = '[{"id":"code","name":"Code","pascalName":"Code","camelName":"code","codePoint":59001,"categories":["development"],"tags":["dev","program"]}]';
      final catalogService = PhosphorCatalogService(
        assetBundle: _TestAssetBundle(sampleJson),
      );
      final preferencesService = TagIconPreferencesService();

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: Scaffold(
            body: TagIconPickerSheet(
              selectedIconId: null,
              tagName: 'flutter',
              catalogService: catalogService,
              preferencesService: preferencesService,
              onIconSelected: (id) => selected = id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Choose Icon for #flutter'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Search for code
      await tester.enterText(find.byType(TextField), 'code');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find code icon item and tap it
      final iconItem = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      expect(iconItem, findsWidgets);
      await tester.tap(iconItem.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(selected, equals('phosphor:code'));
    });

    testWidgets('TagColorPickerSheet renders warm editorial palette and selects color', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: Scaffold(
            body: TagColorPickerSheet(
              selectedColorId: null,
              onColorSelected: (id) => selected = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tag Color'), findsOneWidget);
      expect(find.text('None (Default Paper Accent)'), findsOneWidget);
      expect(find.text('WARM EDITORIAL PALETTE'), findsOneWidget);

      // Find Coral swatch
      expect(find.text('Coral'), findsOneWidget);
      expect(find.text('Sage'), findsOneWidget);
      expect(find.text('Lavender'), findsOneWidget);

      await tester.tap(find.text('Coral'));
      await tester.pumpAndSettle();

      expect(selected, equals('coral'));
    });
  });
}

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this.content);
  final String content;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return content;
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(content);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}
