import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../notes/domain/note_model.dart';

class EditorStatsDialog extends StatelessWidget {
  const EditorStatsDialog({
    super.key,
    required this.note,
    this.onOpenVersionHistory,
  });

  final Note note;
  final VoidCallback? onOpenVersionHistory;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Note details',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(
            label: 'Format',
            value: note.isRichText ? 'Rich text' : 'Plain markdown',
          ),
          _StatRow(
            label: 'Words',
            value: '${note.wordCount}',
          ),
          _StatRow(
            label: 'Characters',
            value: '${note.charCount}',
          ),
          _StatRow(
            label: 'Created',
            value: DateFormatter.formatFullDate(note.createdAt),
          ),
          _StatRow(
            label: 'Modified',
            value: DateFormatter.formatFullDate(note.updatedAt),
          ),
          if (note.tags.isNotEmpty) ...[
            _StatRow(
              label: 'Tags',
              value: note.tags.map((t) => '#$t').join(', '),
            ),
          ],
        ],
      ),
      actions: [
        if (onOpenVersionHistory != null)
          QuietButton(
            label: 'Version history',
            icon: Icons.history_rounded,
            variant: QuietButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              onOpenVersionHistory!();
            },
          ),
        QuietButton(
          label: 'Close',
          variant: QuietButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
