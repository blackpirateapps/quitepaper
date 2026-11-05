import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/core/sharing/quiet_paper_linux_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class MockProcessRunner implements ProcessRunner {
  final List<List<String>> executedCommands = [];
  int Function(String executable, List<String> arguments)? exitCodeProvider;
  bool shouldThrow = false;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    executedCommands.add([executable, ...arguments]);
    if (shouldThrow) {
      throw const ProcessException('mock', ['error']);
    }
    final code = exitCodeProvider != null ? exitCodeProvider!(executable, arguments) : 0;
    return ProcessResult(1234, code, 'mock stdout', 'mock stderr');
  }
}

void main() {
  late Directory tempDir;
  late MockProcessRunner runner;
  String? lastLaunchedUrl;
  bool launchSuccess = true;
  late QuietPaperLinuxSharePlugin plugin;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('quitepaper_share_test_');
    runner = MockProcessRunner();
    lastLaunchedUrl = null;
    launchSuccess = true;
    plugin = QuietPaperLinuxSharePlugin(
      processRunner: runner,
      uriLauncher: (uri) async {
        lastLaunchedUrl = uri.toString();
        return launchSuccess;
      },
      tempDirectory: tempDir,
    );
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('QuietPaperLinuxSharePlugin - shareXFiles validation', () {
    test('throws ArgumentError on empty files list', () async {
      expect(
        () => plugin.shareXFiles([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on fileNameOverrides length mismatch', () async {
      final file = File(p.join(tempDir.path, 'sample.txt'))..writeAsStringSync('hello');
      expect(
        () => plugin.shareXFiles(
          [XFile(file.path)],
          fileNameOverrides: ['one.txt', 'two.txt'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('QuietPaperLinuxSharePlugin - single file sharing', () {
    test('Tier 1: invokes XDG Desktop Portal OpenURI with ask: true', () async {
      final testFile = File(p.join(tempDir.path, 'doc.pdf'))..writeAsStringSync('pdf data');
      final result = await plugin.shareXFiles([XFile(testFile.path)]);

      expect(result.status, ShareResultStatus.success);
      expect(runner.executedCommands.length, 1);
      final cmd = runner.executedCommands.first;
      expect(cmd[0], 'gdbus');
      expect(cmd, contains('org.freedesktop.portal.Desktop'));
      expect(cmd, contains('org.freedesktop.portal.OpenURI.OpenURI'));
      expect(cmd, contains('{"ask": <true>}'));
      expect(cmd, contains(Uri.file(testFile.path).toString()));
    });

    test('Tier 2: falls back to gio open when portal returns non-zero', () async {
      final testFile = File(p.join(tempDir.path, 'note.md'))..writeAsStringSync('# Title');
      runner.exitCodeProvider = (exe, args) {
        if (exe == 'gdbus') return 1; // Portal fails
        if (exe == 'gio') return 0;   // gio succeeds
        return 1;
      };

      final result = await plugin.shareXFiles([XFile(testFile.path)]);
      expect(result.status, ShareResultStatus.success);
      expect(runner.executedCommands.length, 2);
      expect(runner.executedCommands[0][0], 'gdbus');
      expect(runner.executedCommands[1], ['gio', 'open', testFile.path]);
    });

    test('Tier 3: falls back to xdg-open when portal and gio fail', () async {
      final testFile = File(p.join(tempDir.path, 'image.png'))..writeAsStringSync('png data');
      runner.exitCodeProvider = (exe, args) {
        if (exe == 'gdbus') return 1;
        if (exe == 'gio') return 1;
        if (exe == 'xdg-open') return 0; // xdg-open succeeds
        return 1;
      };

      final result = await plugin.shareXFiles([XFile(testFile.path)]);
      expect(result.status, ShareResultStatus.success);
      expect(runner.executedCommands.length, 3);
      expect(runner.executedCommands[2], ['xdg-open', testFile.path]);
    });

    test('Tier 4: falls back to xdg-email when subject or text provided', () async {
      final testFile = File(p.join(tempDir.path, 'data.csv'))..writeAsStringSync('a,b,c');
      runner.exitCodeProvider = (exe, args) {
        if (exe == 'gdbus' || exe == 'gio' || exe == 'xdg-open') return 1;
        if (exe == 'xdg-email') return 0;
        return 1;
      };

      final result = await plugin.shareXFiles(
        [XFile(testFile.path)],
        subject: 'Monthly Data',
        text: 'Please find attached the CSV.',
      );
      expect(result.status, ShareResultStatus.success);
      final emailCmd = runner.executedCommands.firstWhere((cmd) => cmd[0] == 'xdg-email');
      expect(emailCmd, contains('--attach'));
      expect(emailCmd, contains(testFile.path));
      expect(emailCmd, contains('--subject'));
      expect(emailCmd, contains('Monthly Data'));
      expect(emailCmd, contains('--body'));
      expect(emailCmd, contains('Please find attached the CSV.'));
    });

    test('Tier 5: reveals in file manager ShowItems when openers fail', () async {
      final testFile = File(p.join(tempDir.path, 'archive.zip'))..writeAsStringSync('zip data');
      runner.exitCodeProvider = (exe, args) {
        if (exe == 'gdbus' && args.contains('org.freedesktop.FileManager1')) {
          return 0; // ShowItems succeeds
        }
        return 1;
      };

      final result = await plugin.shareXFiles([XFile(testFile.path)]);
      expect(result.status, ShareResultStatus.success);
      final showItemsCmd = runner.executedCommands.firstWhere(
        (cmd) => cmd[0] == 'gdbus' && cmd.contains('org.freedesktop.FileManager1'),
      );
      expect(showItemsCmd, contains('org.freedesktop.FileManager1.ShowItems'));
    });

    test('returns unavailable when all execution tiers fail or throw', () async {
      final testFile = File(p.join(tempDir.path, 'file.bin'))..writeAsStringSync('binary');
      runner.shouldThrow = true;

      final result = await plugin.shareXFiles([XFile(testFile.path)]);
      expect(result.status, ShareResultStatus.unavailable);
    });
  });

  group('QuietPaperLinuxSharePlugin - multiple files sharing', () {
    test('reveals multiple files via FileManager1 ShowItems by default', () async {
      final file1 = File(p.join(tempDir.path, 'doc1.pdf'))..writeAsStringSync('doc 1');
      final file2 = File(p.join(tempDir.path, 'doc2.pdf'))..writeAsStringSync('doc 2');

      final result = await plugin.shareXFiles([XFile(file1.path), XFile(file2.path)]);
      expect(result.status, ShareResultStatus.success);

      expect(runner.executedCommands.length, 1);
      final cmd = runner.executedCommands.first;
      expect(cmd[0], 'gdbus');
      expect(cmd, contains('org.freedesktop.FileManager1'));
      expect(cmd, contains('org.freedesktop.FileManager1.ShowItems'));
      expect(cmd.any((arg) => arg.contains(Uri.file(file1.path).toString())), isTrue);
      expect(cmd.any((arg) => arg.contains(Uri.file(file2.path).toString())), isTrue);
    });

    test('falls back to Portal OpenURI for each file if FileManager1 fails', () async {
      final file1 = File(p.join(tempDir.path, 'img1.png'))..writeAsStringSync('img 1');
      final file2 = File(p.join(tempDir.path, 'img2.png'))..writeAsStringSync('img 2');

      runner.exitCodeProvider = (exe, args) {
        if (args.contains('org.freedesktop.FileManager1')) return 1;
        if (args.contains('org.freedesktop.portal.OpenURI.OpenURI')) return 0;
        return 1;
      };

      final result = await plugin.shareXFiles([XFile(file1.path), XFile(file2.path)]);
      expect(result.status, ShareResultStatus.success);

      final portalCalls = runner.executedCommands
          .where((cmd) => cmd.contains('org.freedesktop.portal.OpenURI.OpenURI'))
          .toList();
      expect(portalCalls.length, 2);
    });
  });

  group('QuietPaperLinuxSharePlugin - in-memory XFile and fileNameOverrides', () {
    test('writes in-memory XFile.fromData bytes to disk using fileNameOverrides', () async {
      final bytes = [10, 20, 30, 40];
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
      );

      final result = await plugin.shareXFiles(
        [xFile],
        fileNameOverrides: ['memory_export.txt'],
      );
      expect(result.status, ShareResultStatus.success);

      final targetFile = File(p.join(tempDir.path, 'memory_export.txt'));
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.readAsBytesSync(), bytes);
    });

    test('writes in-memory XFile.fromData with generated fallback name when no override provided', () async {
      final bytes = [50, 60, 70];
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
      );

      final result = await plugin.shareXFiles([xFile]);
      expect(result.status, ShareResultStatus.success);

      final filesInTemp = tempDir.listSync().whereType<File>().toList();
      expect(filesInTemp.isNotEmpty, isTrue);
      final created = filesInTemp.firstWhere((f) => p.basename(f.path).startsWith('shared_file_'));
      expect(created.readAsBytesSync(), bytes);
    });

    test('applies fileNameOverrides to existing file', () async {
      final original = File(p.join(tempDir.path, 'original.txt'))..writeAsStringSync('some text');
      final xFile = XFile(original.path);

      final result = await plugin.shareXFiles(
        [xFile],
        fileNameOverrides: ['renamed_export.txt'],
      );
      expect(result.status, ShareResultStatus.success);

      final renamedFile = File(p.join(tempDir.path, 'renamed_export.txt'));
      expect(renamedFile.existsSync(), isTrue);
      expect(renamedFile.readAsStringSync(), 'some text');
    });
  });

  group('QuietPaperLinuxSharePlugin - share and shareUri', () {
    test('shareUri opens URI via Portal OpenURI', () async {
      final uri = Uri.parse('https://quietpaper.com/docs');
      final result = await plugin.shareUri(uri);

      expect(result.status, ShareResultStatus.success);
      expect(runner.executedCommands.length, 1);
      final cmd = runner.executedCommands.first;
      expect(cmd, contains('org.freedesktop.portal.OpenURI.OpenURI'));
      expect(cmd, contains('https://quietpaper.com/docs'));
    });

    test('share with HTTP URL opens via Portal OpenURI', () async {
      final result = await plugin.share('https://notes.quietpaper.com/share/abc');
      expect(result.status, ShareResultStatus.success);
      final cmd = runner.executedCommands.first;
      expect(cmd, contains('org.freedesktop.portal.OpenURI.OpenURI'));
      expect(cmd, contains('https://notes.quietpaper.com/share/abc'));
    });

    test('share with text and subject uses xdg-email when available', () async {
      final result = await plugin.share(
        'Check out this note content',
        subject: 'My Note',
      );
      expect(result.status, ShareResultStatus.success);
      final cmd = runner.executedCommands.firstWhere((c) => c[0] == 'xdg-email');
      expect(cmd, contains('--subject'));
      expect(cmd, contains('My Note'));
      expect(cmd, contains('--body'));
      expect(cmd, contains('Check out this note content'));
    });

    test('share falls back to UrlLauncher mailto: when xdg-email fails', () async {
      runner.shouldThrow = true;
      final result = await plugin.share(
        'Fallback text',
        subject: 'Fallback Subject',
      );
      expect(result.status, ShareResultStatus.success);
      expect(lastLaunchedUrl, startsWith('mailto:?'));
      expect(lastLaunchedUrl, contains('Fallback%20Subject'));
      expect(lastLaunchedUrl, contains('Fallback%20text'));
    });
  });

  group('QuietPaperLinuxSharePlugin - Registration & Share.shareXFiles integration', () {
    test('registers successfully and executes Share.shareXFiles without UnimplementedError', () async {
      QuietPaperLinuxSharePlugin.register(
        processRunner: runner,
        uriLauncher: (uri) async {
          lastLaunchedUrl = uri.toString();
          return true;
        },
        tempDirectory: tempDir,
      );

      expect(SharePlatform.instance, isA<QuietPaperLinuxSharePlugin>());

      final testFile = File(p.join(tempDir.path, 'integration.txt'))..writeAsStringSync('ready');
      final res = await Share.shareXFiles([XFile(testFile.path)], subject: 'Integration');

      expect(res.status, ShareResultStatus.success);
      expect(runner.executedCommands.isNotEmpty, isTrue);
    });
  });
}
