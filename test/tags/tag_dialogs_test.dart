import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_action_dialogs.dart';

void main() {
  Widget createDialogApp(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );
  }

  group('Tag Action Dialogs Tests', () {
    testWidgets('TagCreateDialog validates input and produces Tag entity', (
      tester,
    ) async {
      Tag? createdTag;

      await tester.pumpWidget(
        createDialogApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                createdTag = await TagCreateDialog.show(
                  ctx,
                  existingTags: ['existing-tag'],
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('New Tag'), findsOneWidget);

      // Try creating with empty name -> should show error
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Tag name cannot be empty'), findsOneWidget);

      // Try creating with existing name -> should show duplicate error
      await tester.enterText(find.byType(TextField), 'existing-tag');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('A tag with this name already exists'), findsOneWidget);

      // Enter valid name and submit
      await tester.enterText(find.byType(TextField), 'new-tag');
      await tester.tap(find.text('Pin to top of tag list'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(createdTag, isNotNull);
      expect(createdTag?.name, equals('new-tag'));
      expect(createdTag?.isPinned, isTrue);
    });

    testWidgets(
      'TagCreateDialog.showNested displays prefix #parent/ and produces nested tag',
      (tester) async {
        final parentTag = Tag(
          id: 'p1',
          name: 'journal',
          color: 'coral',
          icon: 'book',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        Tag? createdTag;

        await tester.pumpWidget(
          createDialogApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  createdTag = await TagCreateDialog.showNested(
                    ctx,
                    parentTag: parentTag,
                    existingTags: ['journal', 'journal/2025'],
                  );
                },
                child: const Text('Open Nested Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Nested Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('New Nested Tag'), findsOneWidget);
        expect(find.text('#journal/'), findsOneWidget);

        // Try creating empty -> should show error
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(find.text('Nested tag name cannot be empty'), findsOneWidget);

        // Try creating duplicate -> journal/2025
        await tester.enterText(find.byType(TextField), '2025');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(find.text('A tag with this name already exists'), findsOneWidget);

        // Enter valid child segment '2026'
        await tester.enterText(find.byType(TextField), '2026');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(createdTag, isNotNull);
        expect(createdTag?.name, equals('journal/2026'));
        expect(createdTag?.color, equals('coral'));
        expect(createdTag?.icon, equals('book'));
      },
    );

    testWidgets('TagRenameDialog validates new name and submits', (
      tester,
    ) async {
      final tag = Tag(
        id: 't1',
        name: 'old-name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteCount: 5,
      );

      String? renamed;

      await tester.pumpWidget(
        createDialogApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                renamed = await TagRenameDialog.show(
                  ctx,
                  tag: tag,
                  existingTags: ['old-name', 'other-tag'],
                );
              },
              child: const Text('Open Rename'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Tag'), findsOneWidget);
      expect(
        find.text('Renaming this tag will update all 5 associated notes.'),
        findsOneWidget,
      );

      // Enter duplicate name
      await tester.enterText(find.byType(TextField), 'other-tag');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(
        find.text('A tag with this name already exists. Use Merge instead.'),
        findsOneWidget,
      );

      // Enter valid new name
      await tester.enterText(find.byType(TextField), 'brand-new-name');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(renamed, equals('brand-new-name'));
    });

    testWidgets(
      'TagDeleteDialog explains notes will not be deleted and confirms',
      (tester) async {
        final tag = Tag(
          id: 't1',
          name: 'discard',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteCount: 7,
        );

        bool? confirmed;

        await tester.pumpWidget(
          createDialogApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  confirmed = await TagDeleteDialog.show(ctx, tag: tag);
                },
                child: const Text('Open Delete'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete #discard?'), findsOneWidget);
        expect(
          find.textContaining('Your notes will not be deleted'),
          findsOneWidget,
        );

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(confirmed, isTrue);
      },
    );

    testWidgets('TagMergeDialog filters destination tags and selects target', (
      tester,
    ) async {
      final sourceTag = Tag(
        id: 'source-1',
        name: 'flutter-tips',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteCount: 3,
      );

      final available = [
        sourceTag,
        Tag(
          id: 'dest-1',
          name: 'flutter',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteCount: 15,
        ),
        Tag(
          id: 'dest-2',
          name: 'dart',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteCount: 8,
        ),
      ];

      Tag? selectedDest;

      await tester.pumpWidget(
        createDialogApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                selectedDest = await TagMergeDialog.show(
                  ctx,
                  sourceTag: sourceTag,
                  availableTags: available,
                );
              },
              child: const Text('Open Merge'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Merge'));
      await tester.pumpAndSettle();

      expect(find.text('Merge #flutter-tips'), findsOneWidget);
      // Source tag should not be in candidate list
      expect(find.text('#flutter'), findsOneWidget);
      expect(find.text('#dart'), findsOneWidget);

      // Tap on #flutter destination
      await tester.tap(find.text('#flutter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();

      expect(selectedDest, isNotNull);
      expect(selectedDest?.name, equals('flutter'));
    });

    testWidgets(
      'branch delete dialog offers delete-branch and move-children-up',
      (tester) async {
        final tag = Tag(
          id: 't-parent',
          name: 'work',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteCount: 4,
        );

        TagBranchDeleteMode? selectedMode;

        await tester.pumpWidget(
          createDialogApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedMode = await TagDeleteDialog.showWithMode(
                    ctx,
                    tag: tag,
                    hasDescendants: true,
                  );
                },
                child: const Text('Open Branch Delete'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Branch Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete #work?'), findsOneWidget);
        expect(find.text('Delete tag and sub-tags'), findsOneWidget);
        expect(
          find.text('Delete only this tag, move children up'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Your notes will not be deleted'),
          findsOneWidget,
        );

        await tester.tap(find.text('Delete only this tag, move children up'));
        await tester.pumpAndSettle();

        expect(selectedMode, equals(TagBranchDeleteMode.moveChildrenUp));
      },
    );

    testWidgets(
      'branch delete dialog returns deleteBranch and supports cancel',
      (tester) async {
        final tag = Tag(
          id: 't-parent',
          name: 'work',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteCount: 4,
        );

        TagBranchDeleteMode? selectedMode;

        await tester.pumpWidget(
          createDialogApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedMode = await TagDeleteDialog.showWithMode(
                    ctx,
                    tag: tag,
                    hasDescendants: true,
                  );
                },
                child: const Text('Open Branch Delete'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Branch Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(selectedMode, isNull);

        await tester.tap(find.text('Open Branch Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete tag and sub-tags'));
        await tester.pumpAndSettle();
        expect(selectedMode, equals(TagBranchDeleteMode.deleteBranch));
      },
    );

    testWidgets(
      'branch-aware delete falls back to simple confirmation without descendants',
      (tester) async {
        final tag = Tag(
          id: 't-leaf',
          name: 'work/projects',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteCount: 2,
        );

        TagBranchDeleteMode? selectedMode;

        await tester.pumpWidget(
          createDialogApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedMode = await TagDeleteDialog.showWithMode(
                    ctx,
                    tag: tag,
                    hasDescendants: false,
                  );
                },
                child: const Text('Open Leaf Delete'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Leaf Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete #work/projects?'), findsOneWidget);
        expect(find.text('Delete tag and sub-tags'), findsNothing);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(selectedMode, equals(TagBranchDeleteMode.deleteBranch));
      },
    );
  });
}
