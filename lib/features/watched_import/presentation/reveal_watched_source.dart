import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../application/android_folder_access.dart';
import 'package:dbus/dbus.dart';
import 'package:drift/drift.dart';
import 'package:url_launcher/url_launcher.dart';

/// URI encoding preserves Linux filename bytes, including non-UTF-8 names.
String watchedSourceUri(String root, Uint8List relative) {
  final base = Uri.directory(root.endsWith('/') ? root : '$root/').toString();
  final path = relative.map((b) {
    if (b == 47 ||
        (b >= 65 && b <= 90) ||
        (b >= 97 && b <= 122) ||
        (b >= 48 && b <= 57) ||
        const [45, 46, 95, 126].contains(b)) {
      return String.fromCharCode(b);
    }
    return '%${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }).join();
  return '$base$path';
}

Future<void> openWatchedFolder(String root) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await const MethodChannelAndroidFolderAccess().open(root);
  } else {
    await launchUrl(Uri.directory(root));
  }
}

Future<void> revealWatchedSource(QueryRow job) async {
  final root = job.read<String>('source_root');
  if (root.isEmpty) return;
  if (defaultTargetPlatform == TargetPlatform.android) {
    await const MethodChannelAndroidFolderAccess().open(
      root,
      utf8.decode(job.read<Uint8List>('source_path')),
    );
    return;
  }
  final uri = watchedSourceUri(root, job.read<Uint8List>('source_path'));
  final client = DBusClient.session();
  try {
    final manager = DBusRemoteObject(
      client,
      name: 'org.freedesktop.FileManager1',
      path: DBusObjectPath('/org/freedesktop/FileManager1'),
    );
    await manager.callMethod('org.freedesktop.FileManager1', 'ShowItems', [
      DBusArray.string([uri]),
      const DBusString(''),
    ], replySignature: DBusSignature(''));
  } on Exception {
    await launchUrl(Uri.directory(root));
  } finally {
    await client.close();
  }
}
