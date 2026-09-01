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
    this.hasActiveFilters = false,
    this.onClearFilters,
  });

  final VoidCallback onCreateNote;
  final AppDestination destination;
  final String? tagFilter;
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    String title;
    String subtitle;
    bool showCreateButton = true;
    bool showClearFiltersButton = false;

    if (hasActiveFilters) {
      title = 'No notes match these filters';
      subtitle = 'Try adjusting or clearing your active filters.';
      showCreateButton = false;
      showClearFiltersButton = true;
    } else if (tagFilter != null && tagFilter!.isNotEmpty) {
      title = '#$tagFilter';
      subtitle = 'No notes use this tag yet.';
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
          subtitle = 'No notes use this tag yet.';
          break;
        case AppDestination.tagBrowser:
          title = 'No tags';
          subtitle = 'Add tags to your notes to organize them here.';
          showCreateButton = false;
          break;
        case AppDestination.allJournalEntries:
          title = 'No journal entries yet.';
          subtitle = 'Write your first entry in Today.';
          showCreateButton = false;
          break;
        case AppDestination.onThisDay:
          title = 'Nothing from this date yet.';
          subtitle = 'Your first entry here will appear next year.';
          showCreateButton = false;
          break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showClearFiltersButton && onClearFilters != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    QuietButton(
                      label: 'Clear filters',
                      icon: Icons.filter_alt_off_rounded,
                      variant: QuietButtonVariant.secondary,
                      onPressed: onClearFilters,
                    ),
                  ] else if (showCreateButton) ...[
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
          ),
        ),
      ),
    );
  }
}
