import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

class InMemoryNotesRepository implements NotesRepository {
  final Map<String, Note> _notes = {};

  @override
  Future<void> saveNote(Note note) async {
    _notes[note.id] = note;
  }

  @override
  Future<Note?> getNoteById(String id) async => _notes[id];

  @override
  Stream<List<Note>> watchNotes({
    bool isArchived = false,
    bool isTrashed = false,
    bool? isPinned,
    String? filterTag,
    String? searchQuery,
  }) {
    return Stream.value(_notes.values.toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WebClipperService', () {
    test('clips article and creates note in repository', () async {
      final repository = InMemoryNotesRepository();
      final mockClient = MockClient((request) async {
        const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>How Local-First Software Works</title>
  <meta name="author" content="Jordan Key" />
  <meta name="description" content="A guide to local first apps." />
</head>
<body>
  <article>
    <h1>How Local-First Software Works</h1>
    <p>Local data is the primary copy; cloud is secondary.</p>
  </article>
</body>
</html>
''';
        return http.Response(html, 200, headers: {'content-type': 'text/html'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final service = WebClipperService(
        notesRepository: repository,
        scanner: scanner,
      );

      final scanResult = await service.scanUrl('https://example.com/local-first');
      expect(scanResult.metadata.title, 'How Local-First Software Works');

      final clipResult = await service.clipArticle(
        scanResult: scanResult,
        options: const WebClipperOptions(
          tags: ['offline', 'architecture'],
          saveHtmlSnapshot: false,
          downloadImages: false,
        ),
      );

      expect(clipResult.note.title, 'How Local-First Software Works');
      expect(clipResult.note.tags, contains('clipped'));
      expect(clipResult.note.tags, contains('example.com'));
      expect(clipResult.note.tags, contains('offline'));
      expect(clipResult.note.content, contains('title: "How Local-First Software Works"'));
      expect(clipResult.note.content, contains('Local data is the primary copy'));

      final savedNote = await repository.getNoteById(clipResult.note.id);
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'How Local-First Software Works');
    });
  });
}
