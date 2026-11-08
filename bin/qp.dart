import 'dart:io';
import 'package:quitepaper/core/cli/cli_runner.dart';

Future<void> main(List<String> args) async {
  final runner = CliRunner();
  final exitCode = await runner.run(args);
  exit(exitCode);
}
