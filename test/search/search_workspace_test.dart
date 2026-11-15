import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/search/application/search_provider.dart';
import 'package:quitepaper/features/search/presentation/search_screen.dart';
import 'package:quitepaper/features/search/presentation/widgets/search_result_preview.dart';
import 'package:quitepaper/features/search/presentation/widgets/search_result_row.dart';
import 'package:quitepaper/features/search/presentation/widgets/search_workspace.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tags/application/tag_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailableDocuments implements DocumentService {
  final requestedIds = <String>[];

  @override
  Future<ResourceResolution<ResolvedDocumentInfo>> resolveDocument(
    String documentId,
  ) async {
    requestedIds.add(documentId);
    return ResourceResolution.missing(QuietPaperUri.document(documentId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NoteSearchMatch match(String id, {bool tag = false, String? content}) =>
    NoteSearchMatch(
      note: Note(
        id: id,
        title: 'Project $id',
        content: content ?? 'Body of project $id\n\n- [ ] Read-only task',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        tags: tag ? ['project'] : [],
      ),
      matchedInTags: tag,
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> showSearch(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    TargetPlatform platform = TargetPlatform.linux,
    GlobalSearchResults? results,
    Stream<GlobalSearchResults>? stream,
    String query = 'project',
    _UnavailableDocuments? documents,
    AppDatabase? database,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (database != null) databaseProvider.overrideWithValue(database),
        if (database != null)
          notesRepositoryProvider.overrideWithValue(
            DriftNotesRepository(database),
          ),
        allTagsProvider.overrideWith((ref) => Stream.value([])),
        globalSearchResultsProvider.overrideWith(
          (ref) =>
              stream ??
              Stream.value(
                results ??
                    GlobalSearchResults(
                      query: query,
                      noteMatches: [match('one'), match('two', tag: true)],
                    ),
              ),
        ),
        if (documents != null)
          documentServiceProvider.overrideWithValue(documents),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: SearchScreen(initialQuery: query, autoFocus: false),
        ),
      ),
    );
    if (stream == null) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  for (final size in [
    const Size(1920, 1080),
    const Size(1024, 768),
    const Size(768, 1024),
    const Size(600, 960),
  ]) {
    testWidgets('split search fits $size with search above compact results', (
      tester,
    ) async {
      await showSearch(tester, size: size, platform: TargetPlatform.android);
      expect(find.byType(SearchWorkspace), findsOneWidget);
      expect(find.byType(SearchResultRow), findsNWidgets(2));
      final resultsRect = tester.getRect(
        find.byKey(const ValueKey('search_results_pane')),
      );
      final previewRect = tester.getRect(
        find.byKey(const ValueKey('search_preview_pane')),
      );
      expect(resultsRect.right, lessThan(previewRect.left));
      expect(previewRect.width, greaterThanOrEqualTo(280));
      expect(
        tester.getRect(find.byType(TextField)).right,
        lessThanOrEqualTo(resultsRect.right),
      );
      expect(
        tester.getSize(find.byType(SearchResultRow).first).height,
        lessThan(100),
      );
      expect(
        tester
            .widget<SearchResultPreview>(find.byType(SearchResultPreview))
            .result,
        isA<NoteSearchMatch>(),
      );
      expect(
        tester
            .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
            .title,
        'Project one',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selection changes preview and filters select their first result',
    (tester) async {
      await showSearch(tester);
      await tester.tap(find.byType(SearchResultRow).last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
            .title,
        'Project two',
      );
      await tester.tap(find.byKey(const ValueKey('search_filter_tags')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultRow), findsOneWidget);
      expect(
        tester
            .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
            .title,
        'Project two',
      );
      await tester.tap(find.byKey(const ValueKey('search_filter_all')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
            .title,
        'Project one',
      );
    },
  );

  testWidgets(
    'preview stays read-only and exposes explicit open/edit callbacks',
    (tester) async {
      SearchResultItem? opened;
      NoteSearchMatch? edited;
      final first = match('one');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: SearchWorkspace(
                header: const SizedBox(height: 80),
                initialState: const SizedBox(),
                query: 'project',
                filter: SearchFilter.all,
                results: AsyncData(
                  GlobalSearchResults(query: 'project', noteMatches: [first]),
                ),
                onOpen: (item) => opened = item,
                onEdit: (item) => edited = item,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<QuietMarkdownPreview>(
        find.byType(QuietMarkdownPreview),
      );
      expect(preview.onMarkdownChanged, isNull);
      expect(preview.onAddTag, isNull);
      expect(preview.onRemoveTag, isNull);
      expect(preview.interactiveChecklists, isFalse);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.tap(find.text('Edit'));
      expect(opened, same(first));
      expect(edited, same(first));
    },
  );

  testWidgets('divider resizes both panes and clamps to usable widths', (
    tester,
  ) async {
    await showSearch(tester);
    final results = find.byKey(const ValueKey('search_results_pane'));
    final preview = find.byKey(const ValueKey('search_preview_pane'));
    final divider = find.byKey(const ValueKey('search_pane_divider'));
    final oldWidth = tester.getSize(results).width;
    final oldPreviewWidth = tester.getSize(preview).width;
    await tester.drag(divider, const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(results).width, greaterThan(oldWidth + 100));
    expect(tester.getSize(preview).width, lessThan(oldPreviewWidth - 100));
    await tester.drag(divider, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(preview).width, greaterThanOrEqualTo(340));
    tester.view.physicalSize = const Size(600, 960);
    await tester.pumpAndSettle();
    expect(tester.getSize(preview).width, greaterThanOrEqualTo(280));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'progressive results retain clicked selection and clear stale previews',
    (tester) async {
      final stream = StreamController<GlobalSearchResults>();
      addTearDown(stream.close);
      final container = await showSearch(tester, stream: stream.stream);
      stream.add(
        GlobalSearchResults(
          query: 'project',
          noteMatches: [match('one'), match('two')],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchResultRow).last);
      stream.add(
        GlobalSearchResults(
          query: 'project',
          noteMatches: [match('new'), match('one'), match('two')],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
            .title,
        'Project two',
      );
      // Provider deliberately retains an old query value; it must not be previewed.
      await tester.enterText(find.byType(TextField), 'different');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();
      expect(find.byType(QuietMarkdownPreview), findsNothing);
      stream.add(
        GlobalSearchResults(query: 'different', noteMatches: [match('fresh')]),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
            .title,
        'Project fresh',
      );
      container.read(searchFilterProvider.notifier).state =
          SearchFilter.documents;
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultPreview), findsNothing);
      expect(find.text('No results found'), findsOneWidget);
    },
  );

  testWidgets('locked notes never render ciphertext', (tester) async {
    await showSearch(
      tester,
      results: GlobalSearchResults(
        query: 'project',
        noteMatches: [
          match(
            'locked',
            content: '<!-- quiet-paper-encrypted-note-v1:secret-ciphertext -->',
          ),
        ],
      ),
    );
    expect(find.byType(QuietMarkdownPreview), findsNothing);
    expect(find.text('Open this note to unlock it.'), findsOneWidget);
    expect(find.textContaining('secret-ciphertext'), findsNothing);
  });

  testWidgets(
    'document results preview matching page metadata and offer Open',
    (tester) async {
      final documents = _UnavailableDocuments();
      final container = await showSearch(
        tester,
        documents: documents,
        results: GlobalSearchResults(
          query: 'project',
          documentMatches: [
            DocumentSearchMatch(
              document: DocumentEntity(
                id: 'scan',
                title: 'Project scan',
                source: 'scanner',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                mimeType: 'application/pdf',
                byteSize: 12,
                pageCount: 3,
                sha256: '',
                encryptionKeyVersion: 1,
                isDirty: false,
                isDeleted: false,
                serverRevision: 0,
                uploadState: 'local',
                ocrState: 'available',
                ocrLanguage: 'en',
              ),
              title: 'Project scan',
              matchedPageNumber: 3,
              snippet: 'Project OCR on page three',
              isOcrMatch: true,
            ),
          ],
        ),
      );
      expect(documents.requestedIds, ['scan']);
      expect(find.text('Page 3'), findsOneWidget);
      expect(find.text('Project OCR on page three'), findsWidgets);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(container.read(searchFilterProvider), SearchFilter.all);
      expect(tester.takeException(), isNull);
    },
  );

  for (final edit in [false, true]) {
    testWidgets(
      '${edit ? 'Edit' : 'Open'} opens the selected note separately and preserves search on return',
      (tester) async {
        final database = AppDatabase.memory();
        addTearDown(database.close);
        final note = match('one').note;
        await DriftNotesRepository(database).saveNote(note);
        await showSearch(tester, database: database);
        await tester.tap(find.text(edit ? 'Edit' : 'Open'));
        await tester.pumpAndSettle();
        final editor = tester.widget<EditorScreen>(find.byType(EditorScreen));
        expect(editor.note.id, 'one');
        expect(editor.initialPreviewMode, !edit);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchWorkspace), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'project',
        );
        expect(
          tester
              .widget<QuietMarkdownPreview>(find.byType(QuietMarkdownPreview))
              .title,
          'Project one',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets('phone keeps its single-column search', (tester) async {
    await showSearch(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    expect(find.byType(SearchWorkspace), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('search_pane_divider')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
