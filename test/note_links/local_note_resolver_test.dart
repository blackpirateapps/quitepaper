import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/uri/local_note_resolver.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';

void main() {
  group('LocalNoteResolver', () {
    late AppDatabase db;
    late LocalNoteResolver resolver;

    setUp(() {
      db = AppDatabase.memory();
      resolver = LocalNoteResolver(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('resolves active existing note', () async {
      const noteId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      await db.saveNote(
        id: noteId,
        title: 'Fourier Analysis',
        content: 'Sine and cosine waves.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final res = await resolver.resolveNote(noteId);
      expect(res.status, ResourceStatus.available);
      expect(res.data, isNotNull);
      expect(res.data!.title, 'Fourier Analysis');
      expect(res.data!.isTrashed, false);
      expect(res.data!.isLocked, false);
    });

    test('returns missing for non-existent note', () async {
      const noteId = '00000000-0000-4000-8000-000000000000';
      final res = await resolver.resolveNote(noteId);
      expect(res.status, ResourceStatus.missing);
      expect(res.errorMessage, 'This note is no longer available.');
    });

    test('resolves trashed note with isTrashed flag', () async {
      const noteId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      await db.saveNote(
        id: noteId,
        title: 'Old Draft',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isTrashed: true,
        deletedAt: DateTime.now(),
      );


      final res = await resolver.resolveNote(noteId);
      expect(res.status, ResourceStatus.available);
      expect(res.data!.isTrashed, true);
    });

    test('returns missing for invalid note UUID', () async {
      final res = await resolver.resolveNote('invalid-uuid');
      expect(res.status, ResourceStatus.missing);
    });
  });
}
