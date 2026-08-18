import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';

class NoteEmptyState extends StatelessWidget {
  const NoteEmptyState({
    super.key,
    required this.onCreateNote,
    this.tagFilter,
  });

  final VoidCallback onCreateNote;
  final String? tagFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final title = tagFilter != null ? 'No notes with #$tagFilter' : 'No notes yet';
    final subtitle = tagFilter != null
        ? 'Try selecting a different tag or write a new note.'
        : 'Start writing something.';

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
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            QuietButton(
              label: 'Create note',
              icon: Icons.edit_note_rounded,
              variant: QuietButtonVariant.primary,
              onPressed: onCreateNote,
            ),
          ],
        ),
      ),
    );
  }
}
