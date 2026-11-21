import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/watched_import/application/android_folder_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const access = MethodChannelAndroidFolderAccess();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelAndroidFolderAccess.channel, (
          call,
        ) async {
          calls.add(call);
          return switch (call.method) {
            'chooseFolder' => 'content://provider/tree/opaque%3Aroot',
            'inspect' => {
              'root': 'content://provider/tree/opaque%3Aroot',
              'identity': 'saf:opaque',
            },
            'start' => 'opaque:root',
            'children' => {
              'documents': [
                {
                  'id': 'opaque:file',
                  'name': 'a.txt',
                  'mime': 'text/plain',
                  'fingerprint': 'v1',
                  'size': null,
                },
              ],
              'nextOffset': null,
            },
            'stat' => [
              {
                'id': 'opaque:file',
                'name': 'a.txt',
                'mime': 'text/plain',
                'fingerprint': 'v1',
              },
            ],
            'read' => {
              'sha256': 'hash',
              'revision': 'r',
              'fingerprint': 'v1',
              'size': 2,
              'bytes': call.arguments['bytes'] == true
                  ? Uint8List.fromList([1, 2])
                  : null,
            },
            'relatedImage' => Uint8List.fromList([1]),
            _ => null,
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannelAndroidFolderAccess.channel,
          null,
        );
  });
  test(
    'tree URIs, opaque IDs and nullable metadata survive the platform codec',
    () async {
      final root = await access.chooseFolder();
      expect(root, contains('content://'));
      final info = await access.inspect(root!);
      expect(info.identity, 'saf:opaque');
      expect(await access.start('session', root, info.identity), 'opaque:root');
      final page = await access.children('session', 'opaque:root', 0);
      expect(page.documents.single.id, 'opaque:file');
      expect(page.documents.single.size, isNull);
      expect(
        (await access.stat('session', ['opaque:file'])).single.fingerprint,
        'v1',
      );
      expect(
        (await access.read('session', 'opaque:file', 100, bytes: false)).bytes,
        isNull,
      );
      expect(
        (await access.read('session', 'opaque:file', 100, bytes: true)).bytes,
        [1, 2],
      );
      await access.open(root, 'opaque:file');
      expect(calls.last.arguments, {'root': root, 'id': 'opaque:file'});
      expect(
        calls.where((c) => c.method == 'read').last.arguments['limit'],
        100,
      );
    },
  );
  test('cancelled picker returns no enrollment URI', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannelAndroidFolderAccess.channel,
          (_) async => null,
        );
    expect(await access.chooseFolder(), isNull);
  });
  test('revoked permission codes propagate without returning bytes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelAndroidFolderAccess.channel, (
          _,
        ) async {
          throw PlatformException(code: 'permission_needed');
        });
    await expectLater(
      access.read('session', 'id', 10, bytes: true),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'permission_needed',
        ),
      ),
    );
  });
}
