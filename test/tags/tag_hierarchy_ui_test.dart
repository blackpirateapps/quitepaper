import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/quiet_tag_chip.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/sidebar/presentation/sidebar_view.dart';
import 'package:quitepaper/features/tags/application/tag_providers.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_browser_view.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_context_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftNotesRepository repository;
  late SharedPreferences prefs;
  final testDate = DateTime(2026, 1, 1);

  final testTags = [
    Tag(
      id: 't-work',
      name: 'work',
      icon: 'briefcase',
      color: 'blue',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 3,
    ),
    Tag(
      id: 't-projects',
      name: 'work/projects',
      icon: 'code',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 2,
    ),
    Tag(
      id: 't-alpha',
      name: 'work/projects/alpha',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 1,
    ),
    Tag(
      id: 't-ideas',
      name: 'work/ideas',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 0,
    ),
    Tag(
      id: 't-workflow',
      name: 'workflow',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 1,
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestApp({
    Widget? home,
    AppDestination initialDestination = AppDestination.allNotes,
    String? initialTag,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        allTagsProvider.overrideWith((ref) => Stream.value(testTags)),
        allTagsStreamProvider.overrideWith(
          (ref) => Stream.value(
            testTags
                .map(
                  (tag) => TagWithCount(
                    tag: TagEntity(
                      id: tag.id,
                      name: tag.name,
                      icon: tag.icon,
                      color: tag.color,
                      isPinned: tag.isPinned,
                      pinnedOrder: tag.pinnedOrder,
                      createdAt: tag.createdAt,
                      updatedAt: tag.updatedAt,
                      isDirty: false,
                      serverRevision: 0,
                      isDeleted: false,
                    ),
                    noteCount: tag.noteCount,
                  ),
                )
                .toList(),
          ),
        ),
        currentDestinationProvider.overrideWith((ref) => initialDestination),
        selectedTagFilterProvider.overrideWith((ref) => initialTag),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: home ?? const NotesScreen(),
      ),
    );
  }

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  group('Sidebar tag hierarchy', () {
    testWidgets(
      'expands and collapses nested tags with persisted local state',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestApp(home: const Scaffold(body: SidebarView())),
        );
        await tester.pumpAndSettle();

        expect(find.text('work'), findsOneWidget);
        expect(find.text('workflow'), findsOneWidget);
        expect(find.text('projects'), findsNothing);
        expect(find.text('alpha'), findsNothing);

        await tester.tap(find.byTooltip('Expand work'));
        await tester.pumpAndSettle();

        expect(find.text('projects'), findsOneWidget);
        expect(find.text('ideas'), findsOneWidget);
        expect(find.text('alpha'), findsNothing);
        expect(
          prefs.getStringList(ExpandedTagPathsNotifier.storageKey),
          contains('work'),
        );

        await tester.tap(find.byTooltip('Expand projects'));
        await tester.pumpAndSettle();
        expect(find.text('alpha'), findsOneWidget);

        await tester.tap(find.byTooltip('Collapse work'));
        await tester.pumpAndSettle();
        expect(find.text('projects'), findsNothing);
        expect(find.text('alpha'), findsNothing);
        expect(
          prefs.getStringList(ExpandedTagPathsNotifier.storageKey),
          isNot(contains('work')),
        );

        await finishTest(tester);
      },
    );

    testWidgets('selecting a nested leaf filters by its full path', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestApp(
          home: const Scaffold(body: SidebarView()),
          initialTag: 'work/projects/alpha',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Expand work'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand projects'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SidebarView)),
      );
      expect(container.read(currentDestinationProvider), AppDestination.tag);
      expect(
        container.read(selectedTagFilterProvider),
        equals('work/projects/alpha'),
      );
      expect(container.read(selectedTagIdProvider), equals('t-alpha'));

      await finishTest(tester);
    });
  });

  group('Tag browser hierarchy', () {
    testWidgets(
      'shows roots, expands children, and exposes full accessible paths',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1.0;

        String? selected;
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: TagBrowserView(onTagSelected: (tag) => selected = tag.name),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('#work'), findsOneWidget);
        expect(find.text('#workflow'), findsOneWidget);
        expect(find.text('#projects'), findsNothing);
        expect(find.text('#alpha'), findsNothing);

        expect(
          find.bySemanticsLabel(RegExp(r'#work, 3 notes')),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Expand sub-tags'));
        await tester.pumpAndSettle();

        expect(find.text('#projects'), findsOneWidget);
        expect(find.text('#ideas'), findsOneWidget);
        expect(find.text('#alpha'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp(r'#work/projects, 2 notes')),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Expand sub-tags'));
        await tester.pumpAndSettle();
        expect(find.text('#alpha'), findsOneWidget);

        await tester.tap(find.text('#alpha'));
        await tester.pumpAndSettle();
        expect(selected, equals('work/projects/alpha'));

        await finishTest(tester);
      },
    );

    testWidgets('pinned nested tags stay flat and reorderable above the tree', (
      tester,
    ) async {
      final pinnedNested = Tag(
        id: 't-pinned',
        name: 'work/projects',
        isPinned: true,
        pinnedOrder: 0,
        createdAt: testDate,
        updatedAt: testDate,
        noteCount: 2,
      );
      final tags = [
        ...testTags.where((tag) => tag.id != 't-projects'),
        pinnedNested,
      ];

      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            allTagsProvider.overrideWith((ref) => Stream.value(tags)),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const Scaffold(body: TagBrowserView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('#projects'), findsOneWidget);
      // The pinned row is flat: no expansion affordance is attached to it.
      final pinnedRow = find.byKey(const ValueKey('pinned_t-pinned'));
      expect(pinnedRow, findsOneWidget);
      expect(
        find.descendant(
          of: pinnedRow,
          matching: find.byTooltip('Expand sub-tags'),
        ),
        findsNothing,
      );

      await finishTest(tester);
    });
  });

  group('Tag context breadcrumb', () {
    testWidgets('nested tag header shows leaf title and full breadcrumb', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestApp(
          initialDestination: AppDestination.tag,
          initialTag: 'work/projects/alpha',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagContextHeader), findsOneWidget);
      expect(find.text('#alpha'), findsWidgets);
      expect(find.text('#work / projects / alpha'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TagContextHeader),
          matching: find.text('#work/projects/alpha'),
        ),
        findsNothing,
      );

      await finishTest(tester);
    });
  });

  group('Nested tag chips', () {
    testWidgets(
      'chip shows leaf and reveals breadcrumb with an Open tag action',
      (tester) async {
        var opened = false;
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: Scaffold(
              body: QuietTagChip(
                tag: 'work/projects/alpha',
                onTap: () => opened = true,
              ),
            ),
          ),
        );

        expect(find.text('#alpha'), findsOneWidget);
        expect(find.text('#work/projects/alpha'), findsNothing);
        expect(
          find.bySemanticsLabel('#work/projects/alpha, nested tag'),
          findsOneWidget,
        );

        await tester.tap(find.text('#alpha'));
        await tester.pumpAndSettle();

        expect(find.text('Full tag path'), findsOneWidget);
        expect(find.text('#work / projects / alpha'), findsOneWidget);
        expect(find.text('Open tag'), findsOneWidget);

        await tester.tap(find.text('Open tag'));
        await tester.pumpAndSettle();
        expect(opened, isTrue);

        semantics.dispose();
      },
    );

    testWidgets(
      'flat chip keeps direct tap navigation without a disclosure dialog',
      (tester) async {
        var opened = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: Scaffold(
              body: QuietTagChip(tag: 'work', onTap: () => opened = true),
            ),
          ),
        );

        expect(find.text('#work'), findsOneWidget);
        await tester.tap(find.text('#work'));
        await tester.pumpAndSettle();

        expect(opened, isTrue);
        expect(find.text('Full tag path'), findsNothing);
      },
    );
  });

  group('Local hierarchy preferences', () {
    test('expanded paths persist locally and normalize input', () {
      final notifier = ExpandedTagPathsNotifier(prefs);
      expect(notifier.state, isEmpty);

      notifier.toggle('#Work/Projects');
      expect(notifier.state, equals({'work/projects'}));
      expect(
        prefs.getStringList(ExpandedTagPathsNotifier.storageKey),
        equals(['work/projects']),
      );

      final reloaded = ExpandedTagPathsNotifier(prefs);
      expect(reloaded.state, equals({'work/projects'}));

      reloaded.collapse('work/projects');
      expect(reloaded.state, isEmpty);
      expect(prefs.getStringList(ExpandedTagPathsNotifier.storageKey), isEmpty);
    });

    test('folder hierarchy import setting persists locally', () async {
      final notifier = ImportFolderHierarchyNotifier(prefs);
      expect(notifier.state, isFalse);

      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool(ImportFolderHierarchyNotifier.storageKey), isTrue);

      final reloaded = ImportFolderHierarchyNotifier(prefs);
      expect(reloaded.state, isTrue);
    });

    test(
      'tagTreeProvider derives implicit ancestors from the flat tag stream',
      () async {
        final container = ProviderContainer(
          overrides: [
            allTagsProvider.overrideWith(
              (ref) => Stream.value([
                testTags.firstWhere((tag) => tag.name == 'work/projects/alpha'),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(allTagsProvider.future);
        final tree = container.read(tagTreeProvider);
        expect(tree.nodeFor('work')?.isImplicit, isTrue);
        expect(tree.nodeFor('work/projects')?.isImplicit, isTrue);
        expect(tree.nodeFor('work/projects/alpha')?.isImplicit, isFalse);
      },
    );
  });
}
