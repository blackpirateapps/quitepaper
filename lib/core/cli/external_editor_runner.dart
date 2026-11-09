import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'cli_frontmatter.dart';

/// Result from an external editor session.
class EditorResult {
  const EditorResult({
    required this.title,
    required this.content,
    required this.wasModified,
  });

  final String title;
  final String content;
  final bool wasModified;
}

/// Helper that resolves and executes an external terminal editor (e.g. `nvim`, `vim`, `nano`).
class ExternalEditorRunner {
  const ExternalEditorRunner();

  /// Resolves which editor executable to use.
  String resolveEditor([String? explicitEditor]) {
    if (explicitEditor != null && explicitEditor.trim().isNotEmpty) {
      return explicitEditor.trim();
    }
    final qpEditor = Platform.environment['QP_EDITOR'];
    if (qpEditor != null && qpEditor.trim().isNotEmpty) return qpEditor.trim();

    final visual = Platform.environment['VISUAL'];
    if (visual != null && visual.trim().isNotEmpty) return visual.trim();

    final editor = Platform.environment['EDITOR'];
    if (editor != null && editor.trim().isNotEmpty) return editor.trim();

    // Fallbacks
    for (final candidate in ['nvim', 'vim', 'nano', 'vi']) {
      if (_commandExists(candidate)) {
        return candidate;
      }
    }

    return 'nano';
  }

  bool _commandExists(String command) {
    try {
      final res = Process.runSync('which', [command]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Cleans title by removing any leading `title:` marker and trimming outer quotes.
  static String cleanTitle(String rawTitle) {
    var clean = rawTitle.trim();
    if (clean.toLowerCase().startsWith('title:')) {
      clean = clean.substring(6).trim();
    }
    if ((clean.startsWith('"') && clean.endsWith('"')) ||
        (clean.startsWith("'") && clean.endsWith("'"))) {
      if (clean.length >= 2) {
        clean = clean.substring(1, clean.length - 1).trim();
      }
    }
    return clean;
  }

  /// Opens an editor with initial markdown content and returns the updated result.
  ///
  /// Returns `null` if the editor exited without any changes or if the user cleared the file.
  Future<EditorResult?> openInEditor({
    String? initialTitle,
    String? initialContent,
    String? explicitEditor,
    String prefix = 'qp_edit',
  }) async {
    final editor = resolveEditor(explicitEditor);
    final tempDir = Platform.environment['XDG_RUNTIME_DIR'] ?? Directory.systemTemp.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('$tempDir/${prefix}_$timestamp.md');

    // Build initial file text
    final StringBuffer sb = StringBuffer();
    final hasContent = initialContent != null && initialContent.trim().isNotEmpty;
    final hasTitle = initialTitle != null && initialTitle.trim().isNotEmpty;

    if (hasContent) {
      final trimmedContent = initialContent.trim();
      final startsWithHeading = trimmedContent.startsWith('#');
      final startsWithFrontmatter = trimmedContent.startsWith('---');

      if (startsWithFrontmatter) {
        // If frontmatter is present, check if frontmatter already specifies a title.
        // If it lacks a title key and hasTitle is true, inject title into frontmatter.
        final parsedFm = CliFrontmatter.parse(initialContent);
        if (hasTitle && (parsedFm.title == null || parsedFm.title!.trim().isEmpty)) {
          final updated = CliFrontmatter.updateTitle(
            documentText: initialContent,
            newTitle: cleanTitle(initialTitle),
          );
          sb.write(updated);
        } else {
          sb.write(initialContent);
        }
      } else if (hasTitle && !startsWithHeading) {
        sb.writeln('# ${cleanTitle(initialTitle)}');
        sb.writeln();
        sb.writeln(initialContent);
      } else {
        sb.write(initialContent);
      }
    } else if (hasTitle) {
      sb.writeln('# ${cleanTitle(initialTitle)}');
      sb.writeln();
      sb.writeln('Start writing note content...');
    } else {
      sb.writeln('# Note Title');
      sb.writeln();
      sb.writeln('Start writing note content...');
    }

    final initialText = sb.toString();
    await tempFile.writeAsString(initialText, flush: true);

    // Secure permissions on Unix systems: 0600 (owner read/write only)
    try {
      Process.runSync('chmod', ['600', tempFile.path]);
    } catch (_) {}

    final initialHash = sha256.convert(utf8.encode(initialText)).toString();

    // Parse editor command and arguments (e.g. "code --wait" or "nvim")
    final parts = editor.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) parts.add('nano');
    final exec = parts.first;
    final args = [...parts.sublist(1), tempFile.path];

    try {
      final process = await Process.start(
        exec,
        args,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        stdout.writeln('Editor exited with code $exitCode');
      }

      if (!await tempFile.exists()) {
        return null;
      }

      final editedText = await tempFile.readAsString();
      final editedHash = sha256.convert(utf8.encode(editedText)).toString();

      // Check if unchanged
      if (editedHash == initialHash || editedText.trim().isEmpty) {
        return null;
      }

      // Check if unchanged from the default empty template
      if (!hasContent && !hasTitle && editedText.contains('# Note Title') && editedText.contains('Start writing note content...')) {
        return null;
      }

      // Parse title and content
      final parsed = parseTitleAndContent(editedText, fallbackTitle: initialTitle);

      return EditorResult(
        title: parsed.$1,
        content: parsed.$2,
        wasModified: true,
      );
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Parses title from YAML frontmatter `title:` property, first Markdown H1 heading,
  /// or first non-empty line of content body (skipping YAML frontmatter blocks).
  (String, String) parseTitleAndContent(String rawText, {String? fallbackTitle}) {
    if (rawText.trim().isEmpty) {
      final fb = fallbackTitle != null ? cleanTitle(fallbackTitle) : '';
      return (fb.isNotEmpty ? fb : 'Untitled', rawText);
    }

    final parsedFm = CliFrontmatter.parse(rawText);
    String extractedTitle = '';

    if (parsedFm.hasFrontmatter && parsedFm.title != null && parsedFm.title!.trim().isNotEmpty) {
      extractedTitle = cleanTitle(parsedFm.title!);
    }

    if (extractedTitle.isEmpty) {
      final bodyText = parsedFm.hasFrontmatter ? parsedFm.contentBody : rawText;
      final lines = const LineSplitter().convert(bodyText);

      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('# ')) {
          extractedTitle = trimmed.substring(2).trim();
          break;
        } else if (trimmed.startsWith('#')) {
          extractedTitle = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
          break;
        } else {
          // If the note has a fallback title (e.g. from journal date or existing title),
          // prefer that over an arbitrary plain body sentence.
          if (fallbackTitle != null && fallbackTitle.trim().isNotEmpty) {
            extractedTitle = cleanTitle(fallbackTitle);
          } else {
            extractedTitle = trimmed.length > 80 ? '${trimmed.substring(0, 77)}...' : trimmed;
          }
          break;
        }
      }
    }

    final effectiveTitle = extractedTitle.isNotEmpty
        ? extractedTitle
        : (fallbackTitle != null && fallbackTitle.trim().isNotEmpty
            ? cleanTitle(fallbackTitle)
            : 'Untitled');

    final finalClean = cleanTitle(effectiveTitle);
    return (finalClean.isNotEmpty ? finalClean : 'Untitled', rawText);
  }
}
