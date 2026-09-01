import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/domain/note_model.dart';
import '../application/journal_providers.dart';
import '../../../core/journal/domain/journal_date_helper.dart';

class OnThisDayView extends ConsumerWidget {
  const OnThisDayView({
    super.key,
    this.onNoteSelected,
  });

  /// Optional callback when an entry is selected (used on tablet 3-pane layout)
  final void Function(Note note)? onNoteSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final entriesAsync = ref.watch(onThisDayEntriesStreamProvider);
    final today = DateTime.now();
    final monthDayLabel = JournalDateHelper.formatMonthDay(today);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.clockCounterClockwise,
                            size: 22,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'ON THIS DAY',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        monthDayLabel,
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Divider(color: colors.divider, height: 1, thickness: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIconsLight.calendarBlank,
                              size: 44,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Nothing from this date yet.',
                              style: AppTypography.headline.copyWith(
                                color: colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Your first entry here will appear next year.',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final note = entries[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _OnThisDayTile(
                                note: note,
                                onTap: () {
                                  if (onNoteSelected != null) {
                                    onNoteSelected!(note);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => EditorScreen(note: note),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (index < entries.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                  ),
                                  child: Divider(
                                    color: colors.divider.withValues(alpha: 0.6),
                                    height: 1,
                                    thickness: 0.8,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: entries.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Unable to load historical entries.',
                    style: AppTypography.bodySmall.copyWith(color: colors.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnThisDayTile extends StatelessWidget {
  const _OnThisDayTile({
    required this.note,
    required this.onTap,
  });

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateDisplay = note.journalDate != null
        ? JournalDateHelper.formatDisplayDate(note.journalDate!)
        : JournalDateHelper.formatDisplayDate(note.createdAt);

    final relativeYear = note.journalDate != null
        ? JournalDateHelper.formatRelativeYear(note.journalDate!)
        : JournalDateHelper.formatRelativeYear(note.createdAt);

    final semanticLabel = '$dateDisplay, ${note.displayTitle}, $relativeYear';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year & Relative indicator
                Row(
                  children: [
                    Text(
                      dateDisplay,
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (relativeYear.isNotEmpty) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: colors.divider.withValues(alpha: 0.8),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          relativeYear,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6.0),

                // Note Title
                Row(
                  children: [
                    if (note.isPasswordProtected) ...[
                      Icon(
                        PhosphorIconsRegular.lock,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6.0),
                    ],
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Preview Snippet
                if (note.previewSnippet.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  Text(
                    note.previewSnippet,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Tags chips if any
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: note.tags.take(4).map((tag) {
                      return Text(
                        '#$tag',
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
