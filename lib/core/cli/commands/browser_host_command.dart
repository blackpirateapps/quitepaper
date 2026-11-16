import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_browser_host.dart';
import '../cli_database.dart';

class BrowserHostCommand extends Command<int> {
  BrowserHostCommand(this.database);
  final CliDatabase Function() database;

  @override
  String get name => 'browser-host';
  @override
  String get description =>
      'Serve browser web clips over native messaging (Linux).';

  @override
  Future<int> run() async {
    final result = await CliBrowserHost(database).serve(stdin, stdout);
    await stdout.flush();
    return result;
  }
}
