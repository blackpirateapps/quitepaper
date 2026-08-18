import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../application/notes_provider.dart';

class NoteEmptyState extends StatelessWidget {
  const NoteEmptyState({
    super.key,
    required this.onCreateNote,
    this.destination = AppDestination.allNotes,
    this.tagFilter,
  });

  final VoidCallback onCreateNote;
  final AppDestination destination;
  final String? tagFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    String title;
    String subtitle;
    bool showCreateButton = true;

    if (tagFilter != null && tagFilter!.isNotEmpty) {
      title = 'No notes with #$tagFilter';
      subtitle = 'Start writing something with this tag.';
    } else {
      switch (destination) {
        case AppDestination.allNotes:
          title = 'No notes yet';
          subtitle = 'Start writing something.';
          break;
        case AppDestination.pinned:
          title = 'No pinned notes';
          subtitle = 'Pin notes to keep them close.';
          showCreateButton = false;
          break;
        case AppDestination.archive:
          title = 'Archive is empty';
          subtitle = 'Archived notes will appear here.';
          showCreateButton = false;
          break;
        case AppDestination.trash:
          title = 'Trash is empty';
          subtitle = 'Notes stay here until you delete them\npermanently.';
          showCreateButton = false;
          break;
        case AppDestination.tag:
          title = 'No notes';
          subtitle = 'No notes found.';
          break;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (showCreateButton) ...[
              const SizedBox(height: AppSpacing.xl),
              QuietButton(
                label: 'Create note',
                icon: Icons.edit_note_rounded,
                variant: QuietButtonVariant.primary,
                onPressed: onCreateNote,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
