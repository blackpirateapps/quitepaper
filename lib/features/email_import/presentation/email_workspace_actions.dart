import 'dart:convert';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../notes/presentation/widgets/notes_command_palette.dart';
import '../application/email_import_gateway.dart';
import '../application/email_input.dart';
import 'email_import_launcher.dart';

class EmailDesktopRouter {
  static Future<bool>? _classification;
  static String? _pathKey;
  static List<String> paths(DropDoneDetails detail) {
    final result = <String>{
      ...detail.files.map((f) => f.path).where((p) => p.isNotEmpty),
    };
    for (final line in const LineSplitter().convert(detail.rawText ?? '')) {
      final path = line.trim();
      if (path.startsWith('file:')) {
        try {
          result.add(Uri.parse(path).toFilePath());
        } catch (_) {}
      } else if (path.startsWith('/')) {
        result.add(path);
      }
    }
    return result.toList();
  }

  /// Returns true for an email-containing mixed batch. Other drops retain their
  /// original handlers. A synchronous gate coalesces nested desktop drop targets.
  static Future<bool> route(BuildContext context, List<String> paths) async {
    if (paths.isEmpty) return false;
    final key = paths.join('\u0000');
    if (_classification != null && _pathKey == key) return _classification!;
    if (EmailImportLauncher.isActive) return true;
    final inputs = paths.map((path) => EmailInput(path: path)).toList();
    Future<bool> classify() async {
      for (final input in inputs) {
        if (await input.isEmailCandidate()) return true;
      }
      return false;
    }

    final classification = classify();
    _classification = classification;
    _pathKey = key;
    try {
      final candidate = await classification;
      if (!candidate) return false;
      if (context.mounted) {
        await EmailImportLauncher.open(
          context,
          EmailImportRequest(inputs: inputs),
        );
      }
      return true;
    } finally {
      if (identical(_classification, classification)) {
        _classification = null;
        _pathKey = null;
      }
    }
  }
}

/// Existing desktop_drop cannot expose filenames during hover. No email overlay
/// is shown until the drop can be classified; ordinary text drags remain untouched.
class EmailWorkspaceActions extends StatelessWidget {
  const EmailWorkspaceActions({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  BuildContext? get _context => navigatorKey.currentState?.overlay?.context;
  Future<void> _palette() async {
    final context = _context;
    if (context == null || EmailImportLauncher.isActive) return;
    final command = await showNotesCommandPalette(
      context,
      commands: const [
        NotesCommand.importEmail,
        NotesCommand.importEmailAllFiles,
      ],
    );
    if (context.mounted && command != null) {
      await EmailImportLauncher.pick(
        context,
        allFiles: command == NotesCommand.importEmailAllFiles,
      );
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(
        LogicalKeyboardKey.keyP,
        control: true,
        shift: true,
      ): _palette,
      const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true):
          _palette,
      const SingleActivator(
        LogicalKeyboardKey.keyI,
        control: true,
        shift: true,
      ): () {
        final ctx = _context;
        if (ctx != null) EmailImportLauncher.pick(ctx);
      },
    },
    child: DropTarget(
      onDragDone: (detail) {
        final ctx = _context;
        if (ctx != null) {
          EmailDesktopRouter.route(ctx, EmailDesktopRouter.paths(detail));
        }
      },
      child: child,
    ),
  );
}
