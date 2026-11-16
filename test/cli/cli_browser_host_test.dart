import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_browser_host.dart';
import 'package:quitepaper/core/cli/cli_database.dart';

void main() {
  late CliDatabase db;
  late CliBrowserHost host;
  setUp(() {
    db = CliDatabase.openInMemory();
    host = CliBrowserHost(() => db);
  });
  tearDown(() => db.close());

  Map<String, Object?> capture() => {
    'version': 1,
    'action': 'clip',
    'url': 'https://members.example.com/articles/private',
    'title': 'Members-only article',
    'author': 'A Writer',
    'publishedAt': '2026-11-17T10:00:00Z',
    'tags': ['research'],
    'html':
        '<article><h1>Members-only article</h1>'
        '<p>Unique authenticated article text.</p>'
        '<p><a href="../related">Related story</a></p>'
        '<pre><code class="language-dart">print(42);</code></pre>'
        '<table><tr><th>Name</th></tr><tr><td>Quiet Paper</td></tr></table>'
        '</article>',
  };

  test(
    'saves supplied private DOM as a normal searchable, queued web clip',
    () {
      final response = host.handle(capture());
      expect(response['ok'], true);
      final note = db.getNoteByIdOrPrefix(response['id'] as String)!;
      expect(note.title, 'Members-only article');
      expect(note.content, contains('Unique authenticated article text.'));
      expect(
        note.content,
        contains('source: "https://members.example.com/articles/private"'),
      );
      expect(note.content, contains('created: "2026-11-17"'));
      expect(
        note.content,
        contains('[Related story](https://members.example.com/related)'),
      );
      expect(note.content, contains('```dart\nprint(42);\n```'));
      expect(note.content, contains('| Quiet Paper |'));
      expect(
        note.tags,
        containsAll(['clipped', 'web/members-example-com', 'research']),
      );
      expect(db.listNotes(query: 'Unique authenticated').single.id, note.id);
      expect(
        db.connection.select('SELECT * FROM sync_queue').single['note_id'],
        note.id,
      );
      expect(
        db.connection.select('SELECT * FROM note_versions').single['note_id'],
        note.id,
      );
    },
  );

  test('strips scripts, form secrets, active and local/vault URLs', () {
    final request = capture()
      ..['html'] = '''
      <script>SECRET_SCRIPT</script><form>SECRET_FORM<input value="password"></form>
      <p onclick="evil()">Keep this <a href="javascript:evil()">link</a>.</p>
      <p><a href="file:///etc/passwd">file</a><a href="qp://document/fake">vault</a></p>
      <img src="file:///etc/private.png"><img src="https://cdn.example.com/photo.png" alt="Photo">
      <p><a href="mailto:hello@example.com">Email</a></p>
    ''';
    final note = db.getNoteByIdOrPrefix(host.handle(request)['id'] as String)!;
    expect(note.content, contains('Keep this link.'));
    expect(
      note.content,
      contains('![Photo](https://cdn.example.com/photo.png)'),
    );
    expect(note.content, contains('[Email](mailto:hello@example.com)'));
    for (final secret in [
      'SECRET_',
      'javascript:',
      'file:',
      'qp:',
      'password',
      'evil()',
    ]) {
      expect(note.content, isNot(contains(secret)));
    }
  });

  test('browser metadata cannot inject additional YAML properties', () {
    final request = capture()
      ..['title'] = 'Title "quote" \\ path\njournal: true'
      ..['author'] = 'Author"\ntags: [injected]';
    final note = db.getNoteByIdOrPrefix(host.handle(request)['id'] as String)!;
    expect(note.journalDate, isNull);
    expect(note.content, contains('title: ${jsonEncode(request['title'])}'));
    expect(note.content, contains('author: ${jsonEncode(request['author'])}'));
    expect(note.content, isNot(contains('\njournal: true')));
    expect(note.tags, isNot(contains('injected')));
  });

  test('rejects unsupported messages before opening a database', () {
    final guarded = CliBrowserHost(() => throw StateError('Must not open DB'));
    expect(guarded.handle({'version': 1, 'action': 'ping'})['ok'], true);
    for (final request in [
      null,
      {'version': 2, 'action': 'clip'},
      capture()..['action'] = 'exec',
      capture()..['url'] = 'file:///etc/passwd',
      capture()..['url'] = 'https://user:password@example.com',
      capture()..['html'] = ' ',
      capture()..['html'] = '<script>nothing readable</script>',
      capture()..['title'] = 42,
      capture()..['tags'] = ['bad\ntag'],
      capture()..['tags'] = ['invalid tag'],
      capture()..['tags'] = [42],
    ]) {
      expect(() => guarded.handle(request), throwsFormatException);
    }
  });

  Future<(int, List<Map<String, dynamic>>)> serve(
    List<List<int>> chunks,
  ) async {
    final output = StreamController<List<int>>();
    final collected = output.stream.expand((bytes) => bytes).toList();
    final code = await host.serve(Stream.fromIterable(chunks), output.sink);
    await output.close();
    final bytes = Uint8List.fromList(await collected);
    final responses = <Map<String, dynamic>>[];
    var offset = 0;
    while (offset < bytes.length) {
      final length = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0, Endian.host);
      offset += 4;
      responses.add(
        jsonDecode(utf8.decode(bytes.sublist(offset, offset + length)))
            as Map<String, dynamic>,
      );
      offset += length;
    }
    return (code, responses);
  }

  test(
    'frames split across byte boundaries and multiple messages retain Unicode',
    () async {
      final request = capture()..['title'] = 'বাংলা · café ☕';
      final bytes = [
        ...CliBrowserHost.encode({'version': 1, 'action': 'ping'}),
        ...CliBrowserHost.encode(request),
      ];
      final (code, responses) = await serve(bytes.map((b) => [b]).toList());
      expect(code, 0);
      expect(responses, hasLength(2));
      expect(responses.last['title'], 'বাংলা · café ☕');
      expect(db.listNotes(), hasLength(1));
    },
  );

  test(
    'malformed JSON responds with error, next framed request still succeeds',
    () async {
      final bytes = [
        ...((ByteData(4)..setUint32(0, 1, Endian.host)).buffer.asUint8List()),
        ...utf8.encode('{'),
        ...CliBrowserHost.encode(capture()),
      ];
      final (code, responses) = await serve([bytes]);
      expect(code, 0);
      expect(responses.first['ok'], false);
      expect(responses.last['ok'], true);
    },
  );

  test(
    'truncated frames and oversized lengths fail without partial notes',
    () async {
      for (final chunks in [
        [
          [1, 0],
        ],
        [
          [5, 0, 0, 0, 123],
        ],
        [
          ((ByteData(4)
                ..setUint32(0, CliBrowserHost.maxMessageBytes + 1, Endian.host))
              .buffer
              .asUint8List()),
        ],
        [
          [0, 0, 0, 0],
        ],
      ]) {
        final (code, responses) = await serve(chunks);
        expect(code, 65);
        expect(responses.single['ok'], false);
      }
      expect(db.listNotes(), isEmpty);
    },
  );
}
