import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/web_clipper/article_extractor.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final binary = Platform.environment['QP_RUST_CLI_BIN'];

  test('native browser clips save into the current desktop schema', () async {
    final root = Directory.systemTemp.createTempSync('qp_browser_schema_');
    addTearDown(() => root.deleteSync(recursive: true));
    final path = '${root.path}/notebook.sqlite';
    final desktop = AppDatabase(NativeDatabase(File(path)));
    await desktop.customSelect('SELECT COUNT(*) FROM notes').get();
    await desktop.close();
    const url =
        'https://www.thehindu.com/news/article71735766.ece?cx_testId=15#cxrecs_s';
    final fixture = File(
      'test/fixtures/web_clipper/hindu_article.html',
    ).readAsStringSync();
    final article = const ArticleExtractor().extractFromHtml(fixture, url);
    final process = await Process.start(binary!, [
      '--db',
      path,
      'browser-host',
    ]);
    final output = process.stdout.expand((bytes) => bytes).toList();
    final errors = process.stderr.transform(utf8.decoder).join();
    void send(Map<String, Object?> value) {
      final bytes = utf8.encode(jsonEncode(value));
      final header = ByteData(4)..setUint32(0, bytes.length, Endian.host);
      process.stdin.add([...header.buffer.asUint8List(), ...bytes]);
    }

    send({'version': 1, 'action': 'ping'});
    send({
      'version': 1,
      'action': 'clip',
      'url': url,
      'title': 'বাংলা · café ☕',
      'author': 'Test Reporter',
      'tags': ['research'],
      'html': article.cleanedElement.outerHtml,
    });
    await process.stdin.close();
    expect(await process.exitCode, 0, reason: await errors);
    final bytes = Uint8List.fromList(await output);
    final replies = <Map<String, dynamic>>[];
    var offset = 0;
    while (offset < bytes.length) {
      final length = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0, Endian.host);
      offset += 4;
      replies.add(
        jsonDecode(utf8.decode(bytes.sublist(offset, offset + length)))
            as Map<String, dynamic>,
      );
      offset += length;
    }
    expect(replies, hasLength(2));
    expect(replies.first['ok'], true);
    expect(replies.last['ok'], true);
    final db = sqlite3.open(path);
    addTearDown(db.close);
    final id = replies.last['id'] as String;
    final row = db.select(
      'SELECT title, content, is_dirty, journal_date FROM notes WHERE id=?',
      [id],
    ).single;
    expect(row['title'], 'বাংলা · café ☕');
    expect(row['is_dirty'], 1);
    expect(row['journal_date'], isNull);
    final content = (row['content'] as String).replaceAll(r'\_', '_');
    expect(content, contains('FINAL_ARTICLE_PARAGRAPH'));
    expect(content, contains('Constable denies the allegation'));
    expect(content, contains('Most Popular is also a phrase'));
    expect(content, isNot(contains('_NOISE')));
    expect(content, contains('https://www.thehindu.com/article-photo.jpg'));
    expect(content, contains(url));
    for (final table in [
      'sync_queue',
      'note_versions',
      'note_search_prefix',
      'note_search_trigram',
    ]) {
      expect(
        db.select('SELECT COUNT(*) AS n FROM $table WHERE note_id=?', [
          id,
        ]).single['n'],
        1,
      );
    }
    expect(
      db
          .select(
            'SELECT t.name FROM tags t JOIN note_tags nt ON t.id=nt.tag_id WHERE nt.note_id=? ORDER BY t.name',
            [id],
          )
          .map((r) => r['name']),
      ['clipped', 'research', 'web/thehindu-com'],
    );
  }, skip: binary == null ? 'Set QP_RUST_CLI_BIN to the built Rust CLI.' : false);
}
