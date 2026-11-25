import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';

enum NotesCommand {
  newNote('New Note', 'Start with a blank page', PhosphorIconsRegular.plus),
  newFromTemplate(
    'New from Template',
    'Choose a reusable starting point',
    PhosphorIconsRegular.files,
  ),
  importEmail(
    'Import Email',
    'Choose .eml files • Ctrl+Shift+I',
    Icons.mail_outline,
  ),
  importEmailAllFiles(
    'Import Email from all files',
    'For messages with a generic type or missing extension',
    Icons.mail_outline,
  );

  const NotesCommand(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

/// A result is returned before its action runs, so dialogs never stack inside
/// the palette and keyboard dismissal restores the workspace focus.
class CommandPaletteEntry {
  const CommandPaletteEntry({
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    this.keywords = '',
  });
  final String label;
  final String description;
  final IconData icon;
  final Object value;
  final String keywords;

  bool matches(String query) {
    final text = '$label $description $keywords'.toLowerCase();
    return query.split(RegExp(r'\s+')).every(text.contains);
  }
}

Future<NotesCommand?> showNotesCommandPalette(
  BuildContext context, {
  List<NotesCommand> commands = NotesCommand.values,
}) async =>
    (await showCommandPalette(
          context,
          entries: [
            for (final command in commands)
              CommandPaletteEntry(
                label: command.label,
                description: command.description,
                icon: command.icon,
                value: command,
              ),
          ],
        ))?.value
        as NotesCommand?;

Future<CommandPaletteEntry?> showCommandPalette(
  BuildContext context, {
  required List<CommandPaletteEntry> entries,
  Future<List<CommandPaletteEntry>> Function(String)? search,
}) => QuietAdaptiveModal.show<CommandPaletteEntry>(
  context: context,
  type: AdaptiveModalType.spotlight,
  builder: (_) => _NotesCommandPalette(entries: entries, search: search),
);

class _NotesCommandPalette extends StatefulWidget {
  const _NotesCommandPalette({required this.entries, this.search});
  final List<CommandPaletteEntry> entries;
  final Future<List<CommandPaletteEntry>> Function(String)? search;
  @override
  State<_NotesCommandPalette> createState() => _NotesCommandPaletteState();
}

class _NotesCommandPaletteState extends State<_NotesCommandPalette> {
  String _query = '';
  List<CommandPaletteEntry> _results = [];
  Timer? _debounce;
  int _generation = 0;
  int _selected = 0;
  bool _loading = false;
  bool _failed = false;
  final _scroll = ScrollController();
  final _rowKeys = <Object, GlobalKey>{};

  List<CommandPaletteEntry> get _commands => [
    ...widget.entries.where((entry) => entry.matches(_query)),
    ..._results,
  ];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    _query = value.trim().toLowerCase();
    _selected = 0;
    _results = [];
    _rowKeys.clear();
    _failed = false;
    _loading = widget.search != null;
    if (widget.search == null) return;
    _debounce = Timer(const Duration(milliseconds: 160), () async {
      try {
        final results = await widget.search!(_query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = results;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    });
  }

  void _move(int delta) {
    final commands = _commands;
    if (commands.isEmpty) return;
    setState(() => _selected = (_selected + delta) % commands.length);
    final selectedValue = commands[_selected].value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _rowKeys[selectedValue]?.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  void _activate() {
    final commands = _commands;
    if (commands.isNotEmpty) Navigator.pop(context, commands[_selected]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final commands = _commands;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _activate,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _activate,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Material(
          color: colors.surface,
          borderRadius: AppRadii.borderLg,
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  0,
                  media.size.height -
                      media.viewInsets.bottom -
                      media.padding.vertical -
                      32,
                ),
              ),
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Command Palette',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close commands',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            PhosphorIconsRegular.x,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      autofocus: true,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                      cursorColor: colors.accent,
                      textInputAction: TextInputAction.go,
                      decoration: InputDecoration(
                        hintText: 'Search commands',
                        hintStyle: AppTypography.body.copyWith(
                          color: colors.textTertiary,
                        ),
                        prefixIcon: Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                        filled: true,
                        fillColor: colors.surfaceSubtle,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadii.borderMd,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadii.borderMd,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadii.borderMd,
                          borderSide: BorderSide(
                            color: colors.accent,
                            width: 1,
                          ),
                        ),
                      ),
                      onChanged: (value) => setState(() {
                        _search(value);
                      }),
                      onSubmitted: (_) => _activate(),
                    ),
                    const SizedBox(height: 8),
                    if (_loading) const LinearProgressIndicator(),
                    if (_failed)
                      const Text(
                        'Could not search notes and tags. Type to retry.',
                      ),
                    if (commands.isEmpty && !_loading)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No commands found',
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    for (final (index, command) in commands.indexed)
                      ListTile(
                        key: _rowKeys.putIfAbsent(
                          command.value,
                          () => GlobalKey(),
                        ),
                        selected: index == _selected,
                        selectedTileColor: colors.surfaceSubtle,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: Icon(
                          command.icon,
                          size: 22,
                          color: colors.textSecondary,
                        ),
                        title: Text(
                          command.label,
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          command.description,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, command),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
