import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';

void main() {
  test('Rust bootstrap schema matches the current desktop Drift schema', () async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      await database.customSelect('SELECT COUNT(*) FROM notes').get();
      final rows = await database
          .customSelect(
            "SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 ELSE 2 END,name",
          )
          .get();
      final definitions = rows
          .where(
            (r) =>
                !r.read<String>('name').startsWith('note_search_prefix_') &&
                !r.read<String>('name').startsWith('note_search_trigram_'),
          )
          .map(
            (r) =>
                '${r.read<String>('sql').trim().replaceFirst(RegExp(r';\s*$'), '')};',
          )
          .join('\n\n');
      final expected =
          '-- Generated from AppDatabase by test/cli/schema_contract_test.dart.\n'
          '-- Regenerate with QP_EXPORT_CLI_SCHEMA=1 flutter test test/cli/schema_contract_test.dart\n'
          '$definitions\n\nPRAGMA user_version = ${database.schemaVersion};\n';
      final file = File('rust/quietpaper_cli/src/schema.sql');
      if (Platform.environment['QP_EXPORT_CLI_SCHEMA'] == '1') {
        file.writeAsStringSync(expected);
      }
      expect(
        file.readAsStringSync(),
        expected,
        reason:
            'Regenerate the Rust bootstrap schema when the Drift schema changes.',
      );
    } finally {
      await database.close();
    }
  });
}
