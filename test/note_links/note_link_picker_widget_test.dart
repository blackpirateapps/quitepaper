import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/note_links/note_link_search_service.dart';
import 'package:quitepaper/features/editor/presentation/widgets/note_link_picker_sheet.dart';

void main() {
  group('NoteLinkPickerSheet Widget Tests', () {
    late AppDatabase db;
    late NoteLinkSearchService searchService;

    setUp(() {
      db = AppDatabase.memory();
      searchService = NoteLinkSearchService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp({
      required Widget child,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders search input and results list', (tester) async {
      await db.saveNote(
        id: 'fourier-note-id',
        title: 'Fourier Transform',
        content: 'Mathematics notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );


      NoteLinkPickerSelectResult? selected;

      await tester.pumpWidget(
        createTestApp(
          child: NoteLinkPickerSheet(
            searchService: searchService,
            initialQuery: '',
            onSelect: (res) => selected = res,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Link to a note'), findsOneWidget);
      expect(find.text('Fourier Transform'), findsOneWidget);

      await tester.tap(find.text('Fourier Transform'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.noteId, 'fourier-note-id');
      expect(selected!.title, 'Fourier Transform');
    });

    testWidgets('shows create note option when query does not match existing note', (tester) async {
      NoteLinkPickerCreateResult? created;

      await tester.pumpWidget(
        createTestApp(
          child: NoteLinkPickerSheet(
            searchService: searchService,
            initialQuery: 'Brand New Topic',
            onCreate: (res) => created = res,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Create'), findsOneWidget);
      expect(find.textContaining('Brand New Topic'), findsWidgets);

      await tester.tap(find.textContaining('Create'));

      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.newTitle, 'Brand New Topic');
    });
  });
}
