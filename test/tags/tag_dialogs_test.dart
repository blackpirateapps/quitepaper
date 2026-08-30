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
    testWidgets('TagCreateDialog validates input and produces Tag entity', (tester) async {
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

    testWidgets('TagRenameDialog validates new name and submits', (tester) async {
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
      expect(find.text('Renaming this tag will update all 5 associated notes.'), findsOneWidget);

      // Enter duplicate name
      await tester.enterText(find.byType(TextField), 'other-tag');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('A tag with this name already exists. Use Merge instead.'), findsOneWidget);

      // Enter valid new name
      await tester.enterText(find.byType(TextField), 'brand-new-name');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(renamed, equals('brand-new-name'));
    });

    testWidgets('TagDeleteDialog explains notes will not be deleted and confirms', (tester) async {
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
      expect(find.textContaining('Your notes will not be deleted'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('TagMergeDialog filters destination tags and selects target', (tester) async {
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
  });
}
