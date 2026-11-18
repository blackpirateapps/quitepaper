import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/templates/application/template_providers.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/presentation/template_picker.dart';
import 'package:quitepaper/features/templates/presentation/widgets/template_browser.dart';
import 'package:quitepaper/features/templates/presentation/widgets/template_dialogs.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/notes/presentation/widgets/notes_command_palette.dart';
import 'template_domain_test.dart' show fixture;

void main() {
  late AppDatabase db;
  late TemplateRepository repo;
  late TemplateService service;
  late SharedPreferences prefs;
  Note? created;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repo = TemplateRepository(db);
    service = TemplateService(
      repository: repo,
      notes: DriftNotesRepository(db),
    );
    created = null;
  });
  tearDown(() => db.close());
  Widget app(
    Widget home, {
    TargetPlatform platform = TargetPlatform.android,
    Brightness brightness = Brightness.light,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(DriftNotesRepository(db)),
      templateServiceProvider.overrideWithValue(service),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: platform, brightness: brightness),
      home: Scaffold(body: home),
    ),
  );
  Future<void> settle(WidgetTester tester) async {
    // Native SQLite and compute isolates deliver real events; pump between
    // events so chained async operations can progress in the fake test zone.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    await tester.pumpAndSettle();
  }

  Widget opener() => Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        created = await showTemplatePicker(context, activeTag: 'work/plan');
      },
      child: const Text('Open picker'),
    ),
  );

  testWidgets(
    'picker search, sections, preview, use, repeat open and independent creation',
    (tester) async {
      await repo.insertUserTemplate(fixture());
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      expect(find.text('Choose a Template'), findsOneWidget);
      expect(find.text('My Templates'), findsOneWidget);
      expect(find.text('Favorites'), findsNothing);
      await tester.enterText(find.byType(TextField), '  MeEtIng ');
      await tester.pumpAndSettle();
      expect(find.text('Meeting Notes'), findsOneWidget);
      expect(find.text('Daily Planner'), findsNothing);
      await tester.tap(find.text('Meeting Notes'));
      await settle(tester);
      expect(find.text('Use Template'), findsOneWidget);
      expect(await db.select(db.notesTable).get(), isEmpty);
      await tester.tap(find.text('Use Template'));
      await settle(tester);
      expect(created!.title, 'Meeting Notes');
      expect(created!.tags, ['work/plan']);
      final firstId = created!.id;
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Meeting');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meeting Notes'));
      await settle(tester);
      await tester.tap(find.text('Use Template'));
      await settle(tester);
      expect(created!.id, isNot(firstId));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets(
    'favorite moves rows once and persists when providers are recreated',
    (tester) async {
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      await tester.tap(find.byTooltip('Favorite Daily Planner'));
      await settle(tester);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Daily Planner'), findsOneWidget);
      await tester.tap(find.byTooltip('Close templates'));
      await settle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      expect(find.byTooltip('Unfavorite Daily Planner'), findsOneWidget);
      await tester.tap(find.byTooltip('Unfavorite Daily Planner'));
      await settle(tester);
      expect(find.text('Favorites'), findsNothing);
      expect(await repo.getFavoriteTemplateIds(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets(
    'no match, Escape and system Back dismiss, preview back restores search focus',
    (tester) async {
      await tester.pumpWidget(app(opener(), platform: TargetPlatform.linux));
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No templates found'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Choose a Template'), findsNothing);
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      await tester.tap(find.text('Daily Planner'));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Choose a Template'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        true,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Choose a Template'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets(
    'management restricts built-in actions and supports rename and delete confirmation',
    (tester) async {
      await repo.insertUserTemplate(fixture());
      await tester.pumpWidget(
        app(TemplateBrowser(management: true, onCreated: (_) {})),
      );
      await settle(tester);
      expect(find.byTooltip('Template actions'), findsOneWidget);
      await tester.tap(find.byTooltip('Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await settle(tester);
      expect(find.text('Rename Template'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Template'),
        'Renamed',
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await repo.getUserTemplates()).single.displayName, 'Renamed');
      await tester.tap(find.byTooltip('Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('Delete Template?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect((await repo.getUserTemplates()).length, 1);
      await tester.tap(find.byTooltip('Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete Template'));
      await settle(tester);
      expect(await repo.getUserTemplates(), isEmpty);
      expect(find.text('Template deleted'), findsOneWidget);
      expect(find.byTooltip('Template actions'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets(
    'save dialog validates names, prevents double submit, preserves input on error and retries',
    (tester) async {
      var attempts = 0;
      final gate = Completer<void>();
      final result = <String>[];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTemplateNameDialog(
                context: context,
                initialName: 'Initial',
                onSave: (name) async {
                  attempts++;
                  if (attempts == 1) {
                    await gate.future;
                    throw StateError('injected');
                  }
                  result.add(name);
                },
              ),
              child: const Text('Save source'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save source'));
      await settle(tester);
      expect(find.text('Save as Template'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'a' * 81);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Saved name');
      await tester.pump();
      await tester.tap(find.text('Save Template'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(attempts, 1);
      gate.complete();
      await settle(tester);
      expect(find.text('Saved name'), findsOneWidget);
      expect(find.textContaining('Please try again'), findsOneWidget);
      await tester.tap(find.text('Save Template'));
      await settle(tester);
      expect(result, ['Saved name']);
      expect(find.text('Template saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets('save Cancel makes no persistence call', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTemplateNameDialog(
              context: context,
              initialName: 'Initial',
              onSave: (_) async {
                saved = true;
              },
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(saved, false);
    expect(find.text('Save as Template'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
  testWidgets(
    'deletion during preview reports unavailable without creating another note',
    (tester) async {
      await repo.insertUserTemplate(fixture());
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      await tester.tap(find.text('Template'));
      await settle(tester);
      await repo.deleteUserTemplate(fixture().id);
      await settle(tester);
      await tester.tap(find.text('Use Template'));
      await settle(tester);
      expect(find.text('This template is no longer available.'), findsWidgets);
      expect(created, isNull);
      expect(await db.select(db.notesTable).get(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets('management footer closes picker before navigating', (
    tester,
  ) async {
    await tester.pumpWidget(app(opener()));
    await tester.tap(find.text('Open picker'));
    await settle(tester);
    await tester.tap(find.text('Manage Templates'));
    await settle(tester);
    expect(
      find.text('Reusable starting points for your notes.'),
      findsOneWidget,
    );
    expect(find.text('Choose a Template'), findsNothing);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Open picker'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
  for (final brightness in Brightness.values) {
    for (final desktop in [false, true]) {
      testWidgets(
        'responsive ${brightness.name} ${desktop ? 'desktop' : 'phone'} picker',
        (tester) async {
          tester.view.physicalSize = desktop
              ? const Size(1300, 900)
              : const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            app(
              opener(),
              platform: desktop ? TargetPlatform.linux : TargetPlatform.android,
              brightness: brightness,
            ),
          );
          await tester.tap(find.text('Open picker'));
          await settle(tester);
          expect(find.text('Choose a Template'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (desktop) {
            expect(
              tester.getSize(find.byType(TemplateBrowser)).width,
              lessThanOrEqualTo(560),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));
        },
      );
    }
  }
  testWidgets('phone picker stays usable above the software keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(app(opener()));
    await tester.tap(find.text('Open picker'));
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets(
    'favorite and delete failures retain persisted state and visible row',
    (tester) async {
      final failing = _FailingTemplateRepository(db);
      repo = failing;
      service = TemplateService(
        repository: failing,
        notes: DriftNotesRepository(db),
      );
      await repo.insertUserTemplate(fixture());
      await tester.pumpWidget(
        app(TemplateBrowser(management: true, onCreated: (_) {})),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Favorite Template'));
      await settle(tester);
      expect(await repo.getFavoriteTemplateIds(), isEmpty);
      expect(find.byTooltip('Favorite Template'), findsOneWidget);
      expect(find.textContaining('Please try again'), findsOneWidget);
      await tester.tap(find.byTooltip('Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete Template'));
      await settle(tester);
      expect(await repo.getUserTemplate(fixture().id), isNotNull);
      expect(find.text('Template'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'Use Template disables submission and Back while creation is pending',
    (tester) async {
      final gated = _GatedTemplateService(repo, DriftNotesRepository(db));
      service = gated;
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('Open picker'));
      await settle(tester);
      await tester.tap(find.text('Daily Planner'));
      await settle(tester);
      await tester.tap(find.text('Use Template'));
      await tester.pump();
      expect(gated.requests, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Creating…'), findsOneWidget);
      gated.gate.complete();
      await settle(tester);
      expect(created!.title, 'Daily Planner');
      expect((await db.select(db.notesTable).get()).length, 1);
      expect(gated.requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets(
      'pending use survives drag, barrier, Escape and Back on $platform',
      (tester) async {
        final gated = _GatedTemplateService(repo, DriftNotesRepository(db));
        service = gated;
        await tester.pumpWidget(app(opener(), platform: platform));
        await tester.tap(find.text('Open picker'));
        await settle(tester);
        await tester.tap(find.text('Daily Planner'));
        await settle(tester);
        await tester.tap(find.text('Use Template'));
        await tester.pump();
        await tester.fling(
          find.text('Daily Planner').first,
          const Offset(0, 650),
          1500,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tapAt(const Offset(5, 5));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Creating…'), findsOneWidget);
        expect(created, isNull);
        gated.gate.complete();
        await settle(tester);
        expect(created, isNotNull);
        expect((await db.select(db.notesTable).get()).length, 1);
        expect(gated.requests, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'pending save survives drag, barrier, Escape and Back on $platform',
      (tester) async {
        final gate = Completer<void>();
        var requests = 0;
        var finished = false;
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showTemplateNameDialog(
                    context: context,
                    initialName: 'Saved snapshot',
                    onSave: (name) async {
                      requests++;
                      await gate.future;
                      await repo.insertUserTemplate(fixture(name: name));
                    },
                  );
                  finished = true;
                },
                child: const Text('Save snapshot'),
              ),
            ),
            platform: platform,
          ),
        );
        await tester.tap(find.text('Save snapshot'));
        await settle(tester);
        await tester.tap(find.text('Save Template'));
        await tester.pump();
        await tester.fling(
          find.text('Save as Template'),
          const Offset(0, 650),
          1500,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tapAt(const Offset(5, 5));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Saving…'), findsOneWidget);
        expect(finished, false);
        gate.complete();
        await settle(tester);
        expect(finished, true);
        expect(
          (await repo.getUserTemplates()).single.displayName,
          'Saved snapshot',
        );
        expect(requests, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  }

  testWidgets(
    'desktop command palette filters and returns shared template action',
    (tester) async {
      NotesCommand? command;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                command = await showNotesCommandPalette(context);
              },
              child: const Text('Commands'),
            ),
          ),
          platform: TargetPlatform.linux,
        ),
      );
      await tester.tap(find.text('Commands'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'template');
      await tester.pumpAndSettle();
      expect(find.text('New Note'), findsNothing);
      await tester.tap(find.text('New from Template'));
      await settle(tester);
      expect(command, NotesCommand.newFromTemplate);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}

class _FailingTemplateRepository extends TemplateRepository {
  _FailingTemplateRepository(super.database);
  @override
  Future<void> setFavorite(String id, bool favorite) async =>
      throw StateError('injected favorite failure');
  @override
  Future<void> deleteUserTemplate(String id) async =>
      throw StateError('injected delete failure');
}

class _GatedTemplateService extends TemplateService {
  _GatedTemplateService(TemplateRepository repository, NotesRepository notes)
    : super(repository: repository, notes: notes);
  final gate = Completer<void>();
  int requests = 0;
  @override
  Future<Note> instantiate(String id, {String? activeTag}) async {
    requests++;
    await gate.future;
    return super.instantiate(id, activeTag: activeTag);
  }
}
