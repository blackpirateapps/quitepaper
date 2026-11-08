import 'dart:convert';
import 'dart:io';
import 'cli_database.dart';

/// Interactive note selector using `fzf` (if installed) or a numbered terminal prompt fallback.
class InteractivePicker {
  const InteractivePicker();

  /// Prompts user to pick a note from the provided candidate list.
  ///
  /// Returns the chosen [CliNote], or `null` if the user cancelled.
  Future<CliNote?> pickNote(List<CliNote> notes, {String promptTitle = 'Select a note'}) async {
    if (notes.isEmpty) {
      stdout.writeln('No notes found in vault.');
      return null;
    }

    if (notes.length == 1) {
      return notes.first;
    }

    if (_hasFzf()) {
      return _pickWithFzf(notes, promptTitle: promptTitle);
    }

    return _pickWithNumberedPrompt(notes, promptTitle: promptTitle);
  }

  bool _hasFzf() {
    try {
      final res = Process.runSync('which', ['fzf']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<CliNote?> _pickWithFzf(List<CliNote> notes, {required String promptTitle}) async {
    final noteMap = <String, CliNote>{};
    final lines = <String>[];

    for (final note in notes) {
      final key = note.shortId;
      noteMap[key] = note;
      final tagsStr = note.tags.isNotEmpty ? ' #${note.tags.join(' #')}' : '';
      final pin = note.isPinned ? '📌 ' : '   ';
      lines.add('[$key] $pin${note.displayTitle}$tagsStr');
    }

    try {
      final process = await Process.start(
        'fzf',
        [
          '--ansi',
          '--reverse',
          '--header=$promptTitle (ESC or Ctrl+C to cancel)',
          '--prompt=Note > ',
        ],
        mode: ProcessStartMode.normal,
      );

      process.stdin.writeln(lines.join('\n'));
      await process.stdin.close();

      final output = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode != 0 || output.trim().isEmpty) {
        return null;
      }

      final match = RegExp(r'^\[([a-f0-9]+)\]').firstMatch(output.trim());
      if (match != null) {
        final shortId = match.group(1);
        return noteMap[shortId];
      }
    } catch (_) {}

    return _pickWithNumberedPrompt(notes, promptTitle: promptTitle);
  }

  CliNote? _pickWithNumberedPrompt(List<CliNote> notes, {required String promptTitle}) {
    stdout.writeln();
    stdout.writeln('=== $promptTitle ===');
    final displayCount = notes.length > 20 ? 20 : notes.length;

    for (int i = 0; i < displayCount; i++) {
      final n = notes[i];
      final pin = n.isPinned ? '📌 ' : '';
      final tagsStr = n.tags.isNotEmpty ? ' #${n.tags.join(' #')}' : '';
      final numStr = (i + 1).toString().padLeft(2);
      stdout.writeln('  $numStr) [${n.shortId}] $pin${n.displayTitle}$tagsStr');
    }

    if (notes.length > displayCount) {
      stdout.writeln('  ... and ${notes.length - displayCount} more notes (use "qp list" to view all)');
    }

    stdout.write('\nEnter note number (1-$displayCount) or "q" to cancel: ');
    final input = stdin.readLineSync()?.trim();
    if (input == null || input.toLowerCase() == 'q' || input.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(input);
    if (parsed != null && parsed >= 1 && parsed <= displayCount) {
      return notes[parsed - 1];
    }

    stdout.writeln('Invalid selection.');
    return null;
  }
}
