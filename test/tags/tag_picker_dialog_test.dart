import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/tags/application/tag_providers.dart';
import 'package:quitepaper/features/tags/application/tag_suggestions.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_picker_dialog.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:quitepaper/features/editor/presentation/widgets/tag_editor_bar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';
import 'package:quitepaper/features/editor/application/frontmatter_editor_helper.dart';
import 'tag_suggestions_test.dart' show sampleTag;

void main() {
  final tags = [
    sampleTag('pinned', pinned: true),
    sampleTag('recent', count: 1),
    sampleTag('popular', count: 40),
    sampleTag('work/project'),
    sampleTag('work/project/deep'),
    sampleTag('existing'),
  ];
  final field = find.byKey(const ValueKey('tag-picker-input'));
  Finder option(String name) => find.byKey(ValueKey('tag-option-$name'));
  Future<void> open(
    WidgetTester tester, {
    List<String> existing = const [],
    Stream<List<Tag>>? tagStream,
    ValueChanged<List<String>?>? onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allTagsProvider.overrideWith(
            (ref) => tagStream ?? Stream.value(tags),
          ),
          tagSuggestionServiceProvider.overrideWithValue(
            TagSuggestionService(useNative: false),
          ),
          recentTagNamesProvider.overrideWith(
            (ref) => RecentTagNames(null)..record(['recent']),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => onResult?.call(
                  await TagPickerDialog.show(context, existingTags: existing),
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows suggestions immediately, supports categories and excludes attached tags',
    (tester) async {
      await open(tester, existing: ['existing'], onResult: (_) {});
      expect(option('pinned'), findsOneWidget);
      expect(option('existing'), findsNothing);
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      expect(option('recent'), findsOneWidget);
      expect(option('popular'), findsNothing);
      await tester.tap(find.text('Most used'));
      await tester.pumpAndSettle();
      expect(option('popular'), findsOneWidget);
      expect(option('pinned'), findsNothing);
      await tester.tap(find.text('Pinned'));
      await tester.pumpAndSettle();
      expect(option('pinned'), findsOneWidget);
      expect(option('recent'), findsNothing);
    },
  );

  testWidgets('suggestions update when the catalogue changes while open', (
    tester,
  ) async {
    final source = StreamController<List<Tag>>()..add(tags);
    addTearDown(source.close);
    await open(tester, tagStream: source.stream, onResult: (_) {});
    expect(option('pinned'), findsOneWidget);
    source.add([sampleTag('new-pinned', pinned: true)]);
    await tester.pumpAndSettle();
    expect(option('pinned'), findsNothing);
    expect(option('new-pinned'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('stages multiple tags and only returns additions on Apply', (
    tester,
  ) async {
    List<String>? result;
    await open(tester, onResult: (value) => result = value);
    await tester.tap(option('pinned'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(option('pinned'), findsNothing);
    await tester.tap(option('recent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
    await tester.pumpAndSettle();
    expect(result, ['pinned', 'recent']);
  });

  testWidgets(
    'cancel discards additions and chip deletion restores a suggestion',
    (tester) async {
      List<String>? result;
      await open(tester, onResult: (value) => result = value);
      await tester.tap(option('pinned'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove #pinned from selection'));
      await tester.pumpAndSettle();
      expect(option('pinned'), findsOneWidget);
      await tester.tap(option('recent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );

  testWidgets(
    'nested autocomplete scopes children and completes with keyboard',
    (tester) async {
      List<String>? result;
      await open(tester, onResult: (value) => result = value);
      await tester.enterText(field, 'work/');
      await tester.pumpAndSettle();
      expect(find.text(' Subtags of '), findsOneWidget);
      expect(option('work/project'), findsOneWidget);
      expect(option('popular'), findsNothing);
      expect(find.text('Create #work/'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'work/project');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
      await tester.pumpAndSettle();
      expect(result, ['work/project']);
    },
  );

  testWidgets(
    'browse subtag button fills parent prefix and offers a new child',
    (tester) async {
      List<String>? result;
      await open(tester, onResult: (value) => result = value);
      await tester.ensureVisible(
        find.byTooltip('Browse subtags of #work/project'),
      );
      await tester.tap(find.byTooltip('Browse subtags of #work/project'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'work/project/');
      await tester.enterText(field, 'work/project/new');
      await tester.pumpAndSettle();
      await tester.tap(option('work/project/new'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
      await tester.pumpAndSettle();
      expect(result, ['work/project/new']);
    },
  );

  testWidgets('comma paste deduplicates and Apply includes unfinished input', (
    tester,
  ) async {
    List<String>? result;
    await open(
      tester,
      existing: ['existing'],
      onResult: (value) => result = value,
    );
    await tester.enterText(field, '#Ideas, ideas, existing, journal/2026');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
    await tester.pumpAndSettle();
    expect(result, ['ideas', 'journal/2026']);
  });

  testWidgets('invalid pasted batch remains editable and cannot be applied', (
    tester,
  ) async {
    List<String>? result;
    await open(tester, onResult: (value) => result = value);
    await tester.enterText(field, 'valid, work//bad, ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-tag-valid')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.textContaining('each path segment must be complete'),
      findsOneWidget,
    );
    await tester.enterText(field, 'valid, work/fixed');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
    await tester.pumpAndSettle();
    expect(result, ['valid', 'work/fixed']);
  });

  testWidgets('phone keyboard and larger text keep controls reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, onResult: (_) {});
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'journal/2026');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
    await tester.pumpAndSettle();
    expect(find.byType(TagPickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor entry applies the entire picker batch once', (
    tester,
  ) async {
    List<String>? result;
    var batches = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allTagsProvider.overrideWith((ref) => Stream.value(tags)),
          tagSuggestionServiceProvider.overrideWithValue(
            TagSuggestionService(useNative: false),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: Scaffold(
            body: TagEditorBar(
              tags: const ['existing'],
              onAddTag: (_) => fail('expected batch'),
              onAddTags: (value) {
                batches++;
                result = value;
              },
              onRemoveTag: (_) {},
              showAddButton: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tag'));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'ideas, work/project');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
    await tester.pumpAndSettle();
    expect(result, ['ideas', 'work/project']);
    expect(batches, 1);
  });

  testWidgets(
    'frontmatter entry preserves all staged tags in one document update',
    (tester) async {
      const source = '---\ntags: [existing]\n---\n\nBody';
      String? updated;
      var changes = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTagsProvider.overrideWith((ref) => Stream.value(tags)),
            tagSuggestionServiceProvider.overrideWithValue(
              TagSuggestionService(useNative: false),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: Scaffold(
              body: SingleChildScrollView(
                child: FrontmatterPropertiesSection(
                  readOnly: false,
                  frontmatter: FrontmatterEditorHelper.parse(source),
                  rawDocument: source,
                  onDocumentChanged: (value) {
                    updated = value;
                    changes++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tag'));
      await tester.pumpAndSettle();
      await tester.enterText(field, 'ideas, work/project');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-picker-apply')));
      await tester.pumpAndSettle();
      expect(FrontmatterEditorHelper.parse(updated!).tags, [
        'existing',
        'ideas',
        'work/project',
      ]);
      expect(changes, 1);
    },
  );
}
