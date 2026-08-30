import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
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
  late AppDatabase db;
  late DriftNotesRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  final testDate = DateTime(2026, 1, 1);

  final testTags = [
    Tag(
      id: 't-blog',
      name: 'blog',
      icon: 'pen',
      color: 'teal',
      isPinned: true,
      pinnedOrder: 1,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 2,
    ),
    Tag(
      id: 't-ideas',
      name: 'ideas',
      icon: 'bulb',
      color: 'amber',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 1,
    ),
    Tag(
      id: 't-recipes',
      name: 'recipes',
      isPinned: false,
      pinnedOrder: 0,
      createdAt: testDate,
      updatedAt: testDate,
      noteCount: 0,
    ),
  ];

  Widget createWorkspaceTestApp({
    AppDestination initialDestination = AppDestination.allNotes,
    String? initialTag,
    List<Override> extraOverrides = const [],
    Widget? child,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        allTagsProvider.overrideWith((ref) => Stream.value(testTags)),
        allTagsStreamProvider.overrideWith(
          (ref) => Stream.value(
            testTags.map((t) {
              return TagWithCount(
                tag: TagEntity(
                  id: t.id,
                  name: t.name,
                  icon: t.icon,
                  color: t.color,
                  isPinned: t.isPinned,
                  pinnedOrder: t.pinnedOrder,
                  createdAt: t.createdAt,
                  updatedAt: t.updatedAt,
                  isDirty: false,
                  serverRevision: 0,
                  isDeleted: false,
                ),
                noteCount: t.noteCount,
              );
            }).toList(),
          ),
        ),
        currentDestinationProvider.overrideWith((ref) => initialDestination),
        selectedTagFilterProvider.overrideWith((ref) => initialTag),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: child ?? const NotesScreen(),
      ),
    );
  }

  group('3-Pane Workspace Tag Redesign Tests', () {
    testWidgets('Selecting a tag in Sidebar updates workspace context without route push', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createWorkspaceTestApp(
          child: const Scaffold(body: SidebarView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('blog'), findsOneWidget);

      // Tap on tag row
      await tester.tap(find.text('blog'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
      expect(container.read(currentDestinationProvider), AppDestination.tag);
      expect(container.read(selectedTagFilterProvider), 'blog');

      await finishTest(tester);
    });

    testWidgets('Tag Browser renders inside middle pane when destination is tagBrowser', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createWorkspaceTestApp(
          initialDestination: AppDestination.tagBrowser,
        ),
      );
      await tester.pumpAndSettle();

      // TagBrowserView should be present in middle pane
      expect(find.byType(TagBrowserView), findsOneWidget);
      expect(find.text('Tags'), findsWidgets);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('#blog'), findsOneWidget);
      expect(find.text('#ideas'), findsOneWidget);

      // Editor pane shows empty state
      expect(find.text('No note selected'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Tapping a tag in TagBrowserView transitions middle pane to tag context', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createWorkspaceTestApp(
          initialDestination: AppDestination.tagBrowser,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagBrowserView), findsOneWidget);

      // Tap on #blog row in TagBrowserView
      await tester.tap(find.text('#blog'));
      await tester.pumpAndSettle();

      // Workspace switches to Tag context in the middle pane
      expect(find.byType(TagContextHeader), findsOneWidget);
      expect(find.text('#blog'), findsWidgets);

      final container = ProviderScope.containerOf(tester.element(find.byType(NotesScreen)));
      expect(container.read(currentDestinationProvider), AppDestination.tag);
      expect(container.read(selectedTagFilterProvider), 'blog');

      await finishTest(tester);
    });

    testWidgets('Tag context header displays tag name, note count, and tag actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createWorkspaceTestApp(
          initialDestination: AppDestination.tag,
          initialTag: 'blog',
        ),
      );
      await tester.pumpAndSettle();

      // Header is rendered
      expect(find.byType(TagContextHeader), findsOneWidget);
      expect(find.text('#blog'), findsWidgets);

      // Tag options menu button
      expect(find.byTooltip('Tag options'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Opening Tag options menu reveals Rename, Change icon, Change color, Pin, Merge, Delete', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createWorkspaceTestApp(
          initialDestination: AppDestination.tag,
          initialTag: 'blog',
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Tag options menu
      await tester.tap(find.byTooltip('Tag options'));
      await tester.pumpAndSettle();

      expect(find.text('Rename tag'), findsOneWidget);
      expect(find.text('Change icon'), findsOneWidget);
      expect(find.text('Change color'), findsOneWidget);
      expect(find.text('Unpin tag'), findsOneWidget); // blog is pinned in testTags
      expect(find.text('Merge into...'), findsOneWidget);
      expect(find.text('Delete tag'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Mobile back button transitions tag context back to allNotes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createWorkspaceTestApp(
          initialDestination: AppDestination.tag,
          initialTag: 'blog',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagContextHeader), findsOneWidget);

      // Simulate back invocation
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(NotesScreen)));
      expect(container.read(currentDestinationProvider), AppDestination.allNotes);
      expect(container.read(selectedTagFilterProvider), isNull);

      await finishTest(tester);
    });
  });
}
