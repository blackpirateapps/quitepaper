import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/presentation/widgets/tags_filter_bar.dart';

void main() {
  TagEntity makeTag(String id, String name) => TagEntity(
        id: id,
        name: name,
        isPinned: false,
        pinnedOrder: 0,
        isDirty: false,
        serverRevision: 0,
        isDeleted: false,
      );

  final sampleTags = [
    TagWithCount(
      tag: makeTag('1', 'alpha'),
      noteCount: 3,
    ),
    TagWithCount(
      tag: makeTag('2', 'beta'),
      noteCount: 5,
    ),
    TagWithCount(
      tag: makeTag('3', 'gamma'),
      noteCount: 2,
    ),
    TagWithCount(
      tag: makeTag('4', 'delta'),
      noteCount: 8,
    ),
  ];

  Widget buildTestWidget({
    required List<TagWithCount> tags,
    String? initialSelectedTag,
    Widget Function(BuildContext, WidgetRef)? extraControls,
  }) {
    return ProviderScope(
      overrides: [
        allTagsStreamProvider.overrideWith((ref) => Stream.value(tags)),
        selectedTagFilterProvider.overrideWith((ref) => initialSelectedTag),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Scaffold(
          body: Column(
            children: [
              const TagsFilterBar(),
              if (extraControls != null)
                Consumer(builder: (context, ref, _) => extraControls(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders tags in default order when no tag is selected', (tester) async {
    await tester.pumpWidget(buildTestWidget(tags: sampleTags));
    await tester.pumpAndSettle();

    // Verify All is first
    expect(find.text('All'), findsOneWidget);
    expect(find.text('#alpha'), findsOneWidget);
    expect(find.text('#beta'), findsOneWidget);
    expect(find.text('#gamma'), findsOneWidget);
    expect(find.text('#delta'), findsOneWidget);

    // Verify ordering via horizontal position: All < alpha < beta < gamma < delta
    final allDx = tester.getTopLeft(find.text('All')).dx;
    final alphaDx = tester.getTopLeft(find.text('#alpha')).dx;
    final betaDx = tester.getTopLeft(find.text('#beta')).dx;
    final gammaDx = tester.getTopLeft(find.text('#gamma')).dx;
    final deltaDx = tester.getTopLeft(find.text('#delta')).dx;

    expect(allDx < alphaDx, isTrue);
    expect(alphaDx < betaDx, isTrue);
    expect(betaDx < gammaDx, isTrue);
    expect(gammaDx < deltaDx, isTrue);
  });

  testWidgets('places selected tag immediately next to All when filter is active', (tester) async {
    // Select 'gamma' (which is index 2 originally)
    await tester.pumpWidget(
      buildTestWidget(
        tags: sampleTags,
        initialSelectedTag: 'gamma',
      ),
    );
    await tester.pumpAndSettle();

    final allDx = tester.getTopLeft(find.text('All')).dx;
    final gammaDx = tester.getTopLeft(find.text('#gamma')).dx;
    final alphaDx = tester.getTopLeft(find.text('#alpha')).dx;
    final betaDx = tester.getTopLeft(find.text('#beta')).dx;
    final deltaDx = tester.getTopLeft(find.text('#delta')).dx;

    // 'gamma' must now be immediately next to 'All', followed by alpha, beta, delta
    expect(allDx < gammaDx, isTrue);
    expect(gammaDx < alphaDx, isTrue);
    expect(alphaDx < betaDx, isTrue);
    expect(betaDx < deltaDx, isTrue);
  });

  testWidgets('selecting a tag from outside moves it next to All and tapping it deselects', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        tags: sampleTags,
        extraControls: (context, ref) {
          return ElevatedButton(
            onPressed: () {
              ref.read(selectedTagFilterProvider.notifier).state = 'delta';
            },
            child: const Text('Select Delta Outside'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Initial: alpha is next to All
    expect(tester.getTopLeft(find.text('#alpha')).dx < tester.getTopLeft(find.text('#delta')).dx, isTrue);

    // Trigger external select (like from sidebar)
    await tester.tap(find.text('Select Delta Outside'));
    await tester.pumpAndSettle();

    // Now delta is immediately next to All
    final allDx = tester.getTopLeft(find.text('All')).dx;
    final deltaDx = tester.getTopLeft(find.text('#delta')).dx;
    final alphaDx = tester.getTopLeft(find.text('#alpha')).dx;

    expect(allDx < deltaDx, isTrue);
    expect(deltaDx < alphaDx, isTrue);

    // Tapping delta again toggles it off
    await tester.tap(find.text('#delta'));
    await tester.pumpAndSettle();

    // Order restores to alpha first
    final restoredAlphaDx = tester.getTopLeft(find.text('#alpha')).dx;
    final restoredDeltaDx = tester.getTopLeft(find.text('#delta')).dx;
    expect(restoredAlphaDx < restoredDeltaDx, isTrue);
  });

  testWidgets('tapping a tag chip filters in-place without changing currentDestinationProvider', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        tags: sampleTags,
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(TagsFilterBar)));
    expect(container.read(currentDestinationProvider), AppDestination.allNotes);
    expect(container.read(selectedTagFilterProvider), isNull);

    // Tap #beta
    await tester.tap(find.text('#beta'));
    await tester.pumpAndSettle();

    // Must still be allNotes!
    expect(container.read(currentDestinationProvider), AppDestination.allNotes);
    expect(container.read(selectedTagFilterProvider), 'beta');

    // Tap All to clear
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(container.read(currentDestinationProvider), AppDestination.allNotes);
    expect(container.read(selectedTagFilterProvider), isNull);
  });
}
