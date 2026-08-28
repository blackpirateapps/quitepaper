import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/features/export/application/export_provider.dart';
import 'package:quitepaper/features/export/application/export_service.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';
import 'package:quitepaper/features/notes/application/note_security_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NotesRepository repository;
  late MockKeyManager keyManager;
  late AttachmentService attachmentService;
  late DocumentService documentService;
  late ExportService exportService;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
    keyManager = MockKeyManager(masterKey: Uint8List.fromList(List.generate(32, (i) => i)));
    tempDir = await Directory.systemTemp.createTemp('export_service_test_');

    attachmentService = AttachmentService(
      database: db,
      keyManager: keyManager,
    );

    documentService = DocumentService(
      database: db,
      keyManager: keyManager,
    );

    exportService = ExportService(
      database: db,
      keyManager: keyManager,
      attachmentService: attachmentService,
      documentService: documentService,
      tempDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ExportService End-to-End', () {
    test('exports note to Markdown, PlainText, HTML, PDF, DOCX, and QPNOTE', () async {
      // 1. Create a note in database
      final noteId = 'note-test-1';
      final now = DateTime.utc(2026, 1, 1);
      final note = Note(
        id: noteId,
        title: 'Weekly Standup Summary',
        content: '''# Weekly Standup
- [x] Sprint planning finished
- [ ] Deploy release candidate

> High priority deliverables for Q1.

```dart
void main() => print("Ready");
```
''',
        createdAt: now,
        updatedAt: now,
        isPinned: true,
        tags: const ['meeting', 'sprint'],
      );
      await repository.saveNote(note);

      // 2. Test Markdown export
      final mdResult = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.markdown,
          includeMetadata: true,
        ),
      );
      expect(mdResult.format, equals(ExportFormat.markdown));
      expect(await mdResult.file.exists(), isTrue);
      final mdContent = await mdResult.file.readAsString();
      expect(mdContent, contains('Weekly Standup Summary'));
      expect(mdContent, contains('# Weekly Standup'));

      // 3. Test PlainText export
      final txtResult = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.plainText,
          includeMetadata: true,
        ),
      );
      expect(txtResult.format, equals(ExportFormat.plainText));
      final txtContent = await txtResult.file.readAsString();
      expect(txtContent, contains('☑ Sprint planning finished'));

      // 4. Test HTML export
      final htmlResult = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.html,
          includeMetadata: true,
        ),
      );
      expect(htmlResult.format, equals(ExportFormat.html));
      final htmlContent = await htmlResult.file.readAsString();
      expect(htmlContent, contains('<!DOCTYPE html>'));

      // 5. Test PDF export
      final pdfResult = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.pdf,
          includeMetadata: true,
        ),
      );
      expect(pdfResult.format, equals(ExportFormat.pdf));
      expect(pdfResult.byteSize, greaterThan(1000));

      // 6. Test DOCX export
      final docxResult = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.docx,
          includeMetadata: true,
        ),
      );
      expect(docxResult.format, equals(ExportFormat.docx));
      expect(docxResult.byteSize, greaterThan(500));

      // 7. Test QPNOTE export
      final qpResult = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.qpnote,
          includeMetadata: true,
        ),
      );
      expect(qpResult.format, equals(ExportFormat.qpnote));
      final val = await exportService.validateQpNote(qpResult.file);
      expect(val.isValid, isTrue);
      expect(val.noteTitle, equals('Weekly Standup Summary'));
    });

    test('exports password protected note after unlocking', () async {
      final encryptedBody = await NoteSecurityService.encryptNote(
        title: 'Confidential Strategy',
        content: '# Top Secret\nLaunch date is confidential.',
        password: 'secure_pass_123',
        hint: 'mypass',
        tags: const ['confidential'],
      );

      final noteId = 'secret-note-1';
      final now = DateTime.utc(2026, 1, 1);
      final note = Note(
        id: noteId,
        title: 'Confidential Strategy',
        content: encryptedBody,
        createdAt: now,
        updatedAt: now,
        tags: const ['secure'],
      );
      await repository.saveNote(note);

      final result = await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.markdown,
          notePassword: 'secure_pass_123',
        ),
      );

      expect(result.format, equals(ExportFormat.markdown));
      final content = await result.file.readAsString();
      expect(content, contains('# Top Secret'));
      expect(content, contains('Launch date is confidential.'));
    });

    test('reports progress phases sequentially during export', () async {
      final noteId = 'progress-note-1';
      final now = DateTime.utc(2026, 1, 1);
      final note = Note(
        id: noteId,
        title: 'Progress Check',
        content: 'Testing progress stream.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      final observedPhases = <ExportPhase>[];

      await exportService.exportNote(
        ExportRequest(
          noteId: noteId,
          format: ExportFormat.markdown,
        ),
        onProgress: (state) {
          observedPhases.add(state.phase);
        },
      );

      expect(observedPhases, contains(ExportPhase.preparingNote));
      expect(observedPhases, contains(ExportPhase.resolvingAttachments));
      expect(observedPhases, contains(ExportPhase.renderingDocument));
      expect(observedPhases, contains(ExportPhase.complete));
    });
  });

  group('ExportPreferencesNotifier', () {
    test('persists and loads export preferences in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ExportPreferencesNotifier(prefs);
      expect(notifier.state.lastFormat, equals(ExportFormat.markdown));

      await notifier.updatePreferences(
        lastFormat: ExportFormat.pdf,
        includeMetadata: false,
        includeAttachments: false,
      );

      expect(notifier.state.lastFormat, equals(ExportFormat.pdf));
      expect(notifier.state.includeMetadata, isFalse);
      expect(notifier.state.includeAttachments, isFalse);

      // Verify reloaded notifier retrieves updated values
      final reloaded = ExportPreferencesNotifier(prefs);
      expect(reloaded.state.lastFormat, equals(ExportFormat.pdf));
      expect(reloaded.state.includeMetadata, isFalse);
      expect(reloaded.state.includeAttachments, isFalse);
    });
  });
}
