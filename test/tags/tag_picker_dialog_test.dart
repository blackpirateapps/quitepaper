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
    TagSuggestionService? service,
    TargetPlatform platform = TargetPlatform.android,
    ValueChanged<List<String>?>? onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allTagsProvider.overrideWith(
            (ref) => tagStream ?? Stream.value(tags),
          ),
          tagSuggestionServiceProvider.overrideWithValue(
            service ?? TagSuggestionService(useNative: false),
          ),
          recentTagNamesProvider.overrideWith(
            (ref) => RecentTagNames(null)..record(['recent']),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            platform: platform,
            extensions: const [AppColors.light],
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await TagPickerDialog.show(
                    context,
                    existingTags: existing,
                  );
                  onResult?.call(result);
                },
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

  testWidgets('shows one ranked suggestions list and excludes attached tags', (
    tester,
  ) async {
    await open(tester, existing: ['existing']);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Recent'), findsNothing);
    expect(find.text('Most used'), findsNothing);
    expect(find.text('Pinned'), findsNothing);
    expect(option('existing'), findsNothing);
    final rows = tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(TagPickerDialog),
        matching: find.byType(ListTile),
      ),
    );
    expect(rows.take(3).map((row) => row.key), [
      const ValueKey('tag-option-pinned'),
      const ValueKey('tag-option-recent'),
      const ValueKey('tag-option-popular'),
    ]);
  });

  testWidgets('selection updates locally without reloading or resizing', (
    tester,
  ) async {
    final service = _GatedSuggestions();
    await open(tester, service: service);
    final content = find.byKey(const ValueKey('tag-picker-content'));
    final originalRect = tester.getRect(content);
    final originalField = tester.getRect(field);
    final popularElement = tester.element(option('popular'));
    final calls = service.calls;
    await tester.tap(option('pinned'));
    await tester.pump();
    expect(option('pinned'), findsNothing);
    expect(find.byKey(const ValueKey('selected-tag-pinned')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(service.calls, calls);
    expect(tester.element(option('popular')), same(popularElement));
    expect(tester.getRect(content), originalRect);
    expect(tester.getRect(field), originalField);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Remove #pinned from selection'));
    await tester.pump();
    expect(option('pinned'), findsOneWidget);
    expect(service.calls, calls);
    expect(tester.getRect(content), originalRect);
    expect(tester.getRect(field), originalField);
  });

  testWidgets(
    'initial sync keeps results visible across overlapping refreshes',
    (tester) async {
      final source = StreamController<List<Tag>>()..add([]);
      addTearDown(source.close);
      final service = _GatedSuggestions();
      await open(tester, tagStream: source.stream, service: service);
      final content = find.byKey(const ValueKey('tag-picker-content'));
      final originalRect = tester.getRect(content);
      source.add(tags);
      await tester.pumpAndSettle();
      expect(option('pinned'), findsOneWidget);
      expect(tester.getRect(content), originalRect);
      await tester.tap(option('pinned'));
      await tester.pumpAndSettle();
      await tester.enterText(field, 'pop');
      await tester.pumpAndSettle();
      expect(option('popular'), findsOneWidget);
      final originalInput = tester.widget<TextField>(field).controller!.value;
      final scroll = tester
          .widget<SingleChildScrollView>(
            find
                .descendant(
                  of: find.byType(TagPickerDialog),
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          )
          .controller!;
      final offset = scroll.offset;
      service.hold = true;
      source.add([...tags, sampleTag('pop-old')]);
      await tester.pump();
      await tester.pump();
      expect(service.pending, hasLength(2)); // Default and searched lists.
      expect(option('popular'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getRect(content), originalRect);
      expect(tester.widget<TextField>(field).controller!.value, originalInput);
      expect(scroll.offset, offset);
      expect(find.byKey(const ValueKey('selected-tag-pinned')), findsOneWidget);
      source.add([...tags, sampleTag('pop-new')]);
      await tester.pump();
      await tester.pump();
      expect(service.pending, hasLength(4));
      service.pending[2].complete();
      service.pending[3].complete();
      await tester.pumpAndSettle();
      expect(option('pop-new'), findsOneWidget);
      expect(option('pop-old'), findsNothing);
      service.pending[0].complete();
      service.pending[1].complete();
      await tester.pumpAndSettle();
      expect(option('pop-new'), findsOneWidget);
      expect(option('pop-old'), findsNothing);
      expect(tester.getRect(content), originalRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new searches hide old matches and selection restores warm defaults',
    (tester) async {
      final service = _GatedSuggestions();
      await open(tester, service: service);
      service.hold = true;
      await tester.enterText(field, 'work/');
      await tester.pump();
      expect(option('pinned'), findsNothing);
      expect(option('popular'), findsNothing);
      expect(service.pending, hasLength(1));
      service.pending.single.complete();
      await tester.pumpAndSettle();
      final calls = service.calls;
      await tester.ensureVisible(option('work/project'));
      await tester.tap(option('work/project'));
      await tester.pump();
      expect(option('pinned'), findsOneWidget);
      expect(option('work/project'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(service.calls, calls);
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.linux,
  ]) {
    testWidgets('compact adaptive picker on $platform', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, platform: platform);
      final content = find.byKey(const ValueKey('tag-picker-content'));
      expect(tester.getSize(content), const Size(440, 460));
      if (platform == TargetPlatform.linux) {
        expect(find.byType(BottomSheet), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.getBottomLeft(content).dy, 700);
        await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(TagPickerDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selecting deep in a long list preserves the scroll position', (
    tester,
  ) async {
    final service = _GatedSuggestions();
    await open(
      tester,
      service: service,
      tagStream: Stream.value([
        for (var i = 0; i < 50; i++)
          sampleTag('tag${i.toString().padLeft(2, '0')}', count: 50 - i),
      ]),
    );
    await tester.ensureVisible(option('tag20'));
    await tester.pumpAndSettle();
    final scroll = tester
        .widget<SingleChildScrollView>(
          find
              .descendant(
                of: find.byType(TagPickerDialog),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        )
        .controller!;
    final offset = scroll.offset;
    final calls = service.calls;
    expect(offset, greaterThan(0));
    await tester.tap(option('tag20'));
    await tester.pumpAndSettle();
    expect(option('tag20'), findsNothing);
    expect(option('tag21'), findsOneWidget);
    expect(scroll.offset, offset);
    expect(service.calls, calls);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removing an exact match during sync does not duplicate its row',
    (tester) async {
      final source = StreamController<List<Tag>>()..add(tags);
      addTearDown(source.close);
      final service = _GatedSuggestions();
      await open(tester, tagStream: source.stream, service: service);
      await tester.enterText(field, 'popular');
      await tester.pumpAndSettle();
      service.hold = true;
      source.add(tags.where((tag) => tag.name != 'popular').toList());
      await tester.pump();
      await tester.pump();
      expect(option('popular'), findsOneWidget);
      expect(find.text('Create #popular'), findsNothing);
      expect(tester.takeException(), isNull);
      for (final gate in service.pending) {
        gate.complete();
      }
      await tester.pumpAndSettle();
      expect(option('popular'), findsOneWidget);
      expect(find.text('Create #popular'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

/// Holds selected ranking calls to reproduce native work overlapping sync pages.
class _GatedSuggestions extends TagSuggestionService {
  _GatedSuggestions() : super(useNative: false);

  bool hold = false;
  int calls = 0;
  final pending = <Completer<void>>[];

  @override
  Future<List<String>> search({
    required List<Tag> tags,
    required String query,
    required List<String> recent,
    required Set<String> excluded,
    TagSuggestionSort sort = TagSuggestionSort.suggested,
    int limit = 40,
  }) async {
    calls++;
    final result = await super.search(
      tags: tags,
      query: query,
      recent: recent,
      excluded: excluded,
      sort: sort,
      limit: limit,
    );
    if (hold) {
      final gate = Completer<void>();
      pending.add(gate);
      await gate.future;
    }
    return result;
  }
}
