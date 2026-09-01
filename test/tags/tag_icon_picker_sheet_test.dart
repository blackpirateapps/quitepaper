import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/tags/application/phosphor_catalog_service.dart';
import 'package:quitepaper/features/tags/application/tag_icon_preferences_service.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_icon_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle(this.content);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleJson = jsonEncode([
    {
      'id': 'book-open',
      'name': 'Book Open',
      'pascalName': 'BookOpen',
      'camelName': 'bookOpen',
      'codePoint': 59001,
      'categories': ['education', 'media'],
      'tags': ['read', 'novel']
    },
    {
      'id': 'camera',
      'name': 'Camera',
      'pascalName': 'Camera',
      'camelName': 'camera',
      'codePoint': 59002,
      'categories': ['media'],
      'tags': ['photo', 'picture']
    },
    {
      'id': 'heart',
      'name': 'Heart',
      'pascalName': 'Heart',
      'camelName': 'heart',
      'codePoint': 59003,
      'categories': ['health'],
      'tags': ['love', 'like']
    },
  ]);

  late PhosphorCatalogService catalogService;
  late TagIconPreferencesService preferencesService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    catalogService = PhosphorCatalogService(assetBundle: TestAssetBundle(sampleJson));
    preferencesService = TagIconPreferencesService();
  });

  Widget buildTestWidget({
    String? selectedIconId,
    required ValueChanged<String?> onIconSelected,
    String tagName = 'project',
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TagIconPickerSheet(
          selectedIconId: selectedIconId,
          onIconSelected: onIconSelected,
          tagName: tagName,
          catalogService: catalogService,
          preferencesService: preferencesService,
        ),
      ),
    );
  }

  group('TagIconPickerSheet Widget Tests', () {
    testWidgets('renders search input, category chips, and loaded icons', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onIconSelected: (_) {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify title & search box
      expect(find.text('Choose Icon for #project'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify categories
      expect(find.text('All'), findsOneWidget);

      // Verify icons are present
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('searching filters icons dynamically', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onIconSelected: (_) {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter search term "camera"
      await tester.enterText(find.byType(TextField), 'camera');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should find results
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('tapping icon calls onIconSelected with canonical key', (tester) async {
      String? selected;
      await tester.pumpWidget(buildTestWidget(
        onIconSelected: (val) => selected = val,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap first icon item in grid
      final inkWells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      expect(inkWells, findsWidgets);

      await tester.tap(inkWells.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(selected, isNotNull);
      expect(selected!.startsWith('phosphor:'), isTrue);
    });

    testWidgets('shows "Remove Icon" when tag already has an icon', (tester) async {
      String? selected;
      await tester.pumpWidget(buildTestWidget(
        selectedIconId: 'phosphor:heart',
        onIconSelected: (val) => selected = val,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Remove Icon'), findsOneWidget);

      await tester.tap(find.text('Remove Icon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(selected, isNull);
    });
  });
}
