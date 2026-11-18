import 'dart:math' as math;
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
  );

  const NotesCommand(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

/// Both touch and keyboard entry points return to the notes screen's existing
/// creation handlers, so opening or dismissing the palette never creates a note.
Future<NotesCommand?> showNotesCommandPalette(BuildContext context) =>
    QuietAdaptiveModal.show<NotesCommand>(
      context: context,
      type: AdaptiveModalType.spotlight,
      builder: (_) => const _NotesCommandPalette(),
    );

class _NotesCommandPalette extends StatefulWidget {
  const _NotesCommandPalette();
  @override
  State<_NotesCommandPalette> createState() => _NotesCommandPaletteState();
}

class _NotesCommandPaletteState extends State<_NotesCommandPalette> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final commands = NotesCommand.values
        .where((command) => command.label.toLowerCase().contains(_query))
        .toList();
    return Padding(
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
                        borderSide: BorderSide(color: colors.accent, width: 1),
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      _query = value.trim().toLowerCase();
                    }),
                    onSubmitted: (_) {
                      if (commands.isNotEmpty) {
                        Navigator.pop(context, commands.first);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (commands.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No commands found',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  for (final command in commands)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
    );
  }
}
