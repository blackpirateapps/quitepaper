import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import '../../storage/app_storage_path_resolver.dart';

LazyDatabase openConnection({String dbName = 'quiet_paper.sqlite'}) {
  return LazyDatabase(() async {
    final dbFolder = await AppStoragePathResolver.getDataDirectory();
    final file = File(p.join(dbFolder.path, dbName));
    return NativeDatabase.createInBackground(file);
  });
}

QueryExecutor openInMemoryConnection() {
  return NativeDatabase.memory();
}
