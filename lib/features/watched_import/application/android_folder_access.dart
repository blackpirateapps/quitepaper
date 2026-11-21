import 'package:flutter/services.dart';

class AndroidDocument {
  const AndroidDocument({
    required this.id,
    required this.name,
    required this.mime,
    required this.fingerprint,
    this.size,
    this.modified,
    this.partial = false,
    this.virtual = false,
  });
  factory AndroidDocument.fromMap(Map<Object?, Object?> map) => AndroidDocument(
    id: map['id']! as String,
    name: map['name']! as String,
    mime: map['mime']! as String,
    fingerprint: map['fingerprint']! as String,
    size: map['size'] as int?,
    modified: map['modified'] as int?,
    partial: map['partial'] == true,
    virtual: map['virtual'] == true,
  );
  final String id, name, mime, fingerprint;
  final int? size, modified;
  final bool partial, virtual;
  bool get isDirectory => mime == 'vnd.android.document/directory';
}

class AndroidDocumentPage {
  const AndroidDocumentPage(this.documents, this.nextOffset);
  final List<AndroidDocument> documents;
  final int? nextOffset;
}

class AndroidRead {
  const AndroidRead({
    required this.sha256,
    required this.revision,
    required this.fingerprint,
    required this.size,
    this.bytes,
  });
  final String sha256, revision, fingerprint;
  final int size;
  final Uint8List? bytes;
}

abstract class AndroidFolderAccess {
  Future<void> available();
  Future<String?> chooseFolder();
  Future<({String root, String identity, String name})> inspect(String root);
  Future<String> start(String session, String root, String identity);
  Future<void> ready(String session, bool ready);
  Future<AndroidDocumentPage> children(
    String session,
    String parent,
    int offset,
  );
  Future<List<AndroidDocument>> stat(String session, List<String> ids);
  Future<AndroidRead> read(
    String session,
    String id,
    int limit, {
    required bool bytes,
  });
  Future<Uint8List> relatedImage(
    String session,
    List<String> source,
    String target,
  );
  Future<void> stop(String session);
  Future<void> open(String root, [String? documentId]);
}

/// Android owns persisted SAF grants and bounded provider I/O on worker threads.
class MethodChannelAndroidFolderAccess implements AndroidFolderAccess {
  const MethodChannelAndroidFolderAccess();
  static const channel = MethodChannel(
    'com.blackpiratex.quietpaper/watched_folders',
  );
  @override
  Future<void> available() => channel.invokeMethod<void>('available');
  @override
  Future<String?> chooseFolder() =>
      channel.invokeMethod<String>('chooseFolder');
  @override
  Future<({String root, String identity, String name})> inspect(
    String root,
  ) async {
    final map = (await channel.invokeMapMethod<String, Object?>('inspect', {
      'root': root,
    }))!;
    return (
      root: map['root']! as String,
      identity: map['identity']! as String,
      name: map['name'] as String? ?? 'Selected folder',
    );
  }

  @override
  Future<String> start(String session, String root, String identity) async =>
      (await channel.invokeMethod<String>('start', {
        'session': session,
        'root': root,
        'identity': identity,
      }))!;
  @override
  Future<void> ready(String session, bool ready) =>
      channel.invokeMethod<void>('ready', {'session': session, 'ready': ready});
  @override
  Future<AndroidDocumentPage> children(
    String session,
    String parent,
    int offset,
  ) async {
    final map = (await channel.invokeMapMethod<String, Object?>('children', {
      'session': session,
      'parent': parent,
      'offset': offset,
    }))!;
    return AndroidDocumentPage(
      (map['documents']! as List)
          .map(
            (e) => AndroidDocument.fromMap((e as Map).cast<Object?, Object?>()),
          )
          .toList(),
      map['nextOffset'] as int?,
    );
  }

  @override
  Future<List<AndroidDocument>> stat(String session, List<String> ids) async =>
      (await channel.invokeListMethod<Map<Object?, Object?>>('stat', {
        'session': session,
        'ids': ids,
      }))!.map(AndroidDocument.fromMap).toList();
  @override
  Future<AndroidRead> read(
    String session,
    String id,
    int limit, {
    required bool bytes,
  }) async {
    final map = (await channel.invokeMapMethod<String, Object?>('read', {
      'session': session,
      'id': id,
      'limit': limit,
      'bytes': bytes,
    }))!;
    return AndroidRead(
      sha256: map['sha256']! as String,
      revision: map['revision']! as String,
      fingerprint: map['fingerprint']! as String,
      size: map['size']! as int,
      bytes: map['bytes'] as Uint8List?,
    );
  }

  @override
  Future<Uint8List> relatedImage(
    String session,
    List<String> source,
    String target,
  ) async => (await channel.invokeMethod<Uint8List>('relatedImage', {
    'session': session,
    'source': source,
    'target': target,
  }))!;
  @override
  Future<void> stop(String session) =>
      channel.invokeMethod<void>('stop', {'session': session});
  @override
  Future<void> open(String root, [String? documentId]) =>
      channel.invokeMethod<void>('open', {'root': root, 'id': documentId});
}
