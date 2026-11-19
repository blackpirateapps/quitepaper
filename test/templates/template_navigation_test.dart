import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
// Google Fonts exposes this manifest specifically for deterministic tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/settings_screen.dart';
import 'package:quitepaper/features/templates/application/template_providers.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/presentation/templates_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
  setUpAll(() async {
    // Navigation does not test font fetching. Supply the bundled fallback face
    // for sidebar Google-font variants so tests stay deterministic and offline.
    final font = await rootBundle.load('assets/fonts/Kalpurush-Bengali.ttf');
    font_test.assetManifest = _OfflineFontManifest();
    GoogleFonts.config.allowRuntimeFetching = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) {
      final path = utf8.decode(message!.buffer.asUint8List());
      if (path.startsWith('test-fonts/')) return Future.value(font);
      return messenger.delegate.send('flutter/assets', message);
    });
  });
  tearDownAll(() {
    font_test.assetManifest = null;
    GoogleFonts.config.allowRuntimeFetching = originalRuntimeFetching;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
  late AppDatabase db;
  late DriftNotesRepository notes;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    notes = DriftNotesRepository(db);
  });
  tearDown(() => db.close());
  Widget app(Widget home, {TargetPlatform platform = TargetPlatform.linux}) =>
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          isNavSidebarVisibleProvider.overrideWith((ref) => false),
          notesRepositoryProvider.overrideWithValue(notes),
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
          syncStateProvider.overrideWithValue(const SyncState()),
          templateServiceProvider.overrideWith(
            (ref) => TemplateService(
              repository: TemplateRepository(db),
              notes: notes,
              onNoteCreated: () {
                ref.read(notesCollectionProvider.notifier).refresh();
              },
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: platform),
          home: home,
        ),
      );
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final desktop in [false, true]) {
    testWidgets(
      'notes ${desktop ? 'desktop' : 'phone'} menu creates template note in active nested tag',
      (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1440, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await notes.createTag('work/plan');
        await tester.pumpWidget(app(const NotesScreen()));
        await settle(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(NotesScreen)),
        );
        container.read(selectedTagFilterProvider.notifier).state = 'work/plan';
        container.read(currentDestinationProvider.notifier).state =
            AppDestination.tag;
        await settle(tester);
        await tester.tap(find.byTooltip('Tag options').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('New from Template'));
        await settle(tester);
        expect(find.text('Choose a Template'), findsOneWidget);
        await tester.tap(find.text('Daily Planner'));
        await settle(tester);
        await tester.tap(find.text('Use Template'));
        await settle(tester);
        expect(find.byType(EditorScreen), findsOneWidget);
        final note = (await db.getDirtyNotes()).single;
        expect(note.note.title, 'Daily Planner');
        expect(note.tagNames, ['work/plan']);
        expect(note.note.isPinned, false);
        expect(note.note.isArchived, false);
        await finish(tester);
      },
    );
  }
  testWidgets('Settings Templates row opens management screen', (tester) async {
    await tester.pumpWidget(app(const SettingsScreen()));
    await settle(tester);
    expect(
      tester.getTopLeft(find.text('Templates')).dy,
      greaterThan(tester.getTopLeft(find.text('Set up Encrypted Sync')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Templates')).dy,
      lessThan(tester.getTopLeft(find.text('Default Settings')).dy),
    );
    await tester.tap(find.text('Templates'));
    await settle(tester);
    expect(find.byType(TemplatesScreen), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(
      find.text('Make room for priorities, tasks, and reflection.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'no matching template');
    await tester.pumpAndSettle();
    expect(find.text('No templates found'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Planner'), findsOneWidget);
    expect(
      find.text('Reusable starting points for your notes.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await finish(tester);
  });
  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'Android'} overflow icons and palette open the shared picker',
      (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1440, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            const NotesScreen(),
            platform: desktop ? TargetPlatform.linux : TargetPlatform.android,
          ),
        );
        await settle(tester);
        await tester.tap(
          find.byTooltip(desktop ? 'More actions' : 'More options').first,
        );
        await tester.pumpAndSettle();
        for (final (label, icon) in [
          ('New from Template', PhosphorIconsRegular.files),
          ('Command Palette', PhosphorIconsRegular.command),
        ]) {
          final item = find.ancestor(
            of: find.text(label),
            matching: find.byType(PopupMenuItem<String>),
          );
          expect(
            find.descendant(of: item, matching: find.byIcon(icon)),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Command Palette'));
        await settle(tester);
        expect(find.text('Search commands'), findsOneWidget);
        expect(find.text('New Note').hitTestable(), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'template');
        await tester.pumpAndSettle();
        await tester.tap(find.text('New from Template'));
        await settle(tester);
        expect(find.text('Choose a Template'), findsOneWidget);
        expect(await db.select(db.notesTable).get(), isEmpty);
        await tester.tap(find.byTooltip('Close templates'));
        await settle(tester);
        await tester.tap(
          find.byTooltip(desktop ? 'More actions' : 'More options').first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Command Palette'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'new note');
        await tester.testTextInput.receiveAction(TextInputAction.go);
        await settle(tester);
        expect(find.byType(EditorScreen), findsOneWidget);
        expect(find.text('Search commands'), findsNothing);
        await finish(tester);
      },
    );
  }
  testWidgets(
    'desktop command shortcut opens palette then shared picker without a blank note',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const NotesScreen()));
      await settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      await tester.tap(find.text('New from Template'));
      await settle(tester);
      expect(find.text('Choose a Template'), findsOneWidget);
      expect(await db.select(db.notesTable).get(), isEmpty);
      await finish(tester);
    },
  );
}

class _OfflineFontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final family in ['Newsreader', 'JetBrainsMono'])
      for (final variant in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'Italic',
        'MediumItalic',
        'SemiBoldItalic',
        'BoldItalic',
      ])
        'test-fonts/$family-$variant.ttf',
  ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}
