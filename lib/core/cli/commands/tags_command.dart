import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_database.dart';
import '../cli_formatters.dart';

/// Command to list all tags and note counts.
class TagsCommand extends Command<int> {
  TagsCommand(this._dbProvider) {
    argParser.addFlag('json', negatable: false, help: 'Output tags in JSON format');
  }

  final CliDatabase Function() _dbProvider;

  @override
  String get name => 'tags';

  @override
  List<String> get aliases => const ['t'];

  @override
  String get description => 'List all tags and their associated note counts.';

  @override
  int run() {
    final db = _dbProvider();
    final isJson = argResults?['json'] as bool? ?? false;

    final tags = db.listTags();

    if (isJson) {
      final jsonList = tags.map((t) => t.toJson()).toList();
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(jsonList));
      return 0;
    }

    if (tags.isEmpty) {
      stdout.writeln(CliFormatters.dim('No tags found in vault.'));
      return 0;
    }

    stdout.writeln(CliFormatters.bold('TAG'.padRight(30) + 'NOTES'.padLeft(8)));
    stdout.writeln(CliFormatters.dim('─' * 38));

    for (final tag in tags) {
      final pin = tag.isPinned ? CliFormatters.yellow('📌 ') : '';
      final tagName = CliFormatters.blue('#${tag.name}');
      final count = CliFormatters.dim(tag.noteCount.toString().padLeft(8));
      stdout.writeln('$pin$tagName'.padRight(34) + count);
    }

    stdout.writeln();
    stdout.writeln(CliFormatters.dim('${tags.length} tags total.'));
    return 0;
  }
}
