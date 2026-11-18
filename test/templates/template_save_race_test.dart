import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/editor_provider.dart';
import 'package:quitepaper/features/notes/application/note_security_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/domain/note_template.dart';

class GatedNotes extends DriftNotesRepository {
  GatedNotes(super.db);
  Completer<void>? entered;
  Completer<void>? release;
  bool fail = false;
  void gate() {
    entered = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<void> saveNote(Note note, {bool preserveEmptyTags = false}) async {
    if (fail) throw StateError('injected failure');
    if (entered != null && !entered!.isCompleted) {
      entered!.complete();
      await release!.future;
    }
    await super.saveNote(note, preserveEmptyTags: preserveEmptyTags);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late GatedNotes notes;
  late EditorNotifier editor;
  setUp(() async {
    db = AppDatabase.memory();
    notes = GatedNotes(db);
    final note = Note(
      id: 'source',
      title: 'Source',
      content: 'Original',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2020),
    );
    await notes.saveNote(note);
    editor = EditorNotifier(initialNote: note, repository: notes);
  });
  tearDown(() async {
    editor.dispose();
    await db.close();
  });

  test(
    'protection during plaintext save persists ciphertext and blocks template copy',
    () async {
      notes.gate();
      editor.updateContent('Private writing');
      final saving = editor.saveNow();
      await notes.entered!.future;
      final protecting = editor.setPasswordProtection(
        password: 'secret',
        hint: 'hint',
      );
      notes.release!.complete();
      await saving;
      await protecting;
      final saved = (await notes.getNoteById('source'))!;
      expect(saved.isPasswordProtected, true);
      expect(
        (await NoteSecurityService.decryptNote(
          encryptedContent: saved.content,
          password: 'secret',
        )).content,
        'Private writing',
      );
      final service = TemplateService(
        repository: TemplateRepository(db),
        notes: notes,
      );
      await expectLater(
        service.saveNoteAsTemplate(
          noteId: 'source',
          name: 'Blocked',
          flush: () async {},
        ),
        throwsA(isA<TemplateException>()),
      );
      expect(editor.state.isDirty, false);
    },
  );

  for (final remove in [false, true]) {
    test(
      'queued protection ${remove ? 'removal' : 'password change'} awaits its own write',
      () async {
        await editor.setPasswordProtection(password: 'old', hint: 'old hint');
        notes.gate();
        editor.updateContent('Newest secret');
        final saving = editor.saveNow();
        await notes.entered!.future;
        final transition = remove
            ? editor.removePasswordProtection()
            : editor.setPasswordProtection(password: 'new');
        notes.release!.complete();
        await saving;
        await transition;
        final saved = (await notes.getNoteById('source'))!;
        expect(saved.isPasswordProtected, !remove);
        if (remove) {
          expect(saved.content, 'Newest secret');
        } else {
          final decrypted = await NoteSecurityService.decryptNote(
            encryptedContent: saved.content,
            password: 'new',
          );
          expect(decrypted.content, 'Newest secret');
          expect(decrypted.hint, isNull);
          await expectLater(
            NoteSecurityService.decryptNote(
              encryptedContent: saved.content,
              password: 'old',
            ),
            throwsA(anything),
          );
        }
      },
    );
  }

  test(
    'lock during queued save retains password until latest ciphertext persists',
    () async {
      await editor.setPasswordProtection(password: 'secret');
      notes.gate();
      editor.updateContent('First');
      final saving = editor.saveNow();
      await notes.entered!.future;
      editor.updateContent('Latest');
      final locking = editor.lockNow();
      expect(editor.state.activePassword, 'secret');
      notes.release!.complete();
      await saving;
      await locking;
      expect(editor.state.isUnlocked, false);
      final saved = (await notes.getNoteById('source'))!;
      expect(
        (await NoteSecurityService.decryptNote(
          encryptedContent: saved.content,
          password: 'secret',
        )).content,
        'Latest',
      );
    },
  );

  test(
    'failed protection stays dirty and cannot report successful persistence',
    () async {
      notes.fail = true;
      await expectLater(
        editor.setPasswordProtection(password: 'secret'),
        throwsStateError,
      );
      expect(editor.state.isDirty, true);
      expect((await notes.getNoteById('source'))!.isPasswordProtected, false);
    },
  );
}
