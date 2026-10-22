import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:quitepaper/features/whatsapp_formatter/application/whatsapp_preferences_provider.dart';
import 'package:quitepaper/features/whatsapp_formatter/presentation/widgets/whatsapp_chat_card.dart';
import 'package:quitepaper/features/whatsapp_formatter/presentation/widgets/whatsapp_inline_suggestion_banner.dart';
import 'package:quitepaper/features/whatsapp_formatter/presentation/whatsapp_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp Formatter Editor & Widget Integration Tests', () {
    late AppDatabase db;
    late NotesRepository repository;
    late SharedPreferences prefs;

    const sampleChat = '''
[21/10, 11:04\u202Fpm] Sam 3: Yeshh
[21/10, 11:04\u202Fpm] Sam 3: That's so sexyyy
[21/10, 11:04\u202Fpm] Sam 3: 😭😭😭😭 you're using her voice note
[21/10, 11:14\u202Fpm] BlackPirate: Shes goat
[21/10, 11:14\u202Fpm] BlackPirate: Yessh
[21/10, 11:17\u202Fpm] BlackPirate: im starting to understand why iphone apps take more space than their android counterpart.
[21/10, 11:51\u202Fpm] Sam 3: I agree
[21/10, 11:51\u202Fpm] Sam 3: And what did you understand
[22/10, 5:06\u202Fam] BlackPirate: IPhone apps have attention to detail so they have much more code than usual
[22/10, 5:18\u202Fam] BlackPirate: Lemme do the public site of urs first.
''';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('pasteboard'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'files') return <String>[];
          if (methodCall.method == 'image') return null;
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': sampleChat};
          }
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createEditorApp(Note note, {bool isTablet = false}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: EditorScreen(
            note: note,
            initialPreviewMode: isTablet,
            autoFocusBody: false,
            onClose: isTablet ? () {} : null,
          ),
        ),
      );
    }

    Future<void> pasteClipboard(WidgetTester tester) async {
      final contentFieldFinder = find.byType(TextField).last;
      await tester.tap(contentFieldFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> drainTimers(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1000));
    }

    testWidgets('Ordinary typing does not trigger WhatsApp banner', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-1',
        title: 'Ordinary Note',
        content: '',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pump();

      final textFieldFinder = find.byType(TextField).last;
      await tester.enterText(textFieldFinder, 'Just typing an ordinary note.');
      await tester.pump();

      expect(find.byType(WhatsAppInlineSuggestionBanner), findsNothing);

      await drainTimers(tester);
    });

    testWidgets('Pasting WhatsApp text triggers inline suggestion banner', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-2',
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pump();

      await pasteClipboard(tester);

      expect(find.byType(WhatsAppInlineSuggestionBanner), findsOneWidget);
      expect(find.text('WhatsApp conversation detected (10 messages)'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('Tapping Preview on banner opens WhatsAppPreviewScreen', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-3',
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pump();

      await pasteClipboard(tester);

      final previewButton = find.widgetWithText(TextButton, 'Preview');
      expect(previewButton, findsOneWidget);
      await tester.tap(previewButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WhatsAppPreviewScreen), findsOneWidget);
      expect(find.text('Conversation with Sam 3 & BlackPirate'), findsOneWidget);
      expect(find.text('10 messages · 2 participants'), findsOneWidget);
      expect(find.text('Show sender names'), findsOneWidget);
      expect(find.text('Preserve timestamps'), findsOneWidget);
      expect(find.text('Group consecutive messages'), findsOneWidget);
      expect(find.text('Apply format'), findsOneWidget);
      expect(find.text('Copy original'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('Applying format transforms note content, updates title, and allows undo', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-4',
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pump();

      await pasteClipboard(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final applyButton = find.widgetWithText(ElevatedButton, 'Apply format');
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WhatsAppPreviewScreen), findsNothing);

      final titleFinder = find.byType(TextField).first;
      expect((tester.widget(titleFinder) as TextField).controller!.text, equals('Conversation with Sam 3 & BlackPirate'));

      // Formatted chat is rendered as an embedded WhatsAppChatCard block
      expect(find.byType(WhatsAppChatCard), findsOneWidget);
      expect(find.text('Sam 3'), findsWidgets);
      expect(find.text('Yeshh'), findsWidgets);

      // Undo reverts to unformatted text via Toolbar button
      final undoFinder = find.byIcon(PhosphorIconsRegular.arrowUUpLeft);
      expect(undoFinder, findsWidgets);
      await tester.tap(undoFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WhatsAppChatCard), findsNothing);
      final editableTexts = tester.widgetList<EditableText>(find.byType(EditableText));
      expect(editableTexts.any((e) => e.controller.text.contains('Yeshh')), isTrue);

      // Redo restores formatted block via Toolbar button
      final redoFinder = find.byIcon(PhosphorIconsRegular.arrowUUpRight);
      expect(redoFinder, findsWidgets);
      await tester.tap(redoFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WhatsAppChatCard), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('Tapping dismiss on banner leaves text untouched and hides banner', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-5',
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pump();

      await pasteClipboard(tester);

      expect(find.byType(WhatsAppInlineSuggestionBanner), findsOneWidget);

      final dismissIcon = find.byTooltip('Dismiss suggestion');
      expect(dismissIcon, findsOneWidget);
      await tester.tap(dismissIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(WhatsAppInlineSuggestionBanner), findsNothing);

      await drainTimers(tester);
    });

    testWidgets('Toggling tabs switches between Formatted conversation and Original text', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-6',
        title: 'Chat Note',
        content: sampleChat,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note, isTablet: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WhatsAppPreviewScreen), findsOneWidget);
      expect(find.text('Options'), findsOneWidget);

      await tester.tap(find.text('Original text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Options'), findsNothing);

      await tester.tap(find.text('Formatted conversation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Options'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('Format options persist across provider rebuilds in SharedPreferences', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      var opts = container.read(whatsappFormatOptionsProvider);
      expect(opts.showSenderNames, isTrue);

      await container.read(whatsappFormatOptionsProvider.notifier).toggleShowSenderNames();
      opts = container.read(whatsappFormatOptionsProvider);
      expect(opts.showSenderNames, isFalse);

      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      final restored = container2.read(whatsappFormatOptionsProvider);
      expect(restored.showSenderNames, isFalse);

      container.dispose();
      container2.dispose();
    });
  });
}
