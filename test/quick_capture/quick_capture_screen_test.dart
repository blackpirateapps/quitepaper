import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/quick_capture/domain/quick_capture_payload.dart';
import 'package:quitepaper/features/quick_capture/presentation/quick_capture_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required QuickCapturePayload payload}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: QuickCaptureScreen(payload: payload),
      ),
    );
  }

  group('QuickCaptureScreen Widget Tests', () {
    testWidgets('renders all visual elements matching design specification', (tester) async {
      final payload = QuickCapturePayload(
        id: 'widget-test-1',
        targetNoteId: 'note-test-1',
        origin: CaptureOrigin.widget,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(payload: payload));
      await tester.pumpAndSettle();

      expect(find.text('Quick Capture'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text("What's on your mind?"), findsOneWidget);
      expect(
        find.text('The idea goes here. Start typing immediately, without a title or any extra setup.'),
        findsOneWidget,
      );
      expect(find.text('Saved on your device first'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('automatically requests keyboard focus on mount', (tester) async {
      final payload = QuickCapturePayload(
        id: 'focus-test',
        targetNoteId: 'note-focus',
        origin: CaptureOrigin.widget,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(payload: payload));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('save button is disabled for empty content and saves when text entered', (tester) async {
      final payload = QuickCapturePayload(
        id: 'save-test',
        targetNoteId: 'note-saved-ui',
        origin: CaptureOrigin.widget,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(payload: payload));
      await tester.pumpAndSettle();

      // Tap save while empty -> no note created
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      var notes = await db.select(db.notesTable).get();
      expect(notes, isEmpty);

      // Enter text
      await tester.enterText(find.byType(TextField), 'My brilliant quick thought');
      await tester.pump();

      // Tap save now
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      notes = await db.select(db.notesTable).get();
      expect(notes.length, 1);
      expect(notes.first.title, 'My brilliant quick thought');
    });

    testWidgets('prefills shared URL and displays Clip full article action', (tester) async {
      final payload = QuickCapturePayload(
        id: 'share-test',
        targetNoteId: 'note-share',
        origin: CaptureOrigin.share,
        initialContent: 'https://news.ycombinator.com',
        sourceUrl: 'https://news.ycombinator.com',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(payload: payload));
      await tester.pumpAndSettle();

      expect(find.text('https://news.ycombinator.com'), findsOneWidget);
      expect(find.text('Clip full article'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    });

    testWidgets('shows resume unfinished draft chip when earlier drafts exist', (tester) async {
      final now = DateTime.now();
      await db.saveQuickCaptureDraft(
        id: 'earlier-draft-id',
        targetNoteId: 'note-earlier',
        content: 'Earlier unfinished thought',
        source: 'widget',
        createdAt: now,
        updatedAt: now,
      );

      final payload = QuickCapturePayload(
        id: 'new-session-id',
        targetNoteId: 'note-new',
        origin: CaptureOrigin.widget,
        createdAt: now,
      );

      await tester.pumpWidget(createTestWidget(payload: payload));
      await tester.pumpAndSettle();

      expect(find.text('Resume unfinished capture (1)'), findsOneWidget);

      // Tap resume draft chip to open sheet
      await tester.tap(find.text('Resume unfinished capture (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Unfinished Captures'), findsOneWidget);
      expect(find.text('Earlier unfinished thought'), findsOneWidget);

      // Select earlier draft
      await tester.tap(find.text('Earlier unfinished thought'));
      await tester.pumpAndSettle();

      // Text field should now contain the restored content
      expect(find.text('Earlier unfinished thought'), findsOneWidget);
    });

    testWidgets('renders cleanly on narrow viewports without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 600 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final payload = QuickCapturePayload(
        id: 'narrow-test',
        targetNoteId: 'note-narrow',
        origin: CaptureOrigin.widget,
        initialContent: 'Testing layout responsiveness on small screens',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(payload: payload));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quick Capture'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
