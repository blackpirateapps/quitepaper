import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_controller.dart';
import 'package:quitepaper/features/quick_capture/domain/quick_capture_payload.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('QuickCaptureController Unit Tests', () {
    test('opening empty session initializes with empty content and cannot save', () {
      final payload = QuickCapturePayload(
        id: 'session-empty',
        targetNoteId: 'note-empty',
        origin: CaptureOrigin.widget,
        createdAt: DateTime.now(),
      );

      final controller = QuickCaptureController(database: db, initialPayload: payload);
      addTearDown(controller.dispose);

      expect(controller.state.isEmpty, isTrue);
      expect(controller.state.canSave, isFalse);
      expect(controller.state.content, isEmpty);
    });

    test('opening prefilled session automatically persists initial draft', () async {
      final payload = QuickCapturePayload(
        id: 'session-prefilled',
        targetNoteId: 'note-prefilled',
        origin: CaptureOrigin.share,
        initialContent: 'Shared link: https://example.com',
        sourceUrl: 'https://example.com',
        createdAt: DateTime.now(),
      );

      final controller = QuickCaptureController(database: db, initialPayload: payload);
      addTearDown(controller.dispose);

      expect(controller.state.content, 'Shared link: https://example.com');
      expect(controller.state.canSave, isTrue);

      final draft = await db.getQuickCaptureDraft('session-prefilled');
      expect(draft, isNotNull);
      expect(draft!.content, 'Shared link: https://example.com');
    });

    test('debounced updateContent and flushDraft persist latest content', () async {
      final payload = QuickCapturePayload(
        id: 'session-typing',
        targetNoteId: 'note-typing',
        origin: CaptureOrigin.widget,
        createdAt: DateTime.now(),
      );

      final controller = QuickCaptureController(database: db, initialPayload: payload);
      addTearDown(controller.dispose);

      controller.updateContent('First words');
      expect(controller.state.content, 'First words');

      // Immediate flush ensures disk persistence before debounce fires
      await controller.flushDraft();

      final draft = await db.getQuickCaptureDraft('session-typing');
      expect(draft, isNotNull);
      expect(draft!.content, 'First words');
    });

    test('save commits note to database, deletes draft, and sets isSaved to true', () async {
      final payload = QuickCapturePayload(
        id: 'session-save',
        targetNoteId: 'note-saved',
        origin: CaptureOrigin.widget,
        createdAt: DateTime.now(),
      );

      final controller = QuickCaptureController(database: db, initialPayload: payload);
      addTearDown(controller.dispose);

      controller.updateContent('A profound thought on notes.\nSecond line here.');
      final saveResult = await controller.save();

      expect(saveResult, isTrue);
      expect(controller.state.isSaved, isTrue);
      expect(controller.state.canSave, isFalse);

      // Draft deleted
      final draft = await db.getQuickCaptureDraft('session-save');
      expect(draft, isNull);

      // Note saved
      final note = await db.getNoteWithTags('note-saved');
      expect(note, isNotNull);
      expect(note!.note.title, 'A profound thought on notes.');
      expect(note.note.content, 'A profound thought on notes.\nSecond line here.');
    });

    test('incoming share while typing does not overwrite current text and sets incomingPendingPayload', () async {
      final payload1 = QuickCapturePayload(
        id: 'session-active',
        targetNoteId: 'note-active',
        origin: CaptureOrigin.widget,
        initialContent: 'Currently typing user thought',
        createdAt: DateTime.now(),
      );

      final controller = QuickCaptureController(database: db, initialPayload: payload1);
      addTearDown(controller.dispose);

      final payload2 = QuickCapturePayload(
        id: 'session-incoming',
        targetNoteId: 'note-incoming',
        origin: CaptureOrigin.share,
        initialContent: 'Incoming shared URL: https://flutter.dev',
        sourceUrl: 'https://flutter.dev',
        createdAt: DateTime.now(),
      );

      controller.handleIncomingShare(payload2);

      // Current content is preserved
      expect(controller.state.content, 'Currently typing user thought');
      expect(controller.state.incomingPendingPayload, isNotNull);
      expect(controller.state.incomingPendingPayload!.id, 'session-incoming');

      // Accepting switches content
      await controller.acceptIncomingPendingShare();
      expect(controller.state.content, 'Incoming shared URL: https://flutter.dev');
      expect(controller.state.incomingPendingPayload, isNull);
    });

    test('resumeDraft loads an earlier session and preserves current draft', () async {
      final now = DateTime.now();
      await db.saveQuickCaptureDraft(
        id: 'draft-earlier',
        targetNoteId: 'note-earlier',
        content: 'Earlier unfinished thought',
        source: 'widget',
        cursorPosition: 12,
        createdAt: now,
        updatedAt: now,
      );

      final currentPayload = QuickCapturePayload(
        id: 'session-current',
        targetNoteId: 'note-current',
        origin: CaptureOrigin.widget,
        initialContent: 'Current typing',
        createdAt: now,
      );

      final controller = QuickCaptureController(database: db, initialPayload: currentPayload);
      addTearDown(controller.dispose);

      final earlierDraft = await db.getQuickCaptureDraft('draft-earlier');
      expect(earlierDraft, isNotNull);

      await controller.resumeDraft(earlierDraft!);
      expect(controller.state.content, 'Earlier unfinished thought');
      expect(controller.state.payload.id, 'draft-earlier');
    });
  });
}
