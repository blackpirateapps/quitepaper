import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/typewriter_scroll_coordinator.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/typewriter_document_layer.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  group('TypewriterScrollCoordinator Unit Tests', () {
    late ScrollController scrollController;
    late GlobalKey viewportKey;

    setUp(() {
      scrollController = ScrollController();
      viewportKey = GlobalKey();
    });

    tearDown(() {
      scrollController.dispose();
    });

    testWidgets('aligns custom caret position to 45% of viewport', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: viewportKey,
              height: 1000,
              child: SingleChildScrollView(
                controller: scrollController,
                child: const SizedBox(height: 3000),
              ),
            ),
          ),
        ),
      );

      final coordinator = TypewriterScrollCoordinator(
        scrollController: scrollController,
        viewportKey: viewportKey,
        targetFraction: 0.45,
      );

      expect(scrollController.offset, 0.0);

      // Target waterline is 1000 * 0.45 = 450.0.
      // If caret is at global Y = 650.0, dy = 650 - 450 = +200.0.
      coordinator.alignCaretToTarget(
        customGlobalCaretPos: const Offset(50, 650),
        animated: false,
      );

      expect(scrollController.offset, 200.0);
    });

    testWidgets('does not scroll if caret is already within 2px tolerance of 45%', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: viewportKey,
              height: 1000,
              child: SingleChildScrollView(
                controller: scrollController,
                child: const SizedBox(height: 3000),
              ),
            ),
          ),
        ),
      );

      final coordinator = TypewriterScrollCoordinator(
        scrollController: scrollController,
        viewportKey: viewportKey,
        targetFraction: 0.45,
      );

      scrollController.jumpTo(200.0);

      // Target is 450. Caret at 451.0 (dy = 1.0 < 2.0).
      coordinator.alignCaretToTarget(
        customGlobalCaretPos: const Offset(50, 451),
        animated: false,
      );

      expect(scrollController.offset, 200.0);
    });

    testWidgets('clamps scroll offset within [minScrollExtent, maxScrollExtent]', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: viewportKey,
              height: 1000,
              child: SingleChildScrollView(
                controller: scrollController,
                child: const SizedBox(height: 1500), // maxScrollExtent = 500
              ),
            ),
          ),
        ),
      );

      final coordinator = TypewriterScrollCoordinator(
        scrollController: scrollController,
        viewportKey: viewportKey,
        targetFraction: 0.45,
      );

      // Attempt to scroll past maxScrollExtent
      coordinator.alignCaretToTarget(
        customGlobalCaretPos: const Offset(50, 2000),
        animated: false,
      );

      expect(scrollController.offset, 500.0);

      // Attempt to scroll before minScrollExtent
      coordinator.alignCaretToTarget(
        customGlobalCaretPos: const Offset(50, -500),
        animated: false,
      );

      expect(scrollController.offset, 0.0);
    });

    testWidgets('onTypingActivity debounces and schedules alignment for next frame', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: viewportKey,
              height: 1000,
              child: SingleChildScrollView(
                controller: scrollController,
                child: const SizedBox(height: 3000),
              ),
            ),
          ),
        ),
      );

      final coordinator = TypewriterScrollCoordinator(
        scrollController: scrollController,
        viewportKey: viewportKey,
        targetFraction: 0.45,
      );

      // Rapidly call onTypingActivity multiple times within the same frame
      coordinator.onTypingActivity(customGlobalCaretPos: const Offset(50, 600));
      coordinator.onTypingActivity(customGlobalCaretPos: const Offset(50, 700));

      expect(scrollController.offset, 0.0); // Not yet executed

      await tester.pump(); // Executes post-frame callback
      await tester.pumpAndSettle();

      // 700 - 450 = 250
      expect(scrollController.offset, 250.0);
    });
  });

  group('TextField RenderEditable Caret Detection', () {
    testWidgets('finds RenderEditable and calculates global caret Y accurately', (tester) async {
      final textController = TextEditingController(
        text: List.generate(20, (i) => 'Line $i with sample text').join('\n'),
      );
      final focusNode = FocusNode();
      final scrollController = ScrollController();
      final viewportKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: viewportKey,
              height: 600,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    TextField(
                      controller: textController,
                      focusNode: focusNode,
                      maxLines: null,
                    ),
                    const SizedBox(height: 1000),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final coordinator = TypewriterScrollCoordinator(
        scrollController: scrollController,
        viewportKey: viewportKey,
        targetFraction: 0.45,
      );

      // Place caret at Line 12
      textController.selection = TextSelection.collapsed(
        offset: textController.text.indexOf('Line 12'),
      );
      await tester.pump();

      coordinator.alignCaretToTarget(
        activeFocusNode: focusNode,
        animated: false,
      );
      await tester.pump();

      final renderEditable = TypewriterScrollCoordinator.findRenderEditable(focusNode.context!);
      expect(renderEditable, isNotNull);

      final caretRect = renderEditable!.getLocalRectForCaret(
        TextPosition(offset: textController.selection.extentOffset),
      );
      final globalCaretY = renderEditable.localToGlobal(caretRect.center).dy;

      final viewportBox = viewportKey.currentContext!.findRenderObject() as RenderBox;
      final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
      final targetGlobalY = viewportTop + (viewportBox.size.height * 0.45);

      // Verify caret is centered at ~45% of viewport
      expect((globalCaretY - targetGlobalY).abs(), lessThan(2.0));
    });
  });

  group('SuperEditor Typewriter Layer Tests', () {
    testWidgets('TypewriterDocumentLayer reports global caret position on selection change', (tester) async {
      final composer = MutableDocumentComposer();
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText('Line 1 in SuperEditor')),
          ParagraphNode(id: '2', text: AttributedText('Line 2 in SuperEditor')),
          ParagraphNode(id: '3', text: AttributedText('Line 3 in SuperEditor')),
        ],
      );
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      Offset? reportedGlobalCaret;
      final layerBuilder = TypewriterDocumentLayerBuilder(
        onCaretGlobalPosition: (pos) {
          reportedGlobalCaret = pos;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: SuperEditor(
                editor: editor,
                documentOverlayBuilders: [layerBuilder],
              ),
            ),
          ),
        ),
      );

      expect(reportedGlobalCaret, isNull);

      // Change selection to line 2
      composer.setSelectionWithReason(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '2',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );
      await tester.pump();

      expect(reportedGlobalCaret, isNotNull);
      expect(reportedGlobalCaret!.dy, greaterThan(0));
    });
  });

  group('EditorScreen Typewriter Integration Tests', () {
    late AppDatabase db;
    late NotesRepository repository;
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

    Widget createEditorApp(Note note, {EditorEditingStyle initialStyle = EditorEditingStyle.markdown}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith((ref) => EditingStyleNotifier(prefs)..state = initialStyle),
        ],
        child: MaterialApp(
          home: EditorScreen(note: note),
        ),
      );
    }

    testWidgets('Markdown mode keeps active cursor line around 45% of viewport as user types', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      // Generate 40 lines of content
      final longContent = List.generate(40, (i) => 'Paragraph $i with ample descriptive sentences for testing.').join('\n\n');
      final note = Note(
        id: 'test-note-1',
        title: 'Typewriter Test',
        content: longContent,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note, initialStyle: EditorEditingStyle.markdown));
      await tester.pumpAndSettle();

      // Find the SingleChildScrollView scroll controller
      final scrollable = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final controller = scrollable.controller!;

      // Initially at top of note
      expect(controller.offset, 0.0);

      // Find the text field and focus it on line 25
      final targetWord = 'Paragraph 25';
      final offset = longContent.indexOf(targetWord);
      expect(offset, greaterThan(0));

      final textField = find.byType(TextField).last;
      await tester.tap(textField, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Enter text at that line
      await tester.enterText(textField, longContent.replaceFirst(targetWord, '$targetWord typing additional words'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Viewport height is 1000 minus top app bar (~56px).
      // The scroll controller should have smoothly scrolled down past 0.0
      expect(controller.offset, greaterThan(100.0));

      // Clean up before test completion
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
